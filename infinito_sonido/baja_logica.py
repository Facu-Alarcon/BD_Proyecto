# BAJA LÓGICA: en este sistema no se borra nada de la base desde la aplicación.
#
# Para el usuario del sistema es "Eliminar" (el tachito de las tablas) y así se le muestra
# siempre: a propósito, el frontend no le dice que se puede recuperar, para que use el
# botón con cuidado. Por dentro, el registro no se elimina:
# se marca activo=False y se guarda la fecha en fecha_baja. Desde ese momento la API ya no lo
# devuelve, así que desaparece de todas las pantallas y desplegables del frontend, pero sigue
# estando en la base.
#
# ¿Para qué? Si el dueño elimina algo por error, el programador lo puede recuperar desde
# el panel /admin de Django: cada tabla tiene el filtro "Activo" y la acción "Reactivar los
# seleccionados" (ver admin.py). También queda anotado en el Registro de actividad quién lo
# dio de baja y cuándo.
#
# Qué tablas la usan: todas las que tienen botón de borrar (Clientes, Empleados, Equipos,
# Tipos y Estados de equipo, Servicios, Puestos, Sueldos, Horarios, Perfiles, Permisos,
# Métodos de pago y Pagos). Las que no la usan:
#   - Usuarios: ya tenía su propia baja lógica (activo + fecha_baja), visible en la pantalla
#     de Usuarios con los botones "Dar de baja" y "Reactivar".
#   - Reservas: no se dan de baja, se ANULAN con motivo (acción "anular" en api.py).
#   - Tablas intermedias (Puestos_x_Empleados, Permisos_x_Perfiles, etc.): son asignaciones
#     que se tildan y destildan, no registros que se den de baja.
#
# Cómo se usa en el código:
#   - Modelos: heredan de BajaLogica (en models.py) en lugar de models.Model.
#   - Consultas: Modelo.objects.activos() en vez de Modelo.objects.all() cuando solo
#     interesan los que están en uso (ej: los pagos que cuentan para el saldo).
#   - ViewSets: llevan BajaLogicaMixin (abajo) y, si hay que impedir la baja en algún caso,
#     redefinen validar_baja().

from django.db import models
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response


# Agrega a todas las consultas el atajo .activos(): Clientes.objects.activos()
class BajaLogicaQuerySet(models.QuerySet):
    def activos(self):
        return self.filter(activo=True)


class BajaLogica(models.Model):
    """
    Modelo base (abstracto: no crea una tabla propia) que les suma a las tablas los dos
    campos de la baja lógica y el método para darlas de baja.
    """
    # True mientras está en uso; False cuando se dio de baja (ya no se muestra en el sistema)
    activo = models.BooleanField(default=True)
    # Cuándo se dio de baja (vacío mientras está activo)
    fecha_baja = models.DateTimeField(null=True, blank=True)

    objects = BajaLogicaQuerySet.as_manager()

    class Meta:
        abstract = True

    # "Borrar" en este sistema: se marca inactivo y se guarda cuándo, sin tocar el resto de los datos
    def dar_de_baja(self):
        self.activo = False
        self.fecha_baja = timezone.now()
        self.save(update_fields=['activo', 'fecha_baja'])

    # Lo contrario: lo vuelve a poner en uso (lo usa la acción "Reactivar" del panel /admin)
    def reactivar(self):
        self.activo = True
        self.fecha_baja = None
        self.save(update_fields=['activo', 'fecha_baja'])


class BajaLogicaMixin:
    """
    Se agrega a los ViewSets de las tablas con baja lógica. Hace dos cosas:
      - La API solo trabaja con los registros activos: los dados de baja no aparecen en la
        lista, y si alguien pide uno por su id recibe "no encontrado" (404).
      - DELETE ya no borra la fila: la da de baja.
    """

    def get_queryset(self):
        return super().get_queryset().filter(activo=True)

    def validar_baja(self, objeto):
        """
        Cada ViewSet lo redefine si hay casos en los que no se puede dar de baja (por ejemplo,
        un cliente con reservas pendientes). Devuelve el mensaje para el usuario, o None si se puede.
        """
        return None

    def destroy(self, request, *args, **kwargs):
        objeto = self.get_object()
        motivo = self.validar_baja(objeto)
        if motivo:
            # El mensaje le llega al usuario (dice "No se puede eliminar..."). 409 = conflicto: el pedido es válido pero el estado de los datos no lo permite
            return Response({'detail': motivo}, status=status.HTTP_409_CONFLICT)
        objeto.dar_de_baja()
        self.despues_de_baja(objeto)
        return Response(status=status.HTTP_204_NO_CONTENT)

    def despues_de_baja(self, objeto):
        """Por si un módulo tiene que hacer algo más después de la baja (ej: Pagos recalcula saldos)."""
