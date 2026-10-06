import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Sueldos (alta y edición): solo el monto.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function SueldoForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [monto, setMonto] = useState('');
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
    api.get(`/sueldos/${id}/`).then(({ data }) => {
      setMonto(data.monto_sueldo);
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
      const payload = { monto_sueldo: monto };
      if (editando) {
        await api.put(`/sueldos/${id}/`, payload);
        setGuardadoOk(true);
      } else {
        await api.post('/sueldos/', payload);
        navigate('/sueldos');
      }
    } catch (err) {
      setError(err.response?.data?.monto_sueldo?.[0] || 'No se pudo guardar el sueldo.');
    } finally {
      setGuardando(false);
    }
  }

  // Mientras se traen los datos del registro a editar
  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Sueldo modificado correctamente"
        subtitulo={`$${Number(monto).toLocaleString('es-AR')}`}
        textoBoton="Volver a sueldos"
        onContinuar={() => navigate('/sueldos')}
      />
    );
  }

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="form-field">
        <label htmlFor="monto_sueldo">Monto</label>
        <input
          id="monto_sueldo"
          placeholder="Ej: 450000"
          type="number"
          step="0.01"
          min="0"
          value={monto}
          onChange={(e) => setMonto(e.target.value)}
          required
        />
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear sueldo'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/sueldos')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar sueldo" onClose={() => navigate('/sueldos')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Sueldo</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 420 }}>
        {formulario}
      </div>
    </div>
  );
}
