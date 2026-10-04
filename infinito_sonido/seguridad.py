import secrets
import string

from rest_framework import serializers

# Reglas que tiene que cumplir toda contraseña que elija un usuario.
# El frontend muestra la misma lista (ver frontend/src/utils/contraseña.js) para que
# el usuario vea qué le falta mientras escribe; acá se vuelve a controlar porque
# lo que llega a la API se puede mandar sin pasar por la pantalla.
LARGO_MINIMO = 8
CARACTERES_ESPECIALES = '!@#$%&*?-_.+=/'

REGLAS = [
    (lambda c: len(c) >= LARGO_MINIMO, f'Tener al menos {LARGO_MINIMO} caracteres.'),
    (lambda c: any(ch.isupper() for ch in c), 'Tener al menos una letra mayúscula.'),
    (lambda c: any(ch.islower() for ch in c), 'Tener al menos una letra minúscula.'),
    (lambda c: any(ch.isdigit() for ch in c), 'Tener al menos un número.'),
    (lambda c: any(not ch.isalnum() for ch in c), 'Tener al menos un carácter especial (por ejemplo ! @ # $ %).'),
]


# Revisa la contraseña contra todas las reglas y, si falta alguna, corta con un
# error que lista todo lo que falta (así el usuario no tiene que adivinar)
def validar_contraseña_segura(contraseña):
    faltan = [mensaje for regla, mensaje in REGLAS if not regla(contraseña)]
    if faltan:
        raise serializers.ValidationError(['La contraseña tiene que:'] + faltan)
    return contraseña


# Arma una contraseña temporal al azar que ya cumple todas las reglas:
# una mayúscula, una minúscula, un número, un carácter especial y el resto mezclado.
# Se usa 'secrets' (y no 'random') porque está pensado para claves y es impredecible.
def generar_contraseña_temporal(largo=10):
    # Se sacan letras que se confunden al leerlas o copiarlas a mano (O/0, l/1/I)
    letras_may = ''.join(ch for ch in string.ascii_uppercase if ch not in 'OI')
    letras_min = ''.join(ch for ch in string.ascii_lowercase if ch not in 'l')
    numeros = '23456789'
    especiales = '!@#$%&*?'

    obligatorios = [
        secrets.choice(letras_may),
        secrets.choice(letras_min),
        secrets.choice(numeros),
        secrets.choice(especiales),
    ]
    todos = letras_may + letras_min + numeros + especiales
    resto = [secrets.choice(todos) for _ in range(largo - len(obligatorios))]

    caracteres = obligatorios + resto
    # Se mezclan para que los obligatorios no queden siempre al principio
    for i in range(len(caracteres) - 1, 0, -1):
        j = secrets.randbelow(i + 1)
        caracteres[i], caracteres[j] = caracteres[j], caracteres[i]
    return ''.join(caracteres)
