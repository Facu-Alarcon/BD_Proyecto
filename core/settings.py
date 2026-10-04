"""
Configuración del proyecto Django 'core'.
Generado para Django 4.2 y adaptado para conectarse a MySQL en Docker.
"""
import os
from pathlib import Path

# Carpeta raíz del proyecto
BASE_DIR = Path(__file__).resolve().parent.parent

# AVISO DE SEGURIDAD: en producción esta clave debe ser secreta.
SECRET_KEY = 'django-insecure-cambia-esta-clave-en-produccion'

# AVISO DE SEGURIDAD: no usar DEBUG=True en producción.
DEBUG = True

# Hosts permitidos. '*' acepta cualquiera (válido solo para desarrollo).
ALLOWED_HOSTS = ['*']


# --- Aplicaciones instaladas ---
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Terceros:
    'rest_framework',
    'corsheaders',
    # Nuestra app:
    'infinito_sonido',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# --- API (React consume esto desde otro puerto/origen) ---
# Vite prueba 5173 y si está ocupado sigue con 5174, 5175, etc.,
# así que permitimos cualquier puerto local en vez de fijar uno solo.
CORS_ALLOWED_ORIGIN_REGEXES = [
    r'^http://localhost:\d+$',
    r'^http://127\.0\.0\.1:\d+$',
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'infinito_sonido.authentication.TokenUsuarioAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'


# --- Base de datos: MySQL ---
# Los valores se leen de las variables de entorno definidas en docker-compose.yml.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('DB_NAME', 'escuela'),
        'USER': os.environ.get('DB_USER', 'escuela_user'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'escuela_pass'),
        'HOST': os.environ.get('DB_HOST', 'db'),
        'PORT': os.environ.get('DB_PORT', '3306'),
        'OPTIONS': {
            'charset': 'utf8mb4',
        },
    }
}


# --- Validadores de contraseña ---
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]


# --- Internacionalización ---
LANGUAGE_CODE = 'es-ar'
TIME_ZONE = 'America/Argentina/Buenos_Aires'
USE_I18N = True
USE_TZ = True


# --- Archivos estáticos (CSS, JavaScript, imágenes) ---
# core/settings.py

STATIC_URL = 'static/'
STATICFILES_DIRS = [
    BASE_DIR / 'infinito_sonido' / 'static',
]
# Tipo de clave primaria por defecto
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# --- Envío de mails (contraseña temporal de los usuarios nuevos) ---
# Se manda desde una cuenta de Gmail usando una "contraseña de aplicación"
# (no la contraseña normal de la cuenta). Los datos van en el archivo .env:
#   EMAIL_HOST_USER=cuenta@gmail.com
#   EMAIL_HOST_PASSWORD=la contraseña de aplicación de 16 letras
# Si no están cargados, los mails no se envían: se escriben en la consola del
# contenedor web (docker compose logs web) y el sistema le muestra la contraseña
# temporal al administrador en pantalla. Así se puede probar sin configurar nada.
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '').replace(' ', '')

if EMAIL_HOST_USER and EMAIL_HOST_PASSWORD:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = 'smtp.gmail.com'
    EMAIL_PORT = 587
    EMAIL_USE_TLS = True
    EMAIL_TIMEOUT = 15
else:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

DEFAULT_FROM_EMAIL = f'Infinito Sonido e Iluminación <{EMAIL_HOST_USER or "no-responder@infinito.local"}>'

# Para saber desde el código si los mails salen de verdad o solo a la consola
EMAIL_CONFIGURADO = bool(EMAIL_HOST_USER and EMAIL_HOST_PASSWORD)
