# Cambio de baja lógica a baja física: ahora eliminar borra el registro de la base,
# salvo que tenga algo asociado (está explicado en baja_logica.py).
#
# Qué cambia en la base de datos:
#   - A Sueldos, Puestos, Horarios, Perfiles, Permisos, Tipos y Estados de equipo, Equipos
#     y Clientes se les sacan las columnas activo y fecha_baja, porque ya no se dan de
#     baja: se eliminan.
#   - Empleados, Servicios y Métodos de pago las siguen teniendo, porque se pueden desactivar.
#   - Pagos también las sigue teniendo (activo en 0 es "anulado") y se le agregan dos
#     columnas: el motivo de la anulación y el usuario que lo anuló.
#   - En cuatro tablas se cambia CASCADE por PROTECT, para que no se pueda eliminar un
#     puesto, un horario o un permiso que está asignado, ni un servicio que está en reservas.
#
# Qué pasa con lo que ya estaba dado de baja antes de este cambio:
#   - Si no tiene nada asociado, se elimina de verdad (era lo que el usuario había pedido).
#   - Si tiene algo asociado no se puede eliminar, así que vuelve a aparecer en el sistema.
#     Con los permisos hay una diferencia: quedan deshabilitados, para que no le vuelvan
#     a dar acceso a nadie sin que nos demos cuenta.

from django.db import migrations, models, transaction
from django.db.models.deletion import ProtectedError
import django.db.models.deletion

# Las tablas que pasan a baja física. Están en este orden a propósito: primero van las
# que usan a otras. Por ejemplo, puestos va antes que sueldos, porque mientras exista el
# puesto no se puede eliminar su sueldo.
MODELOS_BAJA_FISICA = [
    'clientes', 'equipos', 'tipo_equipos', 'estado_equipos', 'puestos', 'sueldos',
    'horarios', 'perfiles', 'permisos',
]


# Recorre todo lo que estaba dado de baja y trata de eliminarlo de verdad
def limpiar_dados_de_baja(apps, schema_editor):
    for nombre in MODELOS_BAJA_FISICA:
        Modelo = apps.get_model('infinito_sonido', nombre)
        # Solo los que estaban dados de baja
        for objeto in Modelo.objects.filter(activo=False):
            try:
                # Cada uno se borra por separado: si uno no se puede borrar, no afecta
                # a los que ya se borraron
                with transaction.atomic():
                    objeto.delete()
            except ProtectedError:
                # No se pudo porque tiene algo asociado: se queda, y va a volver a
                # aparecer en el sistema. Si es un permiso, lo dejamos deshabilitado
                if nombre == 'permisos':
                    objeto.estado_permiso = False
                    objeto.save(update_fields=['estado_permiso'])


# Hace que la columna motivo_anulacion arranque vacía si no se le manda nada. Sin esto,
# los datos de prueba que cargamos a mano (datos_de_prueba.txt y los scripts de
# scripts_bd/) darían error por no traer esa columna. Es lo mismo que se hizo en la
# migración 0023 con "activo".
def default_en_la_base(apps, schema_editor):
    # Solo hace falta en MySQL, que es la base que usa el proyecto
    if schema_editor.connection.vendor != 'mysql':
        return
    tabla = apps.get_model('infinito_sonido', 'pagos')._meta.db_table
    schema_editor.execute(f"ALTER TABLE `{tabla}` ALTER COLUMN `motivo_anulacion` SET DEFAULT ''")


# Arma la lista de columnas a sacar: activo y fecha_baja de cada una de las tablas de arriba
quitar_columnas = []
for modelo in MODELOS_BAJA_FISICA:
    quitar_columnas.append(migrations.RemoveField(model_name=modelo, name='activo'))
    quitar_columnas.append(migrations.RemoveField(model_name=modelo, name='fecha_baja'))


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0023_baja_logica'),
    ]

    operations = [
        # 1) Las cuatro relaciones que pasan a PROTECT. Van primero porque la limpieza del
        #    paso 3 las necesita: sin esto, al eliminar un puesto dado de baja se borrarían
        #    también los empleados que lo tenían asignado
        migrations.AlterField(
            model_name='puestos_x_empleados', name='id_puesto',
            field=models.ForeignKey(db_column='id_puesto', on_delete=django.db.models.deletion.PROTECT, to='infinito_sonido.puestos'),
        ),
        migrations.AlterField(
            model_name='horarios_x_empleados', name='id_horario',
            field=models.ForeignKey(db_column='id_horario', on_delete=django.db.models.deletion.PROTECT, to='infinito_sonido.horarios'),
        ),
        migrations.AlterField(
            model_name='permisos_x_perfiles', name='id_permiso',
            field=models.ForeignKey(db_column='id_permiso', on_delete=django.db.models.deletion.PROTECT, to='infinito_sonido.permisos'),
        ),
        migrations.AlterField(
            model_name='reservas_x_servicios', name='id_servicio',
            field=models.ForeignKey(db_column='id_servicio', on_delete=django.db.models.deletion.PROTECT, to='infinito_sonido.servicios'),
        ),

        # 2) Las dos columnas nuevas de Pagos para la anulación: el motivo y quién lo anuló
        migrations.AddField(
            model_name='pagos', name='motivo_anulacion',
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name='pagos', name='id_usuario_anulacion',
            field=models.ForeignKey(
                blank=True, null=True, db_column='id_usuario_anulacion',
                on_delete=django.db.models.deletion.PROTECT,
                related_name='pagos_anulados', to='infinito_sonido.usuarios',
            ),
        ),
        # Lleva atomic=False porque MySQL no deja cambiar una tabla de otra forma
        migrations.RunPython(default_en_la_base, migrations.RunPython.noop, atomic=False),

        # 3) Se elimina de verdad lo que estaba dado de baja y no tiene nada asociado
        migrations.RunPython(limpiar_dados_de_baja, migrations.RunPython.noop),

        # 4) Por último se sacan las columnas activo y fecha_baja, que ya no se usan
        *quitar_columnas,
    ]
