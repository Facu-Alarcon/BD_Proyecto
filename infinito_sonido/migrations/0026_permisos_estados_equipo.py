# Estados de equipo pasa a ser un módulo aparte (antes los estados se agregaban con el
# botón "+" del formulario de Equipos).
#
# Esta migración crea sus dos permisos, igual que los demás módulos:
#   - Ver Estados de equipo
#   - Gestionar Estados de equipo
# Se los da al perfil Administrador. Además, a los perfiles que ya podían gestionar
# Equipos les da los dos, para que no pierdan lo que podían hacer hasta ahora
# (antes, con el permiso de Equipos alcanzaba para agregar un estado).
# No se crea ninguna tabla: la tabla de estados ya existía.

from django.db import migrations


def crear_permisos(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    # get_or_create: si el permiso ya existe no lo crea de nuevo
    ver, _ = Permisos.objects.get_or_create(
        codigo='ver_estados_equipo',
        defaults={
            'nombre_permiso': 'Ver Estados de equipo',
            'descripcion_permiso': 'Permite ver el listado de Estados de equipo.',
        },
    )
    gestionar, _ = Permisos.objects.get_or_create(
        codigo='gestionar_estados_equipo',
        defaults={
            'nombre_permiso': 'Gestionar Estados de equipo',
            'descripcion_permiso': 'Permite crear, editar y eliminar en Estados de equipo.',
        },
    )

    # Los perfiles que reciben los permisos nuevos: los administradores...
    perfiles = set(Perfiles.objects.filter(tipo_perfil__icontains='admin'))
    # ...y los que ya tenían "Gestionar Equipos"
    for asignacion in Permisos_x_Perfiles.objects.filter(id_permiso__codigo='gestionar_equipos').select_related('id_perfil'):
        perfiles.add(asignacion.id_perfil)

    for perfil in perfiles:
        for permiso in (ver, gestionar):
            Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0025_permiso_reportes'),
    ]

    operations = [
        migrations.RunPython(crear_permisos, migrations.RunPython.noop),
    ]
