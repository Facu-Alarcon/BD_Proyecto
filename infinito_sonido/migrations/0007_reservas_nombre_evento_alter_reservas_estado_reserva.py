# Generated manually siguiendo el estilo de las migraciones anteriores

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0006_sesiontoken'),
    ]

    operations = [
        migrations.AddField(
            model_name='reservas',
            name='nombre_evento',
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AlterField(
            model_name='reservas',
            name='estado_reserva',
            field=models.CharField(choices=[('PENDIENTE', 'Pendiente'), ('CONFIRMADA', 'Confirmada'), ('FINALIZADA', 'Finalizada'), ('CANCELADA', 'Cancelada')], default='PENDIENTE', max_length=20),
        ),
    ]
