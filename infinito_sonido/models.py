from django.db import models
from django.core.validators import MinValueValidator, MinLengthValidator, RegexValidator
from decimal import Decimal

# Los teléfonos se guardan como texto, no como número: nunca se operan
# matemáticamente y un IntegerField normal tiene tope en 2.147.483.647,
# que un celular con característica (ej: 3878551132) supera fácilmente.
validar_telefono = [
    MinLengthValidator(10, message='El teléfono debe tener al menos 10 dígitos.'),
    RegexValidator(r'^\d+$', message='El teléfono solo puede tener números.'),
]

# Nombres y apellidos: solo letras (con acentos y ñ), espacios, guiones y
# apóstrofes (para nombres compuestos tipo "María José" o "O'Connor").
# Nada de números ni símbolos raros.
validar_nombre_propio = [
    RegexValidator(r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.'),
]

# DNI argentino: solo dígitos, sin puntos. Se valida largo real (7 u 8
# dígitos) en vez de dejarlo libre, para no aceptar cualquier número.
validar_dni = [
    MinLengthValidator(7, message='El DNI debe tener 7 u 8 dígitos.'),
    RegexValidator(r'^\d+$', message='El DNI solo puede tener números, sin puntos ni espacios.'),
]

'''
Van los modelos de la base datos === TABLAS DE LA BD 
Se lo crea como objetos
'''
class Sueldos(models.Model):
    id_sueldo = models.AutoField(primary_key=True)
    monto_sueldo = models.FloatField()

    class Meta:
        verbose_name = "Sueldo"
        verbose_name_plural = "Sueldos"

    def __str__(self):
        return f'${self.monto_sueldo}'


class Puestos(models.Model):
    id_puesto = models.AutoField(primary_key=True)
    id_sueldo = models.ForeignKey(Sueldos, on_delete=models.PROTECT, db_column='id_sueldo')
    nombre_puesto = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Puesto"
        verbose_name_plural = "Puestos"

    def __str__(self):
        return self.nombre_puesto


class Empleados(models.Model):
    id_empleado = models.AutoField(primary_key=True)
    # El DNI ahora es dato del empleado (antes estaba en Usuarios). Puede quedar vacío solo
    # en los empleados que se cargaron antes de este cambio; desde el formulario se pide siempre.
    dni = models.CharField(max_length=8, unique=True, null=True, blank=True, validators=validar_dni)
    nombre_emp = models.CharField(max_length=30, validators=validar_nombre_propio)
    apellido_emp = models.CharField(max_length=30, validators=validar_nombre_propio)
    telefono_emp = models.CharField(max_length=12, validators=validar_telefono)
    email_emp = models.EmailField()

    class Meta:
        verbose_name = "Empleado"
        verbose_name_plural = "Empleados"

    def __str__(self):
        return f'{self.nombre_emp} {self.apellido_emp}'


class Puestos_x_Empleados(models.Model):
    id_puesto_empleado = models.AutoField(primary_key=True)
    id_empleado = models.ForeignKey(Empleados, on_delete=models.CASCADE, db_column='id_empleado')
    id_puesto = models.ForeignKey(Puestos, on_delete=models.CASCADE, db_column='id_puesto')

    class Meta:
        verbose_name = "Puesto x Empleado"
        verbose_name_plural = "Puestos x Empleados"
        unique_together = ('id_empleado', 'id_puesto')

    def __str__(self):
        return f'{self.id_empleado} - {self.id_puesto}'

#! facumacaione - Usuario, Perfil y Horarios

class Horarios(models.Model):
    id_horario = models.AutoField(primary_key=True)
    cantidad_horas = models.FloatField()

    class Meta:
        verbose_name = "Horario"
        verbose_name_plural = "Horarios"

    def __str__(self):
        return f"Horario {self.id_horario} - {self.cantidad_horas}hs"


class Perfiles(models.Model):
    id_perfil = models.AutoField(primary_key=True)
    tipo_perfil = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Perfil"
        verbose_name_plural = "Perfiles"

    def __str__(self):
        return self.tipo_perfil


class Usuarios(models.Model):
    id_usuario = models.AutoField(primary_key=True)
    # Cada usuario es la cuenta de un empleado: relación uno a uno, así un empleado
    # no puede tener dos usuarios. Nombre, apellido, DNI y correo se toman del empleado.
    # PROTECT: no se puede borrar un empleado que tiene usuario (primero se da de baja).
    id_empleado = models.OneToOneField(
        Empleados, on_delete=models.PROTECT, db_column='id_empleado', related_name='usuario'
    )
    id_perfil = models.ForeignKey(Perfiles, on_delete=models.PROTECT, db_column='id_perfil')
    # Se genera solo al crear el usuario: primer apellido + inicial del nombre (ej: perezj),
    # con un número si ya está tomado (ver nombres_usuario.py). Queda fijo de ahí en más.
    usuario = models.CharField(max_length=50, unique=True)
    contraseña = models.CharField(max_length=128)
    # Baja de usuario = activo=False + fecha_baja (no se borra la fila:
    # ver UsuariosViewSet.destroy en api.py).
    activo = models.BooleanField(default=True)
    # Se prende solo al usar "Restablecer clave" (acción del admin) y
    # obliga a definir una contraseña propia en el próximo login; se
    # apaga cuando el usuario la cambia (ver CambiarClaveView en api.py).
    debe_cambiar_clave = models.BooleanField(default=False)
    fecha_ultima_modificacion = models.DateField(auto_now=True)
    fecha_baja = models.DateField(null=True, blank=True)

    class Meta:
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self):
        return self.usuario

    # Accesos directos a los datos del empleado, para no escribir usuario.id_empleado.nombre_emp
    @property
    def nombre(self):
        return self.id_empleado.nombre_emp

    @property
    def apellido(self):
        return self.id_empleado.apellido_emp

    @property
    def correo(self):
        return self.id_empleado.email_emp

    @property
    def is_authenticated(self):
        """Permite que DRF (IsAuthenticated) trate a Usuarios como un usuario válido."""
        return True


class Permisos(models.Model):
    id_permiso = models.AutoField(primary_key=True)
    nombre_permiso = models.CharField(max_length=50, unique=True)
    descripcion_permiso = models.CharField(max_length=150, blank=True)
    estado_permiso = models.BooleanField(default=True)
    # Clave interna estable que usa el backend para decidir accesos
    # (ver infinito_sonido/permissions.py). No se edita desde la UI:
    # se genera solo a partir del nombre al crear el permiso, y no
    # cambia aunque después se renombre el permiso.
    codigo = models.SlugField(max_length=60, unique=True, blank=True)

    class Meta:
        verbose_name = "Permiso"
        verbose_name_plural = "Permisos"

    def __str__(self):
        return self.nombre_permiso


class Permisos_x_Perfiles(models.Model):
    id_permiso_perfil = models.AutoField(primary_key=True)
    id_perfil = models.ForeignKey(Perfiles, on_delete=models.CASCADE, db_column='id_perfil')
    id_permiso = models.ForeignKey(Permisos, on_delete=models.CASCADE, db_column='id_permiso')

    class Meta:
        verbose_name = "Permiso x Perfil"
        verbose_name_plural = "Permisos x Perfiles"
        unique_together = ('id_perfil', 'id_permiso')

    def __str__(self):
        return f"{self.id_perfil} - {self.id_permiso}"


class Horarios_x_Empleados(models.Model):
    id_horario_empleado = models.AutoField(primary_key=True)
    id_empleado = models.ForeignKey(Empleados, on_delete=models.CASCADE, db_column='id_empleado')
    id_horario = models.ForeignKey(Horarios, on_delete=models.CASCADE, db_column='id_horario')

    class Meta:
        verbose_name = "Horario x Empleado"
        verbose_name_plural = "Horarios x Empleados"
        unique_together = ('id_empleado', 'id_horario')

    def __str__(self):
        return f"{self.id_empleado} - {self.id_horario}"


#* facualarcon - Tipo_Equipos, Equipos y Servicios

class Tipo_Equipos(models.Model):
    id_tipoeq = models.AutoField(primary_key=True)
    nombre_tipoeq = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Tipo de Equipo"
        verbose_name_plural = "Tipo de Equipos"

    def __str__(self):
        return self.nombre_tipoeq


class Estado_Equipos(models.Model):
    id_estadoeq = models.AutoField(primary_key=True)
    nombre_estadoeq = models.CharField(max_length=50, unique=True)

    class Meta:
        verbose_name = "Estado de Equipo"
        verbose_name_plural = "Estados de Equipo"

    def __str__(self):
        return self.nombre_estadoeq


class Equipos(models.Model):
    id_equipo = models.AutoField(primary_key=True)
    id_tipoeq = models.ForeignKey(Tipo_Equipos, on_delete=models.PROTECT, db_column='id_tipoeq')
    nombre_equipo = models.CharField(max_length=50)
    id_estadoeq = models.ForeignKey(Estado_Equipos, on_delete=models.PROTECT, db_column='id_estadoeq')
    cantidad_equipo = models.PositiveIntegerField(default=1)

    class Meta:
        verbose_name = "Equipo"
        verbose_name_plural = "Equipos"

    def __str__(self):
        return f"{self.nombre_equipo} ({self.id_tipoeq})"


class Servicios(models.Model):
    id_servicio = models.AutoField(primary_key=True)
    tipo_servicio = models.CharField(max_length=100)
    precio_servicio = models.FloatField(validators=[MinValueValidator(0.0)])

    class Meta:
        verbose_name = "Servicio"
        verbose_name_plural = "Servicios"

    def __str__(self):
        return self.tipo_servicio


class Equipos_x_Servicios(models.Model):
    id_equipo_servicio = models.AutoField(primary_key=True)
    id_equipo = models.ForeignKey(Equipos, on_delete=models.PROTECT, db_column='id_equipo')
    id_servicio = models.ForeignKey(Servicios, on_delete=models.CASCADE, db_column='id_servicio')
    # Cuántas unidades de ese equipo usa el servicio (ej: el Combo Boda usa 4 bafles).
    # Con esto se controla que en un mismo día no se reserven más equipos de los que hay.
    cantidad = models.PositiveIntegerField(default=1, validators=[MinValueValidator(1)])

    class Meta:
        verbose_name = "Equipo x Servicio"
        verbose_name_plural = "Equipos x Servicios"
        unique_together = ('id_equipo', 'id_servicio')

    def __str__(self):
        return f"{self.id_equipo} - {self.id_servicio}"


class Clientes(models.Model):
    id_cliente = models.AutoField(primary_key=True)
    nombre_cliente = models.CharField(max_length=30, validators=validar_nombre_propio)
    apellido_cliente = models.CharField(max_length=30, validators=validar_nombre_propio)
    domicilio_cliente = models.CharField(max_length=60)
    telefono_cliente = models.CharField(max_length=12, validators=validar_telefono)
    email_cliente = models.EmailField(max_length=100)

    class Meta:
        verbose_name = "Cliente"
        verbose_name_plural = "Clientes"

    def __str__(self):
        return f"{self.nombre_cliente} {self.apellido_cliente}"


class Reservas(models.Model):
    # Estados de la reserva. Nace siempre en PENDIENTE. ANULADA reemplaza a la vieja
    # "Cancelada": las reservas no se borran nunca, se anulan dejando fecha, motivo y
    # quién lo hizo (pedido del Hito 3).
    ESTADO_CHOICES = [
        ('PENDIENTE', 'Pendiente'),
        ('CONFIRMADA', 'Confirmada'),
        ('FINALIZADA', 'Finalizada'),
        ('ANULADA', 'Anulada'),
    ]

    id_reserva = models.AutoField(primary_key=True)
    id_cliente = models.ForeignKey(Clientes, on_delete=models.PROTECT, db_column='id_cliente')
    nombre_evento = models.CharField(max_length=100, blank=True)
    fecha_evento = models.DateField()
    # Hora a la que arranca el evento
    hora_evento = models.TimeField()
    direccion_evento = models.CharField(max_length=100)
    # Cuánto dura el evento en horas:minutos (ej: 04:30 = cuatro horas y media).
    # Puede quedar vacía solo en las reservas viejas, de antes de separar hora y duración.
    duracion_evento = models.TimeField(null=True, blank=True)
    monto_total = models.FloatField(default=0)
    estado_reserva = models.CharField(max_length=20, choices=ESTADO_CHOICES, default='PENDIENTE')

    # --- Datos automáticos del registro (el número de comprobante es el propio id_reserva) ---
    # Cuándo se cargó la reserva en el sistema (no confundir con fecha_evento, que es el día de la fiesta).
    # Queda vacía solo en las reservas cargadas antes de agregar este campo.
    fecha_registro = models.DateTimeField(auto_now_add=True, null=True)
    # Usuario logueado que registró la reserva
    id_usuario_registro = models.ForeignKey(
        Usuarios, on_delete=models.PROTECT, null=True, blank=True,
        db_column='id_usuario_registro', related_name='reservas_registradas',
    )

    # --- Anulación: se completan solo cuando la reserva pasa a ANULADA ---
    fecha_anulacion = models.DateTimeField(null=True, blank=True)
    motivo_anulacion = models.CharField(max_length=255, blank=True)
    id_usuario_anulacion = models.ForeignKey(
        Usuarios, on_delete=models.PROTECT, null=True, blank=True,
        db_column='id_usuario_anulacion', related_name='reservas_anuladas',
    )

    class Meta:
        verbose_name = "Reserva"
        verbose_name_plural = "Reservas"

    def __str__(self):
        return f"Reserva N°{self.id_reserva} - {self.id_cliente}"


class Detalles_Reservas(models.Model):
    id_detalle_reserva = models.AutoField(primary_key=True)
    id_reserva = models.ForeignKey(Reservas, on_delete=models.CASCADE, db_column='id_reserva')
    id_empleado = models.ForeignKey(Empleados, on_delete=models.PROTECT, db_column='id_empleado')

    class Meta:
        verbose_name = "Detalle de Reserva"
        verbose_name_plural = "Detalles Reservas"

    def __str__(self):
        return f"Detalle {self.id_detalle_reserva} - Reserva {self.id_reserva_id}"


class Reservas_x_Servicios(models.Model):
    id_reserva_servicio = models.AutoField(primary_key=True)
    id_reserva = models.ForeignKey(Reservas, on_delete=models.CASCADE, db_column='id_reserva')
    id_servicio = models.ForeignKey(Servicios, on_delete=models.CASCADE, db_column='id_servicio')
    # Precio del servicio en el momento de reservar. Se guarda acá (y no se lee siempre de
    # Servicios) para que si mañana cambia el precio, las reservas y comprobantes viejos no cambien.
    precio_servicio = models.FloatField(validators=[MinValueValidator(0.0)])

    class Meta:
        verbose_name = "Reserva x Servicio"
        verbose_name_plural = "Reservas x Servicios"
        unique_together = ('id_reserva', 'id_servicio')

    def __str__(self):
        return f'{self.id_reserva} - {self.id_servicio}'


class Metodo_Pagos(models.Model):
    id_metodo_pago = models.AutoField(primary_key=True)
    metodo_pago = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Método de Pago"
        verbose_name_plural = "Método de Pagos"

    def __str__(self):
        return self.metodo_pago

class Pagos(models.Model):
    id_pago = models.AutoField(primary_key=True)
    id_reserva = models.ForeignKey(Reservas, on_delete=models.PROTECT, db_column='id_reserva')
    monto = models.FloatField(default=0, validators=[MinValueValidator(0.01)])
    saldo_pendiente = models.FloatField(default=0)

    class Meta:
        verbose_name = "Pago"
        verbose_name_plural = "Pagos"

    def __str__(self):
        return f"Pago N°{self.id_pago} - Reserva {self.id_reserva_id}"


class Detalles_de_Pago(models.Model):
    id_detalle_pago = models.AutoField(primary_key=True)
    id_pago = models.ForeignKey(Pagos, on_delete=models.CASCADE, db_column='id_pago')
    id_metodo_pago = models.ForeignKey(Metodo_Pagos, on_delete=models.PROTECT, db_column='id_metodo_pago')

    class Meta:
        verbose_name = "Detalle de Pago"
        verbose_name_plural = "Detalles de Pago"

    def __str__(self):
        return f"Detalle {self.id_detalle_pago} - Pago {self.id_pago_id}"


class SesionToken(models.Model):
    """
    Token de sesión propio para autenticar contra el frontend en React.
    No usamos rest_framework.authtoken porque ese token está atado a
    auth.User, y nuestro modelo de usuarios es Usuarios (definido por el DER).
    """
    token = models.CharField(max_length=64, unique=True, db_index=True)
    id_usuario = models.ForeignKey(Usuarios, on_delete=models.CASCADE, db_column='id_usuario')
    creado = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Sesión (token)"
        verbose_name_plural = "Sesiones (tokens)"

    def __str__(self):
        return f"Token de {self.id_usuario}"

class Registro_Actividad(models.Model):
    """
    Registro de actividad (auditoría): guarda cada alta, modificación y baja que se
    hace en el sistema, los inicios y cierres de sesión, los cambios de clave y los
    errores del servidor. Lo arma solo el backend (ver registro.py) y no se puede
    editar ni borrar desde la API: solo se consulta, con el permiso "Ver Registro de actividad".
    """
    ALTA = 'ALTA'
    MODIFICACION = 'MODIFICACION'
    BAJA = 'BAJA'
    LOGIN = 'LOGIN'
    LOGIN_FALLIDO = 'LOGIN_FALLIDO'
    LOGOUT = 'LOGOUT'
    CLAVE = 'CLAVE'
    ERROR = 'ERROR'
    ACCION_CHOICES = [
        (ALTA, 'Alta'),
        (MODIFICACION, 'Modificación'),
        (BAJA, 'Baja'),
        (LOGIN, 'Inicio de sesión'),
        (LOGIN_FALLIDO, 'Inicio de sesión fallido'),
        (LOGOUT, 'Cierre de sesión'),
        (CLAVE, 'Contraseña'),
        (ERROR, 'Error del sistema'),
    ]

    id_registro = models.AutoField(primary_key=True)
    fecha = models.DateTimeField(auto_now_add=True, db_index=True)
    # Quién lo hizo. SET_NULL para no perder el registro si algún día se borra el usuario
    id_usuario = models.ForeignKey(
        Usuarios, on_delete=models.SET_NULL, null=True, blank=True, db_column='id_usuario'
    )
    # El nombre de usuario como texto: sirve para los intentos de login con un usuario que no existe
    usuario_texto = models.CharField(max_length=50, blank=True)
    accion = models.CharField(max_length=20, choices=ACCION_CHOICES, db_index=True)
    modulo = models.CharField(max_length=50, blank=True)           # ej: "Clientes", "Sesión"
    id_objeto = models.CharField(max_length=20, blank=True)        # id del registro afectado
    descripcion = models.CharField(max_length=255)                 # ej: "Juan Pérez"
    detalle = models.TextField(blank=True)                         # qué campos cambiaron, o el error completo
    ip = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        verbose_name = "Registro de actividad"
        verbose_name_plural = "Registro de actividad"
        ordering = ['-fecha']

    def __str__(self):
        return f"{self.fecha:%d/%m/%Y %H:%M} - {self.usuario_texto} - {self.get_accion_display()}"


class Token_Recuperacion(models.Model):
    """
    Link de "Olvidé mi contraseña". Cuando alguien pide recuperar su clave se crea uno
    de estos y se le manda por mail un link con el token. El link vence a los 30 minutos
    y se puede usar una sola vez (ver RecuperarClaveView en api.py).

    No se guarda el token tal cual sino su "huella" (hash SHA-256): si alguien llegara a
    ver la base de datos, con el hash no puede armar el link. Es la misma idea que con
    las contraseñas.
    """
    id_token = models.AutoField(primary_key=True)
    id_usuario = models.ForeignKey(Usuarios, on_delete=models.CASCADE, db_column='id_usuario')
    token_hash = models.CharField(max_length=64, unique=True)
    creado = models.DateTimeField(auto_now_add=True)
    expira = models.DateTimeField()
    usado = models.BooleanField(default=False)

    class Meta:
        verbose_name = "Token de recuperación"
        verbose_name_plural = "Tokens de recuperación"

    def __str__(self):
        return f"Recuperación de {self.id_usuario} ({'usado' if self.usado else 'pendiente'})"
