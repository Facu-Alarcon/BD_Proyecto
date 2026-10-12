# Lo que hace el sistema cuando alguien quiere eliminar, desactivar o reactivar algo.
# Las reglas (qué se puede eliminar y qué no) están explicadas en baja_logica.py.
#
# Acá hay dos clases que se les agregan a los módulos de api.py para no repetir el
# mismo código en cada uno:
#   - EliminarMixin: para todos los módulos que tienen tachito.
#   - DesactivarMixin: para Empleados, Servicios y Métodos de pago, que además
#     tienen los botones de Desactivar y Reactivar.

from django.db import transaction
from django.db.models.deletion import ProtectedError
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.response import Response


class EliminarMixin:
    """
    Eliminar: borra el registro de la base de datos. Si tiene algo asociado no lo
    borra y devuelve un mensaje explicando por qué.
    """

    def validar_eliminacion(self, objeto):
        """
        Acá cada módulo dice cuándo NO se puede eliminar (por ejemplo, un cliente
        que tiene reservas). Si no se puede, devuelve el mensaje que va a ver el
        usuario. Si se puede, no devuelve nada.
        """
        return None

    # Esto se ejecuta cuando el usuario confirma que quiere eliminar
    def destroy(self, request, *args, **kwargs):
        # Buscamos el registro que se quiere eliminar
        objeto = self.get_object()

        # Primero preguntamos si se puede. Si no, cortamos acá y mostramos el motivo
        motivo = self.validar_eliminacion(objeto)
        if motivo:
            return Response({'detail': motivo}, status=status.HTTP_409_CONFLICT)

        try:
            # Se borra de la base. Va dentro de "atomic" para que, si algo falla en el
            # medio, no quede borrado a medias
            with transaction.atomic():
                objeto.delete()
        except ProtectedError:
            # Por las dudas: si nos olvidamos de controlar algún caso arriba, la base de
            # datos igual no deja borrar algo que otra tabla está usando. Si pasa eso,
            # mostramos un mensaje en vez de que el sistema tire un error
            return Response(
                {'detail': f'No se puede eliminar "{objeto}" porque tiene registros asociados.'},
                status=status.HTTP_409_CONFLICT,
            )

        # Salió bien: se avisa que se eliminó (no hace falta devolver ningún dato)
        return Response(status=status.HTTP_204_NO_CONTENT)


class DesactivarMixin:
    """
    Desactivar y reactivar. Lo usan Empleados, Servicios y Métodos de pago.
    Agrega dos direcciones nuevas a la API:
        /api/<modulo>/<id>/desactivar/
        /api/<modulo>/<id>/reactivar/
    En la lista del módulo se siguen viendo los inactivos (si no, no habría forma de
    reactivarlos). En los formularios de reservas y pagos solo aparecen los activos.
    """

    def validar_desactivacion(self, objeto):
        """
        Acá cada módulo dice cuándo NO se puede desactivar (por ejemplo, un servicio
        que está en una reserva que todavía no se hizo). Devuelve el mensaje para el
        usuario, o nada si se puede.
        """
        return None

    # Botón "Desactivar" de la lista
    @action(detail=True, methods=['post'], url_path='desactivar')
    def desactivar(self, request, pk=None):
        objeto = self.get_object()
        # Si ya estaba desactivado no hay nada que hacer
        if not objeto.activo:
            return Response({'detail': f'"{objeto}" ya está desactivado.'}, status=status.HTTP_409_CONFLICT)
        # Preguntamos si se puede; si no, mostramos el motivo
        motivo = self.validar_desactivacion(objeto)
        if motivo:
            return Response({'detail': motivo}, status=status.HTTP_409_CONFLICT)
        objeto.desactivar()
        # Devolvemos el registro ya actualizado, para que la pantalla lo muestre como Inactivo
        return Response(self.get_serializer(objeto).data)

    # Botón "Reactivar" de la lista (aparece solo en los que están inactivos)
    @action(detail=True, methods=['post'], url_path='reactivar')
    def reactivar(self, request, pk=None):
        objeto = self.get_object()
        # Si ya estaba activo no hay nada que hacer
        if objeto.activo:
            return Response({'detail': f'"{objeto}" ya está activo.'}, status=status.HTTP_409_CONFLICT)
        objeto.reactivar()
        return Response(self.get_serializer(objeto).data)
