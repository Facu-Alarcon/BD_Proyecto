"""
Registro de actividad (auditoría) del sistema.

Acá está todo lo que guarda filas en la tabla Registro_Actividad:
- registrar(): la función que guarda una fila. La usan las demás.
- RegistrarActividadMixin: se agrega a cada ViewSet de la API y registra solo las
  altas, modificaciones y bajas (con qué campos cambiaron), sin tener que escribir
  nada en cada módulo.
- RegistroErroresMiddleware: atrapa los errores del servidor (los 500) y los guarda
  en el registro y en el archivo logs/errores.log para el programador.

Regla de oro: registrar nunca puede romper lo que el usuario estaba haciendo. Si falla
el guardado del registro, se escribe en el log de errores y la operación sigue igual.
"""
import logging
import traceback

from django.forms.models import model_to_dict

from .models import Registro_Actividad, Usuarios

logger = logging.getLogger('infinito_sonido.registro')

# Campos que nunca se muestran en el detalle de una modificación
CAMPOS_OCULTOS = {'contraseña'}


# Saca la IP de quien hizo el pedido. Si hay un proxy adelante viene en X-Forwarded-For
def obtener_ip(request):
    reenviada = request.META.get('HTTP_X_FORWARDED_FOR')
    if reenviada:
        return reenviada.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR') or None


# Devuelve el usuario logueado si lo hay (en un login fallido o un error antes de
# autenticar no hay ninguno)
def _usuario_de(request):
    usuario = getattr(request, 'user', None)
    return usuario if isinstance(usuario, Usuarios) else None


# Guarda una fila en el registro. 'usuario' se puede pasar a mano (ej: en el login,
# donde todavía no hay nadie autenticado); si no, se toma del request.
def registrar(request, accion, descripcion, modulo='', id_objeto='', detalle='', usuario=None, usuario_texto=''):
    try:
        usuario = usuario or _usuario_de(request)
        Registro_Actividad.objects.create(
            id_usuario=usuario,
            usuario_texto=(usuario.usuario if usuario else usuario_texto)[:50],
            accion=accion,
            modulo=modulo[:50],
            id_objeto=str(id_objeto or '')[:20],
            descripcion=str(descripcion)[:255],
            detalle=detalle,
            ip=obtener_ip(request) if request is not None else None,
        )
    except Exception:
        logger.exception('No se pudo guardar el registro de actividad (%s - %s)', accion, descripcion)


# Arma el texto con lo que cambió en una modificación, una línea por campo:
#   "telefono_cliente: 3871111111 → 3872222222"
def _cambios(antes, despues):
    lineas = []
    for campo, valor_nuevo in despues.items():
        if campo in CAMPOS_OCULTOS:
            continue
        valor_viejo = antes.get(campo)
        if valor_viejo != valor_nuevo:
            lineas.append(f'{campo}: {valor_viejo if valor_viejo not in (None, "") else "(vacío)"} → '
                          f'{valor_nuevo if valor_nuevo not in (None, "") else "(vacío)"}')
    return '\n'.join(lineas)


# Texto para las acciones especiales de algunos módulos (las que no son crear/editar/borrar)
ACCIONES_ESPECIALES = {
    'permisos': (Registro_Actividad.MODIFICACION, 'Actualizó los permisos del perfil'),
    'puestos': (Registro_Actividad.MODIFICACION, 'Actualizó los puestos del empleado'),
    'reactivar': (Registro_Actividad.MODIFICACION, 'Reactivó al usuario'),
    'restablecer_clave': (Registro_Actividad.CLAVE, 'Restableció la contraseña del usuario'),
}


class RegistrarActividadMixin:
    """
    Se pone adelante de ModelViewSet en cada módulo, por ejemplo:
        class ClientesViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
            modulo_registro = 'Clientes'

    Funciona mirando la respuesta de cada pedido (finalize_response), así registra igual
    aunque el módulo tenga su propio create() o destroy(). Solo se registra lo que salió
    bien (respuestas 2xx): si la API rechazó algo, no pasó nada que registrar.
    """
    modulo_registro = ''

    # Cada vez que el ViewSet busca el objeto con el que va a trabajar (editar, borrar,
    # o una acción especial) nos guardamos cómo estaba antes, para poder comparar después
    def get_object(self):
        objeto = super().get_object()
        self._objeto_registro = objeto
        self._antes_registro = model_to_dict(objeto)
        self._texto_registro = str(objeto)
        return objeto

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        try:
            if 200 <= response.status_code < 300 and request.method not in ('GET', 'HEAD', 'OPTIONS'):
                self._registrar_respuesta(request, response)
        except Exception:
            logger.exception('Error armando el registro de actividad de %s', self.modulo_registro)
        return response

    def _registrar_respuesta(self, request, response):
        accion = getattr(self, 'action', None)
        modulo = self.modulo_registro

        # Alta: el objeto nuevo se busca por el id que devolvió la API
        if accion == 'create':
            pk = response.data.get(self.get_queryset().model._meta.pk.name) if hasattr(response, 'data') else None
            objeto = self.get_queryset().model.objects.filter(pk=pk).first()
            registrar(request, Registro_Actividad.ALTA, str(objeto) if objeto else '(sin datos)', modulo, pk)

        # Modificación: se vuelve a leer de la base y se compara con cómo estaba
        elif accion in ('update', 'partial_update'):
            objeto = self._objeto_registro
            objeto.refresh_from_db()
            detalle = _cambios(self._antes_registro, model_to_dict(objeto))
            registrar(request, Registro_Actividad.MODIFICACION, str(objeto), modulo, objeto.pk,
                      detalle or 'Se guardó sin cambios en los datos principales.')

        # Baja: se usa el texto que guardamos antes de borrarlo (después ya no existe)
        elif accion == 'destroy':
            registrar(request, Registro_Actividad.BAJA, self._texto_registro, modulo, self._objeto_registro.pk)

        # Acciones especiales (asignar permisos, puestos, reactivar, restablecer clave)
        elif accion in ACCIONES_ESPECIALES:
            tipo, texto = ACCIONES_ESPECIALES[accion]
            registrar(request, tipo, f'{texto}: {self._texto_registro}', modulo, self._objeto_registro.pk)


class RegistroErroresMiddleware:
    """
    Atrapa cualquier error no previsto del servidor (los que terminan en "500 Internal
    Server Error"). Lo guarda en el registro de actividad, con el error completo en
    'detalle', y en el archivo logs/errores.log. Después deja que Django responda el 500
    como siempre: este middleware solo anota, no cambia la respuesta.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_exception(self, request, exception):
        texto_error = ''.join(traceback.format_exception(type(exception), exception, exception.__traceback__))
        logger.error('Error en %s %s\n%s', request.method, request.path, texto_error)
        registrar(
            request,
            Registro_Actividad.ERROR,
            f'{type(exception).__name__}: {exception}',
            modulo=f'{request.method} {request.path}',
            detalle=texto_error,
        )
        return None
