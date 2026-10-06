import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de servicios: nombre, precio y qué equipos usa (y cuántos de cada uno).
// Los equipos se usan al reservar para controlar que en un mismo día no se pidan
// más unidades de las que hay (ver _validar_equipos en serializers.py).
export default function ServicioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState({ tipo_servicio: '', precio_servicio: '' });
  const [equipos, setEquipos] = useState([]);
  // Unidades de cada equipo que usa el servicio: { id_equipo: cantidad }. Si no está o es 0, no lo usa
  const [cantidades, setCantidades] = useState({});
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  // Trae todos los equipos y, si se está editando, el servicio con los equipos que ya usa
  useEffect(() => {
    Promise.all([
      api.get('/equipos/'),
      editando ? api.get(`/servicios/${id}/`) : Promise.resolve(null),
    ]).then(([equiposRes, servicioRes]) => {
      setEquipos(equiposRes.data);
      if (servicioRes) {
        const { tipo_servicio, precio_servicio, equipos_detalle } = servicioRes.data;
        setForm({ tipo_servicio, precio_servicio });
        setCantidades(Object.fromEntries(equipos_detalle.map((e) => [e.id_equipo, e.cantidad])));
      }
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Cambia la cantidad de un equipo (vacío cuenta como 0, o sea que no lo usa)
  function cambiarCantidad(idEquipo, valor) {
    setCantidades((c) => ({ ...c, [idEquipo]: valor === '' ? '' : Number(valor) }));
  }

  // Cuántos equipos distintos usa el servicio, para mostrarlo en el título de la sección
  const equiposElegidos = Object.values(cantidades).filter((c) => Number(c) > 0).length;

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    // Solo se mandan los equipos con cantidad mayor a 0
    const payload = {
      ...form,
      equipos: Object.entries(cantidades)
        .filter(([, cantidad]) => Number(cantidad) > 0)
        .map(([idEquipo, cantidad]) => ({ id_equipo: Number(idEquipo), cantidad: Number(cantidad) })),
    };
    try {
      if (editando) {
        await api.put(`/servicios/${id}/`, payload);
        setGuardadoOk(true);
      } else {
        await api.post('/servicios/', payload);
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

      {/* Equipos que usa el servicio: se escribe cuántas unidades de cada uno (0 = no lo usa) */}
      <div className="form-field">
        <label>Equipos que usa {equiposElegidos > 0 && <span className="form-hint">({equiposElegidos} elegidos)</span>}</label>
        <div className="checkbox-list equipos-servicio">
          {equipos.length === 0 && <p className="form-hint">No hay equipos cargados todavía.</p>}
          {equipos.map((equipo) => {
            const enReparacion = equipo.estado_nombre?.toLowerCase().includes('reparac');
            return (
              <label key={equipo.id_equipo} htmlFor={`equipo-${equipo.id_equipo}`}>
                <span>
                  {equipo.nombre_equipo}
                  <span className="form-hint">
                    {' '}· {equipo.tipo_nombre} · {equipo.cantidad_equipo} en total
                    {enReparacion && ' · en reparación'}
                  </span>
                </span>
                <input
                  id={`equipo-${equipo.id_equipo}`}
                  type="number"
                  min="0"
                  max={equipo.cantidad_equipo}
                  placeholder="0"
                  value={cantidades[equipo.id_equipo] ?? ''}
                  onChange={(e) => cambiarCantidad(equipo.id_equipo, e.target.value)}
                />
              </label>
            );
          })}
        </div>
        <span className="form-hint">
          Al reservar, el sistema controla que ese día no se pidan más unidades de las que hay.
        </span>
        {errores.equipos && <span className="form-error">{errores.equipos}</span>}
      </div>

      <div className="form-acciones">
        <button type="submit" className="btn btn-primary" disabled={guardando}>
          {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear servicio'}
        </button>
        <button type="button" className="btn btn-outline" onClick={() => navigate('/servicios')}>
          {editando ? 'Descartar cambios' : 'Cancelar'}
        </button>
      </div>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar servicio" subtitulo={form.tipo_servicio} onClose={() => navigate('/servicios')} wide>
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
      <div className="card" style={{ padding: 28, maxWidth: 640 }}>
        {formulario}
      </div>
    </div>
  );
}
