"""
Nombre de usuario automático: PRIMER APELLIDO + INICIAL DEL PRIMER NOMBRE.

Ejemplos:
    Juan Pérez            -> perezj
    Juan Pérez García     -> perezj        (solo el primer apellido)
    María José Núñez      -> nunezm        (sin acentos, la ñ pasa a n)
    Lucía De la Fuente    -> delafuentel   (las partículas se pegan al apellido)
    Pedro Van der Berg    -> vanderbergp
    Sean O'Connor         -> oconnors      (sin apóstrofes ni símbolos)
Si el nombre ya está tomado se le agrega un número: perezj2, perezj3, ...

El frontend muestra una vista previa con la misma regla (frontend/src/utils/nombreUsuario.js).
La migración 0022 tiene una copia de esta lógica para no depender de este archivo.
"""
import unicodedata

# Palabras que forman parte de un apellido compuesto y no son un apellido por sí solas
# ("De la Fuente", "Van der Berg", "San Martín"): se pegan a la palabra que sigue
PARTICULAS = {'de', 'del', 'la', 'las', 'los', 'y', 'e', 'da', 'das', 'do', 'dos', 'di', 'van', 'von', 'der', 'den', 'san', 'santa', 'mc', 'mac'}


# Minúsculas, sin acentos (la ñ queda como n) y solo letras y números
def _limpiar(texto):
    sin_acentos = unicodedata.normalize('NFKD', texto or '').encode('ascii', 'ignore').decode('ascii')
    return ''.join(ch for ch in sin_acentos.lower() if ch.isalnum())


# Primer apellido con sus partículas: "De la Fuente López" -> "delafuente"
def primer_apellido(apellido):
    palabras = (apellido or '').split()
    tomadas = []
    for palabra in palabras:
        tomadas.append(palabra)
        # Se sigue juntando mientras sean partículas; con la primera palabra "de verdad" se corta
        if palabra.lower().strip(".'") not in PARTICULAS:
            break
    return _limpiar(''.join(tomadas))


# El usuario "base", sin el número para los repetidos: primer apellido + inicial del primer nombre
def usuario_base(nombre, apellido):
    inicial = _limpiar((nombre or '').split()[0] if (nombre or '').split() else '')[:1]
    return (primer_apellido(apellido) + inicial) or 'usuario'


# Devuelve un usuario libre: el base, o el base con un número si ya existe.
# 'ocupados' es una función que dice si un nombre ya está tomado (así sirve igual
# desde la API, mirando la base, o desde la migración).
def generar_nombre_usuario(nombre, apellido, ocupados):
    base = usuario_base(nombre, apellido)
    candidato, numero = base, 2
    while ocupados(candidato):
        candidato = f'{base}{numero}'
        numero += 1
    return candidato
