# Baja lógica en todas las tablas que se pueden "borrar" desde el sistema (ver baja_logica.py).
#
# Les agrega dos columnas:
#   - activo (por defecto 1): todos los registros que ya existían quedan activos, así que
#     nada desaparece de las pantallas al aplicar esta migración.
#   - fecha_baja (vacía): se completa cuando alguien da de baja el registro.
#
# Además le pone a la columna activo el valor por defecto 1 en la propia base de datos.
# Django no lo hace solo (pone el default solo cuando guarda desde Python), y sin esto
# los INSERT escritos a mano, como los de datos_de_prueba.txt o los scripts de scripts_bd/,
# fallarían por no mandar la columna activo.

from django.db import migrations, models

MODELOS = [
    'sueldos', 'puestos', 'empleados', 'horarios', 'perfiles', 'permisos', 'tipo_equipos',
    'estado_equipos', 'equipos', 'servicios', 'clientes', 'metodo_pagos', 'pagos',
]


def default_en_la_base(apps, schema_editor):
    # Solo en MySQL (es la base del proyecto); con otra base no hace falta
    if schema_editor.connection.vendor != 'mysql':
        return
    for modelo in MODELOS:
        tabla = apps.get_model('infinito_sonido', modelo)._meta.db_table
        schema_editor.execute(f'ALTER TABLE `{tabla}` ALTER COLUMN `activo` SET DEFAULT 1')


operaciones = []
for modelo in MODELOS:
    operaciones.append(migrations.AddField(
        model_name=modelo, name='activo', field=models.BooleanField(default=True),
    ))
    operaciones.append(migrations.AddField(
        model_name=modelo, name='fecha_baja', field=models.DateTimeField(blank=True, null=True),
    ))


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0022_usuarios_apellido_inicial'),
    ]

    operations = operaciones + [
        # atomic=False: MySQL no deja cambiar la estructura de una tabla dentro de una
        # transacción, y RunPython abre una por defecto
        migrations.RunPython(default_en_la_base, migrations.RunPython.noop, atomic=False),
    ]
