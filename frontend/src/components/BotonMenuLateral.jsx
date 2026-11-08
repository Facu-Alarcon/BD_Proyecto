import { IconHamburguesa } from './icons';

// Botón para esconder el menú lateral y volver a mostrarlo (pantallas grandes y medianas; en el
// celular el menú se abre desde la barra de arriba y este botón no se muestra).
// Está arriba a la izquierda del contenido, pegado al menú:
//   - con el menú visible: solo las tres rayitas, que lo esconden
//   - con el menú escondido: las tres rayitas y el texto "Menú" subrayado, que lo vuelven a mostrar
// Los estilos están en Layout.css y el estado (oculto o no) lo maneja Layout.jsx.
export default function BotonMenuLateral({ oculto, onAlternar }) {
  const etiqueta = oculto ? 'Mostrar menú lateral' : 'Ocultar menú lateral';
  return (
    <div className="menu-lateral-ancla no-imprimir">
      <button
        type="button"
        className={`menu-lateral-btn${oculto ? ' con-texto' : ''}`}
        onClick={onAlternar}
        aria-label={etiqueta}
        aria-expanded={!oculto}
        title={etiqueta}
      >
        <IconHamburguesa width={20} height={20} aria-hidden="true" />
        {oculto && <span className="menu-lateral-texto">Menú</span>}
      </button>
    </div>
  );
}
