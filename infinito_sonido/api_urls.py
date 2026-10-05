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
router.register('sueldos', api.SueldosViewSet, basename='api-sueldos')
router.register('puestos', api.PuestosViewSet, basename='api-puestos')
router.register('horarios', api.HorariosViewSet, basename='api-horarios')
router.register('metodos-pago', api.MetodoPagosViewSet, basename='api-metodos-pago')
router.register('pagos', api.PagosViewSet, basename='api-pagos')
router.register('registro', api.RegistroActividadViewSet, basename='api-registro')

urlpatterns = [
    path('login/', api.LoginView.as_view(), name='api_login'),
    path('logout/', api.LogoutView.as_view(), name='api_logout'),
    path('me/', api.MeView.as_view(), name='api_me'),
    path('cambiar-clave/',api.CambiarClaveView.as_view(),name='api_cambiar_clave'),
    # "Olvidé mi contraseña": pedir el link por mail y usarlo para elegir una clave nueva
    path('recuperar-clave/', api.RecuperarClaveView.as_view(), name='api_recuperar_clave'),
    path('restablecer-clave/<str:token>/', api.RestablecerConLinkView.as_view(), name='api_restablecer_con_link'),
    path('dashboard/resumen/', api.DashboardResumenView.as_view(), name='api_dashboard_resumen'),
    path('', include(router.urls)),
]