// Reglas de seguridad de las contraseñas. Son las mismas que controla el backend
// (infinito_sonido/seguridad.py); acá se usan para ir mostrando en pantalla qué le
// falta a la contraseña mientras el usuario la escribe.
export const REGLAS_CONTRASEÑA = [
  { texto: 'Al menos 8 caracteres', cumple: (c) => c.length >= 8 },
  { texto: 'Una letra mayúscula', cumple: (c) => /[A-ZÁÉÍÓÚÑ]/.test(c) },
  { texto: 'Una letra minúscula', cumple: (c) => /[a-záéíóúñ]/.test(c) },
  { texto: 'Un número', cumple: (c) => /\d/.test(c) },
  { texto: 'Un carácter especial (! @ # $ % …)', cumple: (c) => /[^A-Za-z0-9ÁÉÍÓÚáéíóúÑñ]/.test(c) },
];

// true si la contraseña cumple todas las reglas
export function contraseñaSegura(contraseña) {
  return REGLAS_CONTRASEÑA.every((r) => r.cumple(contraseña));
}
