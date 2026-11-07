import { Fragment, useEffect, useRef, useState } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  IconInicio, IconClientes, IconReservas, IconServicios, IconEquipos, IconTiposEquipo, IconEstadosEquipo,
  IconEmpleados, IconPuestos, IconHorarios, IconSueldos, IconUsuarios, IconPerfiles,
  IconPermisos, IconMetodosPago, IconPagos, IconRegistro, IconReportes,
} from './icons';
import './Sidebar.css';

// 'modulo' es el código que usa el backend para decidir el acceso
// (ver_<modulo> / gestionar_<modulo>).

// Inicio va sola, fuera de las secciones
const ITEM_INICIO = { to: '/', label: 'Inicio', icon: IconInicio, end: true };

// El resto del menú está agrupado en secciones. Al hacer click en el nombre de una sección
// se despliegan sus pantallas debajo. Una sección que se abrió queda abierta: abrir otra
// no cierra las que ya estaban abiertas.
// Si el perfil no tiene permiso para ninguna pantalla de una sección, la sección no se muestra.
const NAV_GRUPOS = [
  {
    id: 'reservas', label: 'Reservas', icon: IconReservas,
    items: [
      { to: '/reservas', label: 'Reservas', icon: IconReservas, modulo: 'reservas' },
      { to: '/clientes', label: 'Clientes', icon: IconClientes, modulo: 'clientes' },
      { to: '/servicios', label: 'Servicios', icon: IconServicios, modulo: 'servicios' },
    ],
  },
  {
    id: 'equipos', label: 'Equipos', icon: IconEquipos,
    items: [
      { to: '/equipos', label: 'Equipos', icon: IconEquipos, modulo: 'equipos' },
      { to: '/tipos-equipo', label: 'Tipos de equipo', icon: IconTiposEquipo, modulo: 'tipos_equipo' },
      { to: '/estados-equipo', label: 'Estados de equipo', icon: IconEstadosEquipo, modulo: 'estados_equipo' },
    ],
  },
  {
    id: 'empleados', label: 'Empleados', icon: IconEmpleados,
    items: [
      { to: '/empleados', label: 'Empleados', icon: IconEmpleados, modulo: 'empleados' },
      { to: '/puestos', label: 'Puestos', icon: IconPuestos, modulo: 'puestos' },
      { to: '/horarios', label: 'Horarios', icon: IconHorarios, modulo: 'horarios' },
      { to: '/sueldos', label: 'Sueldos', icon: IconSueldos, modulo: 'sueldos' },
    ],
  },
  {
    id: 'usuarios', label: 'Usuarios', icon: IconUsuarios,
    items: [
      { to: '/usuarios', label: 'Usuarios', icon: IconUsuarios, modulo: 'usuarios' },
      { to: '/perfiles', label: 'Perfiles', icon: IconPerfiles, modulo: 'perfiles' },
      { to: '/permisos', label: 'Permisos', icon: IconPermisos, modulo: 'permisos' },
    ],
  },
  {
    id: 'pagos', label: 'Pagos', icon: IconPagos,
    items: [
      { to: '/pagos', label: 'Pagos', icon: IconPagos, modulo: 'pagos' },
      { to: '/metodos-pago', label: 'Métodos de pago', icon: IconMetodosPago, modulo: 'metodos_pago' },
    ],
  },
  {
    id: 'actividad', label: 'Actividad', icon: IconReportes,
    items: [
      // Solo lo ven los perfiles con el permiso "Ver Reportes" (por defecto, el Administrador)
      { to: '/reportes', label: 'Reportes', icon: IconReportes, modulo: 'reportes' },
      // Solo lo ven los perfiles con el permiso "Ver Registro de actividad" (por defecto, el Administrador)
      { to: '/registro', label: 'Registro de actividad', icon: IconRegistro, modulo: 'registro' },
    ],
  },
];

// Ids de las secciones que tienen una pantalla de la URL actual (ej: "/reservas/nueva" -> ['reservas']).
// Sirve para que, si se entra a una pantalla por otro camino (recargando la página, o con un
// botón de otra pantalla), su sección aparezca abierta y se vea cuál es la actual.
function gruposDeRuta(pathname) {
  return NAV_GRUPOS
    .filter((g) => g.items.some((i) => pathname === i.to || pathname.startsWith(`${i.to}/`)))
    .map((g) => g.id);
}

// Mismos cortes que en Sidebar.css: entre el celular y 1024px el menú muestra solo
// los íconos y el nombre aparece en un cartelito (tooltip). En el celular (hasta
// 640px) el menú se abre completo, con los nombres, desde el botón de la barra de arriba.
const MEDIA_COMPACTO = '(min-width: 641px) and (max-width: 1024px)';

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

// abierto: solo importa en el celular, donde el menú va escondido (lo maneja Layout.jsx)
export default function Sidebar({ abierto = false }) {
  const { usuario } = useAuth();
  const { pathname } = useLocation();
  const permisos = usuario?.permisos || [];
  const compacto = useMenuCompacto();

  // Secciones desplegadas. Solo se les agregan ids: nunca se quitan.
  const [gruposAbiertos, setGruposAbiertos] = useState(() => gruposDeRuta(pathname));
  const [rutaAnterior, setRutaAnterior] = useState(pathname);
  if (rutaAnterior !== pathname) {
    // Cambió la pantalla: se abre la sección que la contiene (las que ya estaban abiertas siguen igual)
    setRutaAnterior(pathname);
    setGruposAbiertos((previos) => [...new Set([...previos, ...gruposDeRuta(pathname)])]);
  }

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

  function abrirGrupo(id) {
    // Al abrirse la sección el menú se reacomoda, así que el cartelito quedaría mal ubicado
    ocultarTooltip();
    setGruposAbiertos((previos) => (previos.includes(id) ? previos : [...previos, id]));
  }

  // Eventos que muestran el nombre en un cartelito (modo compacto). Los usan los enlaces
  // y los encabezados de sección.
  const eventosTooltip = (label) => ({
    onMouseEnter: (e) => mostrarTooltip(e, label),
    onMouseLeave: () => ocultarTooltip(),
    onFocus: (e) => mostrarTooltip(e, label),
    onBlur: () => ocultarTooltip(),
    // En celular/tablet: al mantener apretado aparece el nombre,
    // y se va solo un momento después de soltar.
    onTouchStart: (e) => mostrarTooltip(e, label),
    onTouchEnd: () => ocultarTooltip(1200),
    onContextMenu: (e) => compacto && e.preventDefault(),
  });

  function renderEnlace(item) {
    const Icono = item.icon;
    return (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end}
        aria-label={item.label}
        className={({ isActive }) => 'sidebar-link' + (isActive ? ' active' : '')}
        {...eventosTooltip(item.label)}
      >
        <Icono className="sidebar-icon" aria-hidden="true" />
        <span className="sidebar-label">{item.label}</span>
      </NavLink>
    );
  }

  return (
    <aside className={`sidebar${abierto ? ' abierto' : ''}`}>
      <nav className="sidebar-nav" onScroll={() => ocultarTooltip()}>
        {renderEnlace(ITEM_INICIO)}

        {NAV_GRUPOS.map((grupo) => {
          const items = grupo.items.filter((item) => puedeVer(item.modulo));
          if (items.length === 0) return null;
          const Icono = grupo.icon;
          const desplegado = gruposAbiertos.includes(grupo.id);
          return (
            <Fragment key={grupo.id}>
              <button
                type="button"
                className="sidebar-link sidebar-grupo"
                aria-expanded={desplegado}
                aria-controls={`submenu-${grupo.id}`}
                onClick={() => abrirGrupo(grupo.id)}
                {...eventosTooltip(grupo.label)}
              >
                <Icono className="sidebar-icon" aria-hidden="true" />
                <span className="sidebar-label">{grupo.label}</span>
              </button>

              {desplegado && (
                <div
                  id={`submenu-${grupo.id}`}
                  className="sidebar-submenu"
                  role="group"
                  aria-label={grupo.label}
                  style={{ '--filas': items.length }}
                >
                  {items.map(renderEnlace)}
                </div>
              )}
            </Fragment>
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
