# Generado manualmente: nombre/apellido de Clientes y Empleados pasan a
# aceptar solo letras (nada de números) y bajan el max_length de 50 a 30
# para que no se puedan cargar disparates de decenas de caracteres.
# domicilio_cliente baja de 100 a 60.

import django.core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0011_permisos_puestos_sueldos'),
    ]

    operations = [
        migrations.AlterField(
            model_name='clientes',
            name='apellido_cliente',
            field=models.CharField(max_length=30, validators=[django.core.validators.RegexValidator("^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.')]),
        ),
        migrations.AlterField(
            model_name='clientes',
            name='domicilio_cliente',
            field=models.CharField(max_length=60),
        ),
        migrations.AlterField(
            model_name='clientes',
            name='nombre_cliente',
            field=models.CharField(max_length=30, validators=[django.core.validators.RegexValidator("^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.')]),
        ),
        migrations.AlterField(
            model_name='empleados',
            name='apellido_emp',
            field=models.CharField(max_length=30, validators=[django.core.validators.RegexValidator("^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.')]),
        ),
        migrations.AlterField(
            model_name='empleados',
            name='nombre_emp',
            field=models.CharField(max_length=30, validators=[django.core.validators.RegexValidator("^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.')]),
        ),
    ]
