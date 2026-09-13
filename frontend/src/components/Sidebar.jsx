import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Sidebar.css';

// 'modulo' es el código que usa el backend para decidir el acceso
// (ver_<modulo> / gestionar_<modulo>).
const NAV_ITEMS = [
  { to: '/', label: 'Inicio', end: true },
  { to: '/clientes', label: 'Clientes', modulo: 'clientes' },
  { to: '/reservas', label: 'Reservas', modulo: 'reservas' },
  { to: '/servicios', label: 'Servicios', modulo: 'servicios' },
  { to: '/equipos', label: 'Equipos', modulo: 'equipos' },
  { to: '/tipos-equipo', label: 'Tipos de equipo', modulo: 'tipos_equipo' },
  { to: '/empleados', label: 'Empleados', modulo: 'empleados' },
  { to: '/puestos', label: 'Puestos', modulo: 'puestos' },
  { to: '/horarios', label: 'Horarios', modulo: 'horarios' },
  { to: '/sueldos', label: 'Sueldos', modulo: 'sueldos' },
  { to: '/usuarios', label: 'Usuarios', modulo: 'usuarios' },
  { to: '/perfiles', label: 'Perfiles', modulo: 'perfiles' },
  { to: '/permisos', label: 'Permisos', modulo: 'permisos' },
  { to: '/metodos-pago', label: 'Métodos de pago', modulo: 'metodos_pago' },
  { to: '/pagos', label: 'Pagos', modulo: 'pagos' },
];

export default function Sidebar() {
  const { usuario } = useAuth();
  const permisos = usuario?.permisos || [];

  const puedeVer = (modulo) =>
    !modulo || permisos.includes(`ver_${modulo}`) || permisos.includes(`gestionar_${modulo}`);

  return (
    <aside className="sidebar">
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
    </aside>
  );
}