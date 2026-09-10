import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function ServicioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState({ tipo_servicio: '', precio_servicio: '' });
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/servicios/${id}/`).then(({ data }) => {
      setForm(data);
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        await api.put(`/servicios/${id}/`, form);
        setGuardadoOk(true);
      } else {
        await api.post('/servicios/', form);
        navigate('/servicios');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el servicio.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Servicio modificado correctamente"
        subtitulo={form.tipo_servicio}
        textoBoton="Volver a servicios"
        onContinuar={() => navigate('/servicios')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="tipo_servicio">Nombre del Servicio</label>
        <input id="tipo_servicio" placeholder="Ej: Sonido e iluminación" value={form.tipo_servicio} onChange={(e) => actualizar('tipo_servicio', e.target.value)} required />
        {errores.tipo_servicio && <span className="form-error">{errores.tipo_servicio}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="precio_servicio">Precio</label>
        <input id="precio_servicio" placeholder="Ej: 50000" type="number" step="0.01" min="0" value={form.precio_servicio} onChange={(e) => actualizar('precio_servicio', e.target.value)} required />
        {errores.precio_servicio && <span className="form-error">{errores.precio_servicio}</span>}
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear servicio'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/servicios')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar servicio" subtitulo={form.tipo_servicio} onClose={() => navigate('/servicios')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Servicio</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        {formulario}
      </div>
    </div>
  );
}
