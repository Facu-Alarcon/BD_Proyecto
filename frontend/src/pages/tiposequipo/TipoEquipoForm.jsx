import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Tipos de equipo (alta y edición): solo el nombre.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function TipoEquipoForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [nombre, setNombre] = useState('');
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
    api.get(`/tipo-equipos/${id}/`).then(({ data }) => {
      setNombre(data.nombre_tipoeq);
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

  // Mientras se traen los datos del registro a editar
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

  // Los campos del formulario (los mismos para crear y para editar)
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

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
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