# QUÉ PASA CUANDO SE TOCA EL TACHITO (eliminar, desactivar y anular)
#
# Lo normal: eliminar borra el registro de la base de datos y no se puede recuperar.
# Pero solo se puede borrar si no tiene nada asociado. Por ejemplo, un cliente que ya
# tiene reservas no se puede eliminar, porque esas reservas se quedarían sin cliente.
# En ese caso el sistema no borra nada y le avisa al usuario por qué.
#
# Hay algunas cosas que NO se borran nunca, aunque se pida:
#
#   - Empleados, Servicios y Métodos de pago: si nunca se usaron se eliminan como
#     cualquier otro. Pero si ya tienen historia (un empleado que trabajó en eventos,
#     un servicio que se contrató, un método con el que se cobró) no se pueden borrar,
#     así que se DESACTIVAN: siguen guardados y se ven en su lista como "Inactivo",
#     pero ya no aparecen para elegirlos en las reservas y pagos nuevos.
#     Si hace falta, se pueden volver a activar.
#
#   - Pagos: no se eliminan, se ANULAN escribiendo el motivo. Es plata que se cobró,
#     así que tiene que quedar anotado qué pasó.
#
#   - Reservas: tampoco se eliminan, se anulan con motivo (eso ya estaba de antes).
#
#   - Usuarios: igual que los anteriores. Se eliminan solo si nunca se usaron (por
#     ejemplo, uno creado por error que nunca ingresó). Si ya tienen historial se
#     DESACTIVAN: no pueden entrar más al sistema, pero se pueden reactivar.
#
# En este archivo está lo que necesitan las tablas que se pueden desactivar: los dos
# campos (activo y fecha_baja) y las funciones para desactivar y reactivar.
# Lo que hace la API cuando alguien aprieta eliminar o desactivar está en eliminar.py.

from django.db import models
from django.utils import timezone


# Nos deja pedir solo los que están activos escribiendo .activos()
# Por ejemplo: Servicios.objects.activos() trae los servicios que se pueden contratar
class BajaLogicaQuerySet(models.QuerySet):
    def activos(self):
        return self.filter(activo=True)


class BajaLogica(models.Model):
    """
    Las tablas que se pueden desactivar se arman a partir de esta clase, y así todas
    tienen los mismos dos campos sin tener que escribirlos en cada una.
    No es una tabla de verdad: solo sirve de base para las otras.
    Ojo: en Pagos, activo en False quiere decir que el pago está anulado.
    """
    # True = está en uso. False = se desactivó (o se anuló, si es un pago)
    activo = models.BooleanField(default=True)
    # La fecha en que se desactivó o anuló. Mientras está activo queda vacía
    fecha_baja = models.DateTimeField(null=True, blank=True)

    objects = BajaLogicaQuerySet.as_manager()

    class Meta:
        abstract = True

    # Desactivar: lo marca como inactivo y anota la fecha. Los demás datos no se tocan
    def desactivar(self):
        self.activo = False
        self.fecha_baja = timezone.now()
        self.save(update_fields=['activo', 'fecha_baja'])

    # Reactivar: lo vuelve a dejar activo y borra la fecha
    def reactivar(self):
        self.activo = True
        self.fecha_baja = None
        self.save(update_fields=['activo', 'fecha_baja'])
