# Generado manualmente: telefono_cliente/telefono_emp pasan de IntegerField
# a CharField. Un IntegerField tiene tope en 2.147.483.647 (entero de 32
# bits), y un celular con característica (ej: 3878551132) lo supera.

import django.core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0009_permisos_codigo_y_seed'),
    ]

    operations = [
        migrations.AlterField(
            model_name='clientes',
            name='telefono_cliente',
            field=models.CharField(max_length=12, validators=[django.core.validators.MinLengthValidator(10, message='El teléfono debe tener al menos 10 dígitos.'), django.core.validators.RegexValidator('^\\d+$', message='El teléfono solo puede tener números.')]),
        ),
        migrations.AlterField(
            model_name='empleados',
            name='telefono_emp',
            field=models.CharField(max_length=12, validators=[django.core.validators.MinLengthValidator(10, message='El teléfono debe tener al menos 10 dígitos.'), django.core.validators.RegexValidator('^\\d+$', message='El teléfono solo puede tener números.')]),
        ),
    ]
