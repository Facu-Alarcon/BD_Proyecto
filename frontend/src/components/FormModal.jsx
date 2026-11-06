import { estiloFondoModal } from '../utils/fondoModal';
import './overlay.css';

// Ventana emergente para los formularios de edición: de fondo una foto de equipos de sonido
// (cada módulo tiene la suya, ver utils/fondoModal.js), tarjeta
// blanca con título, subtítulo y la X para cerrar. Lo de adentro (el formulario) viene en children.
// 'wide' la hace más ancha (para formularios largos, como el de reservas).
export default function FormModal({ titulo, subtitulo, onClose, wide, children }) {
  return (
    <div className="overlay-page" style={estiloFondoModal(titulo)}>
      <div className={`overlay-card${wide ? ' overlay-card-wide' : ''}`}>
        <div className="overlay-card-header">
          <div>
            <h2>{titulo}</h2>
            {subtitulo && <p className="overlay-subtitle">{subtitulo}</p>}
          </div>
          <button type="button" className="overlay-close" onClick={onClose} aria-label="Cerrar">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
