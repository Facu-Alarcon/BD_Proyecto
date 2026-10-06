# Los nombres de usuario pasan a ser PRIMER APELLIDO + INICIAL DEL NOMBRE (ej: perezj),
# con un número si se repite (perezj2). Esta migración renombra a todos los usuarios que
# ya existían (antes entraban con su DNI). La contraseña no cambia: solo el usuario.
#
# Excepción: el usuario "admin" queda igual. Es la cuenta del sistema, no de una persona,
# y es el acceso que figura en los datos de prueba, los scripts y la documentación.
#
# La lógica es una copia de infinito_sonido/nombres_usuario.py: las migraciones no deben
# importar código de la app, porque si ese código cambia la migración vieja se rompe.

import unicodedata

from django.db import migrations

PARTICULAS = {'de', 'del', 'la', 'las', 'los', 'y', 'e', 'da', 'das', 'do', 'dos', 'di', 'van', 'von', 'der', 'den', 'san', 'santa', 'mc', 'mac'}
USUARIOS_QUE_NO_SE_TOCAN = {'admin'}


def _limpiar(texto):
    sin_acentos = unicodedata.normalize('NFKD', texto or '').encode('ascii', 'ignore').decode('ascii')
    return ''.join(ch for ch in sin_acentos.lower() if ch.isalnum())


def _usuario_base(nombre, apellido):
    tomadas = []
    for palabra in (apellido or '').split():
        tomadas.append(palabra)
        if palabra.lower().strip(".'") not in PARTICULAS:
            break
    palabras_nombre = (nombre or '').split()
    inicial = _limpiar(palabras_nombre[0] if palabras_nombre else '')[:1]
    return (_limpiar(''.join(tomadas)) + inicial) or 'usuario'


def renombrar_usuarios(apps, schema_editor):
    Usuarios = apps.get_model('infinito_sonido', 'Usuarios')
    a_renombrar = list(
        Usuarios.objects.exclude(usuario__in=USUARIOS_QUE_NO_SE_TOCAN).select_related('id_empleado').order_by('id_usuario')
    )
    if not a_renombrar:
        return

    # Nombres que quedan como están (admin): no se pueden repetir
    tomados = set(Usuarios.objects.filter(usuario__in=USUARIOS_QUE_NO_SE_TOCAN).values_list('usuario', flat=True))

    # Se calcula el nombre nuevo de cada uno, en orden de alta: el más viejo se queda con
    # "perezj" y los siguientes con "perezj2", "perezj3"...
    nuevos = {}
    for usuario in a_renombrar:
        base = _usuario_base(usuario.id_empleado.nombre_emp, usuario.id_empleado.apellido_emp)
        candidato, numero = base, 2
        while candidato in tomados:
            candidato = f'{base}{numero}'
            numero += 1
        tomados.add(candidato)
        nuevos[usuario.pk] = candidato

    # Dos pasadas por la restricción de usuario único: primero un nombre provisorio
    # (así nadie choca con un nombre viejo de otro) y después el definitivo
    for usuario in a_renombrar:
        usuario.usuario = f'tmp_renombre_{usuario.pk}'
        usuario.save(update_fields=['usuario'])
    for usuario in a_renombrar:
        usuario.usuario = nuevos[usuario.pk]
        usuario.save(update_fields=['usuario'])


class Migration(migrations.Migration):

    dependencies = [
        ('infinito_sonido', '0021_equipos_x_servicios_cantidad'),
    ]

    operations = [
        # Sin vuelta atrás automática: los nombres viejos (DNI) no se guardan en ningún lado
        migrations.RunPython(renombrar_usuarios, migrations.RunPython.noop),
    ]
