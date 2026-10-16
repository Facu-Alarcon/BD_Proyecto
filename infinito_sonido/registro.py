"""
Registro de actividad (auditoría) del sistema.

Acá está todo lo que guarda filas en la tabla Registro_Actividad:
- registrar(): la función que guarda una fila. La usan las demás.
- RegistrarActividadMixin: se agrega a cada ViewSet de la API y registra solo las
  altas, modificaciones y bajas (con qué campos cambiaron, qué decían antes y qué dicen
  ahora), sin tener que escribir nada en cada módulo.
- RegistroErroresMiddleware: atrapa los errores del servidor (los 500) y los guarda
  en el registro y en el archivo logs/errores.log para el programador.

Regla de oro: registrar nunca puede romper lo que el usuario estaba haciendo. Si falla
el guardado del registro, se escribe en el log de errores y la operación sigue igual.
"""
import datetime
import logging
import traceback

from django.utils import timezone

from .models import Registro_Actividad, Sueldos, Usuarios

logger = logging.getLogger('infinito_sonido.registro')

# Campos que nunca se muestran en el registro
CAMPOS_OCULTOS = {'contraseña'}

# Cómo se muestra cada campo de la base en el registro (en vez de "telefono_cliente",
# "Teléfono"). Los que no están acá se muestran con el nombre del campo sin guiones bajos.
ETIQUETAS = {
    # Personal
    'dni': 'DNI', 'nombre_emp': 'Nombre', 'apellido_emp': 'Apellido', 'telefono_emp': 'Teléfono',
    'email_emp': 'Email', 'monto_sueldo': 'Monto', 'nombre_puesto': 'Nombre', 'id_sueldo': 'Sueldo',
    'cantidad_horas': 'Cantidad de horas',
    # Usuarios, perfiles y permisos
    'usuario': 'Usuario', 'id_empleado': 'Empleado', 'id_perfil': 'Perfil', 'tipo_perfil': 'Nombre',
    'debe_cambiar_clave': 'Debe cambiar la clave', 'nombre_permiso': 'Nombre',
    'descripcion_permiso': 'Descripción', 'estado_permiso': 'Habilitado', 'codigo': 'Código',
    # Equipos y servicios
    'nombre_tipoeq': 'Nombre', 'nombre_estadoeq': 'Nombre', 'nombre_equipo': 'Nombre',
    'id_tipoeq': 'Tipo de equipo', 'id_estadoeq': 'Estado', 'cantidad_equipo': 'Cantidad',
    'tipo_servicio': 'Nombre', 'precio_servicio': 'Precio',
    # Clientes y reservas
    'nombre_cliente': 'Nombre', 'apellido_cliente': 'Apellido', 'domicilio_cliente': 'Domicilio',
    'telefono_cliente': 'Teléfono', 'email_cliente': 'Email', 'id_cliente': 'Cliente',
    'nombre_evento': 'Nombre del evento', 'fecha_evento': 'Fecha del evento', 'hora_evento': 'Hora del evento',
    'direccion_evento': 'Dirección', 'duracion_evento': 'Duración', 'monto_total': 'Monto total',
    'estado_reserva': 'Estado', 'id_usuario_registro': 'Registrada por', 'fecha_anulacion': 'Fecha de anulación',
    'motivo_anulacion': 'Motivo de anulación', 'id_usuario_anulacion': 'Anulado por',
    # Pagos
    'metodo_pago': 'Nombre', 'id_reserva': 'Reserva', 'monto': 'Monto', 'saldo_pendiente': 'Saldo pendiente',
    # Comunes
    'activo': 'Activo', 'fecha_baja': 'Fecha de baja',
}


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
# 'cambios' es la lista de campos que cambiaron: [{campo, anterior, nuevo}, ...]
def registrar(request, accion, descripcion, modulo='', id_objeto='', detalle='', usuario=None,
              usuario_texto='', cambios=None):
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
            cambios=cambios or [],
            ip=obtener_ip(request) if request is not None else None,
        )
    except Exception:
        logger.exception('No se pudo guardar el registro de actividad (%s - %s)', accion, descripcion)


# Escribe un número como se lee en Argentina: 520000.0 -> "520.000", 8.5 -> "8,50"
def _numero(valor):
    if float(valor).is_integer():
        return f'{int(valor):,}'.replace(',', '.')
    return f'{valor:,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')


# Convierte un valor en el texto que se muestra en el registro: el nombre en vez del id,
# "Sí"/"No", fechas como 18/10/2026, etc. Lo vacío se devuelve como None.
def texto_valor(valor):
    if valor is None or valor == '':
        return None
    if isinstance(valor, bool):
        return 'Sí' if valor else 'No'
    if isinstance(valor, Sueldos):
        return f'$ {_numero(valor.monto_sueldo)}'
    if isinstance(valor, datetime.datetime):
        if timezone.is_aware(valor):
            valor = timezone.localtime(valor)
        return valor.strftime('%d/%m/%Y %H:%M')
    if isinstance(valor, datetime.date):
        return valor.strftime('%d/%m/%Y')
    if isinstance(valor, datetime.time):
        return valor.strftime('%H:%M')
    if isinstance(valor, float):
        return _numero(valor)
    return str(valor)


# Todos los datos de un registro como {etiqueta: texto}, en el orden de la tabla.
# No incluye el id, la contraseña ni las fechas que pone Django solo (auto_now).
def datos_de(objeto):
    datos = {}
    for campo in objeto._meta.concrete_fields:
        if campo.primary_key or campo.name in CAMPOS_OCULTOS:
            continue
        if getattr(campo, 'auto_now', False) or getattr(campo, 'auto_now_add', False):
            continue
        if campo.is_relation:
            valor = getattr(objeto, campo.name, None)          # el objeto relacionado (su nombre)
        elif campo.choices and getattr(objeto, campo.attname):
            valor = getattr(objeto, f'get_{campo.name}_display')()  # ej: "Pendiente" en vez de "PENDIENTE"
        else:
            valor = getattr(objeto, campo.attname)
        datos[ETIQUETAS.get(campo.name, campo.name.replace('_', ' ').capitalize())] = texto_valor(valor)
    return datos


# Compara cómo estaba un registro y cómo quedó, y devuelve solo lo que cambió:
#   [{'campo': 'Teléfono', 'anterior': '3871111111', 'nuevo': '3872222222'}, ...]
# Las listas (servicios de una reserva, puestos de un empleado...) además dicen qué se
# agregó y qué se quitó. Para un alta se compara contra {} y para una baja al revés.
def calcular_cambios(antes, despues):
    cambios = []
    for campo in dict.fromkeys([*antes, *despues]):
        anterior, nuevo = antes.get(campo), despues.get(campo)
        if anterior == nuevo:
            continue
        if isinstance(anterior, list) or isinstance(nuevo, list):
            anterior, nuevo = anterior or [], nuevo or []
            if not anterior and not nuevo:
                continue
            cambios.append({
                'campo': campo,
                'anterior': ', '.join(anterior) or None,
                'nuevo': ', '.join(nuevo) or None,
                'agregados': [x for x in nuevo if x not in anterior],
                'quitados': [x for x in anterior if x not in nuevo],
            })
        elif anterior is not None or nuevo is not None:
            cambios.append({'campo': campo, 'anterior': anterior, 'nuevo': nuevo})
    return cambios


# El mismo contenido de 'cambios' pero en texto, una línea por campo. Se guarda en
# 'detalle' para poder buscarlo con el filtro de texto de la pantalla.
def texto_cambios(cambios, accion):
    lineas = []
    for c in cambios:
        anterior, nuevo = c['anterior'] or '(vacío)', c['nuevo'] or '(vacío)'
        if accion == Registro_Actividad.ALTA:
            lineas.append(f"{c['campo']}: {nuevo}")
        elif accion == Registro_Actividad.BAJA:
            lineas.append(f"{c['campo']}: {anterior}")
        else:
            lineas.append(f"{c['campo']}: {anterior} → {nuevo}")
    return '\n'.join(lineas)


# Texto para las acciones especiales de algunos módulos (las que no son crear/editar/borrar)
ACCIONES_ESPECIALES = {
    'permisos': (Registro_Actividad.MODIFICACION, 'Actualizó los permisos del perfil'),
    'puestos': (Registro_Actividad.MODIFICACION, 'Actualizó los puestos del empleado'),
    'horario': (Registro_Actividad.MODIFICACION, 'Actualizó el horario del empleado'),
    # Estos dos sirven para Usuarios, Empleados, Servicios y Métodos de pago
    # (en el registro, la columna Módulo dice de cuál se trata)
    'desactivar': (Registro_Actividad.MODIFICACION, 'Desactivó'),
    'reactivar': (Registro_Actividad.MODIFICACION, 'Reactivó'),
    'restablecer_clave': (Registro_Actividad.CLAVE, 'Restableció la contraseña del usuario'),
}

# Estas acciones se mandan cada vez que se guarda el formulario del empleado o del perfil,
# aunque no se haya tocado nada: solo se registran si de verdad cambió algo
SOLO_SI_CAMBIA = {'permisos', 'puestos', 'horario'}


class RegistrarActividadMixin:
    """
    Se pone adelante de ModelViewSet en cada módulo, por ejemplo:
        class ClientesViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
            modulo_registro = 'Clientes'

    Funciona mirando la respuesta de cada pedido (finalize_response), así registra igual
    aunque el módulo tenga su propio create() o destroy(). Solo se registra lo que salió
    bien (respuestas 2xx): si la API rechazó algo, no pasó nada que registrar.

    Si un módulo tiene datos en otras tablas que también conviene registrar (por ejemplo
    los servicios y el personal de una reserva), los agrega con datos_extra_registro().
    """
    modulo_registro = ''

    # Datos de otras tablas que se registran junto con el objeto: {etiqueta: lista de textos}.
    # Cada ViewSet lo redefine si lo necesita (ver ReservasViewSet, EmpleadosViewSet...).
    def datos_extra_registro(self, objeto):
        return {}

    def _datos_registro(self, objeto):
        return {**datos_de(objeto), **self.datos_extra_registro(objeto)}

    # Cada vez que el ViewSet busca el objeto con el que va a trabajar (editar, borrar,
    # o una acción especial) nos guardamos cómo estaba antes, para poder comparar después.
    # En las consultas (GET) no hace falta, así no se hacen lecturas de más.
    def get_object(self):
        objeto = super().get_object()
        if self.request.method not in ('GET', 'HEAD', 'OPTIONS'):
            self._objeto_registro = objeto
            # El número (id) lo guardamos aparte, porque después de eliminarlo se pierde
            self._pk_registro = objeto.pk
            self._antes_registro = self._datos_registro(objeto)
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

    # Vuelve a leer el objeto de la base y lo compara con cómo estaba antes
    def _cambios_desde_antes(self):
        objeto = self._objeto_registro
        objeto.refresh_from_db()
        return objeto, calcular_cambios(self._antes_registro, self._datos_registro(objeto))

    def _registrar_respuesta(self, request, response):
        accion = getattr(self, 'action', None)
        modulo = self.modulo_registro
        ALTA, MODIFICACION, BAJA = Registro_Actividad.ALTA, Registro_Actividad.MODIFICACION, Registro_Actividad.BAJA

        # Alta: el objeto nuevo se busca por el id que devolvió la API, y se registran
        # todos los datos con los que se cargó
        if accion == 'create':
            pk = response.data.get(self.get_queryset().model._meta.pk.name) if hasattr(response, 'data') else None
            objeto = self.get_queryset().model.objects.filter(pk=pk).first()
            cambios = calcular_cambios({}, self._datos_registro(objeto)) if objeto else []
            registrar(request, ALTA, str(objeto) if objeto else '(sin datos)', modulo, pk,
                      texto_cambios(cambios, ALTA), cambios=cambios)

        # Modificación: qué campos cambiaron, qué decían antes y qué dicen ahora
        elif accion in ('update', 'partial_update'):
            objeto, cambios = self._cambios_desde_antes()
            registrar(request, MODIFICACION, str(objeto), modulo, objeto.pk,
                      texto_cambios(cambios, MODIFICACION) or 'Se guardó sin cambios.', cambios=cambios)

        # Baja: usamos los datos que habíamos guardado antes de eliminarlo, porque a esta
        # altura ya no está en la base. Es lo único que queda para saber qué se eliminó.
        elif accion == 'destroy':
            cambios = calcular_cambios(self._antes_registro, {})
            registrar(request, BAJA, self._texto_registro, modulo, self._pk_registro,
                      texto_cambios(cambios, BAJA), cambios=cambios)

        # Acciones especiales (asignar permisos, puestos u horario, desactivar, reactivar,
        # restablecer clave): también se registra qué cambió
        elif accion in ACCIONES_ESPECIALES:
            tipo, texto = ACCIONES_ESPECIALES[accion]
            objeto, cambios = self._cambios_desde_antes()
            if not cambios and accion in SOLO_SI_CAMBIA:
                return
            registrar(request, tipo, f'{texto}: {self._texto_registro}', modulo, self._pk_registro,
                      texto_cambios(cambios, MODIFICACION), cambios=cambios)


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
