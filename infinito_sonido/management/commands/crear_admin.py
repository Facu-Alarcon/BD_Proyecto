# Comando de consola: python manage.py crear_admin
# Crea (o actualiza) el perfil Administrador con todos los permisos y un usuario admin.
# Django encuentra solo los comandos que están en management/commands/.
#
# OJO: desde la migración 0017 cada usuario tiene que estar vinculado a un empleado
# (id_empleado es obligatorio) y este comando todavía crea el usuario sin empleado,
# así que hoy falla al crear un admin nuevo. Para crear el admin usar datos_de_prueba.txt
# o los scripts de scripts_bd/ hasta que se actualice este comando.
from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand

from infinito_sonido.models import Perfiles, Permisos, Permisos_x_Perfiles, Usuarios


class Command(BaseCommand):
    help = (
        'Crea (o actualiza) un usuario administrador con TODOS los permisos '
        'asignados, para no tener que cargarlo a mano en cada base local. '
        'Uso: python manage.py crear_admin '
        '[--usuario admin] [--password Admin1234] [--perfil Administrador]'
    )

    # Opciones que se le pueden pasar al comando (todas tienen un valor por defecto)
    def add_arguments(self, parser):
        parser.add_argument('--usuario', default='admin', help='Nombre de usuario (default: admin)')
        parser.add_argument('--password', default='Admin1234', help='Contraseña (default: Admin1234)')
        parser.add_argument('--perfil', default='Administrador', help='Nombre del perfil (default: Administrador)')

    # Lo que hace el comando al ejecutarse
    def handle(self, *args, **options):
        nombre_usuario = options['usuario']
        password = options['password']
        nombre_perfil = options['perfil']

        # get_or_create: si el perfil ya existe lo usa, si no lo crea (así se puede correr varias veces)
        perfil, creado_perfil = Perfiles.objects.get_or_create(tipo_perfil=nombre_perfil)
        if creado_perfil:
            self.stdout.write(self.style.SUCCESS(f'Perfil "{nombre_perfil}" creado.'))
        else:
            self.stdout.write(f'Perfil "{nombre_perfil}" ya existía, lo reutilizo.')

        # Le asigna al perfil todos los permisos que existan
        permisos = Permisos.objects.all()
        nuevos = 0
        for permiso in permisos:
            _, creado = Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)
            if creado:
                nuevos += 1
        self.stdout.write(f'Permisos asignados al perfil: {permisos.count()} en total ({nuevos} nuevos).')

        # Crea el usuario o, si ya existía, le pone el perfil y la contraseña de nuevo
        usuario, creado_usuario = Usuarios.objects.get_or_create(
            usuario=nombre_usuario,
            defaults={'id_perfil': perfil, 'contraseña': make_password(password)},
        )
        if creado_usuario:
            self.stdout.write(self.style.SUCCESS(f'Usuario "{nombre_usuario}" creado.'))
        else:
            usuario.id_perfil = perfil
            usuario.contraseña = make_password(password)
            usuario.save()
            self.stdout.write(self.style.WARNING(f'Usuario "{nombre_usuario}" ya existía: le actualicé perfil y contraseña.'))

        self.stdout.write(self.style.SUCCESS(
            f'\nListo. Entrá al frontend con usuario "{nombre_usuario}" y la contraseña que hayas usado.'
        ))
