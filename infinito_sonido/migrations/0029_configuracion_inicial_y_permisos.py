# Carga los valores iniciales de las alertas (Parcial 2, módulo M3) y crea los permisos
# del módulo Configuración, igual que los demás módulos:
#   - Ver Configuración
#   - Gestionar Configuración (cambiar los parámetros y revisar las alertas en el momento)
# Se los da a los perfiles de administrador.

from django.db import migrations

# Los parámetros con los que arranca el sistema. Después se cambian desde la pantalla
# Configuración (o desde phpMyAdmin), sin tocar el código.
PARAMETROS = [
    ('DIAS_AVISO_SALDO', '7',
     'Días antes del evento en que se avisa que una reserva todavía tiene saldo pendiente.'),
    ('DIAS_AVISO_CONFIRMACION', '10',
     'Días antes del evento en que se avisa que una reserva sigue sin confirmar.'),
    ('FACTOR_MONTO_INUSUAL', '3',
     'Cuántos desvíos por encima del promedio tiene que estar el monto de una reserva para avisar que es inusual.'),
    ('MINIMO_RESERVAS_COMPARAR', '5',
     'Cuántas reservas anteriores tiene que haber como mínimo para calcular si un monto es inusual.'),
]


def cargar_datos(apps, schema_editor):
    Configuracion = apps.get_model('infinito_sonido', 'Configuracion')
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    # get_or_create: si el parámetro ya existe no se pisa el valor que tenga
    for clave, valor, descripcion in PARAMETROS:
        Configuracion.objects.get_or_create(clave=clave, defaults={'valor': valor, 'descripcion': descripcion})

    ver, _ = Permisos.objects.get_or_create(
        codigo='ver_configuracion',
        defaults={
            'nombre_permiso': 'Ver Configuración',
            'descripcion_permiso': 'Permite ver los parámetros de las alertas.',
        },
    )
    gestionar, _ = Permisos.objects.get_or_create(
        codigo='gestionar_configuracion',
        defaults={
            'nombre_permiso': 'Gestionar Configuración',
            'descripcion_permiso': 'Permite cambiar los parámetros de las alertas y revisarlas en el momento.',
        },
    )
    for perfil in Perfiles.objects.filter(tipo_perfil__icontains='admin'):
        for permiso in (ver, gestionar):
            Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0028_notificaciones_y_configuracion'),
    ]

    operations = [
        migrations.RunPython(cargar_datos, migrations.RunPython.noop),
    ]
