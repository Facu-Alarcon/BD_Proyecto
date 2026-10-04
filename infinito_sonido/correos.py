import logging

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


# Le manda al empleado su usuario y la contraseña temporal.
# 'motivo' cambia el texto: 'alta' cuando se crea el usuario y 'restablecer'
# cuando el administrador le genera una clave nueva.
# Devuelve True si el mail salió de verdad. Devuelve False si falló el envío o si
# no hay cuenta de Gmail configurada (en ese caso el mail solo se escribe en la
# consola), y así la API sabe que tiene que mostrarle la contraseña al administrador.
def enviar_contraseña_temporal(usuario, contraseña, motivo='alta'):
    empleado = usuario.id_empleado
    if motivo == 'alta':
        asunto = 'Tu usuario para el sistema de Infinito Sonido e Iluminación'
        intro = 'Se creó tu usuario para ingresar al sistema de Infinito Sonido e Iluminación.'
    else:
        asunto = 'Tu nueva contraseña temporal - Infinito Sonido e Iluminación'
        intro = 'El administrador restableció tu contraseña del sistema de Infinito Sonido e Iluminación.'

    # Versión en texto plano (para los programas de mail que no muestran HTML)
    texto = (
        f'Hola {empleado.nombre_emp}:\n\n'
        f'{intro}\n\n'
        f'Usuario: {usuario.usuario}\n'
        f'Contraseña temporal: {contraseña}\n\n'
        'La primera vez que ingreses el sistema te va a pedir que la cambies por una propia.\n'
        'La nueva tiene que tener al menos 8 caracteres, una mayúscula, una minúscula, '
        'un número y un carácter especial.\n\n'
        'Si no esperabas este mail, avisale al administrador.\n'
    )

    # Versión con formato, con los colores institucionales
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 480px; color: #05284C;">
      <h2 style="margin: 0 0 12px;">Hola {empleado.nombre_emp}</h2>
      <p>{intro}</p>
      <div style="background: #e8f1e4; border-radius: 10px; padding: 16px; margin: 16px 0;">
        <p style="margin: 0 0 6px;">Usuario: <strong>{usuario.usuario}</strong></p>
        <p style="margin: 0;">Contraseña temporal: <strong style="font-family: monospace; font-size: 16px;">{contraseña}</strong></p>
      </div>
      <p>La primera vez que ingreses el sistema te va a pedir que la cambies por una propia.
         La nueva tiene que tener al menos 8 caracteres, una mayúscula, una minúscula,
         un número y un carácter especial.</p>
      <p style="color: #6b7590; font-size: 12px;">Si no esperabas este mail, avisale al administrador.</p>
    </div>
    """

    try:
        send_mail(asunto, texto, settings.DEFAULT_FROM_EMAIL, [empleado.email_emp], html_message=html)
    except Exception:
        # Si Gmail rechaza el envío (clave mal cargada, sin internet, etc.) no se corta
        # la creación del usuario: se registra el error y se avisa con el False
        logger.exception('No se pudo enviar el mail a %s', empleado.email_emp)
        return False
    return settings.EMAIL_CONFIGURADO
