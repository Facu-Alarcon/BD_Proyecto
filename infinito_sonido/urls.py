from django.urls import path
from . import views

urlpatterns = [
    path('', views.inicio, name='inicio'),
    path('equipos/', views.listaEquipos, name='lista_equipos'),
    path('equipos/crear/', views.createEquipos, name='createEquipos'),
]