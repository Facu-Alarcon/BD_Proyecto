from django.apps import AppConfig

# Configuración de la app "infinito_sonido" (la app de Django donde está todo el sistema).
# Django la usa para registrar la app: el 'name' tiene que coincidir con el nombre de la
# carpeta y con lo que figura en INSTALLED_APPS de core/settings.py.
# default_auto_field es el tipo de clave primaria que se usaría si un modelo no la definiera
# (en nuestros modelos siempre la definimos a mano con AutoField).
class Infinito_SonidoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'infinito_sonido'
