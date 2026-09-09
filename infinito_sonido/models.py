from django.db import models
from django.core.validators import MinValueValidator
from decimal import Decimal

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
    nombre_emp = models.CharField(max_length=50)
    apellido_emp = models.CharField(max_length=50)
    telefono_emp = models.IntegerField()
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
    id_perfil = models.ForeignKey(Perfiles, on_delete=models.PROTECT, db_column='id_perfil')
    usuario = models.CharField(max_length=50)
    contraseña = models.CharField(max_length=128)

    class Meta:
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self):
        return self.usuario

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

    class Meta:
        verbose_name = "Equipo x Servicio"
        verbose_name_plural = "Equipos x Servicios"
        unique_together = ('id_equipo', 'id_servicio')

    def __str__(self):
        return f"{self.id_equipo} - {self.id_servicio}"


class Clientes(models.Model):
    id_cliente = models.AutoField(primary_key=True)
    nombre_cliente = models.CharField(max_length=50)
    apellido_cliente = models.CharField(max_length=50)
    domicilio_cliente = models.CharField(max_length=100)
    telefono_cliente = models.IntegerField()
    email_cliente = models.EmailField(max_length=100)

    class Meta:
        verbose_name = "Cliente"
        verbose_name_plural = "Clientes"

    def __str__(self):
        return f"{self.nombre_cliente} {self.apellido_cliente}"


class Reservas(models.Model):
    ESTADO_CHOICES = [
        ('PENDIENTE', 'Pendiente'),
        ('CONFIRMADA', 'Confirmada'),
        ('FINALIZADA', 'Finalizada'),
        ('CANCELADA', 'Cancelada'),
    ]

    id_reserva = models.AutoField(primary_key=True)
    id_cliente = models.ForeignKey(Clientes, on_delete=models.PROTECT, db_column='id_cliente')
    nombre_evento = models.CharField(max_length=100, blank=True)
    fecha_evento = models.DateField()
    direccion_evento = models.CharField(max_length=100)
    duracion_evento = models.TimeField()
    monto_total = models.FloatField(default=0)
    estado_reserva = models.CharField(max_length=20, choices=ESTADO_CHOICES, default='PENDIENTE')

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
    monto = models.FloatField(default=0)
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

    def __str__(self):
        return f"Detalle {self.id_detalle_pago} - Pago {self.id_pago_id}"