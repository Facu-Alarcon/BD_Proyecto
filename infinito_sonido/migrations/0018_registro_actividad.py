# Registro de actividad (auditoría): crea la tabla donde se guardan las altas,
# modificaciones, bajas, inicios de sesión, cambios de clave y errores del sistema.
# También crea el permiso "Ver Registro de actividad" y se lo asigna al perfil
# Administrador (mismo patrón que las migraciones 0009, 0011 y 0013).
# Solo hay permiso de ver: el registro no se puede editar ni borrar desde el sistema.

from django.db import migrations, models
import django.db.models.deletion


# Crea el permiso ver_registro y se lo da a los perfiles de administrador
def crear_permiso(apps, schema_editor):
    Permisos = apps.get_model('infinito_sonido', 'Permisos')
    Perfiles = apps.get_model('infinito_sonido', 'Perfiles')
    Permisos_x_Perfiles = apps.get_model('infinito_sonido', 'Permisos_x_Perfiles')

    permiso, _ = Permisos.objects.get_or_create(
        codigo='ver_registro',
        defaults={
            'nombre_permiso': 'Ver Registro de actividad',
            'descripcion_permiso': 'Permite ver quién hizo cada alta, modificación y baja, los inicios de sesión y los errores del sistema.',
        },
    )
    for perfil in Perfiles.objects.filter(tipo_perfil__icontains='admin'):
        Permisos_x_Perfiles.objects.get_or_create(id_perfil=perfil, id_permiso=permiso)


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0017_usuarios_desde_empleados'),
    ]

    operations = [
        migrations.CreateModel(
            name='Registro_Actividad',
            fields=[
                ('id_registro', models.AutoField(primary_key=True, serialize=False)),
                ('fecha', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('usuario_texto', models.CharField(blank=True, max_length=50)),
                ('accion', models.CharField(choices=[('ALTA', 'Alta'), ('MODIFICACION', 'Modificación'), ('BAJA', 'Baja'), ('LOGIN', 'Inicio de sesión'), ('LOGIN_FALLIDO', 'Inicio de sesión fallido'), ('LOGOUT', 'Cierre de sesión'), ('CLAVE', 'Contraseña'), ('ERROR', 'Error del sistema')], db_index=True, max_length=20)),
                ('modulo', models.CharField(blank=True, max_length=50)),
                ('id_objeto', models.CharField(blank=True, max_length=20)),
                ('descripcion', models.CharField(max_length=255)),
                ('detalle', models.TextField(blank=True)),
                ('ip', models.GenericIPAddressField(blank=True, null=True)),
                ('id_usuario', models.ForeignKey(blank=True, db_column='id_usuario', null=True, on_delete=django.db.models.deletion.SET_NULL, to='infinito_sonido.usuarios')),
            ],
            options={
                'verbose_name': 'Registro de actividad',
                'verbose_name_plural': 'Registro de actividad',
                'ordering': ['-fecha'],
            },
        ),
        migrations.RunPython(crear_permiso, migrations.RunPython.noop),
    ]
