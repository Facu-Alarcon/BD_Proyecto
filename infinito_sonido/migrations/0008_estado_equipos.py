# Generated manually: "Estado del Equipo" pasa de ser una lista fija
# (DISPONIBLE / EN_USO / EN_REPARACION hardcodeada en el modelo) a un
# catálogo editable (Estado_Equipos), igual que Tipo_Equipos, para poder
# cargar estados nuevos desde la pantalla de Equipos.

import django.db.models.deletion
from django.db import migrations, models


def crear_estados_por_defecto(apps, schema_editor):
    Estado_Equipos = apps.get_model('infinito_sonido', 'Estado_Equipos')
    Equipos = apps.get_model('infinito_sonido', 'Equipos')

    disponible, _ = Estado_Equipos.objects.get_or_create(nombre_estadoeq='Disponible')
    Estado_Equipos.objects.get_or_create(nombre_estadoeq='En uso')
    Estado_Equipos.objects.get_or_create(nombre_estadoeq='En reparación')

    # Si ya existieran equipos cargados (viejo campo de texto), los dejamos
    # como "Disponible" por defecto para no perder filas.
    Equipos.objects.filter(id_estadoeq__isnull=True).update(id_estadoeq=disponible)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0007_reservas_nombre_evento_alter_reservas_estado_reserva'),
    ]

    operations = [
        migrations.CreateModel(
            name='Estado_Equipos',
            fields=[
                ('id_estadoeq', models.AutoField(primary_key=True, serialize=False)),
                ('nombre_estadoeq', models.CharField(max_length=50, unique=True)),
            ],
            options={
                'verbose_name': 'Estado de Equipo',
                'verbose_name_plural': 'Estados de Equipo',
            },
        ),
        migrations.AddField(
            model_name='equipos',
            name='id_estadoeq',
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                to='infinito_sonido.estado_equipos',
                db_column='id_estadoeq',
            ),
        ),
        migrations.RunPython(crear_estados_por_defecto, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='equipos',
            name='id_estadoeq',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                to='infinito_sonido.estado_equipos',
                db_column='id_estadoeq',
            ),
        ),
        migrations.RemoveField(
            model_name='equipos',
            name='estado_equipo',
        ),
    ]
