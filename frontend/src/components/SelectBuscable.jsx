import { useEffect, useRef, useState } from 'react';
import './SelectBuscable.css';

// Pasa el texto a minúsculas y le saca los acentos, así "perez" encuentra a "Pérez"
function normalizar(texto) {
  return (texto || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

// Select en el que se puede escribir para filtrar las opciones.
// Recibe la lista de opciones como { value, label } y funciona igual que un
// <select> común: 'value' es el id elegido y 'onChange' recibe el id nuevo.
export default function SelectBuscable({
  id,
  opciones,
  value,
  onChange,
  placeholder = 'Escribí para buscar...',
  required = false,
  sinResultados = 'No hay coincidencias.',
}) {
  const [texto, setTexto] = useState('');
  const [abierto, setAbierto] = useState(false);
  const [resaltado, setResaltado] = useState(0);
  const contenedorRef = useRef(null);
  const inputRef = useRef(null);
  const listaRef = useRef(null);

  const seleccionada = opciones.find((o) => String(o.value) === String(value));

  // Mientras la lista está cerrada, el input muestra el nombre de la opción elegida
  const textoVisible = abierto ? texto : seleccionada?.label || '';

  // Opciones que coinciden con lo que se escribió (si no se escribió nada, van todas)
  const buscado = normalizar(texto.trim());
  const filtradas = buscado ? opciones.filter((o) => normalizar(o.label).includes(buscado)) : opciones;

  // Si el campo es obligatorio y no hay nada elegido, el navegador no deja enviar el formulario
  useEffect(() => {
    inputRef.current?.setCustomValidity(required && !seleccionada ? 'Elegí una opción de la lista.' : '');
  }, [required, seleccionada]);

  // Cierra la lista si se hace clic afuera del componente
  useEffect(() => {
    function alClickearFuera(e) {
      if (contenedorRef.current && !contenedorRef.current.contains(e.target)) setAbierto(false);
    }
    document.addEventListener('mousedown', alClickearFuera);
    return () => document.removeEventListener('mousedown', alClickearFuera);
  }, []);

  // Cuando se mueve con las flechas, la opción resaltada siempre queda a la vista
  useEffect(() => {
    listaRef.current?.children[resaltado]?.scrollIntoView({ block: 'nearest' });
  }, [resaltado]);

  function abrir() {
    setTexto('');
    setResaltado(0);
    setAbierto(true);
  }

  function elegir(opcion) {
    onChange(opcion.value);
    setAbierto(false);
  }

  // Flechas para moverse, Enter para elegir y Escape para cerrar
  function alApretarTecla(e) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (!abierto) return abrir();
      setResaltado((i) => Math.min(i + 1, filtradas.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setResaltado((i) => Math.max(i - 1, 0));
    } else if (e.key === 'Enter' && abierto) {
      e.preventDefault();
      if (filtradas[resaltado]) elegir(filtradas[resaltado]);
    } else if (e.key === 'Escape') {
      setAbierto(false);
    }
  }

  return (
    <div className="select-buscable" ref={contenedorRef}>
      <input
        id={id}
        ref={inputRef}
        type="text"
        autoComplete="off"
        role="combobox"
        aria-expanded={abierto}
        aria-controls={`${id}-lista`}
        placeholder={seleccionada ? seleccionada.label : placeholder}
        value={textoVisible}
        required={required}
        onFocus={abrir}
        onClick={() => !abierto && abrir()}
        onChange={(e) => {
          setTexto(e.target.value);
          setResaltado(0);
          setAbierto(true);
        }}
        onKeyDown={alApretarTecla}
      />
      {/* Flechita para abrir o cerrar la lista sin escribir */}
      <button
        type="button"
        className="select-buscable-flecha"
        tabIndex={-1}
        aria-label="Mostrar opciones"
        onClick={() => {
          if (abierto) {
            setAbierto(false);
          } else {
            inputRef.current?.focus();
            abrir();
          }
        }}
      >
        ▾
      </button>

      {abierto && (
        <ul className="select-buscable-lista" id={`${id}-lista`} role="listbox" ref={listaRef}>
          {filtradas.length === 0 && <li className="select-buscable-vacio">{sinResultados}</li>}
          {filtradas.map((o, i) => (
            <li
              key={o.value}
              role="option"
              aria-selected={String(o.value) === String(value)}
              className={
                'select-buscable-opcion' +
                (i === resaltado ? ' resaltada' : '') +
                (String(o.value) === String(value) ? ' elegida' : '')
              }
              // mousedown en vez de click para que el input no pierda el foco antes de elegir
              onMouseDown={(e) => {
                e.preventDefault();
                elegir(o);
              }}
              onMouseEnter={() => setResaltado(i)}
            >
              {o.label}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
