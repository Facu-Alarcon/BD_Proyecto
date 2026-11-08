import { IconHamburguesa } from './icons';

// Botón "Menú" que vuelve a mostrar el menú lateral después de esconderlo con la flechita «
// (pantallas grandes y medianas; en el celular el menú se abre desde la barra de arriba y este
// botón no se muestra). Layout.jsx lo pone solo mientras el menú está escondido.
// Va arriba a la izquierda del contenido, en azul institucional como el menú, para que se vea bien.
// Los estilos están en Layout.css.
export default function BotonMenuLateral({ onMostrar }) {
  return (
    <div className="menu-lateral-ancla no-imprimir">
      <button
        type="button"
        className="menu-lateral-btn"
        onClick={onMostrar}
        aria-label="Mostrar menú lateral"
        aria-expanded={false}
        title="Mostrar menú lateral"
      >
        <IconHamburguesa width={22} height={22} aria-hidden="true" />
        <span>Menú</span>
      </button>
    </div>
  );
}
