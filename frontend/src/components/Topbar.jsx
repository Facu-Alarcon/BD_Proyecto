import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { IconChevronDown, IconHamburguesa, IconLuna, IconSalir, IconSol } from './icons';
import { useTema } from '../hooks/useTema';
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
// En el celular aparece además, a la izquierda, el botón que abre el menú lateral.
// Al lado del usuario está el botón para pasar a tema claro u oscuro.
export default function Topbar({ onAbrirMenu, menuAbierto }) {
  const { usuario, logout } = useAuth();
  const [abierto, setAbierto] = useState(false);
  const menuRef = useRef(null);
  const { tema, cambiarTema } = useTema();

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
      <div className="topbar-izquierda">
        {/* Solo se ve en el celular (ver Topbar.css) */}
        <button
          type="button"
          className="topbar-menu-btn"
          onClick={onAbrirMenu}
          aria-label={menuAbierto ? 'Cerrar menú' : 'Abrir menú'}
          aria-expanded={menuAbierto}
        >
          <IconHamburguesa />
        </button>
        <img src={logo} alt="Infinito Sonido e Iluminación" className="topbar-logo" />
      </div>

      <div className="topbar-derecha">
      {/* Tema claro / oscuro: muestra la luna en claro (para pasar a oscuro) y el sol en oscuro */}
      <button
        type="button"
        className="topbar-tema-btn"
        onClick={cambiarTema}
        aria-label={tema === 'oscuro' ? 'Pasar a tema claro' : 'Pasar a tema oscuro'}
        title={tema === 'oscuro' ? 'Tema claro' : 'Tema oscuro'}
      >
        {tema === 'oscuro' ? <IconSol /> : <IconLuna />}
      </button>

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
      </div>
    </header>
  );
}
