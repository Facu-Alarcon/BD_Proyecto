import { useEffect, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import api from '../api/client';
import { useAuth } from '../context/AuthContext';
import { IconCampana, IconChevronDown, IconHamburguesa, IconLuna, IconSalir, IconSol } from './icons';
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
// Al lado del usuario está el botón para pasar a tema claro u oscuro y la campana de
// notificaciones, con la cantidad de avisos sin leer.
export default function Topbar({ onAbrirMenu, menuAbierto }) {
  const { usuario, logout } = useAuth();
  const [abierto, setAbierto] = useState(false);
  const menuRef = useRef(null);
  const { tema, cambiarTema } = useTema();
  const [sinLeer, setSinLeer] = useState(0);
  const { pathname } = useLocation();

  // Cantidad de avisos sin leer para el número de la campana. Se pide al cambiar de
  // pantalla, cada un minuto, y cuando la bandeja avisa que se marcó algo como leído
  // (evento "notificaciones-actualizadas", ver pages/notificaciones/Notificaciones.jsx)
  useEffect(() => {
    function contar() {
      api.get('/notificaciones/no-leidas/')
        .then(({ data }) => setSinLeer(data.cantidad))
        .catch(() => {});
    }
    contar();
    const intervalo = setInterval(contar, 60000);
    window.addEventListener('notificaciones-actualizadas', contar);
    return () => {
      clearInterval(intervalo);
      window.removeEventListener('notificaciones-actualizadas', contar);
    };
  }, [pathname]);

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
        {/* El logo lleva al Inicio. En computadora queda centrado sobre el menú lateral */}
        <Link to="/" className="topbar-logo-link" title="Ir al inicio">
          <img src={logo} alt="Infinito Sonido e Iluminación - Ir al inicio" className="topbar-logo" />
        </Link>
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

      {/* Campana: lleva a la bandeja. El número rojo son los avisos sin leer (más de 99 dice "99+") */}
      <Link
        to="/notificaciones"
        className="topbar-tema-btn topbar-campana"
        aria-label={sinLeer ? `Notificaciones: ${sinLeer} sin leer` : 'Notificaciones'}
        title="Notificaciones"
      >
        <IconCampana />
        {sinLeer > 0 && <span className="topbar-campana-numero">{sinLeer > 99 ? '99+' : sinLeer}</span>}
      </Link>

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
