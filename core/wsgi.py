"""
Configuración WSGI para el proyecto core.
Expone el callable WSGI como una variable de módulo llamada 'application'.
"""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

application = get_wsgi_application()
