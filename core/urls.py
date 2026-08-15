"""
Rutas principales del proyecto.
"""
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    # Panel de administración de Django
    path('admin/', admin.site.urls),
    # Rutas de la app 'inifinito sonido' (página de inicio)
    path('', include('infinito.urls')),
]
