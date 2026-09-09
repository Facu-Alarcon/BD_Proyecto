import { usePermiso } from '../hooks/usePermiso';

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
