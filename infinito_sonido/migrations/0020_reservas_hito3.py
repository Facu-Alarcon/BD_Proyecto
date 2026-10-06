# Hito 3 - Proceso de Reserva (paso 1: cambios en la base de datos).
#
# Reservas (cabecera):
#   - fecha_registro: cuándo se cargó la reserva (automática).
#   - id_usuario_registro: usuario logueado que la registró (automático).
#   - fecha_anulacion, motivo_anulacion, id_usuario_anulacion: se completan al anular.
#   - El estado "CANCELADA" pasa a llamarse "ANULADA" (las reservas ya no se borran, se anulan).
# Reservas_x_Servicios (detalle):
#   - precio_servicio: precio del servicio en el momento de reservar.
# Permisos:
#   - "Anular reservas" (anular_reservas), asignado al Administrador. Es la acción
#     restringida por perfil que pide el hito (un perfil puede registrar pero no anular).
#
# Las reservas que ya existían quedan sin fecha de registro ni usuario (no se sabe
# quién ni cuándo las cargó), y a sus servicios se les copia el precio actual.

from django.db import migrations, models
import django.core.validators
import django.db.models.deletion


# Al agregar una columna con auto_now_add, Django les pone a las filas que ya existían la
# fecha del momento de la migración. Eso es falso (no se sabe cuándo se cargaron), así que
# a las reservas viejas se les deja la fecha de registro vacía
def vaciar_fecha_registro_viejas(apps, schema_editor):
    Reservas = apps.get_model('infinito_sonido', 'Reservas')
    Reservas.objects.update(fecha_registro=None)


# A cada servicio ya reservado le copia el precio que tiene hoy el servicio
def copiar_precios_actuales(apps, schema_editor):
    Reservas_x_Servicios = apps.get_model('infinito_sonido', 'Reservas_x_Servicios')
    for detalle in Reservas_x_Servicios.objects.select_related('id_servicio'):
        detalle.precio_servicio = detalle.id_servicio.precio_servicio
        detalle.save(update_fields=['precio_servicio'])


# Las reservas que estaban "Canceladas" pasan a "Anuladas", con un motivo que lo aclara
def cancelada_a_anulada(apps, schema_editor):
    Reservas = apps.get_model('infinito_sonido', 'Reservas')
    Reservas.objects.filter(estado_reserva='CANCELADA').update(
        estado_reserva='ANULADA',
        motivo_anulacion='Cancelada antes de que existiera la anulación formal.',
    )


# Para deshacer la migración: vuelve a dejarlas como "Canceladas"
def anulada_a_cancelada(apps, schema_editor):
    Reservas = apps.get_model('infinito_sonido', 'Reservas')
    Reservas.objects.filter(estado_reserva='ANULADA').update(estado_reserva='CANCELADA')


# Crea el permiso "Anular reservas" y se lo da a los perfiles de administrador
def crear_permiso_anular(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    permiso, _ = Permisos.objects.get_or_create(
        codigo='anular_reservas',
        defaults={
            'nombre_permiso': 'Anular Reservas',
            'descripcion_permiso': 'Permite anular una reserva indicando el motivo. La reserva no se borra: queda como Anulada.',
        },
    )
    for perfil in Perfiles.objects.filter(tipo_perfil__icontains='admin'):
        Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0019_token_recuperacion'),
    ]

    operations = [
        # ---------- Reservas: datos automáticos del registro ----------
        migrations.AddField(
            model_name='reservas',
            name='fecha_registro',
            field=models.DateTimeField(auto_now_add=True, null=True),
        ),
        migrations.RunPython(vaciar_fecha_registro_viejas, migrations.RunPython.noop),
        migrations.AddField(
            model_name='reservas',
            name='id_usuario_registro',
            field=models.ForeignKey(
                blank=True, db_column='id_usuario_registro', null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='reservas_registradas', to='infinito_sonido.usuarios',
            ),
        ),

        # ---------- Reservas: anulación ----------
        migrations.AddField(
            model_name='reservas',
            name='fecha_anulacion',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='reservas',
            name='motivo_anulacion',
            field=models.CharField(blank=True, default='', max_length=255),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='reservas',
            name='id_usuario_anulacion',
            field=models.ForeignKey(
                blank=True, db_column='id_usuario_anulacion', null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='reservas_anuladas', to='infinito_sonido.usuarios',
            ),
        ),
        migrations.AlterField(
            model_name='reservas',
            name='estado_reserva',
            field=models.CharField(
                choices=[('PENDIENTE', 'Pendiente'), ('CONFIRMADA', 'Confirmada'), ('FINALIZADA', 'Finalizada'), ('ANULADA', 'Anulada')],
                default='PENDIENTE', max_length=20,
            ),
        ),
        migrations.RunPython(cancelada_a_anulada, anulada_a_cancelada),

        # ---------- Detalle: precio del servicio al reservar ----------
        # Primero se crea permitiendo vacío, se llena con el precio actual y después pasa a obligatorio
        migrations.AddField(
            model_name='reservas_x_servicios',
            name='precio_servicio',
            field=models.FloatField(null=True),
        ),
        migrations.RunPython(copiar_precios_actuales, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='reservas_x_servicios',
            name='precio_servicio',
            field=models.FloatField(validators=[django.core.validators.MinValueValidator(0.0)]),
        ),

        # ---------- Permiso nuevo ----------
        migrations.RunPython(crear_permiso_anular, migrations.RunPython.noop),
    ]
