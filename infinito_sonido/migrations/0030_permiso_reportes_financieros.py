# Reporte sensible (Parcial 2, módulo M2): crea el permiso "Ver Reportes Financieros" y se lo
# da solo a los perfiles de administrador (igual que en la migración 0025 con "Ver Reportes").
# Con este permiso se ve el reporte "Evolución de ingresos", que muestra la plata que entra al
# negocio. Un perfil que tiene "Ver Reportes" pero no este (ej: Encargado) ve los otros reportes
# y este no. Si después se lo quiere dar a otro perfil, se asigna desde la pantalla Perfiles.

from django.db import migrations


# Crea el permiso ver_reportes_financieros y se lo asigna a los perfiles de administrador
def crear_permiso(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    # get_or_create: si el permiso ya existe no lo crea de nuevo
    permiso, _ = Permisos.objects.get_or_create(
        codigo='ver_reportes_financieros',
        defaults={
            'nombre_permiso': 'Ver Reportes Financieros',
            'descripcion_permiso': 'Permite ver los reportes con información de ingresos del negocio (evolución de ingresos).',
        },
    )
    for perfil in Perfiles.objects.filter(tipo_perfil__icontains='admin'):
        Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0029_configuracion_inicial_y_permisos'),
    ]

    operations = [
        migrations.RunPython(crear_permiso, migrations.RunPython.noop),
    ]
