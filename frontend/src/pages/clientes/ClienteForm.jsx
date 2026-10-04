import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

const VACIO = {
  nombre_cliente: '',
  apellido_cliente: '',
  domicilio_cliente: '',
  telefono_cliente: '',
  email_cliente: '',
};

// Devuelve la fecha de hoy como 'AAAA-MM-DD' con la hora de la compu (igual que en ReservaForm)
function hoyLocal() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Arma los números del panel "Resumen de clientes" y el "Último cliente cargado"
// a partir de las listas de clientes y reservas que ya trae la API
function armarResumen(clientes, reservas) {
  const hoy = hoyLocal();
  const mesActual = hoy.slice(0, 7); // 'AAAA-MM'
  const noCanceladas = reservas.filter((r) => r.estado_reserva !== 'CANCELADA');

  // Reserva vigente = todavía no pasó y no está finalizada
  const conVigentes = new Set(
    noCanceladas.filter((r) => r.fecha_evento >= hoy && r.estado_reserva !== 'FINALIZADA').map((r) => r.id_cliente)
  );
  const conReservasEsteMes = new Set(
    noCanceladas.filter((r) => r.fecha_evento.startsWith(mesActual)).map((r) => r.id_cliente)
  );

  // El último cargado es el de id más alto; si tiene reservas mostramos el evento de la más nueva
  const ultimo = clientes.reduce((max, c) => (!max || c.id_cliente > max.id_cliente ? c : max), null);
  const eventoDelUltimo = ultimo
    ? reservas
        .filter((r) => r.id_cliente === ultimo.id_cliente && r.nombre_evento)
        .sort((a, b) => b.id_reserva - a.id_reserva)[0]?.nombre_evento
    : null;

  return {
    cargados: clientes.length,
    conVigentes: conVigentes.size,
    conReservasEsteMes: conReservasEsteMes.size,
    ultimo: ultimo
      ? [`${ultimo.nombre_cliente} ${ultimo.apellido_cliente}`, eventoDelUltimo].filter(Boolean).join(' - ')
      : null,
  };
}

export default function ClienteForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState(VACIO);
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);
  const [resumen, setResumen] = useState(null);

  // Al editar se traen los datos del cliente para llenar el formulario
  useEffect(() => {
    if (!editando) return;
    api.get(`/clientes/${id}/`).then(({ data }) => {
      setForm(data);
      setCargando(false);
    });
  }, [id, editando]);

  // Al crear se arma el panel de la derecha. Si el usuario no tiene permiso para ver
  // reservas, igual se muestran los datos de clientes y el resto queda en "—"
  useEffect(() => {
    if (editando) return;
    Promise.all([
      api.get('/clientes/'),
      api.get('/reservas/').catch(() => ({ data: null })),
    ]).then(([clientesRes, reservasRes]) => {
      const r = armarResumen(clientesRes.data, reservasRes.data || []);
      setResumen(reservasRes.data ? r : { ...r, conVigentes: null, conReservasEsteMes: null });
    });
  }, [editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        await api.put(`/clientes/${id}/`, form);
        setGuardadoOk(true);
      } else {
        await api.post('/clientes/', form);
        navigate('/clientes');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el cliente.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Cliente modificado correctamente"
        subtitulo={`${form.nombre_cliente} ${form.apellido_cliente}`}
        textoBoton="Volver a clientes"
        onContinuar={() => navigate('/clientes')}
      />
    );
  }

  // Campos del formulario: es el mismo para crear y para editar.
  // Van de a dos por fila (Nombre/Apellido y Teléfono/Email) y el domicilio ocupa todo el ancho.
  // El asterisco rojo marca los campos obligatorios.
  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-grid-2">
        <div className="form-field">
          <label htmlFor="nombre_cliente">Nombre <span className="requerido">*</span></label>
          <input id="nombre_cliente" placeholder="Ej: Jesús" maxLength={30} pattern="[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+" title="Solo letras, sin números" value={form.nombre_cliente} onChange={(e) => actualizar('nombre_cliente', e.target.value)} required />
          {errores.nombre_cliente && <span className="form-error">{errores.nombre_cliente}</span>}
        </div>

        <div className="form-field">
          <label htmlFor="apellido_cliente">Apellido <span className="requerido">*</span></label>
          <input id="apellido_cliente" placeholder="Ej: González" maxLength={30} pattern="[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+" title="Solo letras, sin números" value={form.apellido_cliente} onChange={(e) => actualizar('apellido_cliente', e.target.value)} required />
          {errores.apellido_cliente && <span className="form-error">{errores.apellido_cliente}</span>}
        </div>

        <div className="form-field">
          <label htmlFor="telefono_cliente">Teléfono <span className="requerido">*</span></label>
          <input id="telefono_cliente" placeholder="Ej: 3874455221" type="tel" inputMode="numeric" minLength={10} maxLength={12} pattern="[0-9]{10,12}" title="Solo números, entre 10 y 12 dígitos" value={form.telefono_cliente} onChange={(e) => actualizar('telefono_cliente', e.target.value)} required />
          {errores.telefono_cliente && <span className="form-error">{errores.telefono_cliente}</span>}
        </div>

        <div className="form-field">
          <label htmlFor="email_cliente">Email <span className="requerido">*</span></label>
          <input id="email_cliente" placeholder="Ej: gonzalezjesus@gmail.com" type="email" value={form.email_cliente} onChange={(e) => actualizar('email_cliente', e.target.value)} required />
          {errores.email_cliente && <span className="form-error">{errores.email_cliente}</span>}
        </div>
      </div>

      <div className="form-field">
        <label htmlFor="domicilio_cliente">Domicilio <span className="requerido">*</span></label>
        <input id="domicilio_cliente" placeholder="Ej: Av. Belgrano 240, Salta" maxLength={60} value={form.domicilio_cliente} onChange={(e) => actualizar('domicilio_cliente', e.target.value)} required />
        {errores.domicilio_cliente && <span className="form-error">{errores.domicilio_cliente}</span>}
      </div>

      {/* Botones separados del formulario por una línea, como en el diseño */}
      <div className="form-acciones">
        <button type="submit" className="btn btn-primary" disabled={guardando}>
          {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Guardar cliente'}
        </button>
        <button type="button" className="btn btn-outline" onClick={() => navigate('/clientes')}>
          {editando ? 'Descartar cambios' : 'Cancelar'}
        </button>
      </div>
    </form>
  );

  // Editar se sigue abriendo como ventana emergente encima de la lista
  if (editando) {
    return (
      <FormModal titulo="Editar cliente" subtitulo={`${form.nombre_cliente} ${form.apellido_cliente}`} onClose={() => navigate('/clientes')}>
        {formulario}
      </FormModal>
    );
  }

  // Pantalla de alta: formulario a la izquierda y panel de ayuda a la derecha
  return (
    <div>
      <div className="page-header page-header-con-ruta">
        <div>
          <h1>Nuevo cliente</h1>
          {/* Ruta para saber dónde estamos y volver a la lista con un clic */}
          <nav className="ruta" aria-label="Ruta">
            <Link to="/clientes">Clientes</Link> / <strong>Nuevo cliente</strong>
          </nav>
        </div>
      </div>

      <div className="alta-layout">
        <section className="card alta-form">
          <h2 className="alta-titulo">Datos del cliente</h2>
          <p className="alta-subtitulo">Completá la información del contacto del cliente.</p>
          {formulario}
        </section>

        <aside className="alta-aside">
          {/* Recordatorio antes de guardar */}
          <div className="aside-aviso">
            <h3>Antes de guardar</h3>
            <p>Verificá que el email y el teléfono no estén ya cargados para otro cliente, para evitar registros duplicados.</p>
          </div>

          {/* Números rápidos de clientes */}
          <div className="card aside-resumen">
            <h3>Resumen de clientes</h3>
            <div className="aside-fila">
              <span>Clientes cargados</span>
              <span className="aside-numero">{resumen ? resumen.cargados : '—'}</span>
            </div>
            <div className="aside-fila">
              <span>Con reservas vigentes</span>
              <span className="aside-numero">{resumen?.conVigentes ?? '—'}</span>
            </div>
            <div className="aside-fila">
              <span>Con reservas este mes</span>
              <span className="aside-numero aside-numero-verde">{resumen?.conReservasEsteMes ?? '—'}</span>
            </div>
          </div>

          {/* Último cliente que se dio de alta */}
          <div className="aside-ultimo">
            <span>Último cliente cargado</span>
            <strong>{resumen?.ultimo || 'Todavía no hay clientes'}</strong>
          </div>
        </aside>
      </div>
    </div>
  );
}
