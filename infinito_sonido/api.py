import secrets

from django.contrib.auth.hashers import check_password
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
    Clientes, Empleados, Servicios, Reservas,
)
from .serializers import (
    TipoEquiposSerializer, EstadoEquiposSerializer, EquiposSerializer,
    PerfilesSerializer, UsuariosSerializer,
    PermisosSerializer, PermisoConEstadoSerializer,
    ClientesSerializer, EmpleadosSerializer, ServiciosSerializer,
    ReservasSerializer,
)
from .permissions import permiso_modulo, permisos_del_usuario


def _usuario_repr(usuario):
    return {
        'id_usuario': usuario.pk,
        'usuario': usuario.usuario,
        'id_perfil': usuario.id_perfil_id,
        'perfil_nombre': usuario.id_perfil.tipo_perfil,
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
            usuario = Usuarios.objects.select_related('id_perfil').get(usuario=usuario_nombre)
        except Usuarios.DoesNotExist:
            return Response(error, status=status.HTTP_401_UNAUTHORIZED)

        if not check_password(contraseña, usuario.contraseña):
            return Response(error, status=status.HTTP_401_UNAUTHORIZED)

        sesion = SesionToken.objects.create(token=secrets.token_hex(32), id_usuario=usuario)
        return Response({'token': sesion.token, 'usuario': _usuario_repr(usuario)})


class LogoutView(APIView):
    def post(self, request):
        # request.auth es la instancia de SesionToken usada para autenticar (ver authentication.py)
        if request.auth is not None:
            request.auth.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    def get(self, request):
        return Response(_usuario_repr(request.user))


class TipoEquiposViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Tipo_Equipos.objects.all().order_by('nombre_tipoeq')
    serializer_class = TipoEquiposSerializer
    permission_classes = [permiso_modulo('equipos')]


class EstadoEquiposViewSet(viewsets.ModelViewSet):
    """
    Catálogo editable de estados de equipo (antes era una lista fija
    DISPONIBLE/EN_USO/EN_REPARACION hardcodeada). Se puede crear un
    estado nuevo desde acá, incluido el botón "+" del formulario de Equipos.
    """
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


class EquiposViewSet(viewsets.ModelViewSet):
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


class PerfilesViewSet(viewsets.ModelViewSet):
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


class PermisosViewSet(viewsets.ModelViewSet):
    queryset = Permisos.objects.all().order_by('nombre_permiso')
    serializer_class = PermisosSerializer
    permission_classes = [permiso_modulo('permisos')]


class UsuariosViewSet(viewsets.ModelViewSet):
    queryset = Usuarios.objects.select_related('id_perfil').all().order_by('usuario')
    serializer_class = UsuariosSerializer
    permission_classes = [permiso_modulo('usuarios')]


class ClientesViewSet(viewsets.ModelViewSet):
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


class EmpleadosViewSet(viewsets.ModelViewSet):
    queryset = Empleados.objects.all().order_by('apellido_emp', 'nombre_emp')
    serializer_class = EmpleadosSerializer
    permission_classes = [permiso_modulo('empleados')]

    def destroy(self, request, *args, **kwargs):
        empleado = self.get_object()
        try:
            empleado.delete()
        except ProtectedError:
            return Response(
                {'detail': f'No se puede eliminar a "{empleado}" porque tiene reservas asignadas.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class ServiciosViewSet(viewsets.ModelViewSet):
    queryset = Servicios.objects.all().order_by('tipo_servicio')
    serializer_class = ServiciosSerializer
    permission_classes = [permiso_modulo('servicios')]


class ReservasViewSet(viewsets.ModelViewSet):
    queryset = Reservas.objects.select_related('id_cliente').all().order_by('-fecha_evento', '-duracion_evento')
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
            .order_by('fecha_evento', 'duracion_evento')[:5]
        )
        proximas = [
            {
                'id_reserva': r.id_reserva,
                'cliente_nombre': str(r.id_cliente),
                'nombre_evento': r.nombre_evento,
                'fecha_evento': r.fecha_evento,
                'hora_evento': r.duracion_evento,
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
