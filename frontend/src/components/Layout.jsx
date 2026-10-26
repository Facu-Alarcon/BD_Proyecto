import { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import './Layout.css';

// Estructura de todas las pantallas una vez que se inició sesión: la barra de arriba,
// el menú lateral y, a la derecha, la pantalla que corresponda a la URL (Outlet).
// En el celular el menú no se ve: se abre con el botón de la barra de arriba y se
// cierra solo al elegir una sección o al tocar afuera (ver Sidebar.css).
export default function Layout() {
  const [menuAbierto, setMenuAbierto] = useState(false);
  const { pathname } = useLocation();

  // Al cambiar de pantalla se cierra el menú del celular
  useEffect(() => setMenuAbierto(false), [pathname]);

  return (
    <div className="app-root">
      <Topbar onAbrirMenu={() => setMenuAbierto((v) => !v)} menuAbierto={menuAbierto} />
      <div className="app-shell">
        <Sidebar abierto={menuAbierto} />
        {/* Fondo oscuro detrás del menú abierto en el celular: al tocarlo se cierra */}
        {menuAbierto && <div className="sidebar-fondo" onClick={() => setMenuAbierto(false)} aria-hidden="true" />}
        {/* main es la única parte que scrollea; adentro, app-content centra el contenido */}
        <main className="app-main">
          <div className="app-content">
            {/* Outlet: acá React Router dibuja la pantalla de la ruta actual (Inicio, Clientes, etc.) */}
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
