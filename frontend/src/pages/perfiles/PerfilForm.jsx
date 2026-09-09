import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';

export default function PerfilForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [tipoPerfil, setTipoPerfil] = useState('');
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/perfiles/${id}/`).then(({ data }) => {
      setTipoPerfil(data.tipo_perfil);
      setCargando(false);
    });
  }, [id, editando]);

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setError('');
    try {
      const payload = { tipo_perfil: tipoPerfil };
      if (editando) {
        await api.put(`/perfiles/${id}/`, payload);
      } else {
        await api.post('/perfiles/', payload);
      }
      navigate('/perfiles');
    } catch (err) {
      setError(err.response?.data?.tipo_perfil?.[0] || 'No se pudo guardar el perfil.');
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>{editando ? 'Editar Perfil' : 'Nuevo Perfil'}</h1>
        </div>
      </div>

      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        <form onSubmit={handleSubmit}>
          {error && <div className="alert alert-error">{error}</div>}

          <div className="form-field">
            <label htmlFor="tipo_perfil">Nombre del Perfil</label>
            <input
              id="tipo_perfil"
              value={tipoPerfil}
              onChange={(e) => setTipoPerfil(e.target.value)}
              required
            />
          </div>

          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>{' '}
          <button type="button" className="btn btn-secondary" onClick={() => navigate('/perfiles')}>
            Cancelar
          </button>
        </form>
      </div>
    </div>
  );
}
