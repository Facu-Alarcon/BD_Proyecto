from django.urls import path

from . import views

#Investigar

urlpatterns = [
    path('', views.lista_alumnos, name='lista_alumnos'),
]
