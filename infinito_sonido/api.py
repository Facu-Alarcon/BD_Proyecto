import hashlib
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.db import transaction
from django.db.models import Count, ProtectedError
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import (
    Tipo_Equipos, Estado_Equipos, Equipos,
    Perfiles, Usuarios,
    Permisos, Permisos_x_Perfiles,
    SesionToken,
    Clientes, Empleados, Servicios, Reservas, Reservas_x_Servicios,
    Sueldos, Puestos, Puestos_x_Empleados,
    Horarios, Metodo_Pagos, Pagos,
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
from .permissions import permiso_modulo, permisos_del_usuario
from .correos import enviar_contraseña_temporal, enviar_link_recuperacion
from .registro import RegistrarActividadMixin, registrar
from .seguridad import generar_contraseña_temporal, validar_contraseña_segura


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


class LoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        usuario_nombre = (request.data.get('usuario') or '').strip()
        contraseña = request.data.get('contraseña') or request.data.get('password') or ''

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

        if not check_password(contraseña, usuario.contraseña):
            registrar(request, Registro_Actividad.LOGIN_FALLIDO, 'Contraseña incorrecta', 'Sesión', usuario=usuario)
            return Response(error, status=status.HTTP_401_UNAUTHORIZED)

        if not usuario.activo:
            registrar(request, Registro_Actividad.LOGIN_FALLIDO, 'Usuario dado de baja', 'Sesión', usuario=usuario)
            return Response({'detail': 'Este usuario está dado de baja.'}, status=status.HTTP_403_FORBIDDEN)

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
    Paso 1 de "Olvidé mi contraseña": el usuario escribe su DNI y, si existe y está activo,
    se le manda por mail un link para elegir una contraseña nueva.

    Siempre responde lo mismo, exista o no el usuario: así esta pantalla no sirve para
    averiguar qué DNI tienen cuenta en el sistema. La contraseña actual NO se toca: sigue
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
            return Response({'detail': 'Escribí tu usuario (tu DNI).'}, status=status.HTTP_400_BAD_REQUEST)

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


class LogoutView(APIView):
    def post(self, request):
        # request.auth es la instancia de SesionToken usada para autenticar (ver authentication.py)
        if request.auth is not None:
            request.auth.delete()
        registrar(request, Registro_Actividad.LOGOUT, 'Cerró sesión', 'Sesión')
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    def get(self, request):
        return Response(_usuario_repr(request.user))


class TipoEquiposViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Tipos de equipo'
    queryset = Tipo_Equipos.objects.all().order_by('nombre_tipoeq')
    serializer_class = TipoEquiposSerializer
    permission_classes = [permiso_modulo('tipos_equipo')]

    def destroy(self, request, *args, **kwargs):
        tipo = self.get_object()
        try:
            tipo.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar "{tipo.nombre_tipoeq}" porque hay equipos de ese tipo.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class HorariosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Horarios'
    queryset = Horarios.objects.all().order_by('cantidad_horas')
    serializer_class = HorariosSerializer
    permission_classes = [permiso_modulo('horarios')]


class MetodoPagosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Métodos de pago'
    queryset = Metodo_Pagos.objects.all().order_by('metodo_pago')
    serializer_class = MetodoPagosSerializer
    permission_classes = [permiso_modulo('metodos_pago')]

    def destroy(self, request, *args, **kwargs):
        metodo = self.get_object()
        try:
            metodo.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar "{metodo.metodo_pago}" porque hay pagos que lo usan.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class EstadoEquiposViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    """
    Catálogo editable de estados de equipo (antes era una lista fija
    DISPONIBLE/EN_USO/EN_REPARACION hardcodeada). Se puede crear un
    estado nuevo desde acá, incluido el botón "+" del formulario de Equipos.
    """
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Estados de equipo'
    queryset = Estado_Equipos.objects.all().order_by('nombre_estadoeq')
    serializer_class = EstadoEquiposSerializer
    permission_classes = [permiso_modulo('equipos')]

    def destroy(self, request, *args, **kwargs):
        estado = self.get_object()
        try:
            estado.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar "{estado.nombre_estadoeq}" porque hay equipos con ese estado.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class EquiposViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Equipos'
    queryset = Equipos.objects.select_related('id_tipoeq', 'id_estadoeq').all().order_by('nombre_equipo')
    serializer_class = EquiposSerializer
    permission_classes = [permiso_modulo('equipos')]

    def destroy(self, request, *args, **kwargs):
        equipo = self.get_object()
        try:
            equipo.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar "{equipo.nombre_equipo}" porque tiene servicios asociados.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PerfilesViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Perfiles'
    queryset = Perfiles.objects.all().order_by('tipo_perfil')
    serializer_class = PerfilesSerializer
    permission_classes = [permiso_modulo('perfiles')]

    def destroy(self, request, *args, **kwargs):
        perfil = self.get_object()
        try:
            perfil.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar "{perfil.tipo_perfil}" porque hay usuarios con ese perfil.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)

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
            nuevos = ids_seleccionados - ids_asignados
            for id_permiso in nuevos:
                Permisos_x_Perfiles.objects.create(id_perfil=perfil, id_permiso_id=id_permiso)

            quitados = ids_asignados - ids_seleccionados
            if quitados:
                Permisos_x_Perfiles.objects.filter(id_perfil=perfil, id_permiso_id__in=quitados).delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


class PermisosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Permisos'
    queryset = Permisos.objects.all().order_by('nombre_permiso')
    serializer_class = PermisosSerializer
    permission_classes = [permiso_modulo('permisos')]


class UsuariosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Usuarios'
    queryset = (
        Usuarios.objects.select_related('id_perfil', 'id_empleado').all()
        .order_by('id_empleado__apellido_emp', 'id_empleado__nombre_emp')
    )
    serializer_class = UsuariosSerializer
    permission_classes = [permiso_modulo('usuarios')]

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

    def destroy(self, request, *args, **kwargs):
        """
        Baja lógica: no se borra la fila (rompería el historial de
        reservas/pagos si el usuario quedó vinculado a algo). Se marca
        activo=False + fecha_baja y se cierran sus sesiones activas para
        que un token ya emitido deje de servir.
        """
        usuario = self.get_object()
        usuario.activo = False
        usuario.fecha_baja = timezone.localdate()
        usuario.save()
        SesionToken.objects.filter(id_usuario=usuario).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

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
        usuario.activo = True
        usuario.fecha_baja = None
        usuario.save()
        return Response(UsuariosSerializer(usuario).data)


class ClientesViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Clientes'
    queryset = Clientes.objects.all().order_by('apellido_cliente', 'nombre_cliente')
    serializer_class = ClientesSerializer
    permission_classes = [permiso_modulo('clientes')]

    def destroy(self, request, *args, **kwargs):
        cliente = self.get_object()
        try:
            cliente.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar a "{cliente}" porque tiene reservas asociadas.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class EmpleadosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Empleados'
    queryset = Empleados.objects.all().order_by('apellido_emp', 'nombre_emp')
    serializer_class = EmpleadosSerializer
    permission_classes = [permiso_modulo('empleados')]

    def destroy(self, request, *args, **kwargs):
        empleado = self.get_object()
        # Un empleado con usuario no se puede borrar: el usuario se da de baja desde Usuarios
        if hasattr(empleado, 'usuario'):
            return Response(
                {'detail': f'No se puede eliminar a "{empleado}" porque tiene un usuario del sistema. Dalo de baja desde Usuarios.'},
                status=status.HTTP_409_CONFLICT,
            )
        try:
            empleado.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar a "{empleado}" porque tiene reservas asignadas.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['get', 'put'], url_path='puestos')
    def puestos(self, request, pk=None):
        """Asignar Puestos: qué puestos tiene un empleado (tabla Puestos_x_Empleados)."""
        empleado = self.get_object()

        if request.method == 'GET':
            asignados = set(
                Puestos_x_Empleados.objects.filter(id_empleado=empleado).values_list('id_puesto_id', flat=True)
            )
            puestos_qs = Puestos.objects.select_related('id_sueldo').all().order_by('nombre_puesto')
            for puesto in puestos_qs:
                puesto.asignado = puesto.pk in asignados
            serializer = PuestoConEstadoSerializer(puestos_qs, many=True)
            return Response(serializer.data)

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


class SueldosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Sueldos'
    queryset = Sueldos.objects.all().order_by('monto_sueldo')
    serializer_class = SueldosSerializer
    permission_classes = [permiso_modulo('sueldos')]

    def destroy(self, request, *args, **kwargs):
        sueldo = self.get_object()
        try:
            sueldo.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar el sueldo "${sueldo.monto_sueldo}" porque hay puestos que lo usan.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PuestosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Puestos'
    # Puestos_x_Empleados usa CASCADE sobre id_puesto: si se borra un puesto,
    # sus asignaciones a empleados se limpian solas (no hay ProtectedError
    # que atajar acá, a diferencia de Sueldos que sí usa PROTECT).
    queryset = Puestos.objects.select_related('id_sueldo').all().order_by('nombre_puesto')
    serializer_class = PuestosSerializer
    permission_classes = [permiso_modulo('puestos')]


class ServiciosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Servicios'
    queryset = Servicios.objects.all().order_by('tipo_servicio')
    serializer_class = ServiciosSerializer
    permission_classes = [permiso_modulo('servicios')]

    # No deja borrar un servicio que está cargado en alguna reserva: si se borrara,
    # la reserva lo perdería pero su monto total seguiría sumando ese precio.
    def destroy(self, request, *args, **kwargs):
        servicio = self.get_object()
        if Reservas_x_Servicios.objects.filter(id_servicio=servicio).exists():
            return Response(
                {'detail': f'No se puede eliminar "{servicio.tipo_servicio}" porque está cargado en reservas.'},
                status=status.HTTP_409_CONFLICT,
            )
        servicio.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReservasViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Reservas'
    queryset = Reservas.objects.select_related('id_cliente').all().order_by('-fecha_evento', '-hora_evento')
    serializer_class = ReservasSerializer
    permission_classes = [permiso_modulo('reservas')]

    def destroy(self, request, *args, **kwargs):
        reserva = self.get_object()
        try:
            reserva.delete()
        except ProtectedError:
            return Response(
                {'detail': 'No se puede eliminar esta reserva porque tiene pagos registrados.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PagosViewSet(RegistrarActividadMixin, viewsets.ModelViewSet):
    # Nombre con el que aparece en el registro de actividad (ver registro.py)
    modulo_registro = 'Pagos'
    queryset = Pagos.objects.select_related('id_reserva', 'id_reserva__id_cliente').all().order_by('-id_pago')
    serializer_class = PagosSerializer
    permission_classes = [permiso_modulo('pagos')]

    # Al borrar un pago, los saldos de los otros pagos de la misma reserva
    # quedan viejos, así que se vuelven a calcular
    def destroy(self, request, *args, **kwargs):
        pago = self.get_object()
        reserva = pago.id_reserva
        pago.delete()
        recalcular_saldos(reserva)
        return Response(status=status.HTTP_204_NO_CONTENT)


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

        hoy = timezone.localdate()
        reservas_hoy_qs = Reservas.objects.filter(fecha_evento=hoy).exclude(estado_reserva='CANCELADA')

        proximas_qs = (
            Reservas.objects.select_related('id_cliente')
            .filter(fecha_evento__gte=hoy)
            .exclude(estado_reserva='CANCELADA')
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
            'usuarios_total': Usuarios.objects.count(),
            'perfiles_total': Perfiles.objects.count(),
            'reservas_hoy': reservas_hoy_qs.count(),
            'reservas_hoy_confirmadas': reservas_hoy_qs.filter(estado_reserva='CONFIRMADA').count(),
            'reservas_hoy_pendientes': reservas_hoy_qs.filter(estado_reserva='PENDIENTE').count(),
            'proximas_reservas': proximas,
        })
 