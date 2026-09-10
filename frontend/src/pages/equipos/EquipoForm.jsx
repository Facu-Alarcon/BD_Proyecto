import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function EquipoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();
  const [guardadoOk, setGuardadoOk] = useState(false);

  const [tipos, setTipos] = useState([]);
  const [estados, setEstados] = useState([]);
  const [form, setForm] = useState({
    nombre_equipo: '',
    id_tipoeq: '',
    id_estadoeq: '',
    cantidad_equipo: 1,
  });
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);

  const [mostrarNuevoEstado, setMostrarNuevoEstado] = useState(false);
  const [nuevoEstado, setNuevoEstado] = useState('');
  const [guardandoEstado, setGuardandoEstado] = useState(false);
  const [errorEstado, setErrorEstado] = useState('');

  function cargarEstados() {
    return api.get('/estado-equipos/').then(({ data }) => {
      setEstados(data);
      return data;
    });
  }

  useEffect(() => {
    api.get('/tipo-equipos/').then(({ data }) => setTipos(data));
    cargarEstados();
  }, []);

  useEffect(() => {
    if (!editando) return;
    api.get(`/equipos/${id}/`).then(({ data }) => {
      setForm({
        nombre_equipo: data.nombre_equipo,
        id_tipoeq: data.id_tipoeq,
        id_estadoeq: data.id_estadoeq,
        cantidad_equipo: data.cantidad_equipo,
      });
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  async function agregarEstado(e) {
    e.preventDefault();
    if (!nuevoEstado.trim()) return;
    setGuardandoEstado(true);
    setErrorEstado('');
    try {
      const { data } = await api.post('/estado-equipos/', { nombre_estadoeq: nuevoEstado.trim() });
      await cargarEstados();
      actualizar('id_estadoeq', data.id_estadoeq);
      setNuevoEstado('');
      setMostrarNuevoEstado(false);
    } catch (err) {
      setErrorEstado(err.response?.data?.nombre_estadoeq?.[0] || 'No se pudo agregar el estado.');
    } finally {
      setGuardandoEstado(false);
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        await api.put(`/equipos/${id}/`, form);
        setGuardadoOk(true);
      } else {
        await api.post('/equipos/', form);
        navigate('/equipos');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el equipo.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Equipo modificado correctamente"
        subtitulo={form.nombre_equipo}
        textoBoton="Volver a equipos"
        onContinuar={() => navigate('/equipos')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="nombre_equipo">Nombre del Equipo</label>
        <input
          id="nombre_equipo"
          placeholder="Ej: Parlante JBL 15 pulgadas"
          value={form.nombre_equipo}
          onChange={(e) => actualizar('nombre_equipo', e.target.value)}
          required
        />
        {errores.nombre_equipo && <span className="form-error">{errores.nombre_equipo}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="id_tipoeq">Tipo de Equipo</label>
        <select
          id="id_tipoeq"
          value={form.id_tipoeq}
          onChange={(e) => actualizar('id_tipoeq', e.target.value)}
          required
        >
          <option value="">Seleccionar...</option>
          {tipos.map((t) => (
            <option key={t.id_tipoeq} value={t.id_tipoeq}>{t.nombre_tipoeq}</option>
          ))}
        </select>
        {errores.id_tipoeq && <span className="form-error">{errores.id_tipoeq}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="id_estadoeq">Estado del Equipo</label>
        <div style={{ display: 'flex', gap: 8 }}>
          <select
            id="id_estadoeq"
            value={form.id_estadoeq}
            onChange={(e) => actualizar('id_estadoeq', e.target.value)}
            required
            style={{ flex: 1 }}
          >
            <option value="">Seleccionar...</option>
            {estados.map((estado) => (
              <option key={estado.id_estadoeq} value={estado.id_estadoeq}>{estado.nombre_estadoeq}</option>
            ))}
          </select>
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => setMostrarNuevoEstado((v) => !v)}
            title="Agregar un estado nuevo"
          >
            +
          </button>
        </div>
        {errores.id_estadoeq && <span className="form-error">{errores.id_estadoeq}</span>}

        {mostrarNuevoEstado && (
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <input
              autoFocus
              placeholder="Nombre del estado nuevo (ej: Reservado)"
              value={nuevoEstado}
              onChange={(e) => setNuevoEstado(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') agregarEstado(e);
              }}
              style={{ flex: 1 }}
            />
            <button type="button" className="btn btn-primary btn-sm" onClick={agregarEstado} disabled={guardandoEstado}>
              {guardandoEstado ? 'Agregando...' : 'Agregar'}
            </button>
          </div>
        )}
        {errorEstado && <span className="form-error">{errorEstado}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="cantidad_equipo">Cantidad en Stock</label>
        <input
          id="cantidad_equipo"
          type="number"
          min={0}
          value={form.cantidad_equipo}
          onChange={(e) => actualizar('cantidad_equipo', e.target.value)}
          required
        />
        {errores.cantidad_equipo && <span className="form-error">{errores.cantidad_equipo}</span>}
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear equipo'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/equipos')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar equipo" subtitulo={form.nombre_equipo} onClose={() => navigate('/equipos')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Equipo</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 520 }}>
        {formulario}
      </div>
    </div>
  );
}
