# REPORTES DEL SISTEMA

# REPORTE 1 - USO DE EQUIPOS POR MES
# REPORTE 2 - DEMANDA POR SERVICIO POR MES (reporte táctico)
# REPORTE 3 - EVOLUCIÓN MENSUAL DE INGRESOS Y EVENTOS
# REPORTE 4 - COMPARACIÓN DE PERÍODOS
# REPORTE 5 - CARGA DE TRABAJO DE LOS EMPLEADOS

import calendar
import datetime
from collections import defaultdict

from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .graficos import barras_por_mes, pesos_corto
from .models import Equipos, Equipos_x_Servicios, Reservas, Reservas_x_Servicios, Servicios, Tipo_Equipos
from .models import Detalles_Reservas, Empleados, Puestos, Puestos_x_Empleados
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


# REPORTE 3 - EVOLUCIÓN MENSUAL DE INGRESOS Y EVENTOS

# Calcula cuánto creció o bajó un valor respecto del anterior, en porcentaje.
# Si antes era 0 no se puede calcular (no se puede dividir por cero) y devuelve None.
def _variacion(actual, anterior):
    if not anterior:
        return None
    return round((actual - anterior) / anterior * 100, 1)


class ReporteEvolucionIngresosView(APIView):
    """
    Reporte "Evolución mensual de ingresos contratados y cantidad de eventos".
    Se pide así: /api/reportes/evolucion-ingresos/?desde=2026-01&hasta=2026-12
    Los "ingresos contratados" son lo que suman las reservas (monto_total), no lo que
    ya se cobró. Cada reserva cuenta en el mes de su fecha de evento y las anuladas no entran.
    Si no se manda el período, muestra el año actual completo.
    """
    # Solo entran los perfiles que tienen el permiso "Ver Reportes"
    permission_classes = [permiso_modulo('reportes')]

    def get(self, request):
        # ---------- 1) Leemos el período que eligió el usuario ----------
        hoy = timezone.localdate()
        desde = _leer_mes(request.query_params.get('desde')) or (hoy.year, 1)
        hasta = _leer_mes(request.query_params.get('hasta')) or (hoy.year, 12)

        if desde > hasta:
            return Response({'detail': 'El mes "Desde" no puede ser posterior al mes "Hasta".'},
                            status=status.HTTP_400_BAD_REQUEST)
        meses = _meses_entre(desde, hasta)
        if len(meses) > MAXIMO_MESES:
            return Response({'detail': f'El período no puede tener más de {MAXIMO_MESES} meses.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # ---------- 2) Las reservas del período (sin las anuladas) ----------
        primer_dia = datetime.date(desde[0], desde[1], 1)
        ultimo_dia = datetime.date(hasta[0], hasta[1], calendar.monthrange(hasta[0], hasta[1])[1])
        reservas = Reservas.objects.filter(
            fecha_evento__range=(primer_dia, ultimo_dia)
        ).exclude(estado_reserva='ANULADA').values_list('fecha_evento', 'monto_total')

        # ---------- 3) Sumamos mes por mes ----------
        # ingresos[(año, mes)] = plata contratada ese mes; eventos[(año, mes)] = cuántas reservas
        ingresos = defaultdict(float)
        eventos = defaultdict(int)
        for fecha, monto in reservas:
            mes = (fecha.year, fecha.month)
            ingresos[mes] += monto
            eventos[mes] += 1

        # ---------- 4) Armamos una columna por mes, comparada con el mes anterior ----------
        columnas = []
        ingresos_anterior, eventos_anterior = None, None
        for anio, mes in meses:
            ingresos_mes = round(ingresos[(anio, mes)], 2)
            eventos_mes = eventos[(anio, mes)]
            columnas.append({
                'anio': anio,
                'mes': mes,
                'etiqueta': f'{MESES[mes - 1]} {anio}',
                'ingresos': ingresos_mes,
                'eventos': eventos_mes,
                # El primer mes del período no tiene con qué compararse
                'variacion_ingresos': None if ingresos_anterior is None else _variacion(ingresos_mes, ingresos_anterior),
                'variacion_eventos': None if eventos_anterior is None else _variacion(eventos_mes, eventos_anterior),
            })
            ingresos_anterior, eventos_anterior = ingresos_mes, eventos_mes

        total_ingresos = round(sum(c['ingresos'] for c in columnas), 2)
        total_eventos = sum(c['eventos'] for c in columnas)

        return Response({
            'periodo': {'desde': f'{desde[0]}-{desde[1]:02d}', 'hasta': f'{hasta[0]}-{hasta[1]:02d}'},
            'meses': columnas,
            # Los dos gráficos ya dibujados (pandas + matplotlib) y dónde quedó cada barra (ver graficos.py)
            'graficos': {
                'ingresos': barras_por_mes(columnas, [c['ingresos'] for c in columnas], 'Ingresos', pesos_corto),
                'eventos': barras_por_mes(columnas, [c['eventos'] for c in columnas], 'Eventos'),
            },
            'total_ingresos': total_ingresos,
            'total_eventos': total_eventos,
            'promedio_mensual_ingresos': round(total_ingresos / len(meses), 2),
            # Variación entre el primer y el último mes del período, para ver el crecimiento general
            'variacion_total_ingresos': _variacion(columnas[-1]['ingresos'], columnas[0]['ingresos']),
        })



# REPORTE 4 - COMPARACIÓN DE PERÍODOS

# Cuántos meses tiene cada tipo de período
MESES_POR_PERIODO = {'trimestre': 3, 'semestre': 6}


# Devuelve el primer y el último día de un período. Por ejemplo, el trimestre 2 de 2026
# (abril, mayo y junio) va del 2026-04-01 al 2026-06-30.
def _rango_periodo(anio, tipo, numero):
    largo = MESES_POR_PERIODO[tipo]
    primer_mes = (numero - 1) * largo + 1
    ultimo_mes = primer_mes + largo - 1
    primer_dia = datetime.date(anio, primer_mes, 1)
    ultimo_dia = datetime.date(anio, ultimo_mes, calendar.monthrange(anio, ultimo_mes)[1])
    return primer_dia, ultimo_dia


# Suma, por servicio, lo contratado en un rango de fechas (sin las reservas anuladas).
# Devuelve {id_servicio: {'nombre': ..., 'ingresos': ..., 'contrataciones': ...}}
def _contratado_por_servicio(primer_dia, ultimo_dia):
    filas = Reservas_x_Servicios.objects.filter(
        id_reserva__fecha_evento__range=(primer_dia, ultimo_dia)
    ).exclude(id_reserva__estado_reserva='ANULADA').values_list(
        'id_servicio_id', 'id_servicio__tipo_servicio', 'precio_servicio'
    )
    resultado = {}
    for id_servicio, nombre, precio in filas:
        datos = resultado.setdefault(id_servicio, {'nombre': nombre, 'ingresos': 0.0, 'contrataciones': 0})
        datos['ingresos'] += precio
        datos['contrataciones'] += 1
    return resultado


class ReporteComparacionPeriodosView(APIView):
    """
    Reporte "Comparación de períodos": un trimestre o semestre contra el mismo del año
    anterior, por servicio, para decidir dónde concentrar los recursos.
    Se pide así: /api/reportes/comparacion-periodos/?tipo=trimestre&numero=2&anio=2026
    - tipo: "trimestre" (numero de 1 a 4) o "semestre" (numero 1 o 2)
    - anio: el año que se quiere mirar; se lo compara con anio - 1
    Si no se manda nada, compara el trimestre actual contra el mismo del año pasado.
    Los ingresos son lo contratado (precio del servicio al reservar) en reservas no anuladas,
    contadas según su fecha de evento.
    """
    # Solo entran los perfiles que tienen el permiso "Ver Reportes"
    permission_classes = [permiso_modulo('reportes')]

    def get(self, request):
        # ---------- 1) Leemos y validamos lo que eligió el usuario ----------
        hoy = timezone.localdate()
        tipo = request.query_params.get('tipo') or 'trimestre'
        if tipo not in MESES_POR_PERIODO:
            return Response({'detail': 'El tipo de período debe ser "trimestre" o "semestre".'},
                            status=status.HTTP_400_BAD_REQUEST)

        maximo_numero = 12 // MESES_POR_PERIODO[tipo]  # 4 trimestres o 2 semestres por año
        numero = request.query_params.get('numero')
        if numero is None:
            # Sin número: el período en el que estamos hoy
            numero = (hoy.month - 1) // MESES_POR_PERIODO[tipo] + 1
        elif numero.isdigit() and 1 <= int(numero) <= maximo_numero:
            numero = int(numero)
        else:
            return Response({'detail': f'El número de {tipo} debe estar entre 1 y {maximo_numero}.'},
                            status=status.HTTP_400_BAD_REQUEST)

        anio = request.query_params.get('anio')
        if anio is None:
            anio = hoy.year
        elif anio.isdigit() and 2001 <= int(anio) <= 2100:  # 2001 porque también se mira el año anterior
            anio = int(anio)
        else:
            return Response({'detail': 'El año no es válido.'}, status=status.HTTP_400_BAD_REQUEST)

        # ---------- 2) Los dos períodos: el elegido y el mismo del año anterior ----------
        desde_actual, hasta_actual = _rango_periodo(anio, tipo, numero)
        desde_anterior, hasta_anterior = _rango_periodo(anio - 1, tipo, numero)
        actual = _contratado_por_servicio(desde_actual, hasta_actual)
        anterior = _contratado_por_servicio(desde_anterior, hasta_anterior)

        # ---------- 3) Una fila por servicio que se contrató en alguno de los dos períodos ----------
        sin_datos = {'nombre': '', 'ingresos': 0.0, 'contrataciones': 0}
        filas = []
        for id_servicio in set(actual) | set(anterior):
            a = actual.get(id_servicio, sin_datos)
            b = anterior.get(id_servicio, sin_datos)
            ingresos_a, ingresos_b = round(a['ingresos'], 2), round(b['ingresos'], 2)
            filas.append({
                'id_servicio': id_servicio,
                'nombre_servicio': a['nombre'] or b['nombre'],
                'actual': {'ingresos': ingresos_a, 'contrataciones': a['contrataciones']},
                'anterior': {'ingresos': ingresos_b, 'contrataciones': b['contrataciones']},
                'diferencia_ingresos': round(ingresos_a - ingresos_b, 2),
                'variacion_ingresos': _variacion(ingresos_a, ingresos_b),
                'variacion_contrataciones': _variacion(a['contrataciones'], b['contrataciones']),
            })
        # Primero los servicios que más ingresos dieron en el período actual; si empatan, por nombre
        filas.sort(key=lambda f: (-f['actual']['ingresos'], f['nombre_servicio']))

        total_actual = round(sum(f['actual']['ingresos'] for f in filas), 2)
        total_anterior = round(sum(f['anterior']['ingresos'] for f in filas), 2)
        contrataciones_actual = sum(f['actual']['contrataciones'] for f in filas)
        contrataciones_anterior = sum(f['anterior']['contrataciones'] for f in filas)

        return Response({
            'periodo': {
                'tipo': tipo,
                'numero': numero,
                'anio': anio,
                'actual': {'etiqueta': f'{numero}º {tipo} {anio}', 'desde': desde_actual, 'hasta': hasta_actual},
                'anterior': {'etiqueta': f'{numero}º {tipo} {anio - 1}', 'desde': desde_anterior, 'hasta': hasta_anterior},
            },
            'servicios': filas,
            'totales': {
                'actual': {'ingresos': total_actual, 'contrataciones': contrataciones_actual},
                'anterior': {'ingresos': total_anterior, 'contrataciones': contrataciones_anterior},
                'diferencia_ingresos': round(total_actual - total_anterior, 2),
                'variacion_ingresos': _variacion(total_actual, total_anterior),
            },
        })

# REPORTE 5 - CARGA DE TRABAJO DE LOS EMPLEADOS (reporte táctico)

class ReporteCargaEmpleadosView(APIView):
    """
    Reporte táctico "Carga de trabajo de los empleados".
    Se pide así: /api/reportes/carga-empleados/?desde=2026-01&hasta=2026-12
    Opcionalmente se le puede agregar &puesto=<id> para ver un solo puesto o
    &empleado=<id> para ver un solo empleado.
    Si no se manda el período, muestra el año actual completo.

    Cuenta los eventos a los que fue asignado cada empleado (Detalles_Reservas), mes por mes.
    Cada evento cuenta en el mes de su fecha de evento y las reservas anuladas no entran.
    También se puede mirar agrupado por puesto: ahí cada asignación (un empleado en un evento)
    suma al puesto del empleado. Si un empleado tiene más de un puesto, suma en cada uno.
    Sirve para repartir mejor el trabajo, ver quién está sobrecargado y en qué meses
    hace falta más personal.
    """
    # Solo entran los perfiles que tienen el permiso "Ver Reportes"
    permission_classes = [permiso_modulo('reportes')]

    def get(self, request):
        # ---------- 1) Leemos lo que eligió el usuario en los filtros ----------
        desde, hasta, meses, error = _leer_periodo(request)
        if error:
            return error

        puesto = request.query_params.get('puesto')
        empleado = request.query_params.get('empleado')
        puesto = int(puesto) if puesto and puesto.isdigit() else None
        empleado = int(empleado) if empleado and empleado.isdigit() else None

        # ---------- 2) Los empleados que entran en el reporte ----------
        # Van también los desactivados: pudieron haber trabajado en el período
        empleados_qs = Empleados.objects.order_by('apellido_emp', 'nombre_emp')
        if empleado:
            empleados_qs = empleados_qs.filter(pk=empleado)
        if puesto:
            empleados_qs = empleados_qs.filter(
                pk__in=Puestos_x_Empleados.objects.filter(id_puesto=puesto).values('id_empleado')
            )
        empleados = {e.pk: e for e in empleados_qs}

        # Los puestos de cada empleado: {empleado: [(id_puesto, nombre), ...]}
        puestos_del_empleado = defaultdict(list)
        for id_empleado, id_puesto, nombre in Puestos_x_Empleados.objects.order_by(
            'id_puesto__nombre_puesto'
        ).values_list('id_empleado_id', 'id_puesto_id', 'id_puesto__nombre_puesto'):
            puestos_del_empleado[id_empleado].append((id_puesto, nombre))

        # ---------- 3) Las asignaciones de las reservas del período (sin las anuladas) ----------
        reservas = _reservas_del_periodo(desde, hasta)
        # Por cada una: en qué reserva, qué día es el evento y qué empleado
        asignaciones = Detalles_Reservas.objects.filter(
            id_reserva__in=reservas, id_empleado__in=empleados.keys()
        ).values_list('id_reserva_id', 'id_reserva__fecha_evento', 'id_empleado_id')

        # ---------- 4) Sumamos ----------
        # eventos[empleado][(año, mes)] = las reservas de ese mes en las que trabajó el empleado
        eventos = defaultdict(lambda: defaultdict(set))
        # reservas_del_mes[(año, mes)] = las reservas de ese mes que tienen personal (de los elegidos)
        reservas_del_mes = defaultdict(set)
        for id_reserva, fecha, id_empleado in asignaciones:
            mes = (fecha.year, fecha.month)
            eventos[id_empleado][mes].add(id_reserva)
            reservas_del_mes[mes].add(id_reserva)

        # Cuántos eventos tuvo cada empleado por mes, en el mismo orden que la lista de meses
        por_mes_del_empleado = {
            id_empleado: [len(eventos[id_empleado][m]) for m in meses] for id_empleado in empleados
        }
        total_asignaciones = sum(sum(v) for v in por_mes_del_empleado.values())

        # El mes en que más trabajó (si empatan, el primero): {anio, mes, eventos} o None
        def mes_pico(por_mes):
            if not any(por_mes):
                return None
            anio, mes = meses[por_mes.index(max(por_mes))]
            return {'anio': anio, 'mes': mes, 'eventos': max(por_mes)}

        # ---------- 5) Armamos la respuesta ----------
        # Una fila por empleado, con sus eventos mes por mes
        filas_empleados = []
        for id_empleado, e in empleados.items():
            por_mes = por_mes_del_empleado[id_empleado]
            total = sum(por_mes)
            filas_empleados.append({
                'id_empleado': id_empleado,
                'nombre_empleado': f'{e.apellido_emp}, {e.nombre_emp}',
                'activo': e.activo,
                'puestos': [nombre for _, nombre in puestos_del_empleado[id_empleado]],
                'por_mes': por_mes,
                'total': total,
                # Qué parte de todo el trabajo del período se llevó este empleado
                'porcentaje': round(total * 100 / total_asignaciones, 1) if total_asignaciones else 0,
                'promedio_mensual': round(total / len(meses), 1),
                'mes_pico': mes_pico(por_mes),
            })
        # Primero los que más trabajaron; si empatan, por nombre
        filas_empleados.sort(key=lambda f: (-f['total'], f['nombre_empleado']))

        # Una fila por puesto: suma lo de todos los empleados que tienen ese puesto
        empleados_del_puesto = defaultdict(list)
        nombre_del_puesto = {}
        for id_empleado in empleados:
            for id_puesto, nombre in puestos_del_empleado[id_empleado]:
                empleados_del_puesto[id_puesto].append(id_empleado)
                nombre_del_puesto[id_puesto] = nombre
        filas_puestos = []
        for id_puesto, ids in empleados_del_puesto.items():
            por_mes = [sum(por_mes_del_empleado[i][n] for i in ids) for n in range(len(meses))]
            total = sum(por_mes)
            filas_puestos.append({
                'id_puesto': id_puesto,
                'nombre_puesto': nombre_del_puesto[id_puesto],
                'empleados': len(ids),
                'por_mes': por_mes,
                'total': total,
                'porcentaje': round(total * 100 / total_asignaciones, 1) if total_asignaciones else 0,
                # Cuántos eventos le tocaron en promedio a cada persona del puesto
                'promedio_por_empleado': round(total / len(ids), 1),
                'mes_pico': mes_pico(por_mes),
            })
        filas_puestos.sort(key=lambda f: (-f['total'], f['nombre_puesto']))

        # Una columna del gráfico por mes: el total de asignaciones (un empleado en un evento)
        columnas = []
        for n, (anio, mes) in enumerate(meses):
            columnas.append({
                'anio': anio,
                'mes': mes,
                'etiqueta': f'{MESES[mes - 1]} {anio}',
                'asignaciones': sum(por_mes_del_empleado[i][n] for i in empleados),
                'reservas': len(reservas_del_mes[(anio, mes)]),
                # Cuántos empleados distintos trabajaron ese mes
                'empleados': sum(1 for i in empleados if por_mes_del_empleado[i][n] > 0),
            })

        # Reservas del período que todavía no tienen ningún empleado asignado
        # (se calcula sobre todas las reservas, sin importar los filtros)
        sin_personal = reservas.exclude(pk__in=Detalles_Reservas.objects.values('id_reserva')).count()

        return Response({
            'periodo': {'desde': f'{desde[0]}-{desde[1]:02d}', 'hasta': f'{hasta[0]}-{hasta[1]:02d}'},
            'meses': columnas,
            # El gráfico ya dibujado (pandas + matplotlib) y dónde quedó cada barra (ver graficos.py)
            'grafico': barras_por_mes(columnas, [c['asignaciones'] for c in columnas], 'Eventos asignados'),
            'empleados': filas_empleados,
            'puestos': filas_puestos,
            'total_asignaciones': total_asignaciones,
            # Reservas del período (no anuladas) que tienen personal de los elegidos
            'total_reservas': len(set().union(*reservas_del_mes.values())) if reservas_del_mes else 0,
            'reservas_sin_personal': sin_personal,
            # Las listas para armar los filtros de la pantalla. Van acá para que quien tiene
            # permiso de ver reportes no necesite además los permisos de Empleados y Puestos.
            'opciones': {
                'puestos': [{'id': p.pk, 'nombre': p.nombre_puesto} for p in Puestos.objects.order_by('nombre_puesto')],
                'empleados': [
                    {
                        'id': e.pk,
                        'nombre': f'{e.apellido_emp}, {e.nombre_emp}',
                        'activo': e.activo,
                        # Para que la pantalla muestre solo los empleados del puesto elegido
                        'puestos': [p for p, _ in puestos_del_empleado[e.pk]],
                    }
                    for e in Empleados.objects.order_by('apellido_emp', 'nombre_emp')
                ],
            },
        })