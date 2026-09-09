from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .models import SesionToken


class TokenUsuarioAuthentication(BaseAuthentication):
    """
    Autenticación por token contra el modelo Usuarios (no contra auth.User).
    El frontend manda: Authorization: Token <token>
    """
    keyword = 'Token'

    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return None

        partes = auth_header.split()
        if len(partes) != 2 or partes[0] != self.keyword:
            return None

        token_str = partes[1]
        try:
            sesion = SesionToken.objects.select_related('id_usuario', 'id_usuario__id_perfil').get(token=token_str)
        except SesionToken.DoesNotExist:
            raise AuthenticationFailed('Token inválido o sesión expirada.')

        return (sesion.id_usuario, sesion)

    def authenticate_header(self, request):
        return self.keyword
