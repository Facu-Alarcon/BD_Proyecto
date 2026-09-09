# Generated manually siguiendo el estilo de las migraciones anteriores

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0005_permisos_permisos_x_perfiles_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='SesionToken',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('token', models.CharField(db_index=True, max_length=64, unique=True)),
                ('creado', models.DateTimeField(auto_now_add=True)),
                ('id_usuario', models.ForeignKey(db_column='id_usuario', on_delete=django.db.models.deletion.CASCADE, to='infinito_sonido.usuarios')),
            ],
            options={
                'verbose_name': 'Sesión (token)',
                'verbose_name_plural': 'Sesiones (tokens)',
            },
        ),
    ]
