from django.db import models
from django.core.validators import MinValueValidator
from decimal import Decimal

'''
Van los modelos de la base datos === TABLAS DE LA BD 
Se lo crea como objetos
'''
class Sueldo(models.Model):
    monto_sueldo = models.DecimalField(max_digits = 10, decimal_places = 2)
    def __str__(self):
        return f'${self.monto_sueldo}'

class Puesto(models.Model):
    nombre_puesto = models.CharField(max_length = 50)
    id_sueldo = models.ForeignKey(Sueldo,on_delete=models.PROTECT)

    def __str__(self):
        return self.nombre_puesto
    
class Empleado(models.Model):
    id_empleado = models.AutoField(primary_key=True)
    nombre_emp = models.CharField(max_length=50)
    apellido_emp = models.CharField(max_length=50)
    telefono_emp = models.CharField(max_length=20)
    email_emp = models.EmailField()

    class Meta:
        verbose_name = "Empleado"
        verbose_name_plural = "Empleados"
    
    def __str__(self):
        return f'{self.nombre_emp} {self.apellido_emp}'

#! facumacaione - Usuario y Perfil, agrego Horarios también porque
#! quiero terminar la tabla intermediaria que me toca.

class Horario(models.Model):
    id_horario = models.AutoField(primary_key=True)
    cantidad_horas = models.IntegerField()

    class Meta:
        verbose_name = "Horario"
        verbose_name_plural = "Horarios"

    def __str__(self):
        return f"Horario {self.id_horario} - {self.cantidad_horas}hs"

class Perfil(models.Model):
    id_perfil = models.AutoField(primary_key=True)
    tipo_perfil = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Perfil"
        verbose_name_plural = "Perfiles"

    def __str__(self):
        return self.tipo_perfil


class Usuario(models.Model):
    id_usuario = models.AutoField(primary_key=True)
    id_perfil = models.ForeignKey(Perfil, on_delete=models.PROTECT, db_column='id_perfil')
    usuario = models.CharField(max_length=50)
    contraseña = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self):
        return self.usuario

class HorariosXEmpleados(models.Model):
    id_empleado = models.ForeignKey(Empleado, on_delete=models.CASCADE, db_column='id_empleado')
    id_horario = models.ForeignKey(Horario, on_delete=models.CASCADE, db_column='id_horario')

    class Meta:
        verbose_name = "Horario x Empleado"
        verbose_name_plural = "Horarios x Empleados"
        unique_together = ('id_empleado', 'id_horario')

    def __str__(self):
        return f"{self.id_empleado} - {self.id_horario}"

#* facualarcon - TipoEquipo, Equipo y Servicios

class TipoEquipo(models.Model):
    nombre_tipoeq = models.CharField(max_length=50)

    class Meta:
        verbose_name = "Tipo de Equipo"
        verbose_name_plural = "Tipos de Equipos"

    def __str__(self):
        return self.nombre_tipoeq


class Equipo(models.Model):
    ESTADO_CHOICES = [
        ('DISPONIBLE', 'Disponible'),
        ('EN_USO', 'En uso'),
        ('EN_REPARACION', 'En reparación'),
    ]

    nombre_equipo = models.CharField(max_length=50)
    tipo_equipo = models.ForeignKey(TipoEquipo, on_delete=models.PROTECT)
    estado_equipo = models.CharField(max_length=20, choices=ESTADO_CHOICES, default='DISPONIBLE')
    cantidad_equipo = models.PositiveIntegerField(default=1)

    class Meta:
        verbose_name = "Equipo"
        verbose_name_plural = "Equipos"

    def __str__(self):
        return f"{self.nombre_equipo} ({self.tipo_equipo})"

class Servicio(models.Model):
    nombre_servicio = models.CharField(max_length=100, verbose_name="Nombre del Servicio")
    descripcion_servicio = models.TextField(blank=True, null=True, verbose_name="Descripción")
    precio_servicio = models.DecimalField(
        max_digits=10, 
        decimal_places=2, 
        validators=[MinValueValidator(Decimal('0.00'))],
        verbose_name="Precio base"
    )
    # Relación Muchos a Muchos a través de la tabla intermedia
    equipos = models.ManyToManyField(
        Equipo, 
        through='EquipoPorServicio',
        related_name='servicios',
        blank=True
    )

    class Meta:
        verbose_name = "Servicio"
        verbose_name_plural = "Servicios"

    def __str__(self):
        return self.nombre_servicio

    """
    Tabla intermedia Equipos_x_Servicios.
    """
class EquipoPorServicio(models.Model):
    servicio = models.ForeignKey(
        Servicio, 
        on_delete=models.CASCADE, 
        related_name="detalle_equipos",
        verbose_name="Servicio"
    )
    equipo = models.ForeignKey(
        Equipo, 
        on_delete=models.PROTECT, 
        related_name="servicios_asociados",
        verbose_name="Equipo"
    )
    cantidad = models.PositiveIntegerField(
        default=1, 
        validators=[MinValueValidator(1)],
        verbose_name="Cantidad requerida"
    )

    class Meta:
        verbose_name = "Equipo por Servicio"
        verbose_name_plural = "Equipos por Servicio"
        # Evita que se duplique el mismo equipo en el mismo servicio
        unique_together = ('servicio', 'equipo')

    def __str__(self):
        return f"{self.cantidad}x {self.equipo.nombre_equipo} para {self.servicio.nombre_servicio}"


class Clientes(models.Model):
    nombre_cliente = models.CharField(max_length=50)
    apellido_cliente = models.CharField(max_length=50)
    domicilio_cliente = models.CharField(max_length=100)
    telefono_cliente= models.CharField(max_length=20)
    email_cliente = models.EmailField(max_length=100)

    def __str__(self):
        return f"{self.nombre_cliente} {self.apellido_cliente}"


class Reservas(models.Model):
    ESTADO_CHOICES = [
        ('ACTIVA', 'Activa'),
        ('FINALIZADA', 'Finalizada'),
        ('CANCELADA', 'Cancelada'),
    ]

    cliente = models.ForeignKey(Clientes, on_delete=models.PROTECT, db_column='id_cliente')
    fecha_evento = models.DateField()
    direccion_evento = models.CharField(max_length=100)
    duracion_evento = models.TimeField()
    monto_total = models.FloatField(default=0)
    estado_reserva = models.CharField(max_length=20, choices=ESTADO_CHOICES, default='ACTIVA')

    def __str__(self):
        return f"Reserva N°{self.id} - {self.cliente}"


class DetallesReservas(models.Model):
    id_detalle_reserva = models.AutoField(primary_key=True)
    reserva = models.ForeignKey(Reservas, on_delete=models.CASCADE, db_column='id_reserva')
    empleado = models.ForeignKey(Empleado, on_delete=models.PROTECT, db_column='id_empleado')

    def __str__(self):
        return f"Detalle {self.id_detalle_reserva} - Reserva {self.reserva_id}"


class MetodoPago(models.Model):
    id_metodo_pago = models.AutoField(primary_key=True)
    metodo_pago = models.CharField(max_length=50, verbose_name="Método de pago")

    class Meta:
        verbose_name = "Método de Pago"
        verbose_name_plural = "Métodos de Pago"

    def __str__(self):
        return self.metodo_pago


class Pagos(models.Model):
    id_pago = models.AutoField(primary_key=True)
    reserva = models.ForeignKey(Reservas, on_delete=models.PROTECT, db_column='id_reserva')
    monto = models.FloatField(default=0)

    class Meta:
        verbose_name = "Pago"
        verbose_name_plural = "Pagos"

    def __str__(self):
        return f"Pago N°{self.id_pago} - Reserva {self.reserva_id}"

    """
    Tabla intermedia Detalles_de_Pago.
    """
class DetallesDePago(models.Model):
    id_detalle_pago = models.AutoField(primary_key=True)
    pago = models.ForeignKey(Pagos, on_delete=models.CASCADE, db_column='id_pago', related_name='detalles_pago')
    metodo_pago = models.ForeignKey(MetodoPago, on_delete=models.PROTECT, db_column='id_metodo_pago')

    class Meta:
        verbose_name = "Detalle de Pago"
        verbose_name_plural = "Detalles de Pago"

    def __str__(self):
        return f"Detalle {self.id_detalle_pago} - Pago {self.pago_id}"

    
class Horarios_x_Empleados(models.Model):
    id_empleado = models.ForeignKey(Empleado, on_delete=models.CASCADE)
    id_horario = models.ForeignKey(Horario, on_delete=models.CASCADE)

    def __str__(self):
        return f'{self.id_empleado} - {self.id_horario}'

class Puestos_x_Empleados(models.Model):
    id_empleado = models.ForeignKey(Empleado, on_delete=models.CASCADE)
    id_puesto = models.ForeignKey(Puesto, on_delete=models.CASCADE)

    def __str__(self):
        return f'{self.id_empleado} - {self.id_puesto}'

class Reservas_x_Servicios(models.Model):
    id_reserva = models.ForeignKey(Reserva, on_delete=models.CASCADE)
    id_servicio = models.ForeignKey(Servicio, on_delete=models.CASCADE)

    def __str__(self):
        return f'{self.id_reserva} - {self.id_servicio}'