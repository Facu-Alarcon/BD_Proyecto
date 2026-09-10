import FondoBarras from './FondoBarras';
import './overlay.css';

export default function FormModal({ titulo, subtitulo, onClose, wide, children }) {
  return (
    <div className="overlay-page">
      <FondoBarras className="overlay-bars" />
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
