# REPORTES DEL SISTEMA

# REPORTE 1 - USO DE EQUIPOS POR MES
# REPORTE 2 - DEMANDA POR SERVICIO POR MES (reporte táctico)


import calendar
import datetime
from collections import defaultdict

from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .graficos import barras_por_mes, pesos_corto
from .models import Equipos, Equipos_x_Servicios, Reservas, Reservas_x_Servicios, Servicios, Tipo_Equipos
from .permissions import permiso_modulo

# Nombres cortos de los meses, para las etiquetas del gráfico
MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

# Como mucho se pueden pedir 24 meses juntos: con más, el gráfico no se llega a leer
MAXIMO_MESES = 24


# Convierte un texto como "2026-03" en el par (2026, 3). Si viene mal escrito devuelve None.
def _leer_mes(texto):
    try:
        anio, mes = (texto or '').split('-')
        anio, mes = int(anio), int(mes)
    except ValueError:
        return None
    if 1 <= mes <= 12 and 2000 <= anio <= 2100:
        return anio, mes
    return None


# Arma la lista de todos los meses entre dos fechas, uno atrás del otro:
# de (2026, 11) a (2027, 2) devuelve [(2026, 11), (2026, 12), (2027, 1), (2027, 2)].
# Así en el gráfico aparecen también los meses sin reservas (con 0).
def _meses_entre(desde, hasta):
    meses = []
    anio, mes = desde
    while (anio, mes) <= hasta:
        meses.append((anio, mes))
        mes += 1
        if mes == 13:  # después de diciembre viene enero del año siguiente
            anio, mes = anio + 1, 1
    return meses


# Lee el período que eligió el usuario (?desde=2026-01&hasta=2026-12). Si no viene, es el año
# actual completo. Devuelve (desde, hasta, meses, error): si algo está mal, error trae la
# respuesta con el mensaje para mostrar y lo demás viene en None.
# La usan todos los reportes que muestran un número por mes.
def _leer_periodo(request):
    hoy = timezone.localdate()
    desde = _leer_mes(request.query_params.get('desde')) or (hoy.year, 1)
    hasta = _leer_mes(request.query_params.get('hasta')) or (hoy.year, 12)

    if desde > hasta:
        return None, None, None, Response({'detail': 'El mes "Desde" no puede ser posterior al mes "Hasta".'},
                                          status=status.HTTP_400_BAD_REQUEST)
    meses = _meses_entre(desde, hasta)
    if len(meses) > MAXIMO_MESES:
        return None, None, None, Response({'detail': f'El período no puede tener más de {MAXIMO_MESES} meses.'},
                                          status=status.HTTP_400_BAD_REQUEST)
    return desde, hasta, meses, None


# Las reservas del período, sin las anuladas (una reserva anulada no es demanda real)
def _reservas_del_periodo(desde, hasta):
    primer_dia = datetime.date(desde[0], desde[1], 1)
    # monthrange dice cuántos días tiene el mes (28, 29, 30 o 31)
    ultimo_dia = datetime.date(hasta[0], hasta[1], calendar.monthrange(hasta[0], hasta[1])[1])
    return Reservas.objects.filter(fecha_evento__range=(primer_dia, ultimo_dia)).exclude(estado_reserva='ANULADA')


class ReporteUsoEquiposView(APIView):
    """
    Reporte "Uso de equipos por mes".
    Se pide así: /api/reportes/uso-equipos/?desde=2026-01&hasta=2026-12
    Opcionalmente se le puede agregar &tipo=<id> para ver un solo tipo de equipo
    (por ejemplo solo Sonido) o &equipo=<id> para ver un solo equipo.
    Si no se manda el período, muestra el año actual completo.
    """
    # Solo entran los perfiles que tienen el permiso "Ver Reportes"
    permission_classes = [permiso_modulo('reportes')]

    def get(self, request):
        # ---------- 1) Leemos lo que eligió el usuario en los filtros ----------
        desde, hasta, meses, error = _leer_periodo(request)
        if error:
            return error

        tipo = request.query_params.get('tipo')
        equipo = request.query_params.get('equipo')
        tipo = int(tipo) if tipo and tipo.isdigit() else None
        equipo = int(equipo) if equipo and equipo.isdigit() else None

        # ---------- 2) Los equipos que entran en el reporte ----------
        equipos_qs = Equipos.objects.select_related('id_tipoeq').order_by('nombre_equipo')
        if tipo:
            equipos_qs = equipos_qs.filter(id_tipoeq=tipo)
        if equipo:
            equipos_qs = equipos_qs.filter(pk=equipo)
        equipos = {e.pk: e for e in equipos_qs}

        # ---------- 3) Las reservas del período (sin las anuladas) ----------
        reservas = _reservas_del_periodo(desde, hasta)

        # Los servicios de esas reservas: por cada uno, de qué reserva es y qué día es el evento
        servicios_reservados = Reservas_x_Servicios.objects.filter(id_reserva__in=reservas).values_list(
            'id_reserva_id', 'id_reserva__fecha_evento', 'id_servicio_id'
        )

        # Qué equipos usa cada servicio y cuántos: {servicio: [(equipo, cantidad), ...]}
        equipos_del_servicio = defaultdict(list)
        for id_servicio, id_equipo, cantidad in Equipos_x_Servicios.objects.values_list('id_servicio_id', 'id_equipo_id', 'cantidad'):
            equipos_del_servicio[id_servicio].append((id_equipo, cantidad))

        # ---------- 4) Sumamos ----------
        # unidades[equipo][(año, mes)] = unidades comprometidas de ese equipo en ese mes
        unidades = defaultdict(lambda: defaultdict(int))
        # por_dia[equipo][fecha] = unidades de ese equipo en un mismo día (para sacar el día de más uso)
        por_dia = defaultdict(lambda: defaultdict(int))
        # eventos[equipo] = las reservas donde se usó (para contar en cuántos eventos estuvo)
        eventos = defaultdict(set)
        # reservas_del_mes[(año, mes)] = las reservas de ese mes que usan alguno de los equipos elegidos
        reservas_del_mes = defaultdict(set)

        for id_reserva, fecha, id_servicio in servicios_reservados:
            for id_equipo, cantidad in equipos_del_servicio[id_servicio]:
                # Si el equipo quedó afuera por los filtros, no se cuenta
                if id_equipo not in equipos:
                    continue
                mes = (fecha.year, fecha.month)
                unidades[id_equipo][mes] += cantidad
                por_dia[id_equipo][fecha] += cantidad
                eventos[id_equipo].add(id_reserva)
                reservas_del_mes[mes].add(id_reserva)

        # ---------- 5) Armamos la respuesta ----------
        # Una fila por equipo, con sus unidades mes por mes
        filas = []
        for id_equipo, e in equipos.items():
            por_mes = [unidades[id_equipo][m] for m in meses]
            # El día en que más unidades de este equipo se usaron juntas
            dia_pico, maximo_dia = None, 0
            for fecha, cantidad in por_dia[id_equipo].items():
                if cantidad > maximo_dia:
                    dia_pico, maximo_dia = fecha, cantidad
            filas.append({
                'id_equipo': id_equipo,
                'nombre_equipo': e.nombre_equipo,
                'tipo': e.id_tipoeq.nombre_tipoeq,
                # Cuántas unidades tenemos de este equipo (para comparar con lo que se usa)
                'stock': e.cantidad_equipo,
                'por_mes': por_mes,
                'total': sum(por_mes),
                'eventos': len(eventos[id_equipo]),
                'maximo_dia': maximo_dia,
                'fecha_maximo': dia_pico,
            })
        # Primero los más usados; si empatan, por nombre
        filas.sort(key=lambda f: (-f['total'], f['nombre_equipo']))

        # Una columna del gráfico por mes: el total de unidades de todos los equipos elegidos
        columnas = [
            {
                'anio': anio,
                'mes': mes,
                'etiqueta': f'{MESES[mes - 1]} {anio}',
                'unidades': sum(unidades[id_equipo][(anio, mes)] for id_equipo in equipos),
                'reservas': len(reservas_del_mes[(anio, mes)]),
            }
            for anio, mes in meses
        ]

        return Response({
            'periodo': {'desde': f'{desde[0]}-{desde[1]:02d}', 'hasta': f'{hasta[0]}-{hasta[1]:02d}'},
            'meses': columnas,
            # El gráfico ya dibujado (pandas + matplotlib) y dónde quedó cada barra (ver graficos.py)
            'grafico': barras_por_mes(columnas, [c['unidades'] for c in columnas], 'Unidades'),
            'equipos': filas,
            'total_unidades': sum(c['unidades'] for c in columnas),
            # Reservas del período (no anuladas) que usan alguno de los equipos elegidos
            'total_reservas': len(set().union(*reservas_del_mes.values())) if reservas_del_mes else 0,
            # Las listas para armar los filtros de la pantalla. Van acá para que quien tiene
            # permiso de ver reportes no necesite además el permiso de Equipos.
            'opciones': {
                'tipos': [{'id': t.pk, 'nombre': t.nombre_tipoeq} for t in Tipo_Equipos.objects.order_by('nombre_tipoeq')],
                'equipos': [
                    {'id': e.pk, 'nombre': e.nombre_equipo, 'tipo': e.id_tipoeq_id}
                    for e in Equipos.objects.order_by('nombre_equipo')
                ],
            },
        })


class ReporteDemandaServiciosView(APIView):
    """
    Reporte táctico "Demanda por servicio por mes".
    Se pide así: /api/reportes/demanda-servicios/?desde=2026-01&hasta=2026-12
    Opcionalmente se le puede agregar &servicio=<id> para ver un solo servicio.
    Si no se manda el período, muestra el año actual completo.

    Por cada servicio y cada mes cuenta:
      - contrataciones: en cuántas reservas se contrató ese servicio
      - ingresos: la suma de lo que se cobró por ese servicio. Se usa el precio guardado en
        la reserva (Reservas_x_Servicios.precio_servicio), no el precio de hoy del servicio,
        para que si el precio cambió los meses viejos no se modifiquen.
    Sirve para planificar: qué servicios promocionar, en qué meses reforzar personal y
    equipos, y qué servicios casi no se piden.
    """
    # Solo entran los perfiles que tienen el permiso "Ver Reportes"
    permission_classes = [permiso_modulo('reportes')]

    def get(self, request):
        # ---------- 1) Leemos lo que eligió el usuario en los filtros ----------
        desde, hasta, meses, error = _leer_periodo(request)
        if error:
            return error

        servicio = request.query_params.get('servicio')
        servicio = int(servicio) if servicio and servicio.isdigit() else None

        # ---------- 2) Los servicios que entran en el reporte ----------
        # Van también los desactivados: pudieron haberse contratado en el período
        servicios_qs = Servicios.objects.order_by('tipo_servicio')
        if servicio:
            servicios_qs = servicios_qs.filter(pk=servicio)
        servicios = {s.pk: s for s in servicios_qs}

        # ---------- 3) Los servicios contratados en las reservas del período ----------
        # Por cada uno: de qué reserva es, qué día es el evento, qué servicio y a qué precio se cobró
        contratados = Reservas_x_Servicios.objects.filter(
            id_reserva__in=_reservas_del_periodo(desde, hasta), id_servicio__in=servicios.keys()
        ).values_list('id_reserva_id', 'id_reserva__fecha_evento', 'id_servicio_id', 'precio_servicio')

        # ---------- 4) Sumamos ----------
        # contrataciones[servicio][(año, mes)] = cuántas veces se contrató ese servicio ese mes
        contrataciones = defaultdict(lambda: defaultdict(int))
        # ingresos[servicio][(año, mes)] = cuánta plata dejó ese servicio ese mes
        ingresos = defaultdict(lambda: defaultdict(float))
        # reservas_del_mes[(año, mes)] = las reservas de ese mes que contrataron alguno de los servicios elegidos
        reservas_del_mes = defaultdict(set)

        for id_reserva, fecha, id_servicio, precio in contratados:
            mes = (fecha.year, fecha.month)
            contrataciones[id_servicio][mes] += 1
            ingresos[id_servicio][mes] += precio
            reservas_del_mes[mes].add(id_reserva)

        # ---------- 5) Armamos la respuesta ----------
        total_contrataciones = sum(sum(c.values()) for c in contrataciones.values())
        total_ingresos = sum(sum(i.values()) for i in ingresos.values())

        # Una fila por servicio, con sus números mes por mes
        filas = []
        for id_servicio, s in servicios.items():
            por_mes = [contrataciones[id_servicio][m] for m in meses]
            ingresos_por_mes = [round(ingresos[id_servicio][m], 2) for m in meses]
            total = sum(por_mes)
            total_plata = round(sum(ingresos_por_mes), 2)
            # El mes en que más se pidió este servicio (si empatan, el primero)
            mes_pico = None
            if total > 0:
                anio, mes = meses[por_mes.index(max(por_mes))]
                mes_pico = {'anio': anio, 'mes': mes, 'contrataciones': max(por_mes)}
            filas.append({
                'id_servicio': id_servicio,
                'nombre_servicio': s.tipo_servicio,
                'activo': s.activo,
                # El precio de hoy, para compararlo con el que se cobró en promedio
                'precio_actual': s.precio_servicio,
                'por_mes': por_mes,
                'ingresos_por_mes': ingresos_por_mes,
                'total': total,
                'ingresos': total_plata,
                'precio_promedio': round(total_plata / total, 2) if total else None,
                # Qué parte de toda la demanda del período se llevó este servicio
                'porcentaje': round(total * 100 / total_contrataciones, 1) if total_contrataciones else 0,
                'mes_pico': mes_pico,
            })
        # Primero los más pedidos; si empatan, el que más plata dejó, y después por nombre
        filas.sort(key=lambda f: (-f['total'], -f['ingresos'], f['nombre_servicio']))

        # Una columna del gráfico por mes: el total de todos los servicios elegidos
        columnas = [
            {
                'anio': anio,
                'mes': mes,
                'etiqueta': f'{MESES[mes - 1]} {anio}',
                'contrataciones': sum(contrataciones[id_servicio][(anio, mes)] for id_servicio in servicios),
                'ingresos': round(sum(ingresos[id_servicio][(anio, mes)] for id_servicio in servicios), 2),
                'reservas': len(reservas_del_mes[(anio, mes)]),
            }
            for anio, mes in meses
        ]

        return Response({
            'periodo': {'desde': f'{desde[0]}-{desde[1]:02d}', 'hasta': f'{hasta[0]}-{hasta[1]:02d}'},
            'meses': columnas,
            # Los dos gráficos ya dibujados (pandas + matplotlib, ver graficos.py), uno para cada opción de
            # "Ver por". Van los dos para que la pantalla cambie de uno a otro sin volver a pedir.
            'graficos': {
                'contrataciones': barras_por_mes(columnas, [c['contrataciones'] for c in columnas], 'Contrataciones'),
                'ingresos': barras_por_mes(columnas, [c['ingresos'] for c in columnas], 'Ingresos', pesos_corto),
            },
            'servicios': filas,
            'total_contrataciones': total_contrataciones,
            'total_ingresos': round(total_ingresos, 2),
            # Reservas del período (no anuladas) que contrataron alguno de los servicios elegidos
            'total_reservas': len(set().union(*reservas_del_mes.values())) if reservas_del_mes else 0,
            # La lista para armar el filtro de la pantalla. Va acá para que quien tiene
            # permiso de ver reportes no necesite además el permiso de Servicios.
            'opciones': {
                'servicios': [
                    {'id': s.pk, 'nombre': s.tipo_servicio, 'activo': s.activo}
                    for s in Servicios.objects.order_by('tipo_servicio')
                ],
            },
        })
