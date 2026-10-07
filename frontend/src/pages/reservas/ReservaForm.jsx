import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';
import SelectBuscable from '../../components/SelectBuscable';

// Estados que se pueden elegir al editar (Anulada no: para eso está el botón "Anular")
const ESTADOS = [
  { value: 'PENDIENTE', label: 'Pendiente' },
  { value: 'CONFIRMADA', label: 'Confirmada' },
  { value: 'FINALIZADA', label: 'Finalizada' },
];

// Devuelve la fecha de hoy como 'AAAA-MM-DD' usando la hora de la compu.
// No se usa toISOString() porque ese toma la hora UTC y después de las 21 hs
// (en Argentina) ya daría el día siguiente.
function hoyLocal() {
  const d = new Date();
  const mes = String(d.getMonth() + 1).padStart(2, '0');
  const dia = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mes}-${dia}`;
}

// Valores iniciales del formulario en un alta
const VACIO = {
  id_cliente: '',
  nombre_evento: '',
  fecha_evento: '',
  hora_evento: '',
  duracion_evento: '',
  direccion_evento: '',
  estado_reserva: 'PENDIENTE',
};

// Formulario de Reservas (alta y edición): cliente, evento, fecha, hora, duración, servicios y personal.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function ReservaForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [clientes, setClientes] = useState([]);
  const [servicios, setServicios] = useState([]);
  const [empleados, setEmpleados] = useState([]);
  const [form, setForm] = useState(VACIO);
  // Servicios y empleados tildados (Sets de ids)
  const [serviciosSel, setServiciosSel] = useState(new Set());
  const [empleadosSel, setEmpleadosSel] = useState(new Set());
  // Errores que devuelve el backend, por campo (ej: { telefono_emp: ["..."] })
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);
  // Fecha que tenía la reserva al abrirla para editar (sirve para no trabar las reservas que ya pasaron)
  const [fechaOriginal, setFechaOriginal] = useState('');
  // Unidades libres de cada equipo en la fecha elegida: { id_equipo: libres } (null hasta elegir fecha)
  const [libresDelDia, setLibresDelDia] = useState(null);
  // Servicio cuyo detalle de equipos está abierto con el botón "Ver equipos"
  const [servicioAbierto, setServicioAbierto] = useState(null);

  // Al abrir: clientes, servicios y empleados para elegir; si se está editando, también los
  // datos de la reserva con los servicios y empleados que ya tiene
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
          duracion_evento: r.duracion_evento?.slice(0, 5) || '',
          direccion_evento: r.direccion_evento,
          estado_reserva: r.estado_reserva,
        });
        setFechaOriginal(r.fecha_evento);
        setServiciosSel(new Set(r.servicios_detalle.map((s) => Number(s.id_servicio))));
        setEmpleadosSel(new Set(r.empleados_detalle.map((e) => Number(e.id_empleado))));
      }
      setCargando(false);
    });
  }, [id, editando]);

  // Cada vez que cambia la fecha se pide al backend cuántas unidades de cada equipo quedan
  // libres ese día (descontando las otras reservas pendientes y confirmadas). Al editar se
  // excluye la propia reserva, así no se cuenta a sí misma.
  useEffect(() => {
    if (!form.fecha_evento) {
      setLibresDelDia(null);
      return;
    }
    const params = { fecha: form.fecha_evento, ...(editando ? { excluir: id } : {}) };
    api
      .get('/reservas/disponibilidad/', { params })
      .then(({ data }) => setLibresDelDia(Object.fromEntries(data.equipos.map((e) => [e.id_equipo, e.libres]))))
      .catch(() => setLibresDelDia(null));
  }, [form.fecha_evento, editando, id]);

  // Para cada servicio: ¿alcanzan los equipos ese día si además se lo suma a los ya tildados?
  // Se devuelve { id_servicio: null si alcanza, o el texto de lo que falta }.
  // Así un servicio que solo no tiene problema pero junto con otro ya tildado se pasa del
  // stock, también aparece como no disponible.
  const faltantesPorServicio = useMemo(() => {
    if (!libresDelDia) return {};
    // Unidades que ya piden los servicios tildados
    const pedidosTildados = {};
    for (const s of servicios) {
      if (!serviciosSel.has(Number(s.id_servicio))) continue;
      for (const eq of s.equipos_detalle || []) {
        pedidosTildados[eq.id_equipo] = (pedidosTildados[eq.id_equipo] || 0) + eq.cantidad;
      }
    }
    const resultado = {};
    for (const s of servicios) {
      const tildado = serviciosSel.has(Number(s.id_servicio));
      const faltan = [];
      for (const eq of s.equipos_detalle || []) {
        // Si ya está tildado, sus unidades ya están dentro de pedidosTildados
        const pedido = (pedidosTildados[eq.id_equipo] || 0) + (tildado ? 0 : eq.cantidad);
        const libres = libresDelDia[eq.id_equipo] ?? 0;
        if (pedido > libres) faltan.push(`${eq.nombre_equipo} (quedan ${libres})`);
      }
      resultado[s.id_servicio] = faltan.length ? `Sin equipos suficientes ese día: ${faltan.join(', ')}` : null;
    }
    return resultado;
  }, [libresDelDia, servicios, serviciosSel]);

  // En el calendario no se pueden elegir días anteriores a hoy.
  // Si estamos editando una reserva que ya pasó, el mínimo pasa a ser su propia fecha,
  // así se puede guardar (por ejemplo para marcarla como Finalizada) sin que el navegador la rechace.
  const hoy = hoyLocal();
  const fechaMinima = fechaOriginal && fechaOriginal < hoy ? fechaOriginal : hoy;

  // Cambia un solo campo del formulario y deja los demás como estaban
  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Tilda o destilda un servicio (el total se recalcula solo)
  function toggleServicio(idServicio) {
    const id = Number(idServicio);
    setServiciosSel((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  // Tilda o destilda un empleado
  function toggleEmpleado(idEmpleado) {
    const id = Number(idEmpleado);
    setEmpleadosSel((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  // El monto total se calcula solo sumando el precio de los servicios tildados
  // (el backend hace la misma cuenta al guardar, acá es para que se vea)
  const total = servicios
    .filter((s) => serviciosSel.has(Number(s.id_servicio)))
    .reduce((acc, s) => acc + Number(s.precio_servicio), 0);

  // Subtítulo de la ventana de edición: "Nombre del evento · Cliente"
  const clienteSeleccionado = clientes.find((c) => String(c.id_cliente) === String(form.id_cliente));
  const subtitulo = clienteSeleccionado
    ? [form.nombre_evento, `${clienteSeleccionado.nombre_cliente} ${clienteSeleccionado.apellido_cliente}`].filter(Boolean).join(' · ')
    : undefined;

  // Guardar: si se está editando hace PUT y muestra la ventana de éxito; si es un alta hace
  // POST y vuelve a la lista. Si el backend rechaza los datos (400), se muestran sus errores.
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
        setGuardadoOk(true);
      } else {
        await api.post('/reservas/', payload);
        navigate('/reservas');
      }
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

  // Mientras se traen los datos del registro a editar
  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Reserva modificada correctamente"
        subtitulo={subtitulo}
        textoBoton="Volver a reservas"
        onContinuar={() => navigate('/reservas')}
      />
    );
  }

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}
      {errores.empleados && <div className="alert alert-error">{errores.empleados}</div>}
      {/* Errores de los servicios elegidos (por ejemplo, equipos no disponibles ese día) */}
      {errores.servicios && <div className="alert alert-error">{errores.servicios}</div>}

      <div className="form-field">
        <label htmlFor="id_cliente">Cliente</label>
        {/* Se puede escribir el nombre o apellido para filtrar, o abrir la lista con la flechita */}
        <SelectBuscable
          id="id_cliente"
          opciones={clientes.map((c) => ({ value: c.id_cliente, label: `${c.nombre_cliente} ${c.apellido_cliente}` }))}
          value={form.id_cliente}
          onChange={(valor) => actualizar('id_cliente', valor)}
          placeholder="Buscar cliente por nombre o apellido..."
          sinResultados="No hay clientes con ese nombre."
          required
        />
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

      {/* Fecha, hora de inicio y duración van en la misma fila */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
        <div className="form-field">
          <label htmlFor="fecha_evento">Fecha</label>
          <input
            id="fecha_evento"
            type="date"
            min={fechaMinima}
            value={form.fecha_evento}
            onChange={(e) => actualizar('fecha_evento', e.target.value)}
            required
          />
          {errores.fecha_evento && <span className="form-error">{errores.fecha_evento}</span>}
        </div>
        <div className="form-field">
          <label htmlFor="hora_evento">Hora</label>
          <input id="hora_evento" type="time" value={form.hora_evento} onChange={(e) => actualizar('hora_evento', e.target.value)} required />
          {errores.hora_evento && <span className="form-error">{errores.hora_evento}</span>}
        </div>
        <div className="form-field">
          <label htmlFor="duracion_evento">Duración</label>
          <input
            id="duracion_evento"
            type="time"
            value={form.duracion_evento}
            onChange={(e) => actualizar('duracion_evento', e.target.value)}
            required
          />
          <span className="form-hint">Horas:minutos (ej: 04:30)</span>
          {errores.duracion_evento && <span className="form-error">{errores.duracion_evento}</span>}
        </div>
      </div>

      <div className="form-field">
        <label htmlFor="direccion_evento">Dirección del evento</label>
        <input id="direccion_evento" placeholder="Ej: Salón Los Álamos, Av. San Martín 456" value={form.direccion_evento} onChange={(e) => actualizar('direccion_evento', e.target.value)} required />
        {errores.direccion_evento && <span className="form-error">{errores.direccion_evento}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="estado_reserva">Estado</label>
        {/* Al crear, el estado lo pone el sistema (siempre Pendiente). Al editar se puede
            pasar a Confirmada o Finalizada; para anular está el botón "Anular" de la lista */}
        {editando ? (
          <select id="estado_reserva" value={form.estado_reserva} onChange={(e) => actualizar('estado_reserva', e.target.value)}>
            {ESTADOS.map((e) => (
              <option key={e.value} value={e.value}>{e.label}</option>
            ))}
          </select>
        ) : (
          <>
            <input id="estado_reserva" value="Pendiente" disabled />
            <span className="form-hint">Toda reserva nueva queda Pendiente automáticamente.</span>
          </>
        )}
        {errores.estado_reserva && <span className="form-error">{errores.estado_reserva}</span>}
      </div>

      <div className="form-field">
        <label>Servicios</label>
        {/* Hasta que no se elige la fecha no se sabe qué equipos hay libres */}
        {!form.fecha_evento && <span className="form-hint">Elegí la fecha para ver qué servicios están disponibles ese día.</span>}
        <div className="checkbox-list">
          {servicios.length === 0 && <p className="form-hint">No hay servicios cargados todavía.</p>}
          {servicios.map((s) => {
            const tildado = serviciosSel.has(Number(s.id_servicio));
            const faltante = faltantesPorServicio[s.id_servicio];
            // Un servicio sin equipos libres ese día no se puede tildar. Si ya estaba tildado
            // (al editar) se deja destildar, pero no volver a tildar.
            const bloqueado = Boolean(faltante) && !tildado;
            const abierto = servicioAbierto === s.id_servicio;
            return (
              <div key={s.id_servicio} className={`servicio-fila${bloqueado ? ' servicio-no-disponible' : ''}`}>
                <div className="servicio-fila-principal">
                  <label className="servicio-nombre">
                    <input type="checkbox" checked={tildado} disabled={bloqueado} onChange={() => toggleServicio(s.id_servicio)} />
                    <span>{s.tipo_servicio}</span>
                    {bloqueado && <span className="badge badge-red badge-chica">No disponible</span>}
                  </label>
                  <span className="servicio-precio">${Number(s.precio_servicio).toLocaleString('es-AR')}</span>
                  {/* Muestra u oculta qué equipos trae el servicio */}
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => setServicioAbierto(abierto ? null : s.id_servicio)}>
                    {abierto ? 'Ocultar' : 'Ver equipos'}
                  </button>
                </div>
                {faltante && <span className="form-error">{faltante}</span>}
                {abierto && (
                  <ul className="servicio-equipos">
                    {(s.equipos_detalle || []).length === 0 && <li>Este servicio no tiene equipos cargados.</li>}
                    {(s.equipos_detalle || []).map((eq) => (
                      <li key={eq.id_equipo}>
                        {eq.cantidad} × {eq.nombre_equipo}
                        {libresDelDia && <span className="servicio-equipos-libres"> · libres ese día: {libresDelDia[eq.id_equipo] ?? 0}</span>}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Solo se muestra, no se puede escribir: cambia al tildar o destildar servicios */}
      <div className="form-field">
        <label htmlFor="monto_total">Monto total</label>
        <input id="monto_total" value={`$${total.toLocaleString('es-AR')}`} readOnly disabled />
        <span className="form-hint">Se calcula solo con la suma de los servicios elegidos.</span>
      </div>

      <div className="form-field">
        <label>Personal asignado</label>
        <div className="checkbox-list">
          {empleados.length === 0 && <p className="form-hint">No hay empleados cargados todavía.</p>}
          {empleados.map((e) => (
            <label key={e.id_empleado}>
              <span>{e.nombre_emp} {e.apellido_emp}</span>
              <input type="checkbox" checked={empleadosSel.has(Number(e.id_empleado))} onChange={() => toggleEmpleado(e.id_empleado)} />
            </label>
          ))}
        </div>
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear reserva'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/reservas')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar reserva" subtitulo={subtitulo} onClose={() => navigate('/reservas')} wide>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nueva Reserva</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 640 }}>
        {formulario}
      </div>
    </div>
  );
}