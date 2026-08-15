from django.db import migrations, models

'''
    Investigar que iria en migrations
    Cambiar por la migraciones de la base de datos del proyecto
'''
class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='Alumno',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nombre', models.CharField(max_length=50, verbose_name='Nombre')),
                ('nota', models.DecimalField(blank=True, decimal_places=2, max_digits=4, null=True, verbose_name='Nota')),
                ('fecha_alta', models.DateTimeField(auto_now_add=True, verbose_name='Fecha de alta')),
            ],
            options={
                'verbose_name': 'Alumno',
                'verbose_name_plural': 'Alumnos',
                'ordering': ['nombre'],
            },
        ),
    ]
