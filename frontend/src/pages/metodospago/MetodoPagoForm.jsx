import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Métodos de pago (alta y edición): solo el nombre.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function MetodoPagoForm() {
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
    api.get(`/metodos-pago/${id}/`).then(({ data }) => {
      setNombre(data.metodo_pago);
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
      const payload = { metodo_pago: nombre };
      if (editando) {
        await api.put(`/metodos-pago/${id}/`, payload);
        setGuardadoOk(true);
      } else {
        await api.post('/metodos-pago/', payload);
        navigate('/metodos-pago');
      }
    } catch (err) {
      setError(err.response?.data?.metodo_pago?.[0] || 'No se pudo guardar el método de pago.');
    } finally {
      setGuardando(false);
    }
  }

  // Mientras se traen los datos del registro a editar
  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Método de pago modificado correctamente"
        subtitulo={nombre}
        textoBoton="Volver a métodos de pago"
        onContinuar={() => navigate('/metodos-pago')}
      />
    );
  }

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="form-field">
        <label htmlFor="metodo_pago">Nombre</label>
        <input
          id="metodo_pago"
          placeholder="Ej: Efectivo, Transferencia, Tarjeta..."
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          required
        />
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear método de pago'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/metodos-pago')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar método de pago" onClose={() => navigate('/metodos-pago')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Método de pago</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 420 }}>
        {formulario}
      </div>
    </div>
  );
}