import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';

const ESTADOS = [
  { value: 'PENDIENTE', label: 'Pendiente' },
  { value: 'CONFIRMADA', label: 'Confirmada' },
  { value: 'FINALIZADA', label: 'Finalizada' },
  { value: 'CANCELADA', label: 'Cancelada' },
];

const VACIO = {
  id_cliente: '',
  nombre_evento: '',
  fecha_evento: '',
  hora_evento: '',
  direccion_evento: '',
  estado_reserva: 'PENDIENTE',
};

export default function ReservaForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [clientes, setClientes] = useState([]);
  const [servicios, setServicios] = useState([]);
  const [empleados, setEmpleados] = useState([]);
  const [form, setForm] = useState(VACIO);
  const [serviciosSel, setServiciosSel] = useState(new Set());
  const [empleadosSel, setEmpleadosSel] = useState(new Set());
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    Promise.all([
      api.get('/clientes/'),
      api.get('/servicios/'),
      api.get('/empleados/'),
      editando ? api.get(`/reservas/${id}/`) : Promise.resolve(null),
    ]).then(([clientesRes, serviciosRes, empleadosRes, reservaRes]) => {
      setClientes(clientesRes.data);
      setServicios(serviciosRes.data);
      setEmpleados(empleadosRes.data);

      if (reservaRes) {
        const r = reservaRes.data;
        setForm({
          id_cliente: r.id_cliente,
          nombre_evento: r.nombre_evento || '',
          fecha_evento: r.fecha_evento,
          hora_evento: r.hora_evento?.slice(0, 5) || '',
          direccion_evento: r.direccion_evento,
          estado_reserva: r.estado_reserva,
        });
        setServiciosSel(new Set(r.servicios_detalle.map((s) => s.id_servicio)));
        setEmpleadosSel(new Set(r.empleados_detalle.map((e) => e.id_empleado)));
      }
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  function toggleServicio(idServicio) {
    setServiciosSel((prev) => {
      const next = new Set(prev);
      next.has(idServicio) ? next.delete(idServicio) : next.add(idServicio);
      return next;
    });
  }

  function toggleEmpleado(idEmpleado) {
    setEmpleadosSel((prev) => {
      const next = new Set(prev);
      next.has(idEmpleado) ? next.delete(idEmpleado) : next.add(idEmpleado);
      return next;
    });
  }

  const total = servicios
    .filter((s) => serviciosSel.has(s.id_servicio))
    .reduce((acc, s) => acc + Number(s.precio_servicio), 0);

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    const payload = {
      ...form,
      servicios: Array.from(serviciosSel),
      empleados: Array.from(empleadosSel),
    };
    try {
      if (editando) {
        await api.put(`/reservas/${id}/`, payload);
      } else {
        await api.post('/reservas/', payload);
      }
      navigate('/reservas');
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar la reserva.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>{editando ? 'Editar Reserva' : 'Nueva Reserva'}</h1>
        </div>
      </div>

      <div className="card" style={{ padding: 28, maxWidth: 640 }}>
        <form onSubmit={handleSubmit}>
          {errores.detail && <div className="alert alert-error">{errores.detail}</div>}
          {errores.empleados && <div className="alert alert-error">{errores.empleados}</div>}

          <div className="form-field">
            <label htmlFor="id_cliente">Cliente</label>
            <select id="id_cliente" value={form.id_cliente} onChange={(e) => actualizar('id_cliente', e.target.value)} required>
              <option value="">Seleccionar...</option>
              {clientes.map((c) => (
                <option key={c.id_cliente} value={c.id_cliente}>{c.nombre_cliente} {c.apellido_cliente}</option>
              ))}
            </select>
            {errores.id_cliente && <span className="form-error">{errores.id_cliente}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="nombre_evento">Nombre del evento</label>
            <input
              id="nombre_evento"
              placeholder="Ej: Cumpleaños de 15, Casamiento..."
              value={form.nombre_evento}
              onChange={(e) => actualizar('nombre_evento', e.target.value)}
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <div className="form-field">
              <label htmlFor="fecha_evento">Fecha</label>
              <input id="fecha_evento" type="date" value={form.fecha_evento} onChange={(e) => actualizar('fecha_evento', e.target.value)} required />
              {errores.fecha_evento && <span className="form-error">{errores.fecha_evento}</span>}
            </div>
            <div className="form-field">
              <label htmlFor="hora_evento">Hora</label>
              <input id="hora_evento" type="time" value={form.hora_evento} onChange={(e) => actualizar('hora_evento', e.target.value)} required />
              {errores.hora_evento && <span className="form-error">{errores.hora_evento}</span>}
            </div>
          </div>

          <div className="form-field">
            <label htmlFor="direccion_evento">Dirección del evento</label>
            <input id="direccion_evento" value={form.direccion_evento} onChange={(e) => actualizar('direccion_evento', e.target.value)} required />
            {errores.direccion_evento && <span className="form-error">{errores.direccion_evento}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="estado_reserva">Estado</label>
            <select id="estado_reserva" value={form.estado_reserva} onChange={(e) => actualizar('estado_reserva', e.target.value)}>
              {ESTADOS.map((e) => (
                <option key={e.value} value={e.value}>{e.label}</option>
              ))}
            </select>
          </div>

          <div className="form-field">
            <label>Servicios</label>
            <div className="checkbox-list">
              {servicios.length === 0 && <p className="form-hint">No hay servicios cargados todavía.</p>}
              {servicios.map((s) => (
                <label key={s.id_servicio}>
                  <span>
                    <input type="checkbox" checked={serviciosSel.has(s.id_servicio)} onChange={() => toggleServicio(s.id_servicio)} />{' '}
                    {s.tipo_servicio}
                  </span>
                  <span style={{ color: 'var(--text-muted)' }}>${Number(s.precio_servicio).toLocaleString('es-AR')}</span>
                </label>
              ))}
            </div>
            <span className="form-hint">Total estimado: <strong>${total.toLocaleString('es-AR')}</strong></span>
          </div>

          <div className="form-field">
            <label>Personal asignado</label>
            <div className="checkbox-list">
              {empleados.length === 0 && <p className="form-hint">No hay empleados cargados todavía.</p>}
              {empleados.map((e) => (
                <label key={e.id_empleado}>
                  <span>
                    <input type="checkbox" checked={empleadosSel.has(e.id_empleado)} onChange={() => toggleEmpleado(e.id_empleado)} />{' '}
                    {e.nombre_emp} {e.apellido_emp}
                  </span>
                </label>
              ))}
            </div>
          </div>

          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>{' '}
          <button type="button" className="btn btn-secondary" onClick={() => navigate('/reservas')}>
            Cancelar
          </button>
        </form>
      </div>
    </div>
  );
}
