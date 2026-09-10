import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function SueldoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [monto, setMonto] = useState('');
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/sueldos/${id}/`).then(({ data }) => {
      setMonto(data.monto_sueldo);
      setCargando(false);
    });
  }, [id, editando]);

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
