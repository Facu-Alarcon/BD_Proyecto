# Generado manualmente para el hito "Gestionar usuarios" del DER:
# agrega a Usuarios los campos que pedía la consigna y que todavía no
# existían (dni, nombre, apellido, correo, activo, debe_cambiar_clave,
# fecha_ultima_modificacion, fecha_baja) y deja 'usuario' como único
# (ahora se genera solo, ver serializers.generar_nombre_usuario).
#
# Los usuarios que ya estén cargados en la base no tienen estos datos,
# así que se les completa un valor placeholder único (dni/correo) para
# poder aplicar los unique=True sin romper la migración. Conviene
# editarlos a mano después desde el admin o el formulario de Usuarios.

import django.core.validators
from django.db import migrations, models
from django.utils import timezone


def completar_datos_existentes(apps, schema_editor):
    Usuarios = apps.get_model('infinito_sonido', 'Usuarios')
    hoy = timezone.now().date()
    for usuario in Usuarios.objects.all():
        usuario.dni = str(1000000 + usuario.pk)  # placeholder único, editar a mano
        usuario.nombre = usuario.nombre or 'Pendiente'
        usuario.apellido = usuario.apellido or 'Pendiente'
        usuario.correo = f'usuario{usuario.pk}@pendiente.local'
        usuario.fecha_ultima_modificacion = hoy
        usuario.save()


def revertir_datos_existentes(apps, schema_editor):
    # No hay nada que deshacer: al bajar la migración se borran las columnas.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0013_permisos_modulos_faltantes'),
    ]

    operations = [
        migrations.AddField(
            model_name='usuarios',
            name='dni',
            field=models.CharField(max_length=8, null=True),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='nombre',
            field=models.CharField(blank=True, default='', max_length=30),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='apellido',
            field=models.CharField(blank=True, default='', max_length=30),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='correo',
            field=models.EmailField(blank=True, default='', max_length=254),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='activo',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='debe_cambiar_clave',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='fecha_ultima_modificacion',
            field=models.DateField(null=True),
        ),
        migrations.AddField(
            model_name='usuarios',
            name='fecha_baja',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.RunPython(completar_datos_existentes, revertir_datos_existentes),
        migrations.AlterField(
            model_name='usuarios',
            name='dni',
            field=models.CharField(
                max_length=8,
                unique=True,
                validators=[
                    django.core.validators.MinLengthValidator(7, message='El DNI debe tener 7 u 8 dígitos.'),
                    django.core.validators.RegexValidator(r'^\d+$', message='El DNI solo puede tener números, sin puntos ni espacios.'),
                ],
            ),
        ),
        migrations.AlterField(
            model_name='usuarios',
            name='nombre',
            field=models.CharField(
                max_length=30,
                validators=[django.core.validators.RegexValidator(r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.')],
            ),
        ),
        migrations.AlterField(
            model_name='usuarios',
            name='apellido',
            field=models.CharField(
                max_length=30,
                validators=[django.core.validators.RegexValidator(r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+$", message='Solo se permiten letras.')],
            ),
        ),
        migrations.AlterField(
            model_name='usuarios',
            name='correo',
            field=models.EmailField(max_length=254),
        ),
        migrations.AlterField(
            model_name='usuarios',
            name='usuario',
            field=models.CharField(max_length=50, unique=True),
        ),
        migrations.AlterField(
            model_name='usuarios',
            name='fecha_ultima_modificacion',
            field=models.DateField(auto_now=True),
        ),
    ]