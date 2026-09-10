import { BrowserRouter, Navigate, Outlet, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import RequierePermiso from './components/RequierePermiso';
import Layout from './components/Layout';
import Login from './pages/Login';
import Inicio from './pages/Inicio';
import Placeholder from './pages/Placeholder';

import EquiposList from './pages/equipos/EquiposList';
import EquipoForm from './pages/equipos/EquipoForm';

import PerfilesList from './pages/perfiles/PerfilesList';
import PerfilForm from './pages/perfiles/PerfilForm';

import PermisosList from './pages/permisos/PermisosList';
import PermisoForm from './pages/permisos/PermisoForm';

import UsuariosList from './pages/usuarios/UsuariosList';
import UsuarioForm from './pages/usuarios/UsuarioForm';

import ClientesList from './pages/clientes/ClientesList';
import ClienteForm from './pages/clientes/ClienteForm';

import EmpleadosList from './pages/empleados/EmpleadosList';
import EmpleadoForm from './pages/empleados/EmpleadoForm';

import SueldosList from './pages/sueldos/SueldosList';
import SueldoForm from './pages/sueldos/SueldoForm';

import PuestosList from './pages/puestos/PuestosList';
import PuestoForm from './pages/puestos/PuestoForm';

import ServiciosList from './pages/servicios/ServiciosList';
import ServicioForm from './pages/servicios/ServicioForm';

import ReservasList from './pages/reservas/ReservasList';
import ReservaForm from './pages/reservas/ReservaForm';

const PROXIMAMENTE = [
  { path: 'tipos-equipo', titulo: 'Tipos de equipo' },
  { path: 'horarios', titulo: 'Horarios' },
  { path: 'metodos-pago', titulo: 'Métodos de pago' },
  { path: 'pagos', titulo: 'Pagos' },
];

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Inicio />} />

            <Route path="equipos" element={<RequierePermiso modulo="equipos"><Outlet /></RequierePermiso>}>
              <Route index element={<EquiposList />} />
              <Route path="nuevo" element={<EquipoForm />} />
              <Route path=":id/editar" element={<EquipoForm />} />
            </Route>

            <Route path="perfiles" element={<RequierePermiso modulo="perfiles"><Outlet /></RequierePermiso>}>
              <Route index element={<PerfilesList />} />
              <Route path="nuevo" element={<PerfilForm />} />
              <Route path=":id/editar" element={<PerfilForm />} />
            </Route>

            <Route path="permisos" element={<RequierePermiso modulo="permisos"><Outlet /></RequierePermiso>}>
              <Route index element={<PermisosList />} />
              <Route path="nuevo" element={<PermisoForm />} />
              <Route path=":id/editar" element={<PermisoForm />} />
            </Route>

            <Route path="usuarios" element={<RequierePermiso modulo="usuarios"><Outlet /></RequierePermiso>}>
              <Route index element={<UsuariosList />} />
              <Route path="nuevo" element={<UsuarioForm />} />
              <Route path=":id/editar" element={<UsuarioForm />} />
            </Route>

            <Route path="clientes" element={<RequierePermiso modulo="clientes"><Outlet /></RequierePermiso>}>
              <Route index element={<ClientesList />} />
              <Route path="nuevo" element={<ClienteForm />} />
              <Route path=":id/editar" element={<ClienteForm />} />
            </Route>

            <Route path="empleados" element={<RequierePermiso modulo="empleados"><Outlet /></RequierePermiso>}>
              <Route index element={<EmpleadosList />} />
              <Route path="nuevo" element={<EmpleadoForm />} />
              <Route path=":id/editar" element={<EmpleadoForm />} />
            </Route>

            <Route path="sueldos" element={<RequierePermiso modulo="sueldos"><Outlet /></RequierePermiso>}>
              <Route index element={<SueldosList />} />
              <Route path="nuevo" element={<SueldoForm />} />
              <Route path=":id/editar" element={<SueldoForm />} />
            </Route>

            <Route path="puestos" element={<RequierePermiso modulo="puestos"><Outlet /></RequierePermiso>}>
              <Route index element={<PuestosList />} />
              <Route path="nuevo" element={<PuestoForm />} />
              <Route path=":id/editar" element={<PuestoForm />} />
            </Route>

            <Route path="servicios" element={<RequierePermiso modulo="servicios"><Outlet /></RequierePermiso>}>
              <Route index element={<ServiciosList />} />
              <Route path="nuevo" element={<ServicioForm />} />
              <Route path=":id/editar" element={<ServicioForm />} />
            </Route>

            <Route path="reservas" element={<RequierePermiso modulo="reservas"><Outlet /></RequierePermiso>}>
              <Route index element={<ReservasList />} />
              <Route path="nueva" element={<ReservaForm />} />
              <Route path=":id/editar" element={<ReservaForm />} />
            </Route>

            {PROXIMAMENTE.map((m) => (
              <Route key={m.path} path={m.path} element={<Placeholder titulo={m.titulo} />} />
            ))}

            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
