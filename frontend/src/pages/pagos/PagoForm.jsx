import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

const VACIO = { id_reserva: '', monto: '' };

export default function PagoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [reservas, setReservas] = useState([]);
  const [metodos, setMetodos] = useState([]);
  const [form, setForm] = useState(VACIO);
  const [metodosSel, setMetodosSel] = useState(new Set());
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    Promise.all([
      api.get('/reservas/'),
      api.get('/metodos-pago/'),
      editando ? api.get(`/pagos/${id}/`) : Promise.resolve(null),
    ]).then(([reservasRes, metodosRes, pagoRes]) => {
      setReservas(reservasRes.data);
      setMetodos(metodosRes.data);

      if (pagoRes) {
        const p = pagoRes.data;
        setForm({ id_reserva: p.id_reserva, monto: p.monto });
        setMetodosSel(new Set(p.metodos_pago_detalle.map((m) => Number(m.id_metodo_pago))));
      }
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  function toggleMetodo(idMetodo) {
    const mid = Number(idMetodo);
    setMetodosSel((prev) => {
      const next = new Set(prev);
      next.has(mid) ? next.delete(mid) : next.add(mid);
      return next;
    });
  }

  const reservaSeleccionada = reservas.find((r) => String(r.id_reserva) === String(form.id_reserva));
  const subtitulo = reservaSeleccionada
    ? `${reservaSeleccionada.cliente_nombre}${reservaSeleccionada.nombre_evento ? ' · ' + reservaSeleccionada.nombre_evento : ''}`
    : undefined;

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    const payload = { ...form, metodos_pago: Array.from(metodosSel) };
    try {
      if (editando) {
        await api.put(`/pagos/${id}/`, payload);
        setGuardadoOk(true);
      } else {
        await api.post('/pagos/', payload);
        navigate('/pagos');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el pago.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Pago modificado correctamente"
        subtitulo={subtitulo}
        textoBoton="Volver a pagos"
        onContinuar={() => navigate('/pagos')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="id_reserva">Reserva</label>
        <select id="id_reserva" value={form.id_reserva} onChange={(e) => actualizar('id_reserva', e.target.value)} required>
          <option value="">Seleccionar...</option>
          {reservas.map((r) => (
            <option key={r.id_reserva} value={r.id_reserva}>
              {r.cliente_nombre}{r.nombre_evento ? ` · ${r.nombre_evento}` : ''} — ${Number(r.monto_total).toLocaleString('es-AR')}
            </option>
          ))}
        </select>
        {errores.id_reserva && <span className="form-error">{errores.id_reserva}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="monto">Monto del pago</label>
        <input
          id="monto"
          type="number"
          step="0.01"
          min="0.01"
          placeholder="Ej: 50000 (seña) o el total de la reserva"
          value={form.monto}
          onChange={(e) => actualizar('monto', e.target.value)}
          required
        />
        {errores.monto && <span className="form-error">{errores.monto}</span>}
      </div>

      <div className="form-field">
        <label>Método(s) de pago</label>
        <div className="checkbox-list">
          {metodos.length === 0 && <p className="form-hint">No hay métodos de pago cargados todavía.</p>}
          {metodos.map((m) => (
            <label key={m.id_metodo_pago}>
              <span>{m.metodo_pago}</span>
              <input type="checkbox" checked={metodosSel.has(Number(m.id_metodo_pago))} onChange={() => toggleMetodo(m.id_metodo_pago)} />
            </label>
          ))}
        </div>
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear pago'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/pagos')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar pago" subtitulo={subtitulo} onClose={() => navigate('/pagos')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Pago</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 520 }}>
        {formulario}
      </div>
    </div>
  );
}