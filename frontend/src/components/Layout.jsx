import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import './Layout.css';

// Estructura de todas las pantallas una vez que se inició sesión: la barra de arriba,
// el menú lateral y, a la derecha, la pantalla que corresponda a la URL (Outlet).
export default function Layout() {
  return (
    <div className="app-root">
      <Topbar />
      <div className="app-shell">
        <Sidebar />
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
