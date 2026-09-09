from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import api

router = DefaultRouter()
router.register('equipos', api.EquiposViewSet, basename='api-equipos')
router.register('tipo-equipos', api.TipoEquiposViewSet, basename='api-tipo-equipos')
router.register('estado-equipos', api.EstadoEquiposViewSet, basename='api-estado-equipos')
router.register('perfiles', api.PerfilesViewSet, basename='api-perfiles')
router.register('permisos', api.PermisosViewSet, basename='api-permisos')
router.register('usuarios', api.UsuariosViewSet, basename='api-usuarios')
router.register('clientes', api.ClientesViewSet, basename='api-clientes')
router.register('empleados', api.EmpleadosViewSet, basename='api-empleados')
router.register('servicios', api.ServiciosViewSet, basename='api-servicios')
router.register('reservas', api.ReservasViewSet, basename='api-reservas')

urlpatterns = [
    path('login/', api.LoginView.as_view(), name='api_login'),
    path('logout/', api.LogoutView.as_view(), name='api_logout'),
    path('me/', api.MeView.as_view(), name='api_me'),
    path('dashboard/resumen/', api.DashboardResumenView.as_view(), name='api_dashboard_resumen'),
    path('', include(router.urls)),
]
