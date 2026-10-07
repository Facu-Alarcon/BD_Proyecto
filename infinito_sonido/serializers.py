# Serializers: convierten los modelos a JSON para mandarlos al frontend, y validan lo que
# llega desde el frontend antes de guardarlo. Cada ViewSet de api.py usa uno de estos.
#
# Cómo leer un serializer:
#   - Meta.fields: los campos que viajan en el JSON (en los dos sentidos).
#   - read_only=True / read_only_fields: se mandan al frontend pero no se pueden cambiar desde él.
#   - write_only=True: se reciben pero no se devuelven (ej: contraseñas, listas de ids).
#   - source='id_cliente.nombre': toma el valor de otro lado (ej: un dato de la tabla relacionada).
#   - SerializerMethodField: el valor lo calcula el método get_<campo>.
#   - validate_<campo>: valida un campo; validate(): valida varios juntos.
#   - create / update: qué se hace al guardar (cuando hay que hacer más que guardar la fila).

from django.contrib.auth.hashers import check_password, make_password
from django.db import transaction
from django.utils import timezone
from django.utils.text import slugify
from rest_framework import serializers

from .disponibilidad import equipos_faltantes
from .nombres_usuario import generar_nombre_usuario
from .seguridad import generar_contraseña_temporal, validar_contraseña_segura

from .models import (
    Tipo_Equipos, Estado_Equipos, Equipos,
    Perfiles, Usuarios,
    Permisos, Permisos_x_Perfiles,
    Clientes, Empleados, Servicios, Equipos_x_Servicios,
    Reservas, Reservas_x_Servicios, Detalles_Reservas,
    Sueldos, Puestos,
    Horarios, Metodo_Pagos, Pagos, Detalles_de_Pago,
    Registro_Actividad,
)


# ---------------- Equipos ----------------
#
# Tipos y estados de equipo: solo el id y el nombre
class TipoEquiposSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tipo_Equipos
        fields = ['id_tipoeq', 'nombre_tipoeq']


class EstadoEquiposSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estado_Equipos
        fields = ['id_estadoeq', 'nombre_estadoeq']


# Equipos. Además de los ids de tipo y estado, manda sus nombres para mostrarlos en la tabla
# sin que el frontend tenga que buscarlos aparte.
class EquiposSerializer(serializers.ModelSerializer):
    tipo_nombre = serializers.CharField(source='id_tipoeq.nombre_tipoeq', read_only=True)
    estado_nombre = serializers.CharField(source='id_estadoeq.nombre_estadoeq', read_only=True)

    class Meta:
        model = Equipos
        fields = [
            'id_equipo', 'nombre_equipo', 'id_tipoeq', 'tipo_nombre',
            'id_estadoeq', 'estado_nombre', 'cantidad_equipo',
        ]


# ---------------- Seguridad ----------------
#
# Perfiles: solo el id y el nombre (los permisos de cada perfil se manejan aparte, ver PerfilesViewSet.permisos)
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
        # Arma el código a partir del nombre: "Ver Reportes" -> "ver_reportes".
        # Si ya existe, le agrega un número (ver_reportes_2, ver_reportes_3...).
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
    """
    Los usuarios se crean a partir de un empleado ya registrado (uno a uno).
    Alta: solo se elige el empleado y el perfil. El nombre de usuario se arma solo con el
    primer apellido + la inicial del nombre (ver nombres_usuario.py)
    del empleado y la contraseña es temporal: la arma el sistema al azar, se le
    manda por mail al empleado (ver correos.py) y en el primer ingreso tiene que
    cambiarla (debe_cambiar_clave=True).
    Modificación: solo se puede cambiar el perfil. Los datos de la persona se
    editan desde Empleados. 'activo' y 'fecha_baja' los maneja el destroy() del
    ViewSet (baja lógica).
    """
    perfil_nombre = serializers.CharField(source='id_perfil.tipo_perfil', read_only=True)
    usuario = serializers.CharField(read_only=True)
    # Datos del empleado, solo para mostrar (la lista y los filtros los siguen usando con estos nombres)
    dni = serializers.CharField(source='id_empleado.dni', read_only=True)
    nombre = serializers.CharField(source='id_empleado.nombre_emp', read_only=True)
    apellido = serializers.CharField(source='id_empleado.apellido_emp', read_only=True)
    correo = serializers.CharField(source='id_empleado.email_emp', read_only=True)

    class Meta:
        model = Usuarios
        fields = [
            'id_usuario', 'id_empleado', 'dni', 'nombre', 'apellido', 'correo',
            'id_perfil', 'perfil_nombre', 'usuario', 'activo', 'debe_cambiar_clave',
            'fecha_ultima_modificacion', 'fecha_baja',
        ]
        read_only_fields = ['activo', 'debe_cambiar_clave', 'fecha_ultima_modificacion', 'fecha_baja']
        # Sin el validador automático de "uno a uno": el mensaje lo damos nosotros en validate_id_empleado
        extra_kwargs = {'id_empleado': {'validators': []}}

    # El empleado elegido no puede tener ya un usuario, y necesita correo (ahí le llega
    # la contraseña temporal)
    def validate_id_empleado(self, empleado):
        if not empleado.activo:
            raise serializers.ValidationError(f'{empleado} está dado de baja.')
        if self.instance is not None:
            if empleado != self.instance.id_empleado:
                raise serializers.ValidationError('No se puede cambiar el empleado de un usuario ya creado.')
            return empleado
        if Usuarios.objects.filter(id_empleado=empleado).exists():
            raise serializers.ValidationError(f'{empleado} ya tiene un usuario creado.')
        if not empleado.email_emp:
            raise serializers.ValidationError(f'{empleado} no tiene correo cargado. Cargalo desde Empleados.')
        return empleado

    # Crea el usuario con apellido + inicial como nombre de usuario (con un número si ya
    # está tomado: perezj2) y una contraseña temporal.
    # La contraseña en texto plano se guarda en self.contraseña_temporal solo para que
    # la vista pueda mandarla por mail; en la base queda hasheada.
    def create(self, validated_data):
        empleado = validated_data['id_empleado']
        self.contraseña_temporal = generar_contraseña_temporal()
        validated_data['usuario'] = generar_nombre_usuario(
            empleado.nombre_emp, empleado.apellido_emp,
            lambda candidato: Usuarios.objects.filter(usuario=candidato).exists(),
        )
        validated_data['contraseña'] = make_password(self.contraseña_temporal)
        validated_data['debe_cambiar_clave'] = True
        return super().create(validated_data)

    # Al editar solo cambia el perfil
    def update(self, instance, validated_data):
        instance.id_perfil = validated_data.get('id_perfil', instance.id_perfil)
        instance.save()  # fecha_ultima_modificacion se actualiza sola (auto_now)
        return instance


class CambiarClaveSerializer(serializers.Serializer):
    """Cambio de clave por el propio usuario (por ejemplo, tras un restablecimiento forzado)."""
    contraseña_actual = serializers.CharField(write_only=True)
    # La clave nueva tiene que cumplir las reglas de seguridad (ver seguridad.py)
    contraseña_nueva = serializers.CharField(write_only=True, validators=[validar_contraseña_segura])

    # La clave actual tiene que ser la correcta (así nadie cambia la clave de una sesión ajena abierta)
    def validate(self, attrs):
        usuario = self.context['usuario']
        if not check_password(attrs['contraseña_actual'], usuario.contraseña):
            raise serializers.ValidationError({'contraseña_actual': 'La contraseña actual no es correcta.'})
        # No tiene sentido "cambiarla" por la misma (sobre todo si era la temporal)
        if attrs['contraseña_actual'] == attrs['contraseña_nueva']:
            raise serializers.ValidationError({'contraseña_nueva': 'La contraseña nueva tiene que ser distinta de la actual.'})
        return attrs

    def save(self, **kwargs):
        usuario = self.context['usuario']
        # Se guarda hasheada y se apaga el aviso de "tenés que cambiar la clave"
        usuario.contraseña = make_password(self.validated_data['contraseña_nueva'])
        usuario.debe_cambiar_clave = False
        usuario.save()
        return usuario


# ---------------- Clientes y empleados ----------------
#
# Clientes: todos sus campos, sin nada especial (las validaciones están en el modelo)
class ClientesSerializer(serializers.ModelSerializer):
    class Meta:
        model = Clientes
        fields = [
            'id_cliente', 'nombre_cliente', 'apellido_cliente',
            'domicilio_cliente', 'telefono_cliente', 'email_cliente',
        ]


# Empleados, con un dato extra (tiene_usuario) que no está en la tabla
class EmpleadosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Empleados
        fields = ['id_empleado', 'dni', 'nombre_emp', 'apellido_emp', 'telefono_emp', 'email_emp', 'tiene_usuario']
        # En la base el DNI puede estar vacío (empleados viejos), pero desde el formulario se pide siempre
        extra_kwargs = {'dni': {'required': True, 'allow_null': False, 'allow_blank': False}}

    # Para la pantalla de Usuarios: así se sabe qué empleados todavía no tienen cuenta
    tiene_usuario = serializers.SerializerMethodField()

    def get_tiene_usuario(self, obj):
        # Si el empleado tiene usuario, Django le agrega el atributo 'usuario' (es el related_name de la relación uno a uno)
        return hasattr(obj, 'usuario')


class ServiciosSerializer(serializers.ModelSerializer):
    """
    Además de nombre y precio, cada servicio dice qué equipos usa y cuántos de cada uno
    (tabla Equipos_x_Servicios). Se recibe como lista en 'equipos':
        [{"id_equipo": 3, "cantidad": 4}, {"id_equipo": 7, "cantidad": 2}]
    y se devuelve con los nombres en 'equipos_detalle'. Con esto la reserva controla
    que no se pidan más equipos de los que hay en un mismo día.
    """
    equipos = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)
    equipos_detalle = serializers.SerializerMethodField()

    class Meta:
        model = Servicios
        fields = ['id_servicio', 'tipo_servicio', 'precio_servicio', 'equipos', 'equipos_detalle']

    def get_equipos_detalle(self, obj):
        rels = Equipos_x_Servicios.objects.filter(id_servicio=obj).select_related('id_equipo')
        return [
            {'id_equipo': r.id_equipo_id, 'nombre_equipo': r.id_equipo.nombre_equipo, 'cantidad': r.cantidad}
            for r in rels
        ]

    # Revisa la lista de equipos: que existan, que no se repitan y que la cantidad tenga
    # sentido (al menos 1 y no más de las unidades que tiene el equipo)
    def validate_equipos(self, lista):
        limpia, vistos = [], set()
        for item in lista:
            try:
                id_equipo, cantidad = int(item.get('id_equipo')), int(item.get('cantidad'))
            except (TypeError, ValueError):
                raise serializers.ValidationError('Cada equipo necesita id_equipo y cantidad numéricos.')
            if id_equipo in vistos:
                raise serializers.ValidationError('Hay un equipo repetido en la lista.')
            vistos.add(id_equipo)
            # Solo equipos activos: uno dado de baja ya no se puede agregar a un servicio
            equipo = Equipos.objects.activos().filter(pk=id_equipo).first()
            if equipo is None:
                raise serializers.ValidationError(f'No existe el equipo {id_equipo}.')
            if cantidad < 1:
                raise serializers.ValidationError(f'La cantidad de "{equipo.nombre_equipo}" tiene que ser al menos 1.')
            if cantidad > equipo.cantidad_equipo:
                raise serializers.ValidationError(
                    f'"{equipo.nombre_equipo}" tiene {equipo.cantidad_equipo} unidades: el servicio no puede usar {cantidad}.'
                )
            limpia.append((equipo, cantidad))
        return limpia

    # Reemplaza los equipos del servicio por los de la lista nueva
    def _guardar_equipos(self, servicio, equipos):
        Equipos_x_Servicios.objects.filter(id_servicio=servicio).delete()
        for equipo, cantidad in equipos:
            Equipos_x_Servicios.objects.create(id_servicio=servicio, id_equipo=equipo, cantidad=cantidad)

    @transaction.atomic
    def create(self, validated_data):
        equipos = validated_data.pop('equipos', [])
        servicio = super().create(validated_data)
        self._guardar_equipos(servicio, equipos)
        return servicio

    @transaction.atomic
    def update(self, instance, validated_data):
        equipos = validated_data.pop('equipos', None)
        servicio = super().update(instance, validated_data)
        # Si no se mandó la lista (ej: alguien edita solo el precio por la API) los equipos quedan como estaban
        if equipos is not None:
            self._guardar_equipos(servicio, equipos)
        return servicio


# Vuelve a calcular el saldo pendiente de todos los pagos de una reserva.
# Los recorre en el orden en que se cargaron: cada pago muestra lo que faltaba
# pagar después de él (total de la reserva menos lo pagado hasta ese pago).
# Se llama cada vez que algo puede dejar los saldos viejos: crear, editar o
# borrar un pago, o cambiar los servicios (y con eso el total) de la reserva.
# ---------------- Reservas y pagos ----------------
#
def recalcular_saldos(reserva):
    pagado = 0
    # Solo los pagos activos: uno dado de baja ya no cuenta para el saldo
    for pago in Pagos.objects.activos().filter(id_reserva=reserva).order_by('id_pago'):
        pagado += pago.monto
        nuevo_saldo = max(reserva.monto_total - pagado, 0)
        if pago.saldo_pendiente != nuevo_saldo:
            pago.saldo_pendiente = nuevo_saldo
            pago.save(update_fields=['saldo_pendiente'])


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
    servicios = serializers.PrimaryKeyRelatedField(
        # Solo se pueden elegir servicios y empleados activos (los dados de baja no aparecen)
        queryset=Servicios.objects.activos(), many=True, write_only=True, required=False
    )
    empleados = serializers.PrimaryKeyRelatedField(
        queryset=Empleados.objects.activos(), many=True, write_only=True, required=False
    )
    servicios_detalle = serializers.SerializerMethodField()
    empleados_detalle = serializers.SerializerMethodField()
    # Quién registró y quién anuló la reserva (usuario y nombre de la persona), solo para mostrar
    usuario_registro = serializers.SerializerMethodField()
    usuario_anulacion = serializers.SerializerMethodField()
    # Para la vista de detalle y el comprobante: datos de contacto del cliente y los pagos
    # de la reserva. Van acá para que quien puede ver reservas vea todo, aunque su perfil
    # no tenga permiso sobre Clientes o Pagos.
    cliente_detalle = serializers.SerializerMethodField()
    pagos_detalle = serializers.SerializerMethodField()

    class Meta:
        model = Reservas
        fields = [
            'id_reserva', 'id_cliente', 'cliente_nombre', 'nombre_evento',
            'fecha_evento', 'hora_evento', 'duracion_evento', 'direccion_evento',
            'monto_total', 'estado_reserva', 'estado_display',
            'servicios', 'empleados', 'servicios_detalle', 'empleados_detalle',
            'fecha_registro', 'usuario_registro',
            'fecha_anulacion', 'motivo_anulacion', 'usuario_anulacion',
            'cliente_detalle', 'pagos_detalle',
        ]
        # Todo lo automático (total, registro y anulación) lo completa el sistema, nunca el formulario
        read_only_fields = ['monto_total', 'fecha_registro', 'fecha_anulacion', 'motivo_anulacion']
        # En la base la duración puede estar vacía (reservas viejas), pero al crear
        # o editar desde el formulario la pedimos siempre.
        extra_kwargs = {'duracion_evento': {'required': True, 'allow_null': False}}

    # Servicios de la reserva (detalle), con el nombre y el precio que tenían al reservar
    def get_servicios_detalle(self, obj):
        rels = Reservas_x_Servicios.objects.filter(id_reserva=obj).select_related('id_servicio')
        return [
            {
                'id_servicio': r.id_servicio_id,
                'tipo_servicio': r.id_servicio.tipo_servicio,
                # El precio guardado al reservar (no el precio actual del servicio)
                'precio_servicio': r.precio_servicio,
            }
            for r in rels
        ]

    # Arma "Nombre Apellido (usuario)" de un usuario, o None si no hay
    def _texto_usuario(self, usuario):
        if usuario is None:
            return None
        return f'{usuario.nombre} {usuario.apellido} ({usuario.usuario})'

    def get_cliente_detalle(self, obj):
        c = obj.id_cliente
        return {
            'nombre': f'{c.nombre_cliente} {c.apellido_cliente}',
            'telefono': c.telefono_cliente,
            'email': c.email_cliente,
            'domicilio': c.domicilio_cliente,
        }

    # Pagos de la reserva, con sus métodos, y el resumen: cuánto se pagó y cuánto falta
    def get_pagos_detalle(self, obj):
        pagos = Pagos.objects.activos().filter(id_reserva=obj).order_by('id_pago').prefetch_related('detalles_de_pago_set__id_metodo_pago')
        lista = [
            {
                'id_pago': p.id_pago,
                'monto': p.monto,
                'saldo_pendiente': p.saldo_pendiente,
                'metodos': [d.id_metodo_pago.metodo_pago for d in p.detalles_de_pago_set.all()],
            }
            for p in pagos
        ]
        total_pagado = sum(p['monto'] for p in lista)
        return {
            'pagos': lista,
            'total_pagado': total_pagado,
            'saldo': max(obj.monto_total - total_pagado, 0),
        }

    def get_usuario_registro(self, obj):
        return self._texto_usuario(obj.id_usuario_registro)

    def get_usuario_anulacion(self, obj):
        return self._texto_usuario(obj.id_usuario_anulacion)

    # Personal asignado a la reserva (detalle)
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

    # No deja cargar reservas con fecha anterior a hoy.
    # Al editar solo se controla si se cambió la fecha: si la reserva ya pasó y se deja
    # la misma fecha (por ejemplo para pasarla a Finalizada), se permite guardar.
    def validate_fecha_evento(self, valor):
        if self.instance is not None and valor == self.instance.fecha_evento:
            return valor
        if valor < timezone.localdate():
            raise serializers.ValidationError('No se puede registrar una reserva en una fecha anterior a hoy.')
        return valor

    # El estado nunca se elige al crear (nace en PENDIENTE, ver create). Al editar se puede
    # pasar entre Pendiente, Confirmada y Finalizada, pero no a Anulada: anular es una
    # acción aparte que pide motivo y deja registrado quién y cuándo (paso 3 del Hito 3)
    def validate_estado_reserva(self, valor):
        if valor == 'ANULADA' and (self.instance is None or self.instance.estado_reserva != 'ANULADA'):
            raise serializers.ValidationError('Para anular una reserva usá la opción "Anular".')
        return valor

    # La duración tiene que ser de al menos un minuto, 00:00 no tiene sentido
    def validate_duracion_evento(self, valor):
        if valor.hour == 0 and valor.minute == 0:
            raise serializers.ValidationError('La duración del evento tiene que ser mayor a 00:00.')
        return valor

    # Un empleado no puede trabajar en dos eventos el mismo día. Se buscan otras reservas de esa
    # fecha (sin contar las anuladas) donde ya esté alguno de los empleados elegidos. Al editar se
    # excluye la propia reserva, si no siempre 'chocaría' consigo misma.
    def _validar_empleados(self, empleados, fecha_evento, excluir_reserva=None):
        if not empleados:
            return
        conflictos = Detalles_Reservas.objects.filter(
            id_empleado__in=empleados,
            id_reserva__fecha_evento=fecha_evento,
        ).exclude(id_reserva__estado_reserva='ANULADA').select_related('id_empleado')
        if excluir_reserva is not None:
            conflictos = conflictos.exclude(id_reserva=excluir_reserva)
        if conflictos.exists():
            nombres = sorted({str(c.id_empleado) for c in conflictos})
            raise serializers.ValidationError({
                'empleados': f'Ya tienen otra reserva ese día: {", ".join(nombres)}.'
            })

    # Disponibilidad de equipos: suma los equipos que piden los servicios de esta reserva y
    # los que ya están comprometidos en las otras reservas de ese mismo día (las anuladas no
    # cuentan, así que anular una reserva libera sus equipos solo). Si para algún equipo
    # se pasa de las unidades que hay, no deja guardar. Los equipos En reparación no se
    # pueden reservar.
    def _validar_equipos(self, servicios, fecha_evento, excluir_reserva=None):
        # La cuenta de unidades libres está en disponibilidad.py (la usan también el
        # formulario, la acción Confirmar y el Inicio, así todos calculan igual)
        faltantes = equipos_faltantes(servicios, fecha_evento, excluir_reserva)
        if faltantes:
            raise serializers.ValidationError({
                'servicios': f'No hay equipos suficientes el {fecha_evento:%d/%m/%Y}: ' + '; '.join(faltantes) + '.'
            })

    # Una reserva anulada queda como está: no se puede modificar (solo consultar)
    def validate(self, attrs):
        if self.instance is not None and self.instance.estado_reserva == 'ANULADA':
            raise serializers.ValidationError({'detail': 'Una reserva anulada no se puede modificar.'})
        return attrs

    # @transaction.atomic: la cabecera y todos los detalles se guardan juntos. Si algo falla
    # a la mitad (por ejemplo, al guardar un servicio), se deshace todo y no queda una
    # reserva incompleta en la base (confirmación o reversión completa, como pide el hito)
    @transaction.atomic
    def create(self, validated_data):
        servicios = validated_data.pop('servicios', [])
        empleados = validated_data.pop('empleados', [])
        self._validar_empleados(empleados, validated_data['fecha_evento'])
        self._validar_equipos(servicios, validated_data['fecha_evento'])
        validated_data['monto_total'] = sum(s.precio_servicio for s in servicios)
        # Estado automático: toda reserva nueva nace Pendiente, se mande lo que se mande
        validated_data['estado_reserva'] = 'PENDIENTE'
        # Usuario logueado que registra la reserva (la fecha de registro la pone sola la base)
        request = self.context.get('request')
        validated_data['id_usuario_registro'] = getattr(request, 'user', None) if request else None

        reserva = Reservas.objects.create(**validated_data)
        # Cada servicio se guarda con el precio que tiene hoy
        for servicio in servicios:
            Reservas_x_Servicios.objects.create(
                id_reserva=reserva, id_servicio=servicio, precio_servicio=servicio.precio_servicio
            )
        for empleado in empleados:
            Detalles_Reservas.objects.create(id_reserva=reserva, id_empleado=empleado)
        return reserva

    # También en una transacción: se reemplazan los detalles y se recalculan los saldos
    # de los pagos; o se hace todo o no se hace nada
    @transaction.atomic
    def update(self, instance, validated_data):
        servicios = validated_data.pop('servicios', None)
        empleados = validated_data.pop('empleados', None)
        fecha_evento = validated_data.get('fecha_evento', instance.fecha_evento)

        if empleados is not None:
            self._validar_empleados(empleados, fecha_evento, excluir_reserva=instance)
        # Si cambian los servicios o la fecha, se vuelve a controlar que haya equipos ese día
        if servicios is not None or fecha_evento != instance.fecha_evento:
            servicios_finales = servicios if servicios is not None else list(
                Servicios.objects.filter(reservas_x_servicios__id_reserva=instance)
            )
            self._validar_equipos(servicios_finales, fecha_evento, excluir_reserva=instance)

        # Precio de cada servicio: los que ya estaban en la reserva conservan el precio con
        # el que se reservaron; los que se agregan ahora toman el precio actual
        precios = {}
        if servicios is not None:
            guardados = dict(
                Reservas_x_Servicios.objects.filter(id_reserva=instance).values_list('id_servicio_id', 'precio_servicio')
            )
            precios = {s.pk: guardados.get(s.pk, s.precio_servicio) for s in servicios}
            validated_data['monto_total'] = sum(precios.values())

        instance = super().update(instance, validated_data)

        if servicios is not None:
            Reservas_x_Servicios.objects.filter(id_reserva=instance).delete()
            for servicio in servicios:
                Reservas_x_Servicios.objects.create(
                    id_reserva=instance, id_servicio=servicio, precio_servicio=precios[servicio.pk]
                )
            # Si cambiaron los servicios cambió el total, así que los saldos de los pagos también
            recalcular_saldos(instance)
        if empleados is not None:
            Detalles_Reservas.objects.filter(id_reserva=instance).delete()
            for empleado in empleados:
                Detalles_Reservas.objects.create(id_reserva=instance, id_empleado=empleado)
        return instance


# ---------------- Personal, horarios y métodos de pago ----------------
#
# Sueldos, horarios y métodos de pago son catálogos simples: solo se mandan sus campos
class SueldosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sueldos
        fields = ['id_sueldo', 'monto_sueldo']


# Puestos, con el monto del sueldo para mostrarlo en la tabla
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
    El saldo_pendiente se calcula solo con recalcular_saldos(): monto_total
    de la reserva menos lo pagado hasta este pago (este incluido), así
    que nunca se manda a mano desde el frontend.
    """
    cliente_nombre = serializers.CharField(source='id_reserva.id_cliente.__str__', read_only=True)
    evento_nombre = serializers.CharField(source='id_reserva.nombre_evento', read_only=True)
    metodos_pago = serializers.PrimaryKeyRelatedField(
        # Solo métodos de pago activos
        queryset=Metodo_Pagos.objects.activos(), many=True, write_only=True, required=False
    )
    metodos_pago_detalle = serializers.SerializerMethodField()

    class Meta:
        model = Pagos
        fields = [
            'id_pago', 'id_reserva', 'cliente_nombre', 'evento_nombre',
            'monto', 'saldo_pendiente', 'metodos_pago', 'metodos_pago_detalle',
        ]
        read_only_fields = ['saldo_pendiente']

    # No se registran pagos de reservas anuladas
    def validate_id_reserva(self, reserva):
        if reserva.estado_reserva == 'ANULADA':
            raise serializers.ValidationError('No se pueden registrar pagos de una reserva anulada.')
        return reserva

    # Un pago no puede superar lo que falta pagar de la reserva. Lo que falta se calcula con
    # los demás pagos de esa reserva (al editar un pago, el mismo pago no se cuenta)
    def validate(self, attrs):
        reserva = attrs.get('id_reserva', getattr(self.instance, 'id_reserva', None))
        monto = attrs.get('monto', getattr(self.instance, 'monto', 0))
        if reserva is not None:
            otros_pagos = Pagos.objects.activos().filter(id_reserva=reserva)
            if self.instance is not None:
                otros_pagos = otros_pagos.exclude(pk=self.instance.pk)
            saldo = max(reserva.monto_total - sum(p.monto for p in otros_pagos), 0)
            if saldo <= 0:
                raise serializers.ValidationError({'monto': 'La reserva ya está totalmente paga.'})
            # 0.01 de tolerancia por los redondeos de los decimales
            if monto > saldo + 0.01:
                # El saldo con formato argentino (puntos de miles y coma decimal): 90000 -> "90.000,00"
                saldo_texto = f'{saldo:,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')
                raise serializers.ValidationError({
                    'monto': f'El pago no puede superar el saldo pendiente ($ {saldo_texto}).'
                })
        return attrs

    # Métodos con los que se hizo el pago (puede ser más de uno)
    def get_metodos_pago_detalle(self, obj):
        rels = Detalles_de_Pago.objects.filter(id_pago=obj).select_related('id_metodo_pago')
        return [
            {'id_metodo_pago': r.id_metodo_pago_id, 'metodo_pago': r.id_metodo_pago.metodo_pago}
            for r in rels
        ]

    def create(self, validated_data):
        # Los métodos van en otra tabla (Detalles_de_Pago): se sacan de los datos, se guarda el pago
        # y después se crea una fila por cada método
        metodos = validated_data.pop('metodos_pago', [])
        pago = Pagos.objects.create(**validated_data)
        for metodo in metodos:
            Detalles_de_Pago.objects.create(id_pago=pago, id_metodo_pago=metodo)
        # El saldo de este pago (y el de los demás de la reserva) se calcula acá
        recalcular_saldos(pago.id_reserva)
        pago.refresh_from_db()
        return pago

    def update(self, instance, validated_data):
        metodos = validated_data.pop('metodos_pago', None)
        reserva_anterior = instance.id_reserva

        instance = super().update(instance, validated_data)

        if metodos is not None:
            Detalles_de_Pago.objects.filter(id_pago=instance).delete()
            for metodo in metodos:
                Detalles_de_Pago.objects.create(id_pago=instance, id_metodo_pago=metodo)

        # Si se cambió el monto, cambian los saldos de este pago y de los que vinieron después.
        # Si se lo pasó a otra reserva, hay que recalcular las dos.
        recalcular_saldos(instance.id_reserva)
        if reserva_anterior.pk != instance.id_reserva_id:
            recalcular_saldos(reserva_anterior)
        instance.refresh_from_db()
        return instance


# ---------------- Registro de actividad ----------------
#
class RegistroActividadSerializer(serializers.ModelSerializer):
    """Una fila del registro de actividad, con el nombre de la acción y de la persona para mostrar."""
    accion_display = serializers.CharField(source='get_accion_display', read_only=True)
    # Nombre y apellido del empleado del usuario (vacío si fue un login con un usuario que no existe)
    persona = serializers.SerializerMethodField()

    class Meta:
        model = Registro_Actividad
        fields = [
            'id_registro', 'fecha', 'usuario_texto', 'persona', 'accion', 'accion_display',
            'modulo', 'id_objeto', 'descripcion', 'detalle', 'ip',
        ]

    def get_persona(self, obj):
        if obj.id_usuario and obj.id_usuario.id_empleado:
            return f'{obj.id_usuario.nombre} {obj.id_usuario.apellido}'
        return ''
