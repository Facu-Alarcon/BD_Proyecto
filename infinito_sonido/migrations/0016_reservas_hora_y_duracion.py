# Generado a mano: hasta ahora la hora de la reserva se guardaba en
# duracion_evento. Acá se agrega la columna hora_evento, se le pasa la hora
# que ya tenían las reservas cargadas y duracion_evento queda para la
# duración real del evento (vacía en las reservas viejas).

from django.db import migrations, models


# Copia la hora que estaba en duracion_evento a la columna nueva y deja la duración vacía
def separar_hora_y_duracion(apps, schema_editor):
    Reservas = apps.get_model('infinito_sonido', 'Reservas')
    for reserva in Reservas.objects.all():
        reserva.hora_evento = reserva.duracion_evento
        reserva.duracion_evento = None
        reserva.save(update_fields=['hora_evento', 'duracion_evento'])


# Por si se deshace la migración: vuelve a poner la hora en duracion_evento
def juntar_hora_y_duracion(apps, schema_editor):
    Reservas = apps.get_model('infinito_sonido', 'Reservas')
    for reserva in Reservas.objects.all():
        reserva.duracion_evento = reserva.hora_evento
        reserva.save(update_fields=['duracion_evento'])


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0015_alter_pagos_monto'),
    ]

    operations = [
        # Primero se crea la columna permitiendo vacío, porque las reservas existentes todavía no tienen hora
        migrations.AddField(
            model_name='reservas',
            name='hora_evento',
            field=models.TimeField(null=True),
        ),
        # La duración pasa a aceptar vacío para las reservas viejas
        migrations.AlterField(
            model_name='reservas',
            name='duracion_evento',
            field=models.TimeField(blank=True, null=True),
        ),
        migrations.RunPython(separar_hora_y_duracion, juntar_hora_y_duracion),
        # Ya con todas las horas copiadas, la hora pasa a ser obligatoria
        migrations.AlterField(
            model_name='reservas',
            name='hora_evento',
            field=models.TimeField(),
        ),
    ]
