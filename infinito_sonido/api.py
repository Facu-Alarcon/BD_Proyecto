# API del sistema: todo lo que el frontend en React le pide al backend pasa por acá.
#
# Hay dos tipos de clases:
#   - Vistas sueltas (APIView): login, logout, "quién soy", cambiar y recuperar la clave,
#     y el resumen de Inicio.
#   - ViewSets: uno por módulo (Clientes, Reservas, Equipos...). Un ModelViewSet arma solo
#     los endpoints de listar, ver uno, crear, editar y borrar; acá solo escribimos lo que
#     cambia respecto de lo normal (por ejemplo, avisar en vez de romper si no se puede borrar).
#
# Las URLs de cada cosa están en api_urls.py. Los permisos (quién puede ver o modificar cada
# módulo) se definen con permission_classes, usando las funciones de permissions.py.
# Todos los ViewSets llevan RegistrarActividadMixin, que anota sus altas, modificaciones y
# bajas en el Registro de actividad (ver registro.py).
#
# Sobre eliminar: el tachito borra el registro de la base, pero solo si no tiene nada
# asociado. Cada módulo dice en validar_eliminacion() cuándo no se puede y qué mensaje
# mostrar. Empleados, Servicios y Métodos de pago además se pueden desactivar.
# Las reservas y los pagos no se eliminan: se anulan. Está todo explicado en baja_logica.py.
import datetime
import hashlib
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.db import transaction
from django.db.models import Count
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import SAFE_METHODS, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import (
    Equipos_x_Servicios, Detalles_Reservas,
    Tipo_Equipos, Estado_Equipos, Equipos,
    Perfiles, Usuarios,
    Permisos, Permisos_x_Perfiles,
    SesionToken,
    Clientes, Empleados, Servicios, Reservas, Reservas_x_Servicios,
    Sueldos, Puestos, Puestos_x_Empleados,
    Horarios, Horarios_x_Empleados, Metodo_Pagos, Pagos, Detalles_de_Pago,
    Registro_Actividad, Token_Recuperacion,
)
from .serializers import (
    TipoEquiposSerializer, EstadoEquiposSerializer, EquiposSerializer,
    PerfilesSerializer, UsuariosSerializer, CambiarClaveSerializer,
    PermisosSerializer, PermisoConEstadoSerializer,
    ClientesSerializer, EmpleadosSerializer, ServiciosSerializer,
    ReservasSerializer,
    SueldosSerializer, PuestosSerializer, PuestoConEstadoSerializer,
    HorariosSerializer, MetodoPagosSerializer, PagosSerializer,
    recalcular_saldos,
    RegistroActividadSerializer,
)
from .permissions import permiso_codigo, permiso_modulo, permisos_del_usuario
from .correos import enviar_contraseña_temporal, enviar_link_recuperacion
from .registro import RegistrarActividadMixin, registrar, texto_cambios, texto_valor
from .eliminar import DesactivarMixin, EliminarMixin
from .disponibilidad import disponibilidad_del_dia, empleados_ocupados, equipos_faltantes
from .seguridad import generar_contraseña_temporal, validar_contraseña_segura


# Datos del usuario logueado que se le mandan al frontend al entrar (y en /api/me/).
# El frontend los guarda y los usa para saber qué mostrar: por ejemplo 'permisos' decide
# qué secciones aparecen en el menú, y debe_cambiar_clave lo manda a la pantalla de cambiar clave.
def _usuario_repr(usuario):
    return {
        'id_usuario': usuario.pk,
        'usuario': usuario.usuario,
        'nombre': usuario.nombre,
        'apellido': usuario.apellido,
        'id_perfil': usuario.id_perfil_id,
        'perfil_nombre': usuario.id_perfil.tipo_perfil,
        'debe_cambiar_clave': usuario.debe_cambiar_clave,
        'permisos': sorted(permisos_del_usuario(usuario)),
    }


# Inicio de sesión: recibe usuario y contraseña y, si están bien, crea una sesión nueva
# (SesionToken) y devuelve el token. El frontend manda ese token en todos los pedidos siguientes.
# Es la única vista (junto con las de recuperar clave) que se puede usar sin estar logueado.
class LoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        # Se acepta 'contraseña' o 'password' por si algún cliente de la API manda el nombre en inglés
        usuario_nombre = (request.data.get('usuario') or '').strip()
        contraseña = request.data.get('contraseña') or request.data.get('password') or ''

        # Mismo mensaje si el usuario no existe o si la clave está mal: así no se puede
        # averiguar qué usuarios existen probando nombres
        error = {'detail': 'Usuario o contraseña incorrectos.'}
        if not usuario_nombre or not contraseña:
            return Response(error, status=status.HTTP_400_BAD_REQUEST)

        try:
            usuario = Usuarios.objects.select_related('id_perfil', 'id_empleado').get(usuario=usuario_nombre)
        except Usuarios.DoesNotExist:
            # Queda registrado el intento con el usuario que escribieron (sirve para detectar ataques)
            registrar(request, Registro_Actividad.LOGIN_FALLIDO, 'Usuario inexistente', 'Sesión',
                      usuario_texto=usuario_nombre)
            return Response(error, status=status.HTTP_401_UNAUTHORIZED)

        # check_password compara lo que escribió contra el hash guardado (la clave nunca se guarda tal cual)
        if not check_password(contraseña, usuario.contraseña):
            registrar(request, Registro_Actividad.LOGIN_FALLIDO, 'Contraseña incorrecta', 'Sesión', usuario=usuario)
            return Response(error, status=status.HTTP_401_UNAUTHORIZED)

        if not usuario.activo:
            registrar(request, Registro_Actividad.LOGIN_FALLIDO, 'Usuario dado de baja', 'Sesión', usuario=usuario)
            return Response({'detail': 'Este usuario está dado de baja.'}, status=status.HTTP_403_FORBIDDEN)

        # Token de 64 caracteres al azar: identifica esta sesión hasta que el usuario cierre sesión
        sesion = SesionToken.objects.create(token=secrets.token_hex(32), id_usuario=usuario)
        registrar(request, Registro_Actividad.LOGIN, 'Inició sesión', 'Sesión', usuario=usuario)
        return Response({'token': sesion.token, 'usuario': _usuario_repr(usuario)})


class CambiarClaveView(APIView):
    """
    Cambio de clave por el propio usuario logueado. Se usa, en particular,
    después de un "Restablecer clave" hecho por un admin: el login sigue
    funcionando con la clave provisoria, pero 'debe_cambiar_clave' queda
    en true hasta que el usuario pase por acá y defina la suya.
    """

    def post(self, request):
        serializer = CambiarClaveSerializer(data=request.data, context={'usuario': request.user})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        registrar(request, Registro_Actividad.CLAVE, 'Cambió su contraseña', 'Sesión')
        return Response(status=status.HTTP_204_NO_CONTENT)


# ---------------- "Olvidé mi contraseña" ----------------

# Cuánto dura el link que se manda por mail, y cuánto hay que esperar para pedir otro
MINUTOS_VALIDEZ_LINK = 30
SEGUNDOS_ENTRE_PEDIDOS = 60


# Huella (hash SHA-256) del token: es lo que se guarda en la base en vez del token real
def _hash_token(token):
    return hashlib.sha256(token.encode()).hexdigest()


# Busca el link de recuperación que todavía sirve: que exista, no esté usado, no haya
# vencido y que el usuario siga activo. Si no cumple algo, devuelve None.
def _token_valido(token):
    return (
        Token_Recuperacion.objects.select_related('id_usuario__id_empleado')
        .filter(token_hash=_hash_token(token), usado=False, expira__gt=timezone.now(), id_usuario__activo=True)
        .first()
    )


class RecuperarClaveView(APIView):
    """
    Paso 1 de "Olvidé mi contraseña": el usuario escribe su usuario y, si existe y está activo,
    se le manda por mail un link para elegir una contraseña nueva.

    Siempre responde lo mismo, exista o no el usuario: así esta pantalla no sirve para
    averiguar qué usuarios existen en el sistema. La contraseña actual NO se toca: sigue
    funcionando hasta que el dueño del mail use el link.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        usuario_nombre = (request.data.get('usuario') or '').strip()
        respuesta = Response({
            'detail': 'Si el usuario existe, le enviamos un mail con un link para elegir una contraseña nueva. '
                      f'El link vence en {MINUTOS_VALIDEZ_LINK} minutos.'
        })
        if not usuario_nombre:
            return Response({'detail': 'Escribí tu usuario.'}, status=status.HTTP_400_BAD_REQUEST)

        usuario = (
            Usuarios.objects.select_related('id_empleado')
            .filter(usuario=usuario_nombre, activo=True).first()
        )
        if usuario is None or not usuario.correo:
            registrar(request, Registro_Actividad.CLAVE, 'Pidió recuperar la contraseña de un usuario inexistente o sin correo',
                      'Sesión', usuario_texto=usuario_nombre)
            return respuesta

        # Para que no se pueda llenar la casilla de mails apretando el botón muchas veces
        hace_poco = timezone.now() - timedelta(seconds=SEGUNDOS_ENTRE_PEDIDOS)
        if Token_Recuperacion.objects.filter(id_usuario=usuario, creado__gt=hace_poco).exists():
            return respuesta

        # Si había links anteriores sin usar, dejan de servir: solo vale el último
        Token_Recuperacion.objects.filter(id_usuario=usuario, usado=False).update(usado=True)

        # Token largo y al azar (no se puede adivinar); en la base solo queda su hash
        token = secrets.token_urlsafe(32)
        Token_Recuperacion.objects.create(
            id_usuario=usuario,
            token_hash=_hash_token(token),
            expira=timezone.now() + timedelta(minutes=MINUTOS_VALIDEZ_LINK),
        )
        link = f'{settings.FRONTEND_URL}/restablecer-clave/{token}'
        enviar_link_recuperacion(usuario, link, MINUTOS_VALIDEZ_LINK)
        registrar(request, Registro_Actividad.CLAVE, 'Pidió recuperar su contraseña (se envió el link por mail)',
                  'Sesión', usuario=usuario)
        return respuesta


class RestablecerConLinkView(APIView):
    """
    Paso 2 de "Olvidé mi contraseña": la pantalla que abre el link del mail.
    GET: revisa si el link todavía sirve (para mostrar el formulario o el aviso de vencido).
    POST: guarda la contraseña nueva, que tiene que cumplir las reglas de seguridad.
    """
    permission_classes = [AllowAny]
    authentication_classes = []
    VENCIDO = {'detail': 'El link venció o ya se usó. Pedí uno nuevo desde "Olvidé mi contraseña".'}

    def get(self, request, token):
        registro = _token_valido(token)
        if registro is None:
            return Response(self.VENCIDO, status=status.HTTP_400_BAD_REQUEST)
        # Solo el nombre, para saludar ("Hola Facundo"); no se muestra nada más del usuario
        return Response({'nombre': registro.id_usuario.nombre})

    def post(self, request, token):
        registro = _token_valido(token)
        if registro is None:
            return Response(self.VENCIDO, status=status.HTTP_400_BAD_REQUEST)

        contraseña = request.data.get('contraseña_nueva') or ''
        try:
            validar_contraseña_segura(contraseña)
        except ValidationError as e:
            return Response({'contraseña_nueva': e.detail}, status=status.HTTP_400_BAD_REQUEST)

        usuario = registro.id_usuario
        usuario.contraseña = make_password(contraseña)
        # La eligió él mismo, así que no hace falta pedirle que la cambie al entrar
        usuario.debe_cambiar_clave = False
        usuario.save()

        # El link queda usado, y se cierran las sesiones que hubiera abiertas con la clave vieja
        registro.usado = True
        registro.save(update_fields=['usado'])
        SesionToken.objects.filter(id_usuario=usuario).delete()
        registrar(request, Registro_Actividad.CLAVE, 'Recuperó su contraseña con el link del mail', 'Sesión', usuario=usuario)
        return Response(status=status.HTTP_204_NO_CONTENT)


# Cierre de sesión: borra el token con el que se hizo el pedido, así deja de servir
class LogoutView(APIView):
    def post(self, request):
        # request.auth es la instancia de SesionToken usada para autenticar (ver authentication.py)
        if request.auth is not None:
            request.auth.delete()
        registrar(request, Registro_Actividad.LOGOUT, 'Cerró sesión', 'Sesión')
        return Response(status=status.HTTP_204_NO_CONTENT)


# "Quién soy": devuelve los datos del usuario logueado. El frontend lo llama al abrir la
# página para refrescar los permisos (por si un admin le cambió el perfil mientras tanto).
class MeView(APIView):
    def get(self, request):
        return Response(_usuario_repr(request.user))


# ---------------- Equipos ----------------
#
# Tipos de equipo (Sonido, Iluminación...). Solo se ordenan por nombre y se avisa si
# se quiere eliminar uno que todavía tiene equipos.
class TipoEquiposViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Tipos de equipo'
    # Con cuántos equipos tiene cada tipo, para mostrarlo en la lista
    queryset = Tipo_Equipos.objects.annotate(cantidad_equipos=Count('equipos')).order_by('nombre_tipoeq')
    serializer_class = TipoEquiposSerializer
    permission_classes = [permiso_modulo('tipos_equipo')]

    # No se elimina un tipo que todavía tiene equipos
    def validar_eliminacion(self, tipo):
        if Equipos.objects.filter(id_tipoeq=tipo).exists():
            return f'No se puede eliminar "{tipo.nombre_tipoeq}" porque hay equipos de ese tipo.'


# Cargas horarias de los empleados.
class HorariosViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Horarios'
    # Con cuántos empleados tienen cada horario, para mostrarlo en la lista
    queryset = Horarios.objects.annotate(cantidad_empleados=Count('horarios_x_empleados')).order_by('cantidad_horas')
    serializer_class = HorariosSerializer
    permission_classes = [permiso_modulo('horarios')]

    # No se elimina un horario que tiene algún empleado asignado
    def validar_eliminacion(self, horario):
        if Horarios_x_Empleados.objects.filter(id_horario=horario).exists():
            return f'No se puede eliminar el horario de {horario.cantidad_horas} hs porque hay empleados que lo tienen asignado.'


# Métodos de pago (Efectivo, Transferencia...). Se eliminan si nunca se usaron; si ya se
# cobró con ellos se pueden desactivar: los pagos viejos los siguen mostrando, pero ya no
# aparecen para elegirlos en los pagos nuevos.
class MetodoPagosViewSet(RegistrarActividadMixin, EliminarMixin, DesactivarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Métodos de pago'
    queryset = Metodo_Pagos.objects.all().order_by('metodo_pago')
    serializer_class = MetodoPagosSerializer
    permission_classes = [permiso_modulo('metodos_pago')]

    # No se elimina un método con el que se registró algún pago (aunque el pago esté anulado)
    def validar_eliminacion(self, metodo):
        if Detalles_de_Pago.objects.filter(id_metodo_pago=metodo).exists():
            return (f'No se puede eliminar "{metodo.metodo_pago}" porque hay pagos registrados con ese método. '
                    'Podés desactivarlo para que deje de ofrecerse en los pagos nuevos.')


# Quién puede usar los Estados de equipo. Es como en los demás módulos (hace falta
# "Ver Estados de equipo" para mirar y "Gestionar Estados de equipo" para cambiar), con
# un agregado: el que tiene permiso sobre Equipos también puede VER la lista de estados,
# porque el formulario de Equipos la necesita para armar el desplegable "Estado del equipo".
class PermisoEstadosEquipo(permiso_modulo('estados_equipo')):
    def has_permission(self, request, view):
        # Primero el control normal del módulo
        if super().has_permission(request, view):
            return True
        # Si no lo pasó: se lo deja solo mirar (nunca cambiar) si tiene permiso sobre Equipos
        if request.method in SAFE_METHODS and getattr(request.user, 'is_authenticated', False):
            permisos = permisos_del_usuario(request.user)
            return 'ver_equipos' in permisos or 'gestionar_equipos' in permisos
        return False


class EstadoEquiposViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    """
    Estados de equipo (Disponible, En uso, En reparación...). Es un módulo aparte, con su
    propia pantalla en el menú: ahí se agregan, se cambian de nombre y se eliminan.
    En el formulario de Equipos solo se elige uno de la lista.
    Ojo con el estado "En reparación": el sistema reconoce por el nombre que esos equipos
    no se pueden reservar (ver disponibilidad.py), así que conviene no cambiarle el nombre.
    """
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Estados de equipo'
    # Con cuántos equipos tienen cada estado, para mostrarlo en la lista
    queryset = Estado_Equipos.objects.annotate(cantidad_equipos=Count('equipos')).order_by('nombre_estadoeq')
    serializer_class = EstadoEquiposSerializer
    permission_classes = [PermisoEstadosEquipo]

    # No se elimina un estado que tiene algún equipo
    def validar_eliminacion(self, estado):
        if Equipos.objects.filter(id_estadoeq=estado).exists():
            return f'No se puede eliminar "{estado.nombre_estadoeq}" porque hay equipos con ese estado.'


# Equipos de la empresa. select_related trae el tipo y el estado en la misma consulta,
# así la lista no hace una consulta extra por cada equipo.
class EquiposViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Equipos'
    queryset = Equipos.objects.select_related('id_tipoeq', 'id_estadoeq').all().order_by('nombre_equipo')
    serializer_class = EquiposSerializer
    permission_classes = [permiso_modulo('equipos')]

    # No se elimina un equipo que está cargado en algún servicio (aunque el servicio esté
    # desactivado), porque las reservas lo usan para saber si alcanzan los equipos.
    # Primero hay que sacarlo de esos servicios. El mensaje dice cuáles son.
    def validar_eliminacion(self, equipo):
        servicios = Equipos_x_Servicios.objects.filter(id_equipo=equipo)
        if servicios.exists():
            nombres = ', '.join(sorted({r.id_servicio.tipo_servicio for r in servicios.select_related('id_servicio')}))
            return f'No se puede eliminar "{equipo.nombre_equipo}" porque lo usan estos servicios: {nombres}.'


# ---------------- Seguridad: perfiles, permisos y usuarios ----------------
#
# Perfiles de usuario. Además del ABM normal tiene la acción /perfiles/<id>/permisos/
# para ver y cambiar qué permisos tiene el perfil (pantalla "Asignar permisos").
class PerfilesViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Perfiles'
    # Con cuántos usuarios y permisos tiene cada perfil (distinct: son dos tablas distintas)
    queryset = Perfiles.objects.annotate(
        cantidad_usuarios=Count('usuarios', distinct=True),
        cantidad_permisos=Count('permisos_x_perfiles', distinct=True),
    ).order_by('tipo_perfil')
    serializer_class = PerfilesSerializer
    permission_classes = [permiso_modulo('perfiles')]

    # En el registro de actividad también se anota qué permisos tenía el perfil
    def datos_extra_registro(self, perfil):
        return {'Permisos': sorted(
            Permisos_x_Perfiles.objects.filter(id_perfil=perfil).values_list('id_permiso__nombre_permiso', flat=True)
        )}

    # No se elimina un perfil que tiene algún usuario (aunque el usuario esté dado de baja).
    # Si se elimina, los permisos que tenía tildados se desasignan solos.
    def validar_eliminacion(self, perfil):
        if Usuarios.objects.filter(id_perfil=perfil).exists():
            return f'No se puede eliminar "{perfil.tipo_perfil}" porque hay usuarios con ese perfil.'

    # GET: todos los permisos del sistema, cada uno marcado con asignado=True/False para este perfil
    # PUT: recibe la lista completa de ids tildados y deja el perfil exactamente con esos
    @action(detail=True, methods=['get', 'put'], url_path='permisos')
    def permisos(self, request, pk=None):
        perfil = self.get_object()

        if request.method == 'GET':
            asignados = set(
                Permisos_x_Perfiles.objects.filter(id_perfil=perfil).values_list('id_permiso_id', flat=True)
            )
            permisos_qs = Permisos.objects.all().order_by('nombre_permiso')
            for permiso in permisos_qs:
                permiso.asignado = permiso.pk in asignados
            serializer = PermisoConEstadoSerializer(permisos_qs, many=True)
            return Response(serializer.data)

        # PUT: sincroniza la lista completa de permisos seleccionados
        ids_seleccionados = request.data.get('permisos', [])
        if not isinstance(ids_seleccionados, list):
            raise ValidationError({'permisos': 'Debe ser una lista de ids de permisos.'})
        ids_seleccionados = {int(pk) for pk in ids_seleccionados}

        ids_asignados = set(
            Permisos_x_Perfiles.objects.filter(id_perfil=perfil).values_list('id_permiso_id', flat=True)
        )

        with transaction.atomic():
            # Con operaciones de conjuntos: se agregan los tildados que no tenía y se sacan los
            # que tenía y ahora no están tildados. Todo dentro de una transacción.
            nuevos = ids_seleccionados - ids_asignados
            for id_permiso in nuevos:
                Permisos_x_Perfiles.objects.create(id_perfil=perfil, id_permiso_id=id_permiso)

            quitados = ids_asignados - ids_seleccionados
            if quitados:
                Permisos_x_Perfiles.objects.filter(id_perfil=perfil, id_permiso_id__in=quitados).delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


# Catálogo de permisos. El código interno (ver_..., gestionar_...) lo arma el serializer.
class PermisosViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Permisos'
    queryset = Permisos.objects.all().order_by('nombre_permiso')
    serializer_class = PermisosSerializer
    permission_classes = [permiso_modulo('permisos')]

    # No se elimina un permiso que está tildado en algún perfil: primero hay que
    # destildarlo. El mensaje dice en qué perfiles está.
    def validar_eliminacion(self, permiso):
        perfiles = Permisos_x_Perfiles.objects.filter(id_permiso=permiso).select_related('id_perfil')
        if perfiles.exists():
            nombres = ', '.join(sorted({r.id_perfil.tipo_perfil for r in perfiles}))
            return f'No se puede eliminar "{permiso.nombre_permiso}" porque está asignado a estos perfiles: {nombres}.'

    # Botones Desactivar y Reactivar de la lista. Un permiso desactivado sigue tildado en
    # los perfiles pero no tiene efecto en ninguno (ver permissions.py) hasta reactivarlo.
    @action(detail=True, methods=['post'], url_path='desactivar')
    def desactivar(self, request, pk=None):
        permiso = self.get_object()
        if not permiso.estado_permiso:
            return Response({'detail': f'"{permiso}" ya está desactivado.'}, status=status.HTTP_409_CONFLICT)
        if permiso.codigo in PermisosSerializer.NO_DESACTIVABLES:
            return Response({'detail': f'"{permiso}" no se puede desactivar: sin él nadie podría volver a entrar '
                                       'a Permisos para activarlo.'}, status=status.HTTP_409_CONFLICT)
        permiso.estado_permiso = False
        permiso.save(update_fields=['estado_permiso'])
        return Response(self.get_serializer(permiso).data)

    @action(detail=True, methods=['post'], url_path='reactivar')
    def reactivar(self, request, pk=None):
        permiso = self.get_object()
        if permiso.estado_permiso:
            return Response({'detail': f'"{permiso}" ya está activo.'}, status=status.HTTP_409_CONFLICT)
        permiso.estado_permiso = True
        permiso.save(update_fields=['estado_permiso'])
        return Response(self.get_serializer(permiso).data)


# Usuarios del sistema. Se crean a partir de un empleado, con usuario y contraseña
# automáticos (ver UsuariosSerializer). Se desactivan y reactivan; solo se eliminan si
# nunca se usaron (ver validar_eliminacion).
class UsuariosViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Usuarios'
    queryset = (
        Usuarios.objects.select_related('id_perfil', 'id_empleado').all()
        .order_by('id_empleado__apellido_emp', 'id_empleado__nombre_emp')
    )
    serializer_class = UsuariosSerializer
    permission_classes = [permiso_modulo('usuarios')]

    # En el registro de actividad también se anota el correo, que se guarda en el empleado
    # (se lee de la base para tener el valor actualizado después de modificarlo)
    def datos_extra_registro(self, usuario):
        return {'Email': Empleados.objects.filter(pk=usuario.id_empleado_id).values_list('email_emp', flat=True).first()}

    # Arma la respuesta después de generar una contraseña temporal: si el mail salió,
    # solo se avisa a qué correo se mandó; si no salió, se devuelve la contraseña para que
    # el administrador se la pase al empleado (es la única vez que se puede ver).
    def _respuesta_contraseña(self, usuario, contraseña, enviado):
        datos = {'mail_enviado': enviado, 'correo': usuario.correo}
        if not enviado:
            datos['contraseña_temporal'] = contraseña
        return datos

    def create(self, request, *args, **kwargs):
        """Crea el usuario de un empleado y le manda la contraseña temporal por mail."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        usuario = serializer.save()
        contraseña = serializer.contraseña_temporal
        enviado = enviar_contraseña_temporal(usuario, contraseña, motivo='alta')
        datos = {**serializer.data, **self._respuesta_contraseña(usuario, contraseña, enviado)}
        return Response(datos, status=status.HTTP_201_CREATED)

    # Eliminar (tachito, ver EliminarMixin): solo un usuario que nunca se usó, por ejemplo
    # uno creado por error. Si ya registró o anuló reservas, anuló pagos o tiene movimientos
    # en el registro de actividad (por ejemplo, ya inició sesión), no se borra para no perder
    # el historial: se desactiva. Tampoco se puede eliminar el usuario con el que se está.
    # Sus sesiones y links de recuperación se borran solos con él (CASCADE).
    def validar_eliminacion(self, usuario):
        if usuario.pk == getattr(self.request.user, 'pk', None):
            return 'No podés eliminar tu propio usuario.'
        usado = (
            Reservas.objects.filter(id_usuario_registro=usuario).exists()
            or Reservas.objects.filter(id_usuario_anulacion=usuario).exists()
            or Pagos.objects.filter(id_usuario_anulacion=usuario).exists()
            or Registro_Actividad.objects.filter(id_usuario=usuario).exists()
        )
        if usado:
            return (f'No se puede eliminar a "{usuario}" porque ya usó el sistema y tiene historial. '
                    'Podés desactivarlo para que no pueda volver a ingresar.')

    @action(detail=True, methods=['post'], url_path='desactivar')
    def desactivar(self, request, pk=None):
        """
        Desactivar (baja lógica): no se borra la fila, así se conserva su historial. Se marca
        activo=False + fecha_baja y se cierran sus sesiones abiertas para que un token ya
        emitido deje de servir. Se puede deshacer con Reactivar.
        """
        usuario = self.get_object()
        if not usuario.activo:
            return Response({'detail': f'"{usuario}" ya está desactivado.'}, status=status.HTTP_409_CONFLICT)
        if usuario.pk == request.user.pk:
            return Response({'detail': 'No podés desactivar tu propio usuario.'}, status=status.HTTP_409_CONFLICT)
        usuario.activo = False
        usuario.fecha_baja = timezone.localdate()
        usuario.save()
        SesionToken.objects.filter(id_usuario=usuario).delete()
        return Response(UsuariosSerializer(usuario).data)

    @action(detail=True, methods=['post'], url_path='restablecer-clave')
    def restablecer_clave(self, request, pk=None):
        """
        Genera una contraseña temporal nueva, se la manda por mail al empleado y lo obliga
        a cambiarla en el próximo ingreso. También cierra las sesiones que tenga abiertas.
        """
        usuario = self.get_object()
        contraseña = generar_contraseña_temporal()
        usuario.contraseña = make_password(contraseña)
        usuario.debe_cambiar_clave = True
        usuario.save()
        SesionToken.objects.filter(id_usuario=usuario).delete()
        enviado = enviar_contraseña_temporal(usuario, contraseña, motivo='restablecer')
        return Response(self._respuesta_contraseña(usuario, contraseña, enviado))

    @action(detail=True, methods=['post'], url_path='reactivar')
    def reactivar(self, request, pk=None):
        """Contraparte de la baja lógica: reactiva a un usuario dado de baja."""
        usuario = self.get_object()
        # Si el empleado está desactivado, primero hay que reactivarlo a él (desde Empleados)
        if not usuario.id_empleado.activo:
            return Response({'detail': f'No se puede reactivar: el empleado {usuario.id_empleado} está desactivado. Reactivalo primero desde Empleados.'},
                            status=status.HTTP_409_CONFLICT)
        usuario.activo = True
        usuario.fecha_baja = None
        usuario.save()
        return Response(UsuariosSerializer(usuario).data)


# ---------------- Clientes y personal ----------------
#
# Clientes. Se eliminan solo si nunca tuvieron una reserva.
class ClientesViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Clientes'
    queryset = Clientes.objects.all().order_by('apellido_cliente', 'nombre_cliente')
    serializer_class = ClientesSerializer
    permission_classes = [permiso_modulo('clientes')]

    # No se elimina un cliente que tiene reservas, sin importar el estado (también cuentan
    # las finalizadas y las anuladas): si lo borramos, esas reservas se quedan sin cliente.
    def validar_eliminacion(self, cliente):
        cantidad = Reservas.objects.filter(id_cliente=cliente).count()
        if cantidad:
            return f'No se puede eliminar a "{cliente}" porque tiene {cantidad} reserva(s) registrada(s).'


# Empleados. Además del ABM tiene /empleados/<id>/puestos/ para asignarle puestos
# y /empleados/<id>/horario/ para asignarle su horario laboral.
# Se eliminan si no tienen usuario ni trabajaron en reservas; si no, se pueden desactivar.
class EmpleadosViewSet(RegistrarActividadMixin, EliminarMixin, DesactivarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Empleados'
    queryset = Empleados.objects.all().order_by('apellido_emp', 'nombre_emp')
    serializer_class = EmpleadosSerializer
    permission_classes = [permiso_modulo('empleados')]

    # En el registro de actividad también se anotan los puestos y el horario del empleado
    def datos_extra_registro(self, empleado):
        horario = Horarios_x_Empleados.objects.filter(id_empleado=empleado).select_related('id_horario').first()
        return {
            'Puestos': sorted(
                Puestos_x_Empleados.objects.filter(id_empleado=empleado).values_list('id_puesto__nombre_puesto', flat=True)
            ),
            'Horario': f'{texto_valor(horario.id_horario.cantidad_horas)} horas' if horario else None,
        }

    # No se elimina un empleado que tiene usuario (aunque esté dado de baja) ni uno que
    # trabajó en alguna reserva. En esos casos el mensaje avisa que se puede desactivar.
    # Si se elimina, los puestos y horarios que tenía asignados se desasignan solos.
    def validar_eliminacion(self, empleado):
        if Usuarios.objects.filter(id_empleado=empleado).exists():
            return (f'No se puede eliminar a "{empleado}" porque tiene un usuario del sistema. '
                    'Podés desactivarlo para que deje de ofrecerse en las reservas nuevas.')
        if Detalles_Reservas.objects.filter(id_empleado=empleado).exists():
            return (f'No se puede eliminar a "{empleado}" porque estuvo asignado a reservas. '
                    'Podés desactivarlo para que deje de ofrecerse en las reservas nuevas.')

    # No se desactiva un empleado que todavía puede entrar al sistema (primero hay que
    # darle de baja el usuario) ni uno que tiene eventos por hacer (reservas pendientes
    # o confirmadas).
    def validar_desactivacion(self, empleado):
        if Usuarios.objects.filter(id_empleado=empleado, activo=True).exists():
            return f'No se puede desactivar a "{empleado}" porque tiene un usuario activo. Dalo de baja primero desde Usuarios.'
        if Detalles_Reservas.objects.filter(id_empleado=empleado, id_reserva__estado_reserva__in=('PENDIENTE', 'CONFIRMADA')).exists():
            return f'No se puede desactivar a "{empleado}" porque está asignado a reservas pendientes o confirmadas.'

    @action(detail=True, methods=['get', 'put'], url_path='puestos')
    def puestos(self, request, pk=None):
        """Asignar Puestos: qué puestos tiene un empleado (tabla Puestos_x_Empleados)."""
        empleado = self.get_object()

        if request.method == 'GET':
            asignados = set(
                Puestos_x_Empleados.objects.filter(id_empleado=empleado).values_list('id_puesto_id', flat=True)
            )
            puestos_qs = Puestos.objects.select_related('id_sueldo').order_by('nombre_puesto')
            for puesto in puestos_qs:
                puesto.asignado = puesto.pk in asignados
            serializer = PuestoConEstadoSerializer(puestos_qs, many=True)
            return Response(serializer.data)

        # Misma lógica que con los permisos de un perfil: se agregan los nuevos y se sacan los destildados
        # PUT: sincroniza la lista completa de puestos seleccionados
        ids_seleccionados = request.data.get('puestos', [])
        if not isinstance(ids_seleccionados, list):
            raise ValidationError({'puestos': 'Debe ser una lista de ids de puestos.'})
        ids_seleccionados = {int(pk) for pk in ids_seleccionados}

        ids_asignados = set(
            Puestos_x_Empleados.objects.filter(id_empleado=empleado).values_list('id_puesto_id', flat=True)
        )

        with transaction.atomic():
            nuevos = ids_seleccionados - ids_asignados
            for id_puesto in nuevos:
                Puestos_x_Empleados.objects.create(id_empleado=empleado, id_puesto_id=id_puesto)

            quitados = ids_asignados - ids_seleccionados
            if quitados:
                Puestos_x_Empleados.objects.filter(id_empleado=empleado, id_puesto_id__in=quitados).delete()

        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['get', 'put'], url_path='horario')
    def horario(self, request, pk=None):
        """
        Asignar Horarios: el horario laboral del empleado (tabla Horarios_x_Empleados).
        Cada empleado tiene un solo horario o ninguno.
        GET devuelve el horario asignado y la lista de horarios para elegir (así quien edita
        empleados no necesita además el permiso de Horarios).
        PUT recibe { "id_horario": 3 } para asignarlo o { "id_horario": null } para quitarlo.
        """
        empleado = self.get_object()
        asignado = Horarios_x_Empleados.objects.filter(id_empleado=empleado).first()

        if request.method == 'GET':
            horarios_qs = Horarios.objects.order_by('cantidad_horas')
            return Response({
                'id_horario': asignado.id_horario_id if asignado else None,
                'horarios': HorariosSerializer(horarios_qs, many=True).data,
            })

        # PUT: se reemplaza el horario que tenía por el elegido (o se le quita si viene vacío)
        id_horario = request.data.get('id_horario')
        if id_horario in (None, ''):
            horario = None
        else:
            horario = Horarios.objects.filter(pk=id_horario).first() if str(id_horario).isdigit() else None
            if horario is None:
                raise ValidationError({'id_horario': 'El horario elegido no existe.'})

        with transaction.atomic():
            Horarios_x_Empleados.objects.filter(id_empleado=empleado).delete()
            if horario:
                Horarios_x_Empleados.objects.create(id_empleado=empleado, id_horario=horario)

        return Response(status=status.HTTP_204_NO_CONTENT)


# Sueldos. No se puede eliminar uno que esté asignado a algún puesto.
class SueldosViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Sueldos'
    # Con cuántos puestos usan cada sueldo, para mostrarlo en la lista
    queryset = Sueldos.objects.annotate(cantidad_puestos=Count('puestos')).order_by('monto_sueldo')
    serializer_class = SueldosSerializer
    permission_classes = [permiso_modulo('sueldos')]

    # No se elimina un sueldo que usa algún puesto
    def validar_eliminacion(self, sueldo):
        if Puestos.objects.filter(id_sueldo=sueldo).exists():
            return f'No se puede eliminar el sueldo "${sueldo.monto_sueldo}" porque hay puestos que lo usan.'


# Puestos de trabajo, con su sueldo.
class PuestosViewSet(RegistrarActividadMixin, EliminarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Puestos'
    # Con cuántos empleados tienen cada puesto, para mostrarlo en la lista
    queryset = Puestos.objects.select_related('id_sueldo').annotate(
        cantidad_empleados=Count('puestos_x_empleados')
    ).order_by('nombre_puesto')
    serializer_class = PuestosSerializer
    permission_classes = [permiso_modulo('puestos')]

    # No se elimina un puesto que tiene algún empleado: primero hay que sacárselo a esos
    # empleados desde la pantalla de Empleados
    def validar_eliminacion(self, puesto):
        cantidad = Puestos_x_Empleados.objects.filter(id_puesto=puesto).count()
        if cantidad:
            return f'No se puede eliminar "{puesto.nombre_puesto}" porque lo tienen asignado {cantidad} empleado(s).'


# ---------------- Servicios, reservas y pagos (proceso del Hito 3) ----------------
#
# Servicios que se ofrecen, con los equipos que usa cada uno (ver ServiciosSerializer).
# Se eliminan si nunca se contrataron; si figuran en alguna reserva se pueden desactivar.
class ServiciosViewSet(RegistrarActividadMixin, EliminarMixin, DesactivarMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Servicios'
    queryset = Servicios.objects.all().order_by('tipo_servicio')
    serializer_class = ServiciosSerializer
    permission_classes = [permiso_modulo('servicios')]

    # En el registro de actividad también se anotan los equipos que usa (ej: "Bafle JBL x 4")
    def datos_extra_registro(self, servicio):
        return {'Equipos que usa': sorted(
            f'{e.id_equipo.nombre_equipo} x {e.cantidad}'
            for e in Equipos_x_Servicios.objects.filter(id_servicio=servicio).select_related('id_equipo')
        )}

    # No se elimina un servicio que está en alguna reserva, sin importar el estado: si lo
    # borramos no se sabría qué contrató el cliente. El mensaje avisa que se puede desactivar.
    # Si se elimina, la lista de equipos que usaba se borra con él (los equipos no).
    def validar_eliminacion(self, servicio):
        if Reservas_x_Servicios.objects.filter(id_servicio=servicio).exists():
            return (f'No se puede eliminar "{servicio.tipo_servicio}" porque figura en reservas. '
                    'Podés desactivarlo para que deje de ofrecerse en las reservas nuevas.')

    # No se desactiva un servicio que está en reservas que todavía no se hicieron
    # (pendientes o confirmadas). En las reservas viejas no molesta: lo siguen mostrando
    # con el precio que tenía.
    def validar_desactivacion(self, servicio):
        if Reservas_x_Servicios.objects.filter(id_servicio=servicio, id_reserva__estado_reserva__in=('PENDIENTE', 'CONFIRMADA')).exists():
            return f'No se puede desactivar "{servicio.tipo_servicio}" porque está en reservas pendientes o confirmadas.'


# Reservas: el proceso principal. Registrar y editar los maneja ReservasSerializer
# (estado automático, transacción, disponibilidad de equipos y personal). Acá se
# agregan la prohibición de borrar y la acción de anular.
class ReservasViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Reservas'
    queryset = (
        Reservas.objects.select_related(
            'id_cliente', 'id_usuario_registro__id_empleado', 'id_usuario_anulacion__id_empleado'
        ).all().order_by('-fecha_evento', '-hora_evento')
    )
    serializer_class = ReservasSerializer
    permission_classes = [permiso_modulo('reservas')]

    # En el registro de actividad también se anotan los servicios contratados (con el
    # precio cobrado) y el personal asignado
    def datos_extra_registro(self, reserva):
        return {
            'Servicios': sorted(
                f'{s.id_servicio.tipo_servicio} ($ {texto_valor(s.precio_servicio)})'
                for s in Reservas_x_Servicios.objects.filter(id_reserva=reserva).select_related('id_servicio')
            ),
            'Personal': sorted(
                str(d.id_empleado) for d in Detalles_Reservas.objects.filter(id_reserva=reserva).select_related('id_empleado')
            ),
        }

    # Las reservas no se borran nunca de la base (pedido del Hito 3): se anulan con la
    # acción "anular" de abajo, que deja registrado quién, cuándo y por qué.
    def destroy(self, request, *args, **kwargs):
        return Response(
            {'detail': 'Las reservas no se eliminan: usá la opción "Anular" e indicá el motivo.'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED,
        )

    @action(detail=True, methods=['post'], url_path='confirmar')
    def confirmar(self, request, pk=None):
        """
        Confirmar: el cliente aceptó la reserva y pasa de Pendiente a Confirmada.
        Lo puede hacer quien tiene permiso de gestionar reservas (es un POST).
        Los equipos ya estaban apartados desde que se cargó la reserva (las pendientes
        también ocupan equipos), pero se vuelve a controlar por si mientras tanto cambió
        algo, por ejemplo un equipo que pasó a "En reparación".
        """
        reserva = self.get_object()
        if reserva.estado_reserva != 'PENDIENTE':
            return Response({'detail': f'Solo se pueden confirmar reservas pendientes (esta está {reserva.get_estado_reserva_display()}).'},
                            status=status.HTTP_409_CONFLICT)

        servicios = list(Reservas_x_Servicios.objects.filter(id_reserva=reserva).values_list('id_servicio_id', flat=True))
        faltantes = equipos_faltantes(servicios, reserva.fecha_evento, excluir_reserva=reserva)
        if faltantes:
            return Response({'detail': f'No se puede confirmar: no hay equipos suficientes el {reserva.fecha_evento:%d/%m/%Y}: '
                                       + '; '.join(faltantes) + '.'}, status=status.HTTP_409_CONFLICT)

        reserva.estado_reserva = 'CONFIRMADA'
        reserva.save(update_fields=['estado_reserva'])
        # Qué cambió (el estado, de Pendiente a Confirmada), comparando con cómo estaba antes
        _, cambios = self._cambios_desde_antes()
        registrar(request, Registro_Actividad.MODIFICACION, f'Confirmó {reserva}', 'Reservas', reserva.pk,
                  texto_cambios(cambios, Registro_Actividad.MODIFICACION), cambios=cambios)
        return Response(self.get_serializer(reserva).data)

    @action(detail=False, methods=['get'], url_path='disponibilidad')
    def disponibilidad(self, request):
        """
        /api/reservas/disponibilidad/?fecha=2026-10-18[&excluir=12]
        Cuántas unidades de cada equipo quedan libres ese día y qué empleados ya trabajan
        ese día. La usa el formulario de reserva para marcar los servicios y el personal
        que no se pueden elegir esa fecha.
        "excluir" es la reserva que se está editando, para que no se cuente a sí misma.
        """
        try:
            fecha = datetime.date.fromisoformat(request.query_params.get('fecha', ''))
        except ValueError:
            return Response({'fecha': 'Mandá la fecha como AAAA-MM-DD.'}, status=status.HTTP_400_BAD_REQUEST)
        excluir = request.query_params.get('excluir')
        excluir = int(excluir) if excluir and excluir.isdigit() else None
        return Response({
            'fecha': fecha,
            'equipos': disponibilidad_del_dia(fecha, excluir),
            'empleados_ocupados': sorted(empleados_ocupados(fecha, excluir)),
        })

    @action(detail=True, methods=['post'], url_path='anular', permission_classes=[permiso_codigo('anular_reservas')])
    def anular(self, request, pk=None):
        """
        Anula una reserva: pasa a ANULADA guardando fecha, motivo y usuario que la anuló.
        Solo lo pueden hacer los perfiles con el permiso "Anular Reservas".
        Al quedar anulada, sus equipos y su personal vuelven a estar disponibles para ese
        día (las anuladas no cuentan en los controles de disponibilidad).
        No se puede anular si:
          - ya estaba anulada,
          - el evento ya se hizo (Finalizada),
          - tiene pagos registrados (por ahora no hay devoluciones).
        """
        # Primero todas las validaciones; recién si pasan todas se toca la base
        reserva = self.get_object()
        motivo = (request.data.get('motivo') or '').strip()

        if len(motivo) < 10:
            return Response({'motivo': 'Escribí el motivo de la anulación (al menos 10 caracteres).'},
                            status=status.HTTP_400_BAD_REQUEST)
        if reserva.estado_reserva == 'ANULADA':
            return Response({'detail': 'Esta reserva ya está anulada.'}, status=status.HTTP_409_CONFLICT)
        if reserva.estado_reserva == 'FINALIZADA':
            return Response({'detail': 'No se puede anular una reserva Finalizada: el evento ya se realizó.'},
                            status=status.HTTP_409_CONFLICT)
        cantidad_pagos = Pagos.objects.activos().filter(id_reserva=reserva).count()
        if cantidad_pagos:
            return Response(
                {'detail': f'No se puede anular: la reserva tiene {cantidad_pagos} pago(s) registrado(s) '
                           'y por ahora no se hacen devoluciones.'},
                status=status.HTTP_409_CONFLICT,
            )

        # Todo junto o nada: cambio de estado y datos de la anulación
        with transaction.atomic():
            reserva.estado_reserva = 'ANULADA'
            reserva.fecha_anulacion = timezone.now()
            reserva.motivo_anulacion = motivo[:255]
            reserva.id_usuario_anulacion = request.user
            reserva.save(update_fields=['estado_reserva', 'fecha_anulacion', 'motivo_anulacion', 'id_usuario_anulacion'])
            # Qué cambió: el estado y los datos de la anulación (fecha, motivo y quién)
            _, cambios = self._cambios_desde_antes()
            registrar(request, Registro_Actividad.BAJA, f'Anuló {reserva}', 'Reservas', reserva.pk,
                      texto_cambios(cambios, Registro_Actividad.MODIFICACION), cambios=cambios)

        return Response(self.get_serializer(reserva).data)


# Pagos de las reservas. Al crear o editar, el serializer valida que no superen el saldo
# y recalcula los saldos. Los pagos no se eliminan: se anulan con la acción de abajo.
class PagosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Pagos'
    # Se traen todos los pagos, también los anulados: en la pantalla se ven con el cartel
    # "Anulado", así queda a la vista lo que pasó
    queryset = (
        Pagos.objects.select_related('id_reserva', 'id_reserva__id_cliente', 'id_usuario_anulacion__id_empleado')
        .all().order_by('-id_pago')
    )
    serializer_class = PagosSerializer
    permission_classes = [permiso_modulo('pagos')]

    # En el registro de actividad también se anotan los métodos con los que se pagó
    def datos_extra_registro(self, pago):
        return {'Métodos de pago': sorted(
            Detalles_de_Pago.objects.filter(id_pago=pago).values_list('id_metodo_pago__metodo_pago', flat=True)
        )}

    # Los pagos no se pueden eliminar porque es plata que se cobró. Si alguien lo intenta,
    # se le avisa que tiene que usar "Anular"
    def destroy(self, request, *args, **kwargs):
        return Response(
            {'detail': 'Los pagos no se eliminan: usá la opción "Anular" e indicá el motivo.'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED,
        )

    @action(detail=True, methods=['post'], url_path='anular')
    def anular(self, request, pk=None):
        """
        Anular un pago. El pago no se borra: queda marcado como anulado y se guarda la
        fecha, el motivo y quién lo anuló.
        Como ese pago ya no cuenta, cambia lo que falta pagar de la reserva, así que se
        vuelven a calcular los saldos de los otros pagos.
        No se puede deshacer: si se anuló por error hay que cargar el pago de nuevo.
        Lo puede hacer cualquier usuario que tenga permiso para gestionar pagos.
        """
        pago = self.get_object()
        # El motivo que escribió el usuario, sin los espacios de adelante y de atrás
        motivo = (request.data.get('motivo') or '').strip()

        # Antes de tocar nada revisamos que esté todo bien:
        # el motivo es obligatorio y tiene que decir algo (mínimo 10 letras)
        if len(motivo) < 10:
            return Response({'motivo': 'Escribí el motivo de la anulación (al menos 10 caracteres).'},
                            status=status.HTTP_400_BAD_REQUEST)
        # y no se puede anular dos veces el mismo pago
        if not pago.activo:
            return Response({'detail': 'Este pago ya está anulado.'}, status=status.HTTP_409_CONFLICT)

        # Va todo dentro de "atomic": o se hace todo (anular, recalcular los saldos y
        # anotarlo en el registro de actividad) o no se hace nada. Así no puede quedar
        # un pago anulado con los saldos sin actualizar
        with transaction.atomic():
            pago.activo = False                       # anulado
            pago.fecha_baja = timezone.now()          # cuándo
            pago.motivo_anulacion = motivo[:255]      # por qué
            pago.id_usuario_anulacion = request.user  # quién
            pago.save(update_fields=['activo', 'fecha_baja', 'motivo_anulacion', 'id_usuario_anulacion'])
            recalcular_saldos(pago.id_reserva)
            # Se anota en el registro de actividad con lo que cambió (activo, fecha, motivo
            # y quién lo anuló) y el monto del pago anulado
            _, cambios = self._cambios_desde_antes()
            registrar(request, Registro_Actividad.BAJA, f'Anuló {pago}', 'Pagos', pago.pk,
                      f'Monto: {texto_valor(pago.monto)}\n' + texto_cambios(cambios, Registro_Actividad.MODIFICACION),
                      cambios=cambios)

        # Devolvemos el pago ya anulado para que la pantalla lo muestre actualizado
        return Response(self.get_serializer(pago).data)


# ---------------- Consultas ----------------
#
# ReadOnlyModelViewSet: solo tiene listar y ver uno, no crear, editar ni borrar
class RegistroActividadViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Consulta del registro de actividad. Es de solo lectura: nadie puede editar ni borrar
    lo que quedó registrado. Devuelve los últimos 2000 movimientos (los más nuevos primero),
    que alcanzan para la pantalla; los filtros se aplican en el frontend como en los demás módulos.
    """
    serializer_class = RegistroActividadSerializer
    permission_classes = [permiso_modulo('registro')]

    def get_queryset(self):
        return Registro_Actividad.objects.select_related('id_usuario__id_empleado').order_by('-fecha')[:2000]


class DashboardResumenView(APIView):
    """
    Datos reales para las cards de la pantalla de Inicio.
    Solo exponemos lo que hoy tiene backend; el resto de los módulos
    del sidebar (Servicios como paquete, Pagos) todavía no están
    implementados, así que no se inventan cifras de negocio.
    """

    def get(self, request):
        # Equipos agrupados por estado (para las barras de "Estado de equipos" en Inicio).
        # values + annotate arma un GROUP BY: cuántos equipos hay de cada estado.
        total = Equipos.objects.count()
        por_estado = list(
            Equipos.objects.values('id_estadoeq', 'id_estadoeq__nombre_estadoeq')
            .annotate(cantidad=Count('id_equipo'))
            .order_by('id_estadoeq__nombre_estadoeq')
        )
        por_estado = [
            {
                'id_estadoeq': r['id_estadoeq'],
                'nombre_estadoeq': r['id_estadoeq__nombre_estadoeq'],
                'cantidad': r['cantidad'],
            }
            for r in por_estado
        ]

        # Reservas de hoy (sin contar las anuladas) y las próximas 5, para la lista de Inicio
        hoy = timezone.localdate()

        # Equipos HOY (contando cada equipo, ej: 6 bafles = 6): libres, en uso por reservas de hoy y en reparación
        # (ver disponibilidad.py). Es lo que muestran la tarjeta y las barras de Inicio.
        dia = disponibilidad_del_dia(hoy)
        equipos_hoy = {
            'total': sum(e['total'] for e in dia),
            'libres': sum(e['libres'] for e in dia),
            'ocupadas': sum(min(e['ocupadas'], e['total']) for e in dia if not e['en_reparacion']),
            'en_reparacion': sum(e['total'] for e in dia if e['en_reparacion']),
            # Qué equipos están en uso hoy y cuántos de cada uno (ej: 4 Bafle)
            'en_uso': [{'nombre_equipo': e['nombre_equipo'], 'cantidad': min(e['ocupadas'], e['total'])}
                       for e in dia if e['ocupadas'] > 0 and not e['en_reparacion']],
            # Los equipos que hoy no tienen ninguno libre, para listarlos por nombre
            'agotados': [e['nombre_equipo'] for e in dia if e['libres'] == 0 and e['total'] > 0],
        }
        reservas_hoy_qs = Reservas.objects.filter(fecha_evento=hoy).exclude(estado_reserva='ANULADA')

        proximas_qs = (
            Reservas.objects.select_related('id_cliente')
            .filter(fecha_evento__gte=hoy)
            .exclude(estado_reserva='ANULADA')
            .order_by('fecha_evento', 'hora_evento')[:5]
        )
        proximas = [
            {
                'id_reserva': r.id_reserva,
                'cliente_nombre': str(r.id_cliente),
                'nombre_evento': r.nombre_evento,
                'fecha_evento': r.fecha_evento,
                'hora_evento': r.hora_evento,
                'estado_reserva': r.estado_reserva,
                'estado_display': r.get_estado_reserva_display(),
            }
            for r in proximas_qs
        ]

        return Response({
            'equipos': {
                'total': total,
                'por_estado': por_estado,
            },
            'equipos_hoy': equipos_hoy,
            'usuarios_total': Usuarios.objects.filter(activo=True).count(),
            'perfiles_total': Perfiles.objects.count(),
            'reservas_hoy': reservas_hoy_qs.count(),
            'reservas_hoy_confirmadas': reservas_hoy_qs.filter(estado_reserva='CONFIRMADA').count(),
            'reservas_hoy_pendientes': reservas_hoy_qs.filter(estado_reserva='PENDIENTE').count(),
            'proximas_reservas': proximas,
        })
 