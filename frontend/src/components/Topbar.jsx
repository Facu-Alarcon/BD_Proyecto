import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { IconChevronDown, IconSalir } from './icons';
import logo from '../assets/img/logonuevo.png';
import './Topbar.css';

// Iniciales para el circulito del usuario: "perezj" -> "P"; "juan.perez" -> "JP".
// Separa por punto, espacio, guion o guion bajo y toma la primera letra de las dos primeras partes.
function iniciales(texto) {
  return (texto || '')
    .split(/[.\s_-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('');
}

// Barra de arriba: el logo a la izquierda y, a la derecha, el circulito del usuario
// con un menú que muestra su usuario, su perfil y el botón para cerrar sesión.
export default function Topbar() {
  const { usuario, logout } = useAuth();
  const [abierto, setAbierto] = useState(false);
  const menuRef = useRef(null);

  // Cierra el menú si se hace clic en cualquier otro lado de la pantalla
  useEffect(() => {
    function alClickearFuera(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setAbierto(false);
      }
    }
    document.addEventListener('mousedown', alClickearFuera);
    return () => document.removeEventListener('mousedown', alClickearFuera);
  }, []);

  return (
        <header className="topbar">
      <img src={logo} alt="Infinito Sonido e Iluminación" className="topbar-logo" />

      {/* Menú del usuario: el botón lo abre y lo cierra; la flechita gira cuando está abierto */}
      <div className="topbar-menu" ref={menuRef}>
        <button type="button" className="topbar-avatar-btn" onClick={() => setAbierto((v) => !v)}>
          <span className="topbar-avatar">{iniciales(usuario?.usuario)}</span>
          <IconChevronDown className={`topbar-chevron${abierto ? ' abierto' : ''}`} />
        </button>

        {abierto && (
          <div className="topbar-dropdown">
            <div className="topbar-dropdown-user">
              <strong>{usuario?.usuario}</strong>
              <span>{usuario?.perfil_nombre}</span>
            </div>
            <button type="button" className="topbar-dropdown-item" onClick={logout}>
              <IconSalir /> Cerrar sesión
            </button>
          </div>
        )}
      </div>
    </header>
  );
}
