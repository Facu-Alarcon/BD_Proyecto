// Vista previa del nombre de usuario que va a recibir un empleado: primer apellido +
// inicial del primer nombre, en minúscula, sin acentos y con la ñ como n (ej: "perezj").
// Es la misma regla del backend (infinito_sonido/nombres_usuario.py). La única diferencia es
// que acá no se sabe si ya existe: si está tomado, el sistema le agrega un número (perezj2).

// Partículas de los apellidos compuestos ("De la Fuente", "Van der Berg"): se pegan al apellido
const PARTICULAS = new Set(['de', 'del', 'la', 'las', 'los', 'y', 'e', 'da', 'das', 'do', 'dos', 'di', 'van', 'von', 'der', 'den', 'san', 'santa', 'mc', 'mac']);

// Minúsculas, sin acentos y solo letras y números
function limpiar(texto) {
  return (texto || '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

// Primer apellido con sus partículas: "De la Fuente López" -> "delafuente"
function primerApellido(apellido) {
  const tomadas = [];
  for (const palabra of (apellido || '').split(/\s+/).filter(Boolean)) {
    tomadas.push(palabra);
    if (!PARTICULAS.has(palabra.toLowerCase().replace(/[.']/g, ''))) break;
  }
  return limpiar(tomadas.join(''));
}

export function usuarioSugerido(nombre, apellido) {
  const inicial = limpiar((nombre || '').split(/\s+/)[0]).slice(0, 1);
  return primerApellido(apellido) + inicial || 'usuario';
}
