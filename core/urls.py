# URLs principales del proyecto:
#   /admin/ -> panel de administración que trae Django (para revisar las tablas a mano)
#   /api/   -> la API que usa el frontend en React (ver infinito_sonido/api_urls.py)
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('infinito_sonido.api_urls')),
]