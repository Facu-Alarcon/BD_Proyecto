import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Topbar from './Topbar';
import './Layout.css';

export default function Layout() {
  return (
    <div className="app-root">
      <Topbar />
      <div className="app-shell">
        <Sidebar />
        {/* main es la única parte que scrollea; adentro, app-content centra el contenido */}
        <main className="app-main">
          <div className="app-content">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
