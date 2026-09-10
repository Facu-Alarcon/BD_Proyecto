# Generado a mano: siembra ver_puestos/gestionar_puestos y
# ver_sueldos/gestionar_sueldos (mismo patrón que la migración 0009),
# y se los asigna al perfil "Administrador" si existe.

from django.db import migrations

MODULOS = {
    'puestos': 'Puestos',
    'sueldos': 'Sueldos',
}


def poblar_permisos(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    nuevos_por_modulo = {}
    for modulo, nombre_modulo in MODULOS.items():
        ver, _ = Permisos.objects.get_or_create(
            codigo=f'ver_{modulo}',
            defaults={
                'nombre_permiso': f'Ver {nombre_modulo}',
                'descripcion_permiso': f'Permite ver el listado de {nombre_modulo}.',
            },
        )
        gestionar, _ = Permisos.objects.get_or_create(
            codigo=f'gestionar_{modulo}',
            defaults={
                'nombre_permiso': f'Gestionar {nombre_modulo}',
                'descripcion_permiso': f'Permite crear, editar y eliminar en {nombre_modulo}.',
            },
        )
        nuevos_por_modulo[modulo] = [ver, gestionar]

    admin_perfiles = Perfiles.objects.filter(tipo_perfil__icontains='admin')
    for perfil in admin_perfiles:
        for permisos_modulo in nuevos_por_modulo.values():
            for permiso in permisos_modulo:
                Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0010_alter_clientes_telefono_cliente_and_more'),
    ]

    operations = [
        migrations.RunPython(poblar_permisos, migrations.RunPython.noop),
    ]
