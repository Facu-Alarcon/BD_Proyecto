from django.urls import path
from . import views

urlpatterns = [
    # Inicio / Landing
    path('', views.inicio, name='inicio'),
    
    # Módulo Equipos
    path('equipos/', views.listaEquipos, name='equipo_list'),
    path('equipos/crear/', views.createEquipos, name='equipo_create'),
    path('equipos/editar/<int:id_equipo>/', views.editarEquipos, name='equipo_update'),
    path('equipos/eliminar/<int:id_equipo>/', views.eliminarEquipos, name='equipo_delete'),

    #Modulo Servicio

    #Modulo Clientes

    #Modulo Pagos

    # Módulo Perfiles
    path('perfiles/', views.listaPerfiles, name='perfil_list'),
    path('perfiles/crear/', views.crearPerfil, name='perfil_create'),
    path('perfiles/editar/<int:id_perfil>/', views.editarPerfil, name='perfil_update'),
    path('perfiles/eliminar/<int:id_perfil>/', views.eliminarPerfil, name='perfil_delete'),
    path('perfiles/<int:id_perfil>/permisos/', views.asignarPermisos, name='perfil_asignar_permisos'),

    # Módulo Permisos
    path('permisos/', views.listaPermisos, name='permiso_list'),
    path('permisos/crear/', views.crearPermiso, name='permiso_create'),
    path('permisos/editar/<int:id_permiso>/', views.editarPermiso, name='permiso_update'),
    path('permisos/eliminar/<int:id_permiso>/', views.eliminarPermiso, name='permiso_delete'),

    # Módulo Usuarios
    path('usuarios/', views.listaUsuarios, name='usuario_list'),
    path('usuarios/crear/', views.crearUsuario, name='usuario_create'),
    path('usuarios/editar/<int:id_usuario>/', views.editarUsuario, name='usuario_update'),
    path('usuarios/eliminar/<int:id_usuario>/', views.eliminarUsuario, name='usuario_delete'),
]