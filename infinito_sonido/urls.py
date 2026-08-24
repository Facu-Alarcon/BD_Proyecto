from django.urls import path
from . import views

urlpatterns = [
    # Inicio / Landing
    path('', views.inicio, name='inicio'),
    
    # Módulo Equipos
    path('equipos/', views.listaEquipos, name='lista_equipos'),
    path('equipos/crear/', views.createEquipos, name='createEquipos'),

    #Modulo Servicio

    #Modulo Clientes

    #Modulo Pagos
]