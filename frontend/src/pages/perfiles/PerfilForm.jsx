import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import { useAuth } from '../../context/AuthContext';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

// Formulario de Perfiles (alta y edición): el nombre del perfil y qué permisos tiene.
// Es el mismo componente para crear y para editar: si la URL trae un id (/.../5/editar)
// se está editando y se abre como ventana emergente; si no, es una pantalla de alta común.
export default function PerfilForm() {
  // id viene de la URL; si existe, estamos editando
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();
  const { usuario } = useAuth();

  const [tipoPerfil, setTipoPerfil] = useState('');
  const [permisos, setPermisos] = useState([]);
  // Permisos tildados para este perfil
  const [seleccionados, setSeleccionados] = useState(new Set());
  const [error, setError] = useState('');
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  // Se prende después de guardar una edición, para mostrar la ventana de éxito
  const [guardadoOk, setGuardadoOk] = useState(false);

  // Si estoy editando mi propio perfil hay que tener cuidado: si me saco el permiso de
  // gestionar perfiles, ya no lo voy a poder volver a poner (se pide confirmación al guardar)
  const esMiPropioPerfil = editando && usuario?.id_perfil === Number(id);

  // Al abrir: la lista de permisos (con cuáles tiene el perfil, si se está editando)
  useEffect(() => {
    if (editando) {
      Promise.all([
        api.get(`/perfiles/${id}/`),
        api.get(`/perfiles/${id}/permisos/`),
      ]).then(([perfilRes, permisosRes]) => {
        setTipoPerfil(perfilRes.data.tipo_perfil);
        setPermisos(permisosRes.data);
        setSeleccionados(new Set(permisosRes.data.filter((p) => p.asignado).map((p) => p.id_permiso)));
        setCargando(false);
      });
    } else {
      api.get('/permisos/').then(({ data }) => {
        setPermisos(data);
        setCargando(false);
      });
    }
  }, [id, editando]);

  // Tilda o destilda un permiso
  function toggle(idPermiso) {
    setSeleccionados((prev) => {
      const next = new Set(prev);
      next.has(idPermiso) ? next.delete(idPermiso) : next.add(idPermiso);
      return next;
    });
  }

  // Guardar: si se está editando hace PUT y muestra la ventana de éxito; si es un alta hace
  // POST y vuelve a la lista. Si el backend rechaza los datos (400), se muestran sus errores.
  async function handleSubmit(e) {
    e.preventDefault();

    if (esMiPropioPerfil) {
      const seguisTeniendoGestionPerfiles = permisos
        .filter((p) => seleccionados.has(p.id_permiso))
        .some((p) => p.codigo === 'gestionar_perfiles');
      if (!seguisTeniendoGestionPerfiles) {
        const confirmar = window.confirm(
          'Estás por sacarle a tu propio perfil el permiso de "Gestionar Perfiles". ' +
          'Si continuás, no vas a poder volver a editar permisos vos mismo. ¿Confirmás igual?'
        );
        if (!confirmar) return;
      }
    }

    setGuardando(true);
    setError('');
    try {
      let perfilId = id;
      if (editando) {
        await api.put(`/perfiles/${id}/`, { tipo_perfil: tipoPerfil });
      } else {
        const { data } = await api.post('/perfiles/', { tipo_perfil: tipoPerfil });
        perfilId = data.id_perfil;
      }
      await api.put(`/perfiles/${perfilId}/permisos/`, { permisos: Array.from(seleccionados) });

      if (editando) {
        setGuardadoOk(true);
      } else {
        navigate('/perfiles');
      }
    } catch (err) {
      setError(err.response?.data?.tipo_perfil?.[0] || 'No se pudo guardar el perfil.');
    } finally {
      setGuardando(false);
    }
  }

  // Mientras se traen los datos del registro a editar
  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Perfil modificado correctamente"
        subtitulo={tipoPerfil}
        textoBoton="Volver a perfiles"
        onContinuar={() => navigate('/perfiles')}
      />
    );
  }

  // Los campos del formulario (los mismos para crear y para editar)
  const formulario = (
    <form onSubmit={handleSubmit}>
      {error && <div className="alert alert-error">{error}</div>}

      <div className="form-field">
        <label htmlFor="tipo_perfil">Nombre del Perfil</label>
        <input
          id="tipo_perfil"
          placeholder="Ej: Administrador"
          value={tipoPerfil}
          onChange={(e) => setTipoPerfil(e.target.value)}
          required
        />
      </div>

      {esMiPropioPerfil && (
        <div className="alert" style={{ background: 'var(--amber-bg)', color: 'var(--amber)' }}>
          Este es el perfil de tu propio usuario — tené cuidado de no sacarte el acceso a vos mismo.
        </div>
      )}

      <div className="form-field">
        <label>Permisos</label>
        <div className="checkbox-list">
          {permisos.length === 0 && <p className="form-hint">No hay permisos cargados todavía.</p>}
          {permisos.map((permiso) => (
            <label key={permiso.id_permiso} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, padding: '6px 0' }}>
              <span>
                {permiso.nombre_permiso}
                {!permiso.estado_permiso && <span className="badge badge-gray" style={{ marginLeft: 8 }}>Inactivo</span>}
              </span>
              <input
                type="checkbox"
                checked={seleccionados.has(permiso.id_permiso)}
                onChange={() => toggle(permiso.id_permiso)}
              />
            </label>
          ))}
        </div>
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear perfil'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/perfiles')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  // Editar se muestra como ventana emergente encima de la lista; el alta, como pantalla común
  if (editando) {
    return (
      <FormModal titulo="Editar perfil" subtitulo={tipoPerfil} onClose={() => navigate('/perfiles')} wide>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Perfil</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28 }}>
        {formulario}
      </div>
    </div>
  );
}
