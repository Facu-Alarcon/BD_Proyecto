# Generated manually siguiendo el estilo de las migraciones anteriores
# (agrega Gestionar/Asignar Permisos y ajusta el campo de contraseña)

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0004_clientes_detalles_de_pago_detalles_reservas_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='usuarios',
            name='contraseña',
            field=models.CharField(max_length=128),
        ),
        migrations.CreateModel(
            name='Permisos',
            fields=[
                ('id_permiso', models.AutoField(primary_key=True, serialize=False)),
                ('nombre_permiso', models.CharField(max_length=50, unique=True)),
                ('descripcion_permiso', models.CharField(blank=True, max_length=150)),
                ('estado_permiso', models.BooleanField(default=True)),
            ],
            options={
                'verbose_name': 'Permiso',
                'verbose_name_plural': 'Permisos',
            },
        ),
        migrations.CreateModel(
            name='Permisos_x_Perfiles',
            fields=[
                ('id_permiso_perfil', models.AutoField(primary_key=True, serialize=False)),
                ('id_perfil', models.ForeignKey(db_column='id_perfil', on_delete=django.db.models.deletion.CASCADE, to='infinito_sonido.perfiles')),
                ('id_permiso', models.ForeignKey(db_column='id_permiso', on_delete=django.db.models.deletion.CASCADE, to='infinito_sonido.permisos')),
            ],
            options={
                'verbose_name': 'Permiso x Perfil',
                'verbose_name_plural': 'Permisos x Perfiles',
                'unique_together': {('id_perfil', 'id_permiso')},
            },
        ),
    ]
