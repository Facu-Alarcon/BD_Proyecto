from rest_framework.permissions import SAFE_METHODS, BasePermission

from .models import Permisos_x_Perfiles


def permisos_del_usuario(usuario):
    """
    Códigos de permiso habilitados para el perfil del usuario logueado.
    Un permiso desactivado globalmente (estado_permiso=False) no cuenta,
    aunque siga "asignado" al perfil.
    """
    if not getattr(usuario, 'id_perfil_id', None):
        return set()
    return set(
        Permisos_x_Perfiles.objects.filter(
            id_perfil_id=usuario.id_perfil_id,
            id_permiso__estado_permiso=True,
        ).values_list('id_permiso__codigo', flat=True)
    )


def permiso_modulo(modulo):
    """
    Fábrica de permission_classes de DRF: exige 'ver_<modulo>' para
    lectura (GET/HEAD/OPTIONS) y 'gestionar_<modulo>' para escritura
    (POST/PUT/PATCH/DELETE). 'gestionar_<modulo>' también habilita lectura.
    """
    codigo_ver = f'ver_{modulo}'
    codigo_gestionar = f'gestionar_{modulo}'

    class _PermisoModulo(BasePermission):
        message = f'Tu perfil no tiene acceso a "{modulo}".'

        def has_permission(self, request, view):
            usuario = request.user
            if not getattr(usuario, 'is_authenticated', False):
                return False
            codigos = permisos_del_usuario(usuario)
            if codigo_gestionar in codigos:
                return True
            if request.method in SAFE_METHODS:
                return codigo_ver in codigos
            return False

    _PermisoModulo.__name__ = f'PermisoModulo_{modulo}'
    return _PermisoModulo
