"""
Finalización automática de reservas.

Cuando un evento ya terminó (fecha + hora + duración), la reserva Confirmada pasa sola a
Finalizada, y queda anotado en el registro de actividad como hecho por "Sistema".
Las Pendientes no se tocan: si nunca se confirmó no está claro que el evento se haya
hecho, así que las resuelve el administrador (finalizándolas o anulándolas).

No hay un programa aparte corriendo todo el tiempo: la revisión la hace el middleware de
abajo cuando llega cualquier pedido a la API, como mucho una vez cada pocos minutos.
Así, apenas alguien usa el sistema, las reservas vencidas ya aparecen finalizadas.
"""
import datetime
import logging

from django.utils import timezone

from .models import Registro_Actividad, Reservas
from .registro import registrar

logger = logging.getLogger('infinito_sonido.registro')

# Cada cuánto se vuelve a revisar (no hace falta hacerlo en cada pedido)
MINUTOS_ENTRE_REVISIONES = 5


# Fecha y hora en que termina el evento: empieza a la hora del evento y dura lo que dice la duración
def fin_del_evento(fecha, hora, duracion):
    inicio = datetime.datetime.combine(fecha, hora)
    return inicio + datetime.timedelta(hours=duracion.hour, minutes=duracion.minute)


# ¿El evento ya terminó? (se compara con la hora de Argentina)
def evento_terminado(fecha, hora, duracion):
    ahora = timezone.localtime().replace(tzinfo=None)
    return fin_del_evento(fecha, hora, duracion) <= ahora


# Pasa a Finalizada las reservas Confirmadas cuyo evento ya terminó.
# Devuelve cuántas finalizó.
def finalizar_reservas_vencidas():
    hoy = timezone.localdate()
    # Primero se filtra en la base por fecha (hasta hoy) y después se mira la hora exacta
    candidatas = Reservas.objects.filter(estado_reserva='CONFIRMADA', fecha_evento__lte=hoy).select_related('id_cliente')
    finalizadas = 0
    for reserva in candidatas:
        if not evento_terminado(reserva.fecha_evento, reserva.hora_evento, reserva.duracion_evento):
            continue
        reserva.estado_reserva = 'FINALIZADA'
        reserva.save(update_fields=['estado_reserva'])
        finalizadas += 1
        registrar(
            None, Registro_Actividad.MODIFICACION, str(reserva), 'Reservas', reserva.pk,
            'Estado: Confirmada → Finalizada (automático: el evento ya terminó)',
            usuario_texto='Sistema',
            cambios=[{'campo': 'Estado', 'anterior': 'Confirmada', 'nuevo': 'Finalizada'}],
        )
    return finalizadas


class FinalizarReservasMiddleware:
    """
    Antes de atender un pedido a la API, revisa si hay reservas para finalizar.
    Para no hacer consultas de más, lo hace como mucho una vez cada MINUTOS_ENTRE_REVISIONES.
    Si algo falla se anota en el log y el pedido sigue normalmente.
    """
    ultima_revision = None

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith('/api/'):
            ahora = timezone.now()
            ultima = FinalizarReservasMiddleware.ultima_revision
            if ultima is None or ahora - ultima >= datetime.timedelta(minutes=MINUTOS_ENTRE_REVISIONES):
                FinalizarReservasMiddleware.ultima_revision = ahora
                try:
                    finalizar_reservas_vencidas()
                except Exception:
                    logger.exception('No se pudieron finalizar las reservas vencidas')
        return self.get_response(request)
