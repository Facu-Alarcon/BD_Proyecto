import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Permisos (alta y edición): nombre, descripción y si está activo.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function PermisoForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState({
    nombre_permiso: '',
    descripcion_permiso: '',
    estado_permiso: true,
  });
  // Errores que devuelve el backend, por campo (ej: { telefono_emp: ["..."] })
  const [errores, setErrores] = useState({});
  // Al editar arranca en "cargando" hasta que llegan los datos del registro
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/permisos/${id}/`).then(({ data }) => {
      setForm(data);
      setCargando(false);
    });
  }, [id, editando]);

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
        await api.put(`/permisos/${id}/`, form);
        setGuardadoOk(true);
      } else {
        await api.post('/permisos/', form);
        navigate('/permisos');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el permiso.' });
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
        titulo="Permiso modificado correctamente"
        subtitulo={form.nombre_permiso}
        textoBoton="Volver a permisos"
        onContinuar={() => navigate('/permisos')}
      />
    );
  }

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="nombre_permiso">Nombre del Permiso</label>
        <input
          id="nombre_permiso"
          placeholder="Ej: Ver Reportes"
          value={form.nombre_permiso}
          onChange={(e) => actualizar('nombre_permiso', e.target.value)}
          required
        />
        {errores.nombre_permiso && <span className="form-error">{errores.nombre_permiso}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="descripcion_permiso">Descripción</label>
        <input
          id="descripcion_permiso"
          placeholder="Ej: Permite ver los reportes de ventas"
          value={form.descripcion_permiso}
          onChange={(e) => actualizar('descripcion_permiso', e.target.value)}
        />
      </div>

      <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <input
          type="checkbox"
          checked={form.estado_permiso}
          onChange={(e) => actualizar('estado_permiso', e.target.checked)}
        />
        Activo
      </label>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear permiso'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/permisos')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar permiso" subtitulo={form.nombre_permiso} onClose={() => navigate('/permisos')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Permiso</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        {formulario}
      </div>
    </div>
  );
}
