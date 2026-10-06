# Cómo sabe la API quién hace cada pedido. Está configurado en settings.py
# (DEFAULT_AUTHENTICATION_CLASSES), así que se usa en todas las vistas.
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .models import SesionToken


class TokenUsuarioAuthentication(BaseAuthentication):
    """
    Autenticación por token contra el modelo Usuarios (no contra auth.User).
    El frontend manda: Authorization: Token <token>
    """
    keyword = 'Token'

    # Lee el encabezado Authorization, busca la sesión con ese token y devuelve el usuario.
    # Lo que devuelve queda en request.user (el usuario) y request.auth (la sesión).
    # Si no hay encabezado devuelve None: el pedido sigue como "no logueado" y después
    # los permisos deciden si se lo deja pasar (ej: el login sí, el resto no).
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return None

        # Tiene que venir como "Token <el token>"; si viene de otra forma se ignora
        partes = auth_header.split()
        if len(partes) != 2 or partes[0] != self.keyword:
            return None

        token_str = partes[1]
        try:
            sesion = SesionToken.objects.select_related('id_usuario', 'id_usuario__id_perfil', 'id_usuario__id_empleado').get(token=token_str)
        except SesionToken.DoesNotExist:
            raise AuthenticationFailed('Token inválido o sesión expirada.')

        return (sesion.id_usuario, sesion)

    # Lo que se manda en el encabezado WWW-Authenticate cuando se responde 401
    def authenticate_header(self, request):
        return self.keyword
