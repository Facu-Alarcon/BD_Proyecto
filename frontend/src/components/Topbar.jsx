import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { IconChevronDown, IconSalir } from './icons';
import './Topbar.css';

function iniciales(texto) {
  return (texto || '')
    .split(/[.\s_-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('');
}

export default function Topbar() {
  const { usuario, logout } = useAuth();
  const [abierto, setAbierto] = useState(false);
  const menuRef = useRef(null);

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
