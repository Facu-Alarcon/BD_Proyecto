# Generado a mano: los usuarios pasan a crearse a partir de los empleados.
# - El DNI se mueve de Usuarios a Empleados.
# - Usuarios tiene una clave foránea uno a uno a Empleados (id_empleado).
# - Nombre, apellido y correo se sacan de Usuarios porque ahora se toman del empleado.
#
# Para no perder los usuarios que ya existen, a cada uno se le busca un empleado con el
# mismo nombre y apellido; si no hay, se crea el empleado con los datos del usuario.

import unicodedata

import django.core.validators
from django.db import migrations, models
import django.db.models.deletion


# Nombre en minúscula y sin acentos, para comparar "Pérez" con "perez"
def _normalizar(texto):
    return unicodedata.normalize('NFKD', texto or '').encode('ascii', 'ignore').decode().lower().strip()


# Vincula cada usuario existente con un empleado y le pasa el DNI
def vincular_usuarios_con_empleados(apps, schema_editor):
    Usuarios = apps.get_model('infinito_sonido', 'Usuarios')
    Empleados = apps.get_model('infinito_sonido', 'Empleados')

    for usuario in Usuarios.objects.all():
        # Empleado con el mismo nombre y apellido que todavía no tenga usuario
        empleado = next(
            (
                e for e in Empleados.objects.all()
                if _normalizar(e.nombre_emp) == _normalizar(usuario.nombre)
                and _normalizar(e.apellido_emp) == _normalizar(usuario.apellido)
                and not Usuarios.objects.filter(id_empleado=e).exists()
            ),
            None,
        )
        dni_libre = not Empleados.objects.filter(dni=usuario.dni).exists()

        if empleado is None:
            # No hay empleado para este usuario: se crea con lo que tenía el usuario.
            # El teléfono no lo teníamos, queda en ceros para completarlo después.
            empleado = Empleados.objects.create(
                nombre_emp=usuario.nombre,
                apellido_emp=usuario.apellido,
                email_emp=usuario.correo,
                telefono_emp='0000000000',
                dni=usuario.dni if dni_libre else None,
            )
        elif not empleado.dni and dni_libre:
            empleado.dni = usuario.dni
            empleado.save(update_fields=['dni'])

        usuario.id_empleado = empleado
        usuario.save(update_fields=['id_empleado'])


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0016_reservas_hora_y_duracion'),
    ]

    operations = [
        # DNI en Empleados (vacío por ahora en los empleados que ya estaban)
        migrations.AddField(
            model_name='empleados',
            name='dni',
            field=models.CharField(
                blank=True, max_length=8, null=True, unique=True,
                validators=[
                    django.core.validators.MinLengthValidator(7, message='El DNI debe tener 7 u 8 dígitos.'),
                    django.core.validators.RegexValidator('^\\d+$', message='El DNI solo puede tener números, sin puntos ni espacios.'),
                ],
            ),
        ),
        # Primero la relación se crea permitiendo vacío, porque los usuarios existentes todavía no tienen empleado
        migrations.AddField(
            model_name='usuarios',
            name='id_empleado',
            field=models.OneToOneField(
                db_column='id_empleado', null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='usuario', to='infinito_sonido.empleados',
            ),
        ),
        migrations.RunPython(vincular_usuarios_con_empleados, migrations.RunPython.noop),
        # Ya con todos vinculados, el empleado pasa a ser obligatorio
        migrations.AlterField(
            model_name='usuarios',
            name='id_empleado',
            field=models.OneToOneField(
                db_column='id_empleado',
                on_delete=django.db.models.deletion.PROTECT,
                related_name='usuario', to='infinito_sonido.empleados',
            ),
        ),
        # Estos datos ahora se toman del empleado
        migrations.RemoveField(model_name='usuarios', name='dni'),
        migrations.RemoveField(model_name='usuarios', name='nombre'),
        migrations.RemoveField(model_name='usuarios', name='apellido'),
        migrations.RemoveField(model_name='usuarios', name='correo'),
        # El comentario del campo 'usuario' cambió, pero la columna queda igual
        migrations.AlterField(
            model_name='usuarios',
            name='usuario',
            field=models.CharField(max_length=50, unique=True),
        ),
    ]
