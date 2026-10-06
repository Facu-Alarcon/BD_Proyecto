import FondoBarras from './FondoBarras';
import './overlay.css';

// Ventana de "¡Listo!" que se muestra después de guardar una edición, con un tilde
// verde y un botón para volver a la lista
export default function SuccessModal({ titulo, subtitulo, textoBoton, onContinuar }) {
  return (
    <div className="overlay-page">
      <FondoBarras className="overlay-bars" />
      <div className="overlay-card overlay-success">
        <div className="overlay-success-icon">✓</div>
        <h2>{titulo}</h2>
        {subtitulo && <p className="overlay-subtitle">{subtitulo}</p>}
        <button type="button" className="btn btn-primary" onClick={onContinuar} style={{ width: '100%', justifyContent: 'center' }}>
          {textoBoton}
        </button>
      </div>
    </div>
  );
}
