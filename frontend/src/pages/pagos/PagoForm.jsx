import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SelectBuscable from '../../components/SelectBuscable';
import SuccessModal from '../../components/SuccessModal';
import { IconVolver } from '../../components/icons';

const VACIO = { id_reserva: '', monto: '' };

// Formulario de Pagos (alta y edición): la reserva, el monto y con qué métodos se pagó.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function PagoForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [reservas, setReservas] = useState([]);
  const [metodos, setMetodos] = useState([]);
  const [form, setForm] = useState(VACIO);
  // Métodos de pago tildados (un pago puede tener más de uno)
  const [metodosSel, setMetodosSel] = useState(new Set());
  // Errores que devuelve el backend, por campo (ej: { telefono_emp: ["..."] })
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);
  // Al editar: reserva y monto que tenía el pago antes de cambiarlo (para calcular bien el saldo)
  const [pagoOriginal, setPagoOriginal] = useState(null);

  // Al abrir: reservas y métodos de pago para elegir y, si se está editando, los datos del pago
  useEffect(() => {
    Promise.all([
      api.get('/reservas/'),
      api.get('/metodos-pago/'),
      editando ? api.get(`/pagos/${id}/`) : Promise.resolve(null),
    ]).then(([reservasRes, metodosRes, pagoRes]) => {
      setReservas(reservasRes.data);
      // Solo se muestran para elegir los métodos de pago activos. Los desactivados aparecen
      // únicamente si el pago que se está editando ya los tenía, así se pueden ver y destildar.
      const metodosDelPago = new Set((pagoRes?.data.metodos_pago_detalle || []).map((m) => Number(m.id_metodo_pago)));
      setMetodos(metodosRes.data.filter((m) => m.activo || metodosDelPago.has(Number(m.id_metodo_pago))));

      if (pagoRes) {
        const p = pagoRes.data;
        setForm({ id_reserva: p.id_reserva, monto: p.monto });
        setPagoOriginal({ id_reserva: p.id_reserva, monto: Number(p.monto), activo: !p.anulado });
        setMetodosSel(new Set(p.metodos_pago_detalle.map((m) => Number(m.id_metodo_pago))));
      }
      setCargando(false);
    });
  }, [id, editando]);

  // Cambia un solo campo del formulario y deja los demás como estaban
  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Tilda o destilda un método de pago
  function toggleMetodo(idMetodo) {
    const mid = Number(idMetodo);
    setMetodosSel((prev) => {
      const next = new Set(prev);
      next.has(mid) ? next.delete(mid) : next.add(mid);
      return next;
    });
  }

  // Reserva elegida, para mostrar cliente y evento como subtítulo de la ventana
  const reservaSeleccionada = reservas.find((r) => String(r.id_reserva) === String(form.id_reserva));
  const subtitulo = reservaSeleccionada
    ? `${reservaSeleccionada.cliente_nombre}${reservaSeleccionada.nombre_evento ? ' · ' + reservaSeleccionada.nombre_evento : ''}`
    : undefined;

  // Lo que falta pagar de una reserva. Al editar, el monto que ya tenía este mismo pago no se
  // descuenta (se va a reemplazar por el nuevo), igual que lo calcula el backend.
  function saldoDe(r) {
    let saldo = Number(r.pagos_detalle?.saldo ?? r.monto_total);
    if (pagoOriginal?.activo && String(pagoOriginal.id_reserva) === String(r.id_reserva)) {
      saldo = Math.min(saldo + pagoOriginal.monto, Number(r.monto_total));
    }
    return saldo;
  }
  const pesos = (n) => `$${Number(n).toLocaleString('es-AR')}`;

  // Guardar: si se está editando hace PUT y muestra la ventana de éxito; si es un alta hace
  // POST y vuelve a la lista. Si el backend rechaza los datos (400), se muestran sus errores.
  async function handleSubmit(e) {
    e.preventDefault();
    // Sin ningún método de pago tildado no se manda nada (el backend también lo controla)
    if (metodosSel.size === 0) {
      setErrores({ metodos_pago: 'Elegí al menos un método de pago.' });
      return;
    }
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

  // Mientras se traen los datos del registro a editar
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

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="id_reserva">Reserva</label>
        {/* Se puede escribir el nombre o apellido del cliente (o el evento) para filtrar la lista */}
        <SelectBuscable
          id="id_reserva"
          opciones={reservas.map((r) => ({
            value: r.id_reserva,
            label: `${r.cliente_nombre}${r.nombre_evento ? ` · ${r.nombre_evento}` : ''} — Saldo pendiente ${pesos(saldoDe(r))}`,
          }))}
          value={form.id_reserva}
          onChange={(valor) => actualizar('id_reserva', valor)}
          placeholder="Escribí el nombre o apellido del cliente..."
          sinResultados="No hay reservas de ese cliente."
          required
        />
        {/* Resumen de la reserva elegida: cuánto sale, cuánto se pagó y cuánto falta */}
        {reservaSeleccionada && (
          <p className="form-hint">
            Total {pesos(reservaSeleccionada.monto_total)} · Pagado{' '}
            {pesos(Number(reservaSeleccionada.monto_total) - saldoDe(reservaSeleccionada))} ·{' '}
            <b>Saldo pendiente {pesos(saldoDe(reservaSeleccionada))}</b>
          </p>
        )}
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
        {errores.metodos_pago && <span className="form-error">{errores.metodos_pago}</span>}
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear pago'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/pagos')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
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
        {/* Flecha para volver a la lista de pagos, al lado del título */}
        <div className="titulo-con-volver">
          <button type="button" className="btn-volver" onClick={() => navigate('/pagos')} title="Volver a Pagos" aria-label="Volver a Pagos">
            <IconVolver />
          </button>
          <h1>Nuevo Pago</h1>
        </div>
      </div>
      {/* Sin ancho máximo: el formulario ocupa todo el ancho de la sección, igual que la lista */}
      <div className="card" style={{ padding: 28 }}>
        {formulario}
      </div>
    </div>
  );
}