from django.urls import path, include
from django.contrib import admin
from.import views
urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('infinito_sonido.urls')),
    path('',views.inicio, name='inicio'),
    path('equipos/', views.equipo_list, name='equipo_list'),
    path('equipos/nuevo/', views.equipo_create, name='equipo_create'),
    path('equipos/<int:pk>/editar/', views.equipo_update, name='equipo_update'),
    path('equipos/<int:pk>/eliminar/', views.equipo_delete, name='equipo_delete'),
    #!Agregado por Aye Tipo_equipos 
    path('tipoequipos/', views.tipoequipo_list, name='tipoequipo_list'),
    path('tipoequipos/nuevo/', views.tipoequipo_create, name='tipoequipo_create'),
    path('tipoequipos/<int:pk>/editar/', views.tipoequipo_update, name='tipoequipo_update'),
    path('tipoequipos/<int:pk>/eliminar/', views.tipoequipo_delete, name='tipoequipo_delete'),
]
