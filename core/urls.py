from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('infinito_sonido.api_urls')),
    path('', include('infinito_sonido.urls')),
]