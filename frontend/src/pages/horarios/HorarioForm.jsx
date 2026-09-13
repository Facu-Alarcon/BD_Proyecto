import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function HorarioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [horas, setHoras] = useState('');
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/horarios/${id}/`).then(({ data }) => {
      setHoras(String(data.cantidad_horas));
      setCargando(false);
    });
  }, [id, editando]);

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setError('');
    try {
      const payload = { cantidad_horas: horas };
      if (editando) {
        await api.put(`/horarios/${id}/`, payload);
        setGuardadoOk(true);
      } else {
        await api.post('/horarios/', payload);
        navigate('/horarios');
      }
    } catch (err) {
      setError(err.response?.data?.cantidad_horas?.[0] || 'No se pudo guardar el horario.');
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Horario modificado correctamente"
        subtitulo={`${horas} hs`}
        textoBoton="Volver a horarios"
        onContinuar={() => navigate('/horarios')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="form-field">
        <label htmlFor="cantidad_horas">Cantidad de horas</label>
        <input
          id="cantidad_horas"
          type="number"
          min="1"
          max="24"
          step="1"
          placeholder="Ej: 8"
          value={horas}
          onChange={(e) => setHoras(e.target.value)}
          required
        />
        <span className="form-hint">Entre 1 y 24 horas (un día tiene 24hs).</span>
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear horario'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/horarios')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar horario" onClose={() => navigate('/horarios')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Horario</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 420 }}>
        {formulario}
      </div>
    </div>
  );
}