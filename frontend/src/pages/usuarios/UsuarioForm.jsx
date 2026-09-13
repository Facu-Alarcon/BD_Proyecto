
import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

const FORM_VACIO = { id_perfil: '', dni: '', nombre: '', apellido: '', correo: '', contraseña: '' };

export default function UsuarioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [perfiles, setPerfiles] = useState([]);
  const [form, setForm] = useState(FORM_VACIO);
  const [datosUsuario, setDatosUsuario] = useState(null); // solo lectura: usuario/activo/fechas
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    api.get('/perfiles/').then(({ data }) => setPerfiles(data));
  }, []);

  useEffect(() => {
    if (!editando) return;
    api.get(`/usuarios/${id}/`).then(({ data }) => {
      setForm({
        id_perfil: data.id_perfil,
        dni: data.dni,
        nombre: data.nombre,
        apellido: data.apellido,
        correo: data.correo,
        contraseña: '',
      });
      setDatosUsuario(data);
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        // Por consigna, un usuario ya creado solo puede modificar el Correo:
        // el resto se manda igual (el backend lo ignora, ver UsuariosSerializer.update).
        await api.put(`/usuarios/${id}/`, {
          id_perfil: form.id_perfil,
          dni: form.dni,
          nombre: form.nombre,
          apellido: form.apellido,
          correo: form.correo,
        });
        setGuardadoOk(true);
      } else {
        await api.post('/usuarios/', {
          id_perfil: form.id_perfil,
          dni: form.dni,
          nombre: form.nombre,
          apellido: form.apellido,
          correo: form.correo,
          contraseña: form.contraseña,
        });
        navigate('/usuarios');
      }
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el usuario.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Usuario modificado correctamente"
        subtitulo={datosUsuario?.usuario}
        textoBoton="Volver a usuarios"
        onContinuar={() => navigate('/usuarios')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="id_perfil">Perfil</label>
        <select
          id="id_perfil"
          value={form.id_perfil}
          onChange={(e) => actualizar('id_perfil', e.target.value)}
          disabled={editando}
          required
        >
          <option value="">Seleccionar...</option>
          {perfiles.map((p) => (
            <option key={p.id_perfil} value={p.id_perfil}>{p.tipo_perfil}</option>
          ))}
        </select>
        {errores.id_perfil && <span className="form-error">{errores.id_perfil}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="dni">DNI</label>
        <input
          id="dni"
          value={form.dni}
          onChange={(e) => actualizar('dni', e.target.value)}
          disabled={editando}
          maxLength={8}
          placeholder="Ej: 30123456"
          required
        />
        {errores.dni && <span className="form-error">{errores.dni}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="nombre">Nombre</label>
        <input
          id="nombre"
          value={form.nombre}
          onChange={(e) => actualizar('nombre', e.target.value)}
          disabled={editando}
          maxLength={30}
          required
        />
        {errores.nombre && <span className="form-error">{errores.nombre}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="apellido">Apellido</label>
        <input
          id="apellido"
          value={form.apellido}
          onChange={(e) => actualizar('apellido', e.target.value)}
          disabled={editando}
          maxLength={30}
          required
        />
        {errores.apellido && <span className="form-error">{errores.apellido}</span>}
      </div>

      {editando && (
        <div className="form-field">
          <label>Nombre de usuario</label>
          <input value={datosUsuario?.usuario || ''} disabled />
          <span className="form-hint">Se genera solo (apellido + inicial del nombre); no se puede editar.</span>
        </div>
      )}

      <div className="form-field">
        <label htmlFor="correo">Correo</label>
        <input
          id="correo"
          type="email"
          value={form.correo}
          onChange={(e) => actualizar('correo', e.target.value)}
          required
        />
        {errores.correo && <span className="form-error">{errores.correo}</span>}
      </div>

      {!editando && (
        <div className="form-field">
          <label htmlFor="contraseña">Contraseña</label>
          <input
            id="contraseña"
            type="password"
            value={form.contraseña}
            onChange={(e) => actualizar('contraseña', e.target.value)}
            required
          />
          <span className="form-hint">Obligatoria para un usuario nuevo.</span>
          {errores.contraseña && <span className="form-error">{errores.contraseña}</span>}
        </div>
      )}

      {editando && datosUsuario && (
        <div className="form-field">
          <label>Estado</label>
          <div>
            {datosUsuario.activo
              ? <span className="badge badge-green">Activo</span>
              : <span className="badge badge-red">Inactivo{datosUsuario.fecha_baja ? ` desde ${datosUsuario.fecha_baja}` : ''}</span>}
            {datosUsuario.debe_cambiar_clave && (
              <span className="badge badge-amber" style={{ marginLeft: 6 }}>Debe cambiar clave</span>
            )}
          </div>
          <span className="form-hint">Última modificación: {datosUsuario.fecha_ultima_modificacion}</span>
        </div>
      )}

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear usuario'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/usuarios')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar usuario" subtitulo={datosUsuario?.usuario} onClose={() => navigate('/usuarios')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Usuario</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        {formulario}
      </div>
    </div>
  );
}