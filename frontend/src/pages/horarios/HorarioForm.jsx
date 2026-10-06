import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Horarios (alta y edición): solo la cantidad de horas.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function HorarioForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [horas, setHoras] = useState('');
  // Como el formulario tiene un solo campo, alcanza con un solo mensaje de error
  const [error, setError] = useState('');
  // Al editar arranca en "cargando" hasta que llegan los datos del registro
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);

  // Al editar: se trae el registro y se carga su valor en el campo
  useEffect(() => {
    if (!editando) return;
    api.get(`/horarios/${id}/`).then(({ data }) => {
      setHoras(String(data.cantidad_horas));
      setCargando(false);
    });
  }, [id, editando]);

  // Guardar: si se está editando hace PUT y muestra la ventana de éxito; si es un alta hace
  // POST y vuelve a la lista. Si el backend rechaza los datos (400), se muestran sus errores.
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

  // Mientras se traen los datos del registro a editar
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

  // Los campos del formulario (los mismos para crear y para editar)
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

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
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