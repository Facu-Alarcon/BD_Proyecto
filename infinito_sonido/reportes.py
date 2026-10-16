# REPORTES DEL SISTEMA

# REPORTE 1 - USO DE EQUIPOS POR MES


import calendar
import datetime
from collections import defaultdict

from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Equipos, Equipos_x_Servicios, Reservas, Reservas_x_Servicios, Tipo_Equipos
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
        primer_dia = datetime.date(desde[0], desde[1], 1)
        # monthrange dice cuántos días tiene el mes (28, 29, 30 o 31)
        ultimo_dia = datetime.date(hasta[0], hasta[1], calendar.monthrange(hasta[0], hasta[1])[1])
        reservas = Reservas.objects.filter(fecha_evento__range=(primer_dia, ultimo_dia)).exclude(estado_reserva='ANULADA')

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


#REPORTE N°2:

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
            'total_ingresos': total_ingresos,
            'total_eventos': total_eventos,
            'promedio_mensual_ingresos': round(total_ingresos / len(meses), 2),
            # Variación entre el primer y el último mes del período, para ver el crecimiento general
            'variacion_total_ingresos': _variacion(columnas[-1]['ingresos'], columnas[0]['ingresos']),
        })



# REPORTE N°3 - COMPARACIÓN DE PERÍODOS

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