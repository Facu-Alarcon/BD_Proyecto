import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import { useAuth } from '../../context/AuthContext';

export default function PerfilPermisos() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { usuario } = useAuth();

  const [perfil, setPerfil] = useState(null);
  const [permisos, setPermisos] = useState([]);
  const [seleccionados, setSeleccionados] = useState(new Set());
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);

  const esMiPropioPerfil = usuario?.id_perfil === Number(id);

  useEffect(() => {
    Promise.all([
      api.get(`/perfiles/${id}/`),
      api.get(`/perfiles/${id}/permisos/`),
    ]).then(([perfilRes, permisosRes]) => {
      setPerfil(perfilRes.data);
      setPermisos(permisosRes.data);
      setSeleccionados(new Set(permisosRes.data.filter((p) => p.asignado).map((p) => p.id_permiso)));
      setCargando(false);
    });
  }, [id]);

  function toggle(idPermiso) {
    setSeleccionados((prev) => {
      const next = new Set(prev);
      if (next.has(idPermiso)) next.delete(idPermiso);
      else next.add(idPermiso);
      return next;
    });
  }

  async function guardar(e) {
    e.preventDefault();
    if (esMiPropioPerfil) {
      const seguisTeniendoGestionPerfiles = permisos
        .filter((p) => seleccionados.has(p.id_permiso))
        .some((p) => p.codigo === 'gestionar_perfiles');
      if (!seguisTeniendoGestionPerfiles) {
        const confirmar = window.confirm(
          'Estás por sacarle a tu propio perfil el permiso de "Gestionar Perfiles". ' +
          'Si continuás, no vas a poder volver a esta pantalla vos mismo. ¿Confirmás igual?'
        );
        if (!confirmar) return;
      }
    }

    setGuardando(true);
    try {
      await api.put(`/perfiles/${id}/permisos/`, { permisos: Array.from(seleccionados) });
      navigate('/perfiles');
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Permisos del perfil: {perfil.tipo_perfil}</h1>
          <p>Tildá los permisos que este perfil debe tener habilitados.</p>
        </div>
      </div>

      {esMiPropioPerfil && (
        <div className="alert" style={{ background: 'var(--amber-bg)', color: 'var(--amber)' }}>
          Este es el perfil de tu propio usuario — tené cuidado de no sacarte el acceso a vos mismo.
        </div>
      )}

      <div className="card" style={{ padding: 28, maxWidth: 560 }}>
        <form onSubmit={guardar}>
          {permisos.length === 0 && <p>No hay permisos cargados todavía.</p>}
          {permisos.map((permiso) => (
            <label key={permiso.id_permiso} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0' }}>
              <input
                type="checkbox"
                checked={seleccionados.has(permiso.id_permiso)}
                onChange={() => toggle(permiso.id_permiso)}
              />
              <span>
                {permiso.nombre_permiso}{' '}
                <code style={{ fontSize: 11, color: 'var(--text-muted)' }}>({permiso.codigo})</code>
                {!permiso.estado_permiso && <span className="badge badge-gray" style={{ marginLeft: 8 }}>Inactivo</span>}
              </span>
            </label>
          ))}

          <div style={{ marginTop: 20 }}>
            <button type="submit" className="btn btn-primary" disabled={guardando}>
              {guardando ? 'Guardando...' : 'Guardar Permisos'}
            </button>{' '}
            <button type="button" className="btn btn-secondary" onClick={() => navigate('/perfiles')}>
              Volver
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
