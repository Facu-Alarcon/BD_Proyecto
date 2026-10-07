# Disponibilidad de equipos por día.
#
# Un equipo no tiene un estado "en uso" fijo: depende del día. Si el sábado hay una reserva
# que usa 4 bafles, esos 4 bafles están ocupados el sábado, pero el domingo están libres.
# Por eso la disponibilidad no se guarda en la tabla Equipos, se CALCULA para cada fecha:
#
#   libres = unidades del equipo - unidades que usan las reservas de ese día
#
# Qué reservas ocupan equipos: las Pendientes y las Confirmadas (también las Finalizadas,
# que ya pasaron). Las Anuladas no: al anular una reserva sus equipos quedan libres solos.
# Cuánto usa cada reserva sale de sus servicios: cada servicio dice qué equipos usa y
# cuántas unidades (tabla Equipos_x_Servicios).
#
# Los equipos "En reparación" (estado físico guardado en la tabla) no están disponibles
# ningún día, tengan o no reservas.
#
# Lo usan:
#   - ReservasSerializer._validar_equipos: no deja guardar una reserva si faltan equipos.
#   - La acción "Confirmar" de las reservas: vuelve a controlar antes de confirmar.
#   - /api/reservas/disponibilidad/: el formulario de reserva marca qué servicios no se
#     pueden contratar el día elegido.
#   - El resumen de Inicio: cuántas unidades están ocupadas hoy.
#
# El personal sigue la misma idea (más simple): un empleado asignado a una reserva
# pendiente o confirmada está ocupado todo ese día y no se lo puede asignar a otra.

from collections import Counter

from .models import Detalles_Reservas, Equipos, Equipos_x_Servicios, Reservas_x_Servicios


# Un equipo está fuera de servicio si su estado físico es "En reparación"
def fuera_de_servicio(equipo):
    return 'reparac' in equipo.id_estadoeq.nombre_estadoeq.lower()


# Unidades de cada equipo ocupadas por las reservas de un día: {id_equipo: unidades}.
# excluir_reserva sirve al editar una reserva, para que no se cuente a sí misma.
def unidades_ocupadas(fecha, excluir_reserva=None):
    otras = Reservas_x_Servicios.objects.filter(id_reserva__fecha_evento=fecha).exclude(
        id_reserva__estado_reserva='ANULADA'
    )
    if excluir_reserva is not None:
        otras = otras.exclude(id_reserva=excluir_reserva)
    # Cuántas veces aparece cada servicio ese día (un mismo combo puede estar en dos reservas)
    servicios_del_dia = Counter(otras.values_list('id_servicio_id', flat=True))

    ocupadas = Counter()
    for rel in Equipos_x_Servicios.objects.filter(id_servicio__in=servicios_del_dia):
        ocupadas[rel.id_equipo_id] += rel.cantidad * servicios_del_dia[rel.id_servicio_id]
    return ocupadas


# Estado de todos los equipos activos en un día: cuántas unidades tiene, cuántas están
# ocupadas por reservas y cuántas quedan libres
def disponibilidad_del_dia(fecha, excluir_reserva=None):
    ocupadas = unidades_ocupadas(fecha, excluir_reserva)
    resultado = []
    for equipo in Equipos.objects.activos().select_related('id_estadoeq').order_by('nombre_equipo'):
        reparacion = fuera_de_servicio(equipo)
        usadas = ocupadas[equipo.pk]
        resultado.append({
            'id_equipo': equipo.pk,
            'nombre_equipo': equipo.nombre_equipo,
            'total': equipo.cantidad_equipo,
            'ocupadas': usadas,
            # En reparación no queda ninguna libre; si no, lo que sobra (nunca negativo)
            'libres': 0 if reparacion else max(equipo.cantidad_equipo - usadas, 0),
            'en_reparacion': reparacion,
        })
    return resultado


# Revisa si alcanzan los equipos para un conjunto de servicios en una fecha.
# Devuelve la lista de faltantes en texto (vacía si alcanza todo).
def equipos_faltantes(servicios, fecha, excluir_reserva=None):
    # Unidades que piden los servicios: {id_equipo: unidades}
    pedidos = Counter()
    for rel in Equipos_x_Servicios.objects.filter(id_servicio__in=servicios):
        pedidos[rel.id_equipo_id] += rel.cantidad
    if not pedidos:
        return []

    ocupadas = unidades_ocupadas(fecha, excluir_reserva)
    faltantes = []
    for equipo in Equipos.objects.filter(pk__in=pedidos).select_related('id_estadoeq'):
        if fuera_de_servicio(equipo):
            faltantes.append(f'{equipo.nombre_equipo} (está en reparación)')
            continue
        libres = equipo.cantidad_equipo - ocupadas[equipo.pk]
        if pedidos[equipo.pk] > libres:
            faltantes.append(f'{equipo.nombre_equipo} (se necesitan {pedidos[equipo.pk]}, quedan {max(libres, 0)} libres)')
    return faltantes


# Empleados que ya trabajan en alguna reserva ese día (sin contar las anuladas): {id_empleado}.
# Lo usan el control al guardar una reserva y el formulario, que los muestra como no disponibles.
def empleados_ocupados(fecha, excluir_reserva=None):
    ocupados = Detalles_Reservas.objects.filter(id_reserva__fecha_evento=fecha).exclude(
        id_reserva__estado_reserva='ANULADA'
    )
    if excluir_reserva is not None:
        ocupados = ocupados.exclude(id_reserva=excluir_reserva)
    return set(ocupados.values_list('id_empleado_id', flat=True))
