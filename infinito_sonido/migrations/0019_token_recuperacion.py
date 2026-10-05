# "Olvidé mi contraseña": tabla con los links de recuperación que se mandan por mail.
# Cada link vence a los 30 minutos y se usa una sola vez (ver Token_Recuperacion en models.py).

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0018_registro_actividad'),
    ]

    operations = [
        migrations.CreateModel(
            name='Token_Recuperacion',
            fields=[
                ('id_token', models.AutoField(primary_key=True, serialize=False)),
                ('token_hash', models.CharField(max_length=64, unique=True)),
                ('creado', models.DateTimeField(auto_now_add=True)),
                ('expira', models.DateTimeField()),
                ('usado', models.BooleanField(default=False)),
                ('id_usuario', models.ForeignKey(db_column='id_usuario', on_delete=django.db.models.deletion.CASCADE, to='infinito_sonido.usuarios')),
            ],
            options={
                'verbose_name': 'Token de recuperación',
                'verbose_name_plural': 'Tokens de recuperación',
            },
        ),
    ]
