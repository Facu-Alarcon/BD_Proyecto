# REGLAS DE ALERTA (Parcial 2, módulo M3)
#
# Cada regla revisa una condición sobre las reservas y, si se cumple, guarda un aviso en
# la tabla Notificacion para los perfiles que tienen que enterarse:
#
#   SALDO_PENDIENTE -> la reserva tiene saldo sin pagar y el evento es dentro de pocos días.
#                      Va a quien gestiona pagos y además se manda por correo.
#   SIN_CONFIRMAR   -> la reserva sigue Pendiente y el evento es dentro de pocos días.
#                      Va a quien gestiona reservas.
#   MONTO_INUSUAL   -> el monto de una reserva nueva está muy por encima de lo normal
#                      (más de N desvíos sobre el promedio). Va a quien ve los reportes.
#
# Los umbrales (cuántos días, cuántos desvíos) se leen de la tabla Configuracion.
#
# Cuándo se revisan:
#   - En el momento, al registrar o modificar una reserva y al anular un pago (evaluar_reserva).
#   - Una vez por día, con el comando "python manage.py evaluar_alertas" (evaluar_todas), que
#     el contenedor web corre solo al arrancar y cada 24 horas (ver docker-compose.yml).
#
# Para no repetir avisos: la tabla tiene una restricción única (tipo, reserva, perfil), y acá
# se usa get_or_create, que solo crea el aviso si todavía no existe.

import datetime
import logging

import numpy as np
from django.db import IntegrityError, transaction
from django.db.models import Sum
from django.utils import timezone

from .correos import enviar_alerta
from .models import Configuracion, Notificacion, Pagos, Perfiles, Reservas, Usuarios

logger = logging.getLogger(__name__)

# Qué permiso tiene que tener un perfil para recibir cada tipo de aviso, y si además va por correo
REGLAS = {
    Notificacion.SALDO_PENDIENTE: {'permiso': 'gestionar_pagos', 'correo': True},
    Notificacion.SIN_CONFIRMAR: {'permiso': 'gestionar_reservas', 'correo': False},
    Notificacion.MONTO_INUSUAL: {'permiso': 'ver_reportes', 'correo': False},
}

# Estados en los que una reserva todavía puede generar avisos (las anuladas y las finalizadas no)
ESTADOS_VIGENTES = ['PENDIENTE', 'CONFIRMADA']


# Lee un parámetro de la tabla Configuracion como número. Si no está o está mal cargado,
# usa el valor por defecto, así una configuración rota no deja al sistema sin alertas.
def parametro(clave, por_defecto):
    try:
        return float(Configuracion.objects.get(clave=clave).valor.replace(',', '.'))
    except (Configuracion.DoesNotExist, ValueError):
        logger.warning('Parámetro %s faltante o mal cargado; se usa %s', clave, por_defecto)
        return por_defecto


# Los perfiles que reciben un tipo de aviso: los que tienen el permiso de la regla.
# Así, si mañana se crea un perfil "Encargado" con permiso de pagos, también le llegan.
def perfiles_destino(tipo):
    return list(Perfiles.objects.filter(permisos_x_perfiles__id_permiso__codigo=REGLAS[tipo]['permiso']).distinct())


# Lo que le falta pagar a una reserva: el monto total menos los pagos vigentes (RN14)
def saldo_de(reserva):
    pagado = Pagos.objects.activos().filter(id_reserva=reserva).aggregate(total=Sum('monto'))['total'] or 0
    return max(reserva.monto_total - pagado, 0)


# "es hoy", "es mañana" o "faltan 5 días", para que el aviso se lea natural
def cuando(fecha, hoy):
    faltan = (fecha - hoy).days
    if faltan == 0:
        return 'es hoy'
    if faltan == 1:
        return 'es mañana'
    return f'faltan {faltan} días'


# Escribe la plata como en el resto del sistema: $ 700.000
def pesos(valor):
    return f'$ {valor:,.0f}'.replace(',', '.')


# Guarda el aviso para cada perfil que lo tiene que recibir, si todavía no existía.
# Devuelve cuántos avisos nuevos se crearon.
def notificar(tipo, reserva, mensaje):
    nuevos = 0
    for perfil in perfiles_destino(tipo):
        try:
            # El savepoint (atomic) hace que, si la restricción única rechaza un repetido,
            # no se arruine el resto de lo que se está guardando
            with transaction.atomic():
                aviso, creado = Notificacion.objects.get_or_create(
                    tipo=tipo, id_objeto=reserva.pk, destino_perfil=perfil,
                    defaults={'mensaje': mensaje[:255]},
                )
        except IntegrityError:
            # Otro proceso lo creó justo al mismo tiempo: ya existe, no hay nada que hacer
            continue
        if not creado:
            continue
        nuevos += 1
        if REGLAS[tipo]['correo']:
            # El correo sale recién cuando se confirma lo que se está guardando: si algo
            # falla y se deshace, no se manda un mail de un aviso que no existe
            transaction.on_commit(lambda p=perfil, m=mensaje, t=aviso.get_tipo_display(): _mandar_correo(p, t, m))
    return nuevos


# Manda el aviso por correo a los usuarios activos del perfil que tienen mail cargado
def _mandar_correo(perfil, titulo, mensaje):
    correos = list(
        Usuarios.objects.filter(id_perfil=perfil, activo=True)
        .exclude(id_empleado__email_emp='')
        .values_list('id_empleado__email_emp', flat=True)
    )
    if correos:
        enviar_alerta(correos, titulo, mensaje)


# ---------------------------------------------------------------------------
# REGLA: saldo pendiente cerca del evento
# ---------------------------------------------------------------------------

def revisar_saldo_pendiente(reservas):
    dias = int(parametro('DIAS_AVISO_SALDO', 7))
    hoy = timezone.localdate()
    limite = hoy + datetime.timedelta(days=dias)
    nuevos = 0
    for reserva in reservas.filter(estado_reserva__in=ESTADOS_VIGENTES, fecha_evento__range=(hoy, limite)):
        saldo = saldo_de(reserva)
        if saldo > 0:
            nuevos += notificar(
                Notificacion.SALDO_PENDIENTE, reserva,
                f'La reserva N° {reserva.pk} de {reserva.id_cliente} tiene {pesos(saldo)} sin pagar '
                f'y el evento es el {reserva.fecha_evento:%d/%m/%Y} ({cuando(reserva.fecha_evento, hoy)}).',
            )
    return nuevos


# ---------------------------------------------------------------------------
# REGLA: reserva sin confirmar cerca del evento
# ---------------------------------------------------------------------------

def revisar_sin_confirmar(reservas):
    dias = int(parametro('DIAS_AVISO_CONFIRMACION', 10))
    hoy = timezone.localdate()
    limite = hoy + datetime.timedelta(days=dias)
    nuevos = 0
    for reserva in reservas.filter(estado_reserva='PENDIENTE', fecha_evento__range=(hoy, limite)):
        nuevos += notificar(
            Notificacion.SIN_CONFIRMAR, reserva,
            f'La reserva N° {reserva.pk} de {reserva.id_cliente} sigue Pendiente y el evento es el '
            f'{reserva.fecha_evento:%d/%m/%Y} ({cuando(reserva.fecha_evento, hoy)}).',
        )
    return nuevos


# ---------------------------------------------------------------------------
# REGLA: monto inusual (más de N desvíos sobre el promedio)
# ---------------------------------------------------------------------------

def revisar_monto_inusual(reserva):
    if reserva.estado_reserva not in ESTADOS_VIGENTES:
        return 0
    factor = parametro('FACTOR_MONTO_INUSUAL', 3)
    minimo = int(parametro('MINIMO_RESERVAS_COMPARAR', 5))
    # Se compara contra las demás reservas no anuladas (sin contar esta)
    montos = np.array(
        Reservas.objects.exclude(estado_reserva='ANULADA').exclude(pk=reserva.pk).values_list('monto_total', flat=True),
        dtype=float,
    )
    # Con muy pocas reservas el promedio no dice nada: no se avisa
    if len(montos) < minimo:
        return 0
    promedio, desvio = float(np.mean(montos)), float(np.std(montos))
    umbral = promedio + factor * desvio
    if reserva.monto_total <= umbral:
        return 0
    return notificar(
        Notificacion.MONTO_INUSUAL, reserva,
        f'La reserva N° {reserva.pk} de {reserva.id_cliente} es de {pesos(reserva.monto_total)}, muy por encima '
        f'de lo habitual (promedio {pesos(promedio)}; se avisa desde {pesos(umbral)}).',
    )


# ---------------------------------------------------------------------------
# CUÁNDO SE REVISAN
# ---------------------------------------------------------------------------

# En el momento: se revisan las tres reglas solo para la reserva que se acaba de tocar.
# Si algo falla no se corta lo que hizo el usuario (la reserva ya se guardó): se anota el error.
def evaluar_reserva(reserva):
    try:
        una = Reservas.objects.filter(pk=reserva.pk).select_related('id_cliente')
        return revisar_saldo_pendiente(una) + revisar_sin_confirmar(una) + revisar_monto_inusual(reserva)
    except Exception:
        logger.exception('No se pudieron revisar las alertas de la reserva %s', reserva.pk)
        return 0


# Control diario: las reglas de fechas se revisan para todas las reservas.
# El monto inusual no, porque solo tiene sentido al registrar la reserva.
# Devuelve cuántos avisos nuevos generó cada regla.
def evaluar_todas():
    reservas = Reservas.objects.select_related('id_cliente')
    return {
        Notificacion.SALDO_PENDIENTE: revisar_saldo_pendiente(reservas),
        Notificacion.SIN_CONFIRMAR: revisar_sin_confirmar(reservas),
    }
