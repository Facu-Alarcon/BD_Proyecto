from django.contrib.auth.hashers import make_password
from django.utils.text import slugify
from rest_framework import serializers

from .models import (
    Tipo_Equipos, Estado_Equipos, Equipos,
    Perfiles, Usuarios,
    Permisos, Permisos_x_Perfiles,
    Clientes, Empleados, Servicios,
    Reservas, Reservas_x_Servicios, Detalles_Reservas,
    Sueldos, Puestos,
)


class TipoEquiposSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tipo_Equipos
        fields = ['id_tipoeq', 'nombre_tipoeq']


class EstadoEquiposSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estado_Equipos
        fields = ['id_estadoeq', 'nombre_estadoeq']


class EquiposSerializer(serializers.ModelSerializer):
    tipo_nombre = serializers.CharField(source='id_tipoeq.nombre_tipoeq', read_only=True)
    estado_nombre = serializers.CharField(source='id_estadoeq.nombre_estadoeq', read_only=True)

    class Meta:
        model = Equipos
        fields = [
            'id_equipo', 'nombre_equipo', 'id_tipoeq', 'tipo_nombre',
            'id_estadoeq', 'estado_nombre', 'cantidad_equipo',
        ]


class PerfilesSerializer(serializers.ModelSerializer):
    class Meta:
        model = Perfiles
        fields = ['id_perfil', 'tipo_perfil']


class PermisosSerializer(serializers.ModelSerializer):
    """
    El 'codigo' es la clave que usa el backend para habilitar accesos
    (ver permissions.py) y no se expone como editable: se genera solo a
    partir del nombre la primera vez y después queda fijo, aunque se
    renombre el permiso, para no romper los permisos ya otorgados.
    """
    codigo = serializers.CharField(read_only=True)

    class Meta:
        model = Permisos
        fields = ['id_permiso', 'nombre_permiso', 'descripcion_permiso', 'estado_permiso', 'codigo']

    def create(self, validated_data):
        base = slugify(validated_data['nombre_permiso']).replace('-', '_')[:55] or 'permiso'
        codigo = base
        i = 2
        while Permisos.objects.filter(codigo=codigo).exists():
            codigo = f'{base}_{i}'
            i += 1
        validated_data['codigo'] = codigo
        return super().create(validated_data)


class PermisoConEstadoSerializer(serializers.ModelSerializer):
    """Usado en la pantalla de Asignar Permisos: cada permiso + si está asignado al perfil."""
    asignado = serializers.BooleanField(read_only=True)

    class Meta:
        model = Permisos
        fields = ['id_permiso', 'nombre_permiso', 'descripcion_permiso', 'estado_permiso', 'codigo', 'asignado']


class UsuariosSerializer(serializers.ModelSerializer):
    perfil_nombre = serializers.CharField(source='id_perfil.tipo_perfil', read_only=True)
    contraseña = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Usuarios
        fields = ['id_usuario', 'usuario', 'id_perfil', 'perfil_nombre', 'contraseña']

    def validate_contraseña(self, value):
        if not value and self.instance is None:
            raise serializers.ValidationError('La contraseña es obligatoria.')
        return value

    def create(self, validated_data):
        validated_data['contraseña'] = make_password(validated_data['contraseña'])
        return super().create(validated_data)

    def update(self, instance, validated_data):
        password = validated_data.pop('contraseña', None)
        if password:
            instance.contraseña = make_password(password)
        return super().update(instance, validated_data)


class ClientesSerializer(serializers.ModelSerializer):
    class Meta:
        model = Clientes
        fields = [
            'id_cliente', 'nombre_cliente', 'apellido_cliente',
            'domicilio_cliente', 'telefono_cliente', 'email_cliente',
        ]


class EmpleadosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Empleados
        fields = ['id_empleado', 'nombre_emp', 'apellido_emp', 'telefono_emp', 'email_emp']


class ServiciosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Servicios
        fields = ['id_servicio', 'tipo_servicio', 'precio_servicio']


class ReservasSerializer(serializers.ModelSerializer):
    """
    Reservas_x_Servicios y Detalles_Reservas son tablas intermedias propias
    (no ManyToManyField de Django), así que 'servicios' y 'empleados' se
    reciben como listas de ids y se sincronizan a mano en create()/update().
    De paso: el monto_total se calcula solo sumando el precio de los
    servicios elegidos, y se valida que ningún empleado quede con dos
    eventos el mismo día (regla pedida en el relevamiento original).
    """
    cliente_nombre = serializers.CharField(source='id_cliente.__str__', read_only=True)
    estado_display = serializers.CharField(source='get_estado_reserva_display', read_only=True)
    hora_evento = serializers.TimeField(source='duracion_evento')
    servicios = serializers.PrimaryKeyRelatedField(
        queryset=Servicios.objects.all(), many=True, write_only=True, required=False
    )
    empleados = serializers.PrimaryKeyRelatedField(
        queryset=Empleados.objects.all(), many=True, write_only=True, required=False
    )
    servicios_detalle = serializers.SerializerMethodField()
    empleados_detalle = serializers.SerializerMethodField()

    class Meta:
        model = Reservas
        fields = [
            'id_reserva', 'id_cliente', 'cliente_nombre', 'nombre_evento',
            'fecha_evento', 'hora_evento', 'direccion_evento',
            'monto_total', 'estado_reserva', 'estado_display',
            'servicios', 'empleados', 'servicios_detalle', 'empleados_detalle',
        ]
        read_only_fields = ['monto_total']

    def get_servicios_detalle(self, obj):
        rels = Reservas_x_Servicios.objects.filter(id_reserva=obj).select_related('id_servicio')
        return [
            {
                'id_servicio': r.id_servicio_id,
                'tipo_servicio': r.id_servicio.tipo_servicio,
                'precio_servicio': r.id_servicio.precio_servicio,
            }
            for r in rels
        ]

    def get_empleados_detalle(self, obj):
        rels = Detalles_Reservas.objects.filter(id_reserva=obj).select_related('id_empleado')
        return [
            {
                'id_empleado': r.id_empleado_id,
                'nombre_emp': r.id_empleado.nombre_emp,
                'apellido_emp': r.id_empleado.apellido_emp,
            }
            for r in rels
        ]

    def _validar_empleados(self, empleados, fecha_evento, excluir_reserva=None):
        if not empleados:
            return
        conflictos = Detalles_Reservas.objects.filter(
            id_empleado__in=empleados,
            id_reserva__fecha_evento=fecha_evento,
        ).exclude(id_reserva__estado_reserva='CANCELADA').select_related('id_empleado')
        if excluir_reserva is not None:
            conflictos = conflictos.exclude(id_reserva=excluir_reserva)
        if conflictos.exists():
            nombres = sorted({str(c.id_empleado) for c in conflictos})
            raise serializers.ValidationError({
                'empleados': f'Ya tienen otra reserva ese día: {", ".join(nombres)}.'
            })

    def create(self, validated_data):
        servicios = validated_data.pop('servicios', [])
        empleados = validated_data.pop('empleados', [])
        self._validar_empleados(empleados, validated_data['fecha_evento'])
        validated_data['monto_total'] = sum(s.precio_servicio for s in servicios)

        reserva = Reservas.objects.create(**validated_data)
        for servicio in servicios:
            Reservas_x_Servicios.objects.create(id_reserva=reserva, id_servicio=servicio)
        for empleado in empleados:
            Detalles_Reservas.objects.create(id_reserva=reserva, id_empleado=empleado)
        return reserva

    def update(self, instance, validated_data):
        servicios = validated_data.pop('servicios', None)
        empleados = validated_data.pop('empleados', None)
        fecha_evento = validated_data.get('fecha_evento', instance.fecha_evento)

        if empleados is not None:
            self._validar_empleados(empleados, fecha_evento, excluir_reserva=instance)
        if servicios is not None:
            validated_data['monto_total'] = sum(s.precio_servicio for s in servicios)

        instance = super().update(instance, validated_data)

        if servicios is not None:
            Reservas_x_Servicios.objects.filter(id_reserva=instance).delete()
            for servicio in servicios:
                Reservas_x_Servicios.objects.create(id_reserva=instance, id_servicio=servicio)
        if empleados is not None:
            Detalles_Reservas.objects.filter(id_reserva=instance).delete()
            for empleado in empleados:
                Detalles_Reservas.objects.create(id_reserva=instance, id_empleado=empleado)
        return instance


class SueldosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sueldos
        fields = ['id_sueldo', 'monto_sueldo']


class PuestosSerializer(serializers.ModelSerializer):
    sueldo_monto = serializers.FloatField(source='id_sueldo.monto_sueldo', read_only=True)

    class Meta:
        model = Puestos
        fields = ['id_puesto', 'nombre_puesto', 'id_sueldo', 'sueldo_monto']


class PuestoConEstadoSerializer(serializers.ModelSerializer):
    """Usado en la pantalla de Asignar Puestos: cada puesto + si está asignado al empleado."""
    asignado = serializers.BooleanField(read_only=True)
    sueldo_monto = serializers.FloatField(source='id_sueldo.monto_sueldo', read_only=True)

    class Meta:
        model = Puestos
        fields = ['id_puesto', 'nombre_puesto', 'sueldo_monto', 'asignado']
