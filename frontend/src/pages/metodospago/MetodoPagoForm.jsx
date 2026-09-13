import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function MetodoPagoForm() {
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
    api.get(`/metodos-pago/${id}/`).then(({ data }) => {
      setNombre(data.metodo_pago);
      setCargando(false);
    });
  }, [id, editando]);

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