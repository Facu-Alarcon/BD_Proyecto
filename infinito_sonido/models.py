from django.db import models

'''
Van los modelos de la base datos === TABLAS DE LA BD 
Se lo crea como objetos
'''
class Alumno(models.Model):
    """Modelo de ejemplo. Cada instancia es una fila en la tabla de MySQL."""

    nombre = models.CharField('Nombre', max_length=50)
    nota = models.DecimalField(
        'Nota',
        max_digits=4,
        decimal_places=2,
        null=True,
        blank=True,
    )
    fecha_alta = models.DateTimeField('Fecha de alta', auto_now_add=True)

    class Meta:
        verbose_name = 'Alumno'
        verbose_name_plural = 'Alumnos'
        ordering = ['nombre']

    def __str__(self):
        return f'{self.nombre} ({self.nota})'
