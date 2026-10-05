import { useEffect, useRef, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  IconInicio, IconClientes, IconReservas, IconServicios, IconEquipos, IconTiposEquipo,
  IconEmpleados, IconPuestos, IconHorarios, IconSueldos, IconUsuarios, IconPerfiles,
  IconPermisos, IconMetodosPago, IconPagos, IconRegistro,
} from './icons';
import './Sidebar.css';

// 'modulo' es el código que usa el backend para decidir el acceso
// (ver_<modulo> / gestionar_<modulo>).
const NAV_ITEMS = [
  { to: '/', label: 'Inicio', icon: IconInicio, end: true },
  { to: '/clientes', label: 'Clientes', icon: IconClientes, modulo: 'clientes' },
  { to: '/reservas', label: 'Reservas', icon: IconReservas, modulo: 'reservas' },
  { to: '/servicios', label: 'Servicios', icon: IconServicios, modulo: 'servicios' },
  { to: '/equipos', label: 'Equipos', icon: IconEquipos, modulo: 'equipos' },
  { to: '/tipos-equipo', label: 'Tipos de equipo', icon: IconTiposEquipo, modulo: 'tipos_equipo' },
  { to: '/empleados', label: 'Empleados', icon: IconEmpleados, modulo: 'empleados' },
  { to: '/puestos', label: 'Puestos', icon: IconPuestos, modulo: 'puestos' },
  { to: '/horarios', label: 'Horarios', icon: IconHorarios, modulo: 'horarios' },
  { to: '/sueldos', label: 'Sueldos', icon: IconSueldos, modulo: 'sueldos' },
  { to: '/usuarios', label: 'Usuarios', icon: IconUsuarios, modulo: 'usuarios' },
  { to: '/perfiles', label: 'Perfiles', icon: IconPerfiles, modulo: 'perfiles' },
  { to: '/permisos', label: 'Permisos', icon: IconPermisos, modulo: 'permisos' },
  { to: '/metodos-pago', label: 'Métodos de pago', icon: IconMetodosPago, modulo: 'metodos_pago' },
  { to: '/pagos', label: 'Pagos', icon: IconPagos, modulo: 'pagos' },
  // Solo lo ven los perfiles con el permiso "Ver Registro de actividad" (por defecto, el Administrador)
  { to: '/registro', label: 'Registro de actividad', icon: IconRegistro, modulo: 'registro' },
];

// Mismo corte que en Sidebar.css: por debajo de este ancho el menú
// muestra solo los íconos y el nombre aparece en un cartelito (tooltip).
const MEDIA_COMPACTO = '(max-width: 1024px)';

function useMenuCompacto() {
  const [compacto, setCompacto] = useState(() => window.matchMedia(MEDIA_COMPACTO).matches);
  useEffect(() => {
    const mq = window.matchMedia(MEDIA_COMPACTO);
    const alCambiar = (e) => setCompacto(e.matches);
    mq.addEventListener('change', alCambiar);
    return () => mq.removeEventListener('change', alCambiar);
  }, []);
  return compacto;
}

export default function Sidebar() {
  const { usuario } = useAuth();
  const permisos = usuario?.permisos || [];
  const compacto = useMenuCompacto();

  // El tooltip se dibuja con position: fixed (fuera del <nav>, que tiene
  // scroll y lo recortaría) al lado del ícono sobre el que se está.
  const [tooltip, setTooltip] = useState(null);
  const timerOcultar = useRef(null);

  const puedeVer = (modulo) =>
    !modulo || permisos.includes(`ver_${modulo}`) || permisos.includes(`gestionar_${modulo}`);

  function mostrarTooltip(e, label) {
    if (!compacto) return;
    clearTimeout(timerOcultar.current);
    const r = e.currentTarget.getBoundingClientRect();
    setTooltip({ label, top: r.top + r.height / 2, left: r.right + 10 });
  }

  function ocultarTooltip(demora = 0) {
    clearTimeout(timerOcultar.current);
    timerOcultar.current = setTimeout(() => setTooltip(null), demora);
  }

  useEffect(() => () => clearTimeout(timerOcultar.current), []);

  return (
    <aside className="sidebar">
      <nav className="sidebar-nav" onScroll={() => ocultarTooltip()}>
        {NAV_ITEMS.filter((item) => puedeVer(item.modulo)).map((item) => {
          const Icono = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              aria-label={item.label}
              className={({ isActive }) => 'sidebar-link' + (isActive ? ' active' : '')}
              onMouseEnter={(e) => mostrarTooltip(e, item.label)}
              onMouseLeave={() => ocultarTooltip()}
              onFocus={(e) => mostrarTooltip(e, item.label)}
              onBlur={() => ocultarTooltip()}
              // En celular/tablet: al mantener apretado aparece el nombre,
              // y se va solo un momento después de soltar.
              onTouchStart={(e) => mostrarTooltip(e, item.label)}
              onTouchEnd={() => ocultarTooltip(1200)}
              onContextMenu={(e) => compacto && e.preventDefault()}
            >
              <Icono className="sidebar-icon" aria-hidden="true" />
              <span className="sidebar-label">{item.label}</span>
            </NavLink>
          );
        })}
      </nav>

      {compacto && tooltip && (
        <div className="sidebar-tooltip" role="tooltip" style={{ top: tooltip.top, left: tooltip.left }}>
          {tooltip.label}
        </div>
      )}
    </aside>
  );
}
