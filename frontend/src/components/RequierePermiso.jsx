import { usePermiso } from '../hooks/usePermiso';

// Envuelve las pantallas de cada módulo (ver App.jsx). Si el perfil del usuario no puede
// ver ese módulo, en lugar de la pantalla muestra un aviso de acceso restringido.
// Es solo para la vista: el backend igual rechaza los pedidos sin permiso.
export default function RequierePermiso({ modulo, children }) {
  const { puedeVer } = usePermiso(modulo);

  if (!puedeVer) {
    return (
      <div className="card" style={{ padding: 40, textAlign: 'center' }}>
        <h2 style={{ marginTop: 0 }}>Acceso restringido</h2>
        <p className="form-hint">Tu perfil no tiene permiso para ver este módulo. Pedile a un administrador que te lo asigne.</p>
      </div>
    );
  }

  return children;
}
