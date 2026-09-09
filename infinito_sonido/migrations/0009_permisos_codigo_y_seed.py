# Generado a mano: agrega el campo 'codigo' (clave interna estable que usa
# el backend para decidir accesos, ver infinito_sonido/permissions.py),
# siembra un permiso "ver_<modulo>" y "gestionar_<modulo>" por cada módulo
# real del sistema, y se los asigna todos al perfil "Administrador" (si
# existe) para no dejar sin acceso al usuario admin actual.

from django.db import migrations, models
from django.utils.text import slugify

MODULOS = {
    'equipos': 'Equipos',
    'clientes': 'Clientes',
    'empleados': 'Empleados',
    'servicios': 'Servicios',
    'reservas': 'Reservas',
    'perfiles': 'Perfiles',
    'permisos': 'Permisos',
    'usuarios': 'Usuarios',
}


def poblar_codigos_y_permisos(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    # Permisos que ya existieran cargados a mano: les generamos un código
    # derivado del nombre para no perderlos (no van a activar ningún
    # control de acceso real, salvo que coincidan con uno de los de abajo).
    usados = set()
    for permiso in Permisos.objects.filter(codigo=''):
        base = slugify(permiso.nombre_permiso).replace('-', '_')[:55] or f'permiso_{permiso.pk}'
        codigo = base
        i = 2
        while codigo in usados or Permisos.objects.filter(codigo=codigo).exists():
            codigo = f'{base}_{i}'
            i += 1
        usados.add(codigo)
        permiso.codigo = codigo
        permiso.save(update_fields=['codigo'])

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
        ('infinito_sonido', '0008_estado_equipos'),
    ]

    operations = [
        migrations.AddField(
            model_name='permisos',
            name='codigo',
            field=models.SlugField(blank=True, default='', max_length=60),
        ),
        migrations.RunPython(poblar_codigos_y_permisos, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='permisos',
            name='codigo',
            field=models.SlugField(blank=True, max_length=60, unique=True),
        ),
    ]
