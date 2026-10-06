import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Puestos (alta y edición): nombre y sueldo (con un botón para crear un sueldo nuevo sin salir).
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function PuestoForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [sueldos, setSueldos] = useState([]);
  const [form, setForm] = useState({ nombre_puesto: '', id_sueldo: '' });
  // Errores que devuelve el backend, por campo (ej: { telefono_emp: ["..."] })
  const [errores, setErrores] = useState({});
  // Al editar arranca en "cargando" hasta que llegan los datos del registro
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);

  // Para el botón que permite crear un sueldo nuevo sin salir del formulario
  const [mostrarNuevoSueldo, setMostrarNuevoSueldo] = useState(false);
  const [nuevoMonto, setNuevoMonto] = useState('');
  const [guardandoSueldo, setGuardandoSueldo] = useState(false);
  const [errorSueldo, setErrorSueldo] = useState('');

  // Trae los sueldos para el desplegable (se vuelve a llamar después de crear uno)
  function cargarSueldos() {
    return api.get('/sueldos/').then(({ data }) => {
      setSueldos(data);
      return data;
    });
  }

  useEffect(() => {
    cargarSueldos();
  }, []);

  useEffect(() => {
    if (!editando) return;
    api.get(`/puestos/${id}/`).then(({ data }) => {
      setForm({ nombre_puesto: data.nombre_puesto, id_sueldo: data.id_sueldo });
      setCargando(false);
    });
  }, [id, editando]);

  // Cambia un solo campo del formulario y deja los demás como estaban
  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Crea un sueldo nuevo, recarga la lista y lo deja elegido en el formulario
  async function agregarSueldo(e) {
    e.preventDefault();
    if (!nuevoMonto) return;
    setGuardandoSueldo(true);
    setErrorSueldo('');
    try {
      const { data } = await api.post('/sueldos/', { monto_sueldo: nuevoMonto });
      await cargarSueldos();
      actualizar('id_sueldo', data.id_sueldo);
      setNuevoMonto('');
      setMostrarNuevoSueldo(false);
    } catch (err) {
      setErrorSueldo(err.response?.data?.monto_sueldo?.[0] || 'No se pudo agregar el sueldo.');
    } finally {
      setGuardandoSueldo(false);
    }
  }

  // Guardar: si se está editando hace PUT y muestra la ventana de éxito; si es un alta hace
  // POST y vuelve a la lista. Si el backend rechaza los datos (400), se muestran sus errores.
  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        await api.put(`/puestos/${id}/`, form);
        setGuardadoOk(true);
      } else {
        await api.post('/puestos/', form);
        navigate('/puestos');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el puesto.' });
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
        titulo="Puesto modificado correctamente"
        subtitulo={form.nombre_puesto}
        textoBoton="Volver a puestos"
        onContinuar={() => navigate('/puestos')}
      />
    );
  }

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="nombre_puesto">Nombre del Puesto</label>
        <input
          id="nombre_puesto"
          placeholder="Ej: DJ"
          value={form.nombre_puesto}
          onChange={(e) => actualizar('nombre_puesto', e.target.value)}
          required
        />
        {errores.nombre_puesto && <span className="form-error">{errores.nombre_puesto}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="id_sueldo">Sueldo</label>
        <div style={{ display: 'flex', gap: 8 }}>
          <select
            id="id_sueldo"
            value={form.id_sueldo}
            onChange={(e) => actualizar('id_sueldo', e.target.value)}
            required
            style={{ flex: 1 }}
          >
            <option value="">Seleccionar...</option>
            {sueldos.map((s) => (
              <option key={s.id_sueldo} value={s.id_sueldo}>${Number(s.monto_sueldo).toLocaleString('es-AR')}</option>
            ))}
          </select>
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => setMostrarNuevoSueldo((v) => !v)}
            title="Agregar un sueldo nuevo"
          >
            +
          </button>
        </div>
        {errores.id_sueldo && <span className="form-error">{errores.id_sueldo}</span>}

        {mostrarNuevoSueldo && (
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <input
              autoFocus
              type="number"
              step="0.01"
              min="0"
              placeholder="Monto del sueldo nuevo"
              value={nuevoMonto}
              onChange={(e) => setNuevoMonto(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') agregarSueldo(e);
              }}
              style={{ flex: 1 }}
            />
            <button type="button" className="btn btn-primary btn-sm" onClick={agregarSueldo} disabled={guardandoSueldo}>
              {guardandoSueldo ? 'Agregando...' : 'Agregar'}
            </button>
          </div>
        )}
        {errorSueldo && <span className="form-error">{errorSueldo}</span>}
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear puesto'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/puestos')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar puesto" subtitulo={form.nombre_puesto} onClose={() => navigate('/puestos')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Puesto</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        {formulario}
      </div>
    </div>
  );
}
