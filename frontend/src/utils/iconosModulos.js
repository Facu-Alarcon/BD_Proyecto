// Acá se decide qué ícono y qué color lleva cada fila de las tablas
// (Equipos, Tipos de equipo, Servicios, Puestos, Métodos de pago, Permisos y Perfiles).
// Todas las funciones devuelven { icono, color }: 'icono' es el nombre de uno de los
// dibujos de components/IconoCelda.jsx y 'color' una de las clases .icono-<color> de index.css.
// Se eligen por palabras del nombre, así que si se carga algo nuevo que no coincide
// con ninguna regla, queda con un ícono genérico gris.

// Pasa el texto a minúsculas y le saca los acentos, así "Iluminación" y "iluminacion" dan igual
function normalizar(texto) {
  return (texto || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

const GENERICO = { icono: 'etiqueta', color: 'pizarra' };

// Ícono y color de cada tipo de equipo (también lo usan los equipos para tomar su color)
export function iconoTipoEquipo(nombreTipo) {
  const t = normalizar(nombreTipo);
  if (t.includes('sonido') || t.includes('audio')) return { icono: 'onda', color: 'azul' };
  if (t.includes('ilumin') || t.includes('luces')) return { icono: 'foco', color: 'ambar' };
  if (t.includes('estructura') || t.includes('soporte')) return { icono: 'estructura', color: 'pizarra' };
  if (t.includes('efecto')) return { icono: 'destellos', color: 'violeta' };
  if (t.includes('cable') || t.includes('accesorio')) return { icono: 'cable', color: 'teal' };
  return GENERICO;
}

// El color sale del tipo; los micrófonos y las consolas tienen su propio dibujo
export function iconoEquipo(nombreEquipo, nombreTipo) {
  const base = iconoTipoEquipo(nombreTipo);
  const n = normalizar(nombreEquipo);
  if (n.includes('microfono')) return { ...base, icono: 'microfono' };
  if (n.includes('consola') || n.includes('mezcladora')) return { ...base, icono: 'consola' };
  return base;
}

// Los servicios con DJ llevan auriculares; el resto, nota musical
export function iconoServicio(nombreServicio) {
  if (/\bdj\b/.test(normalizar(nombreServicio))) return { icono: 'auriculares', color: 'rosa' };
  return { icono: 'musica', color: 'verde' };
}

// Cada puesto toma el ícono de su área; los administrativos llevan maletín
export function iconoPuesto(nombrePuesto) {
  const n = normalizar(nombrePuesto);
  if (/\bdj\b/.test(n) || n.includes('sonido')) return { icono: 'auriculares', color: 'rosa' };
  if (n.includes('ilumin')) return { icono: 'foco', color: 'ambar' };
  if (n.includes('montaje') || n.includes('estructura')) return { icono: 'estructura', color: 'pizarra' };
  if (n.includes('cable') || n.includes('tecnic')) return { icono: 'cable', color: 'teal' };
  return { icono: 'maletin', color: 'azul' };
}

// Efectivo, transferencia, tarjeta o billetera virtual
export function iconoMetodoPago(nombreMetodo) {
  const n = normalizar(nombreMetodo);
  if (n.includes('efectivo')) return { icono: 'billete', color: 'verde' };
  if (n.includes('transfer')) return { icono: 'transferencia', color: 'azul' };
  if (n.includes('tarjeta') || n.includes('debito') || n.includes('credito')) return { icono: 'tarjeta', color: 'violeta' };
  if (n.includes('mercado') || n.includes('billetera') || n.includes('virtual')) return { icono: 'billetera', color: 'celeste' };
  return { icono: 'tarjeta', color: 'pizarra' };
}

// Se mira el código del permiso: los "ver_" son de solo lectura y los "gestionar_" dejan modificar
export function iconoPermiso(codigo) {
  if (codigo?.startsWith('ver_')) return { icono: 'ojo', color: 'azul' };
  if (codigo?.startsWith('gestionar_')) return { icono: 'lapiz', color: 'ambar' };
  return { icono: 'candado', color: 'pizarra' };
}

// El administrador se distingue del resto de los perfiles
export function iconoPerfil(nombrePerfil) {
  if (normalizar(nombrePerfil).includes('admin')) return { icono: 'escudoOk', color: 'azul' };
  return { icono: 'escudoPersona', color: 'pizarra' };
}
