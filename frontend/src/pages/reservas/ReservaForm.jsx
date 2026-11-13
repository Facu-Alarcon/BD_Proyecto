import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';
import SelectBuscable from '../../components/SelectBuscable';
import PantallaAlta from '../../components/PantallaAlta';

// Estados que se pueden elegir al editar (Anulada no: para eso está el botón "Anular")
const ESTADOS = [
  { value: 'PENDIENTE', label: 'Pendiente' },
  { value: 'CONFIRMADA', label: 'Confirmada' },
  { value: 'FINALIZADA', label: 'Finalizada' },
];

// Opciones de los desplegables de la duración: de 0 a 12 horas (un evento no dura más de 12 horas)
// y los minutos de a cuarto de hora. Con 12 horas solo se puede elegir 00 minutos, así el tope es 12:00
const MAXIMO_HORAS_DURACION = 12;
const HORAS_DURACION = Array.from({ length: MAXIMO_HORAS_DURACION + 1 }, (_, i) => String(i).padStart(2, '0'));
const MINUTOS_DURACION = ['00', '15', '30', '45'];

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

// Arma los números del panel "Resumen de reservas" y la "Última reserva cargada" a partir de la
// lista de reservas que ya trae la API. "Eventos este mes" no cuenta las anuladas.
function armarResumen(reservas) {
  const mesActual = hoyLocal().slice(0, 7); // 'AAAA-MM'
  // La última cargada es la de id más alto
  const ultima = reservas.reduce((max, r) => (!max || r.id_reserva > max.id_reserva ? r : max), null);
  return {
    pendientes: reservas.filter((r) => r.estado_reserva === 'PENDIENTE').length,
    confirmadas: reservas.filter((r) => r.estado_reserva === 'CONFIRMADA').length,
    esteMes: reservas.filter((r) => r.estado_reserva !== 'ANULADA' && r.fecha_evento.startsWith(mesActual)).length,
    ultima: ultima ? [ultima.nombre_evento, ultima.cliente_nombre].filter(Boolean).join(' - ') : null,
  };
}

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
  // Empleados que ya trabajan en otra reserva la fecha elegida (Set de ids; null hasta elegir fecha)
  const [empleadosOcupados, setEmpleadosOcupados] = useState(null);
  // Servicio cuyo detalle de equipos está abierto con el botón "Ver equipos"
  const [servicioAbierto, setServicioAbierto] = useState(null);
  // Números del panel de la derecha (solo en el alta)
  const [resumen, setResumen] = useState(null);

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
      // Solo se muestran para elegir los servicios y empleados activos. Los desactivados
      // aparecen únicamente si la reserva que se está editando ya los tenía, así se
      // pueden ver y destildar.
      const serviciosDeLaReserva = new Set((reservaRes?.data.servicios_detalle || []).map((s) => Number(s.id_servicio)));
      const empleadosDeLaReserva = new Set((reservaRes?.data.empleados_detalle || []).map((e) => Number(e.id_empleado)));
      setServicios(serviciosRes.data.filter((s) => s.activo || serviciosDeLaReserva.has(Number(s.id_servicio))));
      setEmpleados(empleadosRes.data.filter((e) => e.activo || empleadosDeLaReserva.has(Number(e.id_empleado))));

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

  // Al crear: se arma el panel de la derecha con las reservas que ya están cargadas
  useEffect(() => {
    if (editando) return;
    api.get('/reservas/').then(({ data }) => setResumen(armarResumen(data))).catch(() => {});
  }, [editando]);

  // Cada vez que cambia la fecha se pide al backend cuántas unidades de cada equipo quedan
  // libres ese día (descontando las otras reservas pendientes y confirmadas). Al editar se
  // excluye la propia reserva, así no se cuenta a sí misma.
  useEffect(() => {
    if (!form.fecha_evento) {
      setLibresDelDia(null);
      setEmpleadosOcupados(null);
      return;
    }
    const params = { fecha: form.fecha_evento, ...(editando ? { excluir: id } : {}) };
    api
      .get('/reservas/disponibilidad/', { params })
      .then(({ data }) => {
        setLibresDelDia(Object.fromEntries(data.equipos.map((e) => [e.id_equipo, e.libres])));
        setEmpleadosOcupados(new Set(data.empleados_ocupados));
      })
      .catch(() => {
        setLibresDelDia(null);
        setEmpleadosOcupados(null);
      });
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

  // Personal agrupado por puesto (DJ, Operadores...), con los grupos en orden alfabético y
  // "Sin puesto asignado" al final. Por ahora cada empleado tiene un solo puesto; si tuviera
  // más de uno, aparece en el primero (por orden alfabético).
  const empleadosPorPuesto = useMemo(() => {
    const grupos = {};
    for (const e of empleados) {
      const puesto = e.puestos?.[0] || 'Sin puesto asignado';
      (grupos[puesto] = grupos[puesto] || []).push(e);
    }
    return Object.entries(grupos).sort(([a], [b]) => {
      if (a === 'Sin puesto asignado') return 1;
      if (b === 'Sin puesto asignado') return -1;
      return a.localeCompare(b, 'es');
    });
  }, [empleados]);

  // En el calendario no se pueden elegir días anteriores a hoy.
  // Si estamos editando una reserva que ya pasó, el mínimo pasa a ser su propia fecha,
  // así se puede guardar (por ejemplo para marcarla como Finalizada) sin que el navegador la rechace.
  const hoy = hoyLocal();
  const fechaMinima = fechaOriginal && fechaOriginal < hoy ? fechaOriginal : hoy;

  // Sin fecha no se sabe qué servicios y qué personal están libres, así que hasta
  // que no se elige no se puede tildar ninguno
  const sinFecha = !form.fecha_evento;

  // Cambia un solo campo del formulario y deja los demás como estaban
  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Duración: en el formulario se guarda como "HH:MM" (así la espera el backend) y en pantalla
  // se muestra partida en dos desplegables, horas y minutos
  const [durHoras = '', durMinutos = ''] = form.duracion_evento ? form.duracion_evento.split(':') : [];
  const enElTope = Number(durHoras) >= MAXIMO_HORAS_DURACION;
  // Si una reserva vieja tiene un valor que no está en la lista (ej: 14 horas, o 04:20), se agrega
  // a las opciones para no perderlo al editarla
  const horasDuracion = durHoras && !HORAS_DURACION.includes(durHoras) ? [...HORAS_DURACION, durHoras] : HORAS_DURACION;
  const minutosBase = enElTope ? ['00'] : MINUTOS_DURACION;
  const minutosDuracion = durMinutos && !minutosBase.includes(durMinutos) ? [...minutosBase, durMinutos].sort() : minutosBase;

  // Junta las horas y los minutos elegidos en "HH:MM". Si se eligió uno solo, el otro arranca
  // en 00 (ej: se eligen 4 horas -> "04:00"); si se vuelven a dejar los dos vacíos, queda vacío.
  // Con 12 horas los minutos pasan a 00, para no pasarse del tope (12:30 no se puede)
  function cambiarDuracion(horas, minutos) {
    if (!horas && !minutos) {
      actualizar('duracion_evento', '');
      return;
    }
    const minutosFinal = Number(horas) === MAXIMO_HORAS_DURACION ? '00' : minutos || '00';
    actualizar('duracion_evento', `${horas || '00'}:${minutosFinal}`);
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
    <form onSubmit={handleSubmit} className="reserva-form">
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}
      {errores.empleados && <div className="alert alert-error">{errores.empleados}</div>}
      {/* Errores de los servicios elegidos (por ejemplo, equipos no disponibles ese día) */}
      {errores.servicios && <div className="alert alert-error">{errores.servicios}</div>}

      <div className="form-grid-2">
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
      </div>

      {/* Fecha, hora de inicio y duración van en la misma fila */}
      {/* En el celular pasan a ir uno debajo del otro (ver .form-grid-3 en index.css) */}
      <div className="form-grid-3">
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
          {/* La aclaración va debajo del campo: al lado del nombre no entra en una línea cuando
              el formulario tiene el panel de la derecha, y empujaba el campo hacia abajo */}
          <label htmlFor="duracion_evento">Duración</label>
          {/* Dos desplegables (horas y minutos) en vez de un campo de hora: el campo de hora del
              navegador es para un horario del día y en algunas compus pide a. m./p. m., que para
              una duración no tiene sentido. Por atrás se sigue guardando "HH:MM" (ver cambiarDuracion) */}
          <div className="selector-duracion">
            <select
              id="duracion_evento"
              aria-label="Horas de duración"
              value={durHoras}
              onChange={(e) => cambiarDuracion(e.target.value, durMinutos)}
              required
            >
              <option value="">Horas</option>
              {horasDuracion.map((h) => (
                <option key={h} value={h}>{Number(h)} {Number(h) === 1 ? 'hora' : 'horas'}</option>
              ))}
            </select>
            <select
              aria-label="Minutos de duración"
              value={durMinutos}
              onChange={(e) => cambiarDuracion(durHoras, e.target.value)}
              required
            >
              <option value="">Min</option>
              {minutosDuracion.map((m) => <option key={m} value={m}>{m} min</option>)}
            </select>
          </div>
          {errores.duracion_evento && <span className="form-error">{errores.duracion_evento}</span>}
        </div>
      </div>

      {/* Al editar, la dirección comparte la fila con el estado; en el alta va sola a todo el ancho */}
      <div className={editando ? 'form-grid-2' : undefined}>
        <div className="form-field">
          <label htmlFor="direccion_evento">Dirección del evento</label>
          <input id="direccion_evento" placeholder="Ej: Salón Los Álamos, Av. San Martín 456" value={form.direccion_evento} onChange={(e) => actualizar('direccion_evento', e.target.value)} required />
          {errores.direccion_evento && <span className="form-error">{errores.direccion_evento}</span>}
        </div>

        {/* El estado solo se muestra al editar: toda reserva nueva queda Pendiente sola.
            Al editar se puede pasar a Confirmada o Finalizada; para anular está el botón "Anular" de la lista */}
        {editando && (
          <div className="form-field">
            <label htmlFor="estado_reserva">Estado</label>
            <select id="estado_reserva" value={form.estado_reserva} onChange={(e) => actualizar('estado_reserva', e.target.value)}>
              {ESTADOS.map((e) => (
                <option key={e.value} value={e.value}>{e.label}</option>
              ))}
            </select>
            <span className="form-hint">Las reservas confirmadas pasan solas a Finalizada cuando termina el evento.</span>
            {errores.estado_reserva && <span className="form-error">{errores.estado_reserva}</span>}
          </div>
        )}
      </div>
      {/* Si el backend rechazara el estado en un alta, el error igual se ve */}
      {!editando && errores.estado_reserva && <div className="alert alert-error">{errores.estado_reserva}</div>}

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
              <div key={s.id_servicio} className={`servicio-fila${bloqueado || sinFecha ? ' servicio-no-disponible' : ''}`}>
                <div className="servicio-fila-principal">
                  <label className="servicio-nombre">
                    <input type="checkbox" checked={tildado} disabled={bloqueado || sinFecha} onChange={() => toggleServicio(s.id_servicio)} />
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
        {!form.fecha_evento && <span className="form-hint">Elegí la fecha para ver qué personal está disponible ese día.</span>}
        <div className="checkbox-list">
          {empleados.length === 0 && <p className="form-hint">No hay empleados cargados todavía.</p>}
          {/* Un bloque por puesto, con su título (ej: DJ, Operador de iluminación) */}
          {empleadosPorPuesto.map(([puesto, lista]) => (
            <div key={puesto} className="personal-grupo">
              <div className="personal-grupo-titulo">{puesto}</div>
              {lista.map((e) => {
                const tildado = empleadosSel.has(Number(e.id_empleado));
                // Si ya trabaja en otra reserva ese día no se puede elegir. Si ya estaba tildado
                // (al editar) se deja destildar, pero no volver a tildar.
                const ocupado = Boolean(empleadosOcupados?.has(Number(e.id_empleado))) && !tildado;
                return (
                  <label key={e.id_empleado} className={ocupado || sinFecha ? 'personal-no-disponible' : ''}>
                    <span>
                      {e.nombre_emp} {e.apellido_emp}
                      {ocupado && <span className="badge badge-red badge-chica" style={{ marginLeft: 8 }}>No disponible</span>}
                    </span>
                    <input type="checkbox" checked={tildado} disabled={ocupado || sinFecha} onChange={() => toggleEmpleado(e.id_empleado)} />
                  </label>
                );
              })}
            </div>
          ))}
        </div>
        {empleadosOcupados?.size > 0 && (
          <span className="form-hint">Los marcados como "No disponible" ya trabajan en otra reserva ese día.</span>
        )}
      </div>

      {/* Botones separados del formulario por una línea, como en "Nuevo cliente" */}
      <div className="form-acciones">
        <button type="submit" className="btn btn-primary" disabled={guardando}>
          {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear reserva'}
        </button>
        <button type="button" className="btn btn-outline" onClick={() => navigate('/reservas')}>
          {editando ? 'Descartar cambios' : 'Cancelar'}
        </button>
      </div>
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
    <PantallaAlta
      titulo="Nueva reserva"
      seccion="Reservas"
      rutaSeccion="/reservas"
      tituloFormulario="Datos de la reserva"
      subtituloFormulario="Completá los datos del evento, los servicios y el personal."
      aviso="Elegí primero la fecha: así el sistema muestra qué servicios y qué personal están disponibles ese día. Toda reserva nueva queda Pendiente."
      resumen={{
        titulo: 'Resumen de reservas',
        filas: [
          { etiqueta: 'Reservas pendientes', valor: resumen?.pendientes },
          { etiqueta: 'Reservas confirmadas', valor: resumen?.confirmadas },
          { etiqueta: 'Eventos este mes', valor: resumen?.esteMes, verde: true },
        ],
      }}
      ultimo={{ etiqueta: 'Última reserva cargada', texto: resumen?.ultima, vacio: 'Todavía no hay reservas' }}
    >
      {formulario}
    </PantallaAlta>
  );
}