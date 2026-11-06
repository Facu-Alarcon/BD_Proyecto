// Fotos de fondo de las ventanas de pantalla completa (editar y "¡Listo!").
// Son fotos de equipos de sonido pasadas a los colores del sistema (azul y verde).
// Cada ventana usa siempre la misma, elegida según su título: así cada módulo tiene "su"
// foto y no cambia cada vez que se abre (por ejemplo, "Editar cliente" siempre la misma).
import fondoDj from '../assets/img/fondo_dj.jpg';
import fondoEstudio from '../assets/img/fondo_estudio.jpg';
import fondoConsola from '../assets/img/fondo_consola.jpg';

const FONDOS = [fondoDj, fondoEstudio, fondoConsola];

// Capa azul oscura semitransparente encima de la foto, para que la tarjeta blanca resalte
const CAPA = 'linear-gradient(rgba(6, 15, 36, 0.55), rgba(6, 15, 36, 0.55))';

// Convierte el título en un número (siempre el mismo para el mismo texto) y elige una foto
export function estiloFondoModal(titulo = '') {
  let suma = 0;
  // (con el 29 las 3 fotos quedan repartidas parejo: 5 módulos cada una)
  for (const letra of titulo) suma = (suma * 29 + letra.charCodeAt(0)) % 9973;
  return { backgroundImage: `${CAPA}, url(${FONDOS[suma % FONDOS.length]})` };
}
