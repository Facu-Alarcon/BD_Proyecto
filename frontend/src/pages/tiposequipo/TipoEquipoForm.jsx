import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function TipoEquipoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [nombre, setNombre] = useState('');
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/tipo-equipos/${id}/`).then(({ data }) => {
      setNombre(data.nombre_tipoeq);
      setCargando(false);
    });
  }, [id, editando]);

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setError('');
    try {
      const payload = { nombre_tipoeq: nombre };
      if (editando) {
        await api.put(`/tipo-equipos/${id}/`, payload);
        setGuardadoOk(true);
      } else {
        await api.post('/tipo-equipos/', payload);
        navigate('/tipos-equipo');
      }
    } catch (err) {
      setError(err.response?.data?.nombre_tipoeq?.[0] || 'No se pudo guardar el tipo de equipo.');
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Tipo de equipo modificado correctamente"
        subtitulo={nombre}
        textoBoton="Volver a tipos de equipo"
        onContinuar={() => navigate('/tipos-equipo')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="form-field">
        <label htmlFor="nombre_tipoeq">Nombre</label>
        <input
          id="nombre_tipoeq"
          placeholder="Ej: Parlante, Micrófono, Consola..."
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          required
        />
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear tipo de equipo'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/tipos-equipo')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar tipo de equipo" onClose={() => navigate('/tipos-equipo')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Tipo de equipo</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 420 }}>
        {formulario}
      </div>
    </div>
  );
}