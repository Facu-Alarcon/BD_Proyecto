import unicodedata

from django.contrib.auth.hashers import check_password, make_password
from django.utils import timezone
from django.utils.text import slugify
from rest_framework import serializers

from .models import (
    Tipo_Equipos, Estado_Equipos, Equipos,
    Perfiles, Usuarios,
    Permisos, Permisos_x_Perfiles,
    Clientes, Empleados, Servicios,
    Reservas, Reservas_x_Servicios, Detalles_Reservas,
    Sueldos, Puestos,
    Horarios, Metodo_Pagos, Pagos, Detalles_de_Pago,
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


def _normalizar_para_usuario(texto):
    """Quita acentos/ñ y cualquier caracter que no sea letra o número, en minúscula."""
    sin_acentos = unicodedata.normalize('NFKD', texto or '').encode('ascii', 'ignore').decode('ascii')
    return ''.join(ch for ch in sin_acentos if ch.isalnum()).lower()


def generar_nombre_usuario(nombre, apellido):
    """
    Nombre de usuario = apellido + inicial del nombre (ej: "Pérez" + "Juan"
    -> "perezj"), todo en minúscula y sin acentos/espacios. Si ya existe,
    se le agrega un número al final hasta encontrar uno libre.
    """
    base = _normalizar_para_usuario(apellido) + _normalizar_para_usuario(nombre)[:1]
    base = base or 'usuario'
    candidato = base
    i = 2
    while Usuarios.objects.filter(usuario=candidato).exists():
        candidato = f'{base}{i}'
        i += 1
    return candidato


class UsuariosSerializer(serializers.ModelSerializer):
    """
    Alta: se cargan dni/nombre/apellido/correo/id_perfil/contraseña y el
    'usuario' se genera solo (generar_nombre_usuario). Modificación: por
    consigna, un usuario ya creado solo puede editar su Correo (el resto
    de los datos de identidad quedan fijos); la contraseña se cambia
    aparte con "Restablecer clave" (ver UsuarioRestablecerClaveSerializer
    y la acción 'restablecer_clave' en UsuariosViewSet). 'activo' y
    'fecha_baja' tampoco se tocan acá: los maneja el destroy() del
    ViewSet (baja lógica) para no borrar la fila.
    """
    perfil_nombre = serializers.CharField(source='id_perfil.tipo_perfil', read_only=True)
    usuario = serializers.CharField(read_only=True)
    contraseña = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Usuarios
        fields = [
            'id_usuario', 'id_perfil', 'perfil_nombre', 'dni', 'nombre', 'apellido',
            'correo', 'usuario', 'contraseña', 'activo', 'debe_cambiar_clave',
            'fecha_ultima_modificacion', 'fecha_baja',
        ]
        read_only_fields = ['activo', 'debe_cambiar_clave', 'fecha_ultima_modificacion', 'fecha_baja']

    def validate_contraseña(self, value):
        if not value and self.instance is None:
            raise serializers.ValidationError('La contraseña es obligatoria.')
        return value

    def create(self, validated_data):
        validated_data['usuario'] = generar_nombre_usuario(
            validated_data.get('nombre', ''), validated_data.get('apellido', '')
        )
        validated_data['contraseña'] = make_password(validated_data['contraseña'])
        return super().create(validated_data)

    def update(self, instance, validated_data):
        instance.correo = validated_data.get('correo', instance.correo)
        instance.save()  # fecha_ultima_modificacion se actualiza sola (auto_now)
        return instance


class UsuarioRestablecerClaveSerializer(serializers.Serializer):
    """Restablecer clave (admin): define una contraseña nueva y obliga a cambiarla en el próximo login."""
    contraseña = serializers.CharField(write_only=True, min_length=4)

    def save(self, **kwargs):
        usuario = self.context['usuario']
        usuario.contraseña = make_password(self.validated_data['contraseña'])
        usuario.debe_cambiar_clave = True
        usuario.save()
        return usuario


class CambiarClaveSerializer(serializers.Serializer):
    """Cambio de clave por el propio usuario (por ejemplo, tras un restablecimiento forzado)."""
    contraseña_actual = serializers.CharField(write_only=True)
    contraseña_nueva = serializers.CharField(write_only=True, min_length=4)

    def validate(self, attrs):
        usuario = self.context['usuario']
        if not check_password(attrs['contraseña_actual'], usuario.contraseña):
            raise serializers.ValidationError({'contraseña_actual': 'La contraseña actual no es correcta.'})
        return attrs

    def save(self, **kwargs):
        usuario = self.context['usuario']
        usuario.contraseña = make_password(self.validated_data['contraseña_nueva'])
        usuario.debe_cambiar_clave = False
        usuario.save()
        return usuario


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

    def validate_fecha_evento(self, valor):
        if valor < timezone.localdate():
            raise serializers.ValidationError('No se puede registrar una reserva en una fecha anterior a hoy.')
        return valor

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


class HorariosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Horarios
        fields = ['id_horario', 'cantidad_horas']


class MetodoPagosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Metodo_Pagos
        fields = ['id_metodo_pago', 'metodo_pago']


class PagosSerializer(serializers.ModelSerializer):
    """
    Detalles_de_Pago es una tabla intermedia propia (no ManyToManyField),
    así que 'metodos_pago' se recibe como lista de ids y se sincroniza a
    mano, igual que 'servicios'/'empleados' en ReservasSerializer.
    El saldo_pendiente se calcula solo: monto_total de la reserva menos
    todos los pagos ya registrados para esa reserva (este incluido), así
    que nunca se manda a mano desde el frontend.
    """
    cliente_nombre = serializers.CharField(source='id_reserva.id_cliente.__str__', read_only=True)
    evento_nombre = serializers.CharField(source='id_reserva.nombre_evento', read_only=True)
    metodos_pago = serializers.PrimaryKeyRelatedField(
        queryset=Metodo_Pagos.objects.all(), many=True, write_only=True, required=False
    )
    metodos_pago_detalle = serializers.SerializerMethodField()

    class Meta:
        model = Pagos
        fields = [
            'id_pago', 'id_reserva', 'cliente_nombre', 'evento_nombre',
            'monto', 'saldo_pendiente', 'metodos_pago', 'metodos_pago_detalle',
        ]
        read_only_fields = ['saldo_pendiente']

    def get_metodos_pago_detalle(self, obj):
        rels = Detalles_de_Pago.objects.filter(id_pago=obj).select_related('id_metodo_pago')
        return [
            {'id_metodo_pago': r.id_metodo_pago_id, 'metodo_pago': r.id_metodo_pago.metodo_pago}
            for r in rels
        ]

    def _saldo_antes_de_este_pago(self, reserva, excluir_pago=None):
        pagos_previos = Pagos.objects.filter(id_reserva=reserva)
        if excluir_pago is not None:
            pagos_previos = pagos_previos.exclude(pk=excluir_pago.pk)
        total_pagado = sum(p.monto for p in pagos_previos)
        return reserva.monto_total - total_pagado

    def create(self, validated_data):
        metodos = validated_data.pop('metodos_pago', [])
        reserva = validated_data['id_reserva']
        saldo_previo = self._saldo_antes_de_este_pago(reserva)
        validated_data['saldo_pendiente'] = max(saldo_previo - validated_data['monto'], 0)

        pago = Pagos.objects.create(**validated_data)
        for metodo in metodos:
            Detalles_de_Pago.objects.create(id_pago=pago, id_metodo_pago=metodo)
        return pago

    def update(self, instance, validated_data):
        metodos = validated_data.pop('metodos_pago', None)
        reserva = validated_data.get('id_reserva', instance.id_reserva)
        monto = validated_data.get('monto', instance.monto)
        saldo_previo = self._saldo_antes_de_este_pago(reserva, excluir_pago=instance)
        validated_data['saldo_pendiente'] = max(saldo_previo - monto, 0)

        instance = super().update(instance, validated_data)

        if metodos is not None:
            Detalles_de_Pago.objects.filter(id_pago=instance).delete()
            for metodo in metodos:
                Detalles_de_Pago.objects.create(id_pago=instance, id_metodo_pago=metodo)
        return instance