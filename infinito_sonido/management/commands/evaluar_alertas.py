# Control diario de las alertas (Parcial 2, módulo M3).
# Se corre con:  python manage.py evaluar_alertas
# El contenedor web lo ejecuta solo al arrancar y después cada 24 horas (ver docker-compose.yml).
# También se puede correr a mano en la demo para ver aparecer los avisos.

from django.core.management.base import BaseCommand
from django.utils import timezone

from infinito_sonido.models import Notificacion
from infinito_sonido.notificaciones import evaluar_todas


class Command(BaseCommand):
    help = 'Revisa las reglas de alerta de todas las reservas y guarda los avisos nuevos.'

    def handle(self, *args, **options):
        resultado = evaluar_todas()
        nombres = dict(Notificacion.TIPO_CHOICES)
        self.stdout.write(f'Control de alertas del {timezone.localtime():%d/%m/%Y %H:%M}')
        for tipo, nuevos in resultado.items():
            self.stdout.write(f'  {nombres[tipo]}: {nuevos} aviso(s) nuevo(s)')
        self.stdout.write(self.style.SUCCESS(f'Listo: {sum(resultado.values())} aviso(s) nuevo(s) en total.'))
