import { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import BotonMenuLateral from './BotonMenuLateral';
import './Layout.css';

// Estructura de todas las pantallas una vez que se inició sesión: la barra de arriba,
// el menú lateral y, a la derecha, la pantalla que corresponda a la URL (Outlet).
// En el celular el menú no se ve: se abre con el botón de la barra de arriba y se
// cierra solo al elegir una sección o al tocar afuera (ver Sidebar.css).
// En pantallas más grandes el menú se ve siempre, pero se puede esconder con la flechita «
// que tiene arriba de todo. Al esconderlo, el contenido ocupa todo el ancho y queda centrado,
// y a la izquierda aparece el botón "Menú" para volver a mostrarlo (ver BotonMenuLateral.jsx).
export default function Layout() {
  const [menuAbierto, setMenuAbierto] = useState(false);
  // Menú lateral escondido a propósito (solo pantallas grandes y medianas)
  const [menuOculto, setMenuOculto] = useState(false);
  const { pathname } = useLocation();

  // Al cambiar de pantalla se cierra el menú del celular
  useEffect(() => setMenuAbierto(false), [pathname]);

  // La flechita « del menú: en el celular cierra el cajón; en pantallas más grandes esconde
  // el menú (mismo corte de 640px que en Sidebar.css)
  function ocultarMenu() {
    if (window.matchMedia('(max-width: 640px)').matches) setMenuAbierto(false);
    else setMenuOculto(true);
  }

  return (
    <div className="app-root">
      <Topbar onAbrirMenu={() => setMenuAbierto((v) => !v)} menuAbierto={menuAbierto} />
      <div className={`app-shell${menuOculto ? ' menu-oculto' : ''}`}>
        <Sidebar abierto={menuAbierto} onOcultar={ocultarMenu} />
        {/* Fondo oscuro detrás del menú abierto en el celular: al tocarlo se cierra */}
        {menuAbierto && <div className="sidebar-fondo" onClick={() => setMenuAbierto(false)} aria-hidden="true" />}
        {/* main es la única parte que scrollea; adentro, app-content centra el contenido */}
        <main className="app-main">
          {menuOculto && <BotonMenuLateral onMostrar={() => setMenuOculto(false)} />}
          <div className="app-content">
            {/* Outlet: acá React Router dibuja la pantalla de la ruta actual (Inicio, Clientes, etc.) */}
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
