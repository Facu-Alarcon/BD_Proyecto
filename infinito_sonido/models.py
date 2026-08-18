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
    nombre_emp = models.CharField(max_length=50)
    apellido_emp = models.CharField(max_length=50)
    telefono_emp = models.CharField(max_length=20)
    email_emp = models.EmailField()
    
    def __str__(self):
        return f'{self.nombre_emp}{self.apellido_emp}'

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
