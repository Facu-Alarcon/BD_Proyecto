import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';
import PantallaAlta from '../../components/PantallaAlta';
import { usePermiso } from '../../hooks/usePermiso';

// Arma los números del panel "Resumen de equipos" y el "Último equipo cargado" a partir de la
// lista de equipos que ya trae la API. Las cantidades se cuentan en unidades (6 bafles = 6).
function armarResumen(equipos) {
  const unidades = (e) => Number(e.cantidad_equipo) || 0;
  // Mismo criterio que el resto del sistema: un estado con "reparac" en el nombre = fuera de servicio
  const enReparacion = equipos.filter((e) => (e.estado_nombre || '').toLowerCase().includes('reparac'));
  // El último cargado es el de id más alto
  const ultimo = equipos.reduce((max, e) => (!max || e.id_equipo > max.id_equipo ? e : max), null);
  return {
    cargados: equipos.length,
    unidades: equipos.reduce((suma, e) => suma + unidades(e), 0),
    enReparacion: enReparacion.reduce((suma, e) => suma + unidades(e), 0),
    ultimo: ultimo ? [ultimo.nombre_equipo, ultimo.tipo_nombre].filter(Boolean).join(' - ') : null,
  };
}

// Formulario de Equipos (alta y edición): nombre, tipo, estado y cantidad de unidades.
// El tipo y el estado se eligen de una lista. Para agregar un tipo o un estado nuevo hay
// que ir a sus módulos del menú (Tipos de equipo y Estados de equipo).
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function EquipoForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);

  const [tipos, setTipos] = useState([]);
  const [estados, setEstados] = useState([]);
  const [form, setForm] = useState({
    nombre_equipo: '',
    id_tipoeq: '',
    id_estadoeq: '',
    cantidad_equipo: 1,
  });
  // Errores que devuelve el backend, por campo (ej: { telefono_emp: ["..."] })
  const [errores, setErrores] = useState({});
  // Al editar arranca en "cargando" hasta que llegan los datos del registro
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  // Números del panel de la derecha (solo en el alta)
  const [resumen, setResumen] = useState(null);

  // Para saber si a este usuario le mostramos el link al módulo Estados de equipo
  const { puedeGestionar: puedeGestionarEstados } = usePermiso('estados_equipo');

  // Al abrir: tipos y estados para los desplegables
  useEffect(() => {
    api.get('/tipo-equipos/').then(({ data }) => setTipos(data));
    api.get('/estado-equipos/').then(({ data }) => setEstados(data));
  }, []);

  // Al editar: se traen los datos del equipo
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

  // Al crear: se arma el panel de la derecha con los equipos que ya están cargados
  useEffect(() => {
    if (editando) return;
    api.get('/equipos/').then(({ data }) => setResumen(armarResumen(data))).catch(() => {});
  }, [editando]);

  // Cambia un solo campo del formulario y deja los demás como estaban
  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Guardar: si se está editando hace PUT y muestra la ventana de éxito; si es un alta hace
  // POST y vuelve a la lista. Si el backend rechaza los datos (400), se muestran sus errores.
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

  // Mientras se traen los datos del registro a editar
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

  // Los campos del formulario (los mismos para crear y para editar)
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

      <div className="form-grid-2">
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
          <select
            id="id_estadoeq"
            value={form.id_estadoeq}
            onChange={(e) => actualizar('id_estadoeq', e.target.value)}
            required
          >
            <option value="">Seleccionar...</option>
            {estados.map((estado) => (
              <option key={estado.id_estadoeq} value={estado.id_estadoeq}>{estado.nombre_estadoeq}</option>
            ))}
          </select>
          {errores.id_estadoeq && <span className="form-error">{errores.id_estadoeq}</span>}
          {/* Los estados ya no se agregan desde acá: se le avisa al usuario dónde se hace
              (solo a los que tienen permiso para gestionarlos) */}
          {puedeGestionarEstados && (
            <span className="form-hint">
              ¿Falta un estado? Se agregan desde <Link to="/estados-equipo">Estados de equipo</Link>.
            </span>
          )}
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
      </div>

      {/* Botones separados del formulario por una línea, como en "Nuevo cliente" */}
      <div className="form-acciones">
        <button type="submit" className="btn btn-primary" disabled={guardando}>
          {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear equipo'}
        </button>
        <button type="button" className="btn btn-outline" onClick={() => navigate('/equipos')}>
          {editando ? 'Descartar cambios' : 'Cancelar'}
        </button>
      </div>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar equipo" subtitulo={form.nombre_equipo} onClose={() => navigate('/equipos')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <PantallaAlta
      titulo="Nuevo equipo"
      seccion="Equipos"
      rutaSeccion="/equipos"
      tituloFormulario="Datos del equipo"
      subtituloFormulario="Completá la información del equipo y cuántas unidades tenés."
      aviso="Verificá que el equipo no esté ya cargado. Si es el mismo, sumá las unidades en Cantidad en Stock en lugar de crear otro registro."
      resumen={{
        titulo: 'Resumen de equipos',
        filas: [
          { etiqueta: 'Equipos cargados', valor: resumen?.cargados },
          { etiqueta: 'Unidades en total', valor: resumen?.unidades },
          { etiqueta: 'Unidades en reparación', valor: resumen?.enReparacion },
        ],
      }}
      ultimo={{ etiqueta: 'Último equipo cargado', texto: resumen?.ultimo, vacio: 'Todavía no hay equipos' }}
    >
      {formulario}
    </PantallaAlta>
  );
}
