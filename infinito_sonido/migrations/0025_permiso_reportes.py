# Reportes: crea el permiso "Ver Reportes" y se lo da al perfil Administrador
# (igual que se hizo con los otros permisos en las migraciones 0009, 0011, 0013 y 0018).
# Solo hay permiso de ver, porque los reportes no cargan ni modifican nada: solo se consultan.
# No se crea ninguna tabla: los reportes se calculan con los datos que ya existen.

from django.db import migrations


# Crea el permiso ver_reportes y se lo asigna a los perfiles de administrador
def crear_permiso(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    # get_or_create: si el permiso ya existe no lo crea de nuevo
    permiso, _ = Permisos.objects.get_or_create(
        codigo='ver_reportes',
        defaults={
            'nombre_permiso': 'Ver Reportes',
            'descripcion_permiso': 'Permite ver los reportes del sistema (uso de equipos, etc.).',
        },
    )
    for perfil in Perfiles.objects.filter(tipo_perfil__icontains='admin'):
        Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0024_baja_fisica'),
    ]

    operations = [
        migrations.RunPython(crear_permiso, migrations.RunPython.noop),
    ]
