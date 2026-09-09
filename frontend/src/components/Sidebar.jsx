import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Sidebar.css';

// 'modulo' es el código que usa el backend para decidir el acceso
// (ver_<modulo> / gestionar_<modulo>). Los ítems sin 'modulo' son
// módulos que todavía no tienen backend, así que se muestran siempre
// como "próximamente" (no hay nada real que proteger ahí todavía).
const NAV_ITEMS = [
  { to: '/', label: 'Inicio', end: true },
  { to: '/clientes', label: 'Clientes', modulo: 'clientes' },
  { to: '/reservas', label: 'Reservas', modulo: 'reservas' },
  { to: '/servicios', label: 'Servicios', modulo: 'servicios' },
  { to: '/equipos', label: 'Equipos', modulo: 'equipos' },
  { to: '/tipos-equipo', label: 'Tipos de equipo' },
  { to: '/empleados', label: 'Empleados', modulo: 'empleados' },
  { to: '/puestos', label: 'Puestos' },
  { to: '/horarios', label: 'Horarios' },
  { to: '/sueldos', label: 'Sueldos' },
  { to: '/usuarios', label: 'Usuarios', modulo: 'usuarios' },
  { to: '/perfiles', label: 'Perfiles', modulo: 'perfiles' },
  { to: '/permisos', label: 'Permisos', modulo: 'permisos' },
  { to: '/metodos-pago', label: 'Métodos de pago' },
  { to: '/pagos', label: 'Pagos' },
];

export default function Sidebar() {
  const { usuario, logout } = useAuth();
  const permisos = usuario?.permisos || [];

  const puedeVer = (modulo) =>
    !modulo || permisos.includes(`ver_${modulo}`) || permisos.includes(`gestionar_${modulo}`);

  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <span className="sidebar-logo-text">
          INFINITO
          <small>SONIDO E ILUMINACIÓN</small>
        </span>
      </div>

      <nav className="sidebar-nav">
        {NAV_ITEMS.filter((item) => puedeVer(item.modulo)).map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => 'sidebar-link' + (isActive ? ' active' : '')}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-footer">
        <div className="sidebar-user">
          {usuario?.usuario} · {usuario?.perfil_nombre}
        </div>
        <button type="button" className="sidebar-logout" onClick={logout}>
          Cerrar sesión
        </button>
      </div>
    </aside>
  );
}
