import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';
import SelectBuscable from '../../components/SelectBuscable';
import AvisoContraseñaTemporal from '../../components/AvisoContraseñaTemporal';
import { usuarioSugerido } from '../../utils/nombreUsuario';

// Formulario de usuarios. Un usuario es la cuenta de un empleado ya registrado:
// al crear solo se elige el empleado y el perfil. El nombre de usuario se arma solo con el
// primer apellido + la inicial del nombre, y la contraseña temporal la genera el sistema
// y se la manda por mail.
// Al editar solo se puede cambiar el perfil (los datos de la persona se editan en Empleados).
export default function UsuarioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [perfiles, setPerfiles] = useState([]);
  const [empleados, setEmpleados] = useState([]);
  const [form, setForm] = useState({ id_empleado: '', id_perfil: '' });
  const [datosUsuario, setDatosUsuario] = useState(null); // solo lectura al editar
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);
  const [creado, setCreado] = useState(null); // respuesta de la API al crear (usuario + resultado del mail)

  // Perfiles para el desplegable, y al crear también los empleados
  useEffect(() => {
    api.get('/perfiles/').then(({ data }) => setPerfiles(data));
    if (!editando) api.get('/empleados/').then(({ data }) => setEmpleados(data));
  }, [editando]);

  // Al editar se traen los datos del usuario
  useEffect(() => {
    if (!editando) return;
    api.get(`/usuarios/${id}/`).then(({ data }) => {
      setForm({ id_empleado: data.id_empleado, id_perfil: data.id_perfil });
      setDatosUsuario(data);
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  // Solo se pueden elegir empleados que todavía no tienen usuario
  const disponibles = empleados.filter((e) => !e.tiene_usuario);
  const empleadoElegido = empleados.find((e) => String(e.id_empleado) === String(form.id_empleado));
  // Si al empleado le falta el correo no se puede crear el usuario (ahí le llega la contraseña): se avisa antes de enviar
  const faltanDatos = Boolean(empleadoElegido && !empleadoElegido.email_emp);

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        await api.put(`/usuarios/${id}/`, { id_empleado: form.id_empleado, id_perfil: form.id_perfil });
        setGuardadoOk(true);
      } else {
        const { data } = await api.post('/usuarios/', form);
        setCreado(data);
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

  // Después de crear: se muestra el usuario y qué pasó con el mail de la contraseña temporal
  if (creado) {
    return (
      <div>
        <div className="page-header">
          <div>
            <h1>Usuario creado</h1>
          </div>
        </div>
        <div className="card" style={{ padding: 28, maxWidth: 560 }}>
          <p style={{ marginTop: 0 }}>
            Se creó el usuario de <strong>{creado.nombre} {creado.apellido}</strong> con el perfil{' '}
            <strong>{creado.perfil_nombre}</strong>.
          </p>
          <p>Usuario para ingresar: <strong>{creado.usuario}</strong></p>
          <AvisoContraseñaTemporal resultado={creado} />
          <div className="form-acciones">
            <button type="button" className="btn btn-primary" onClick={() => navigate('/usuarios')}>
              Volver a usuarios
            </button>
          </div>
        </div>
      </div>
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      {/* Empleado: al crear se elige de la lista (con buscador); al editar ya no se puede cambiar */}
      <div className="form-field">
        <label htmlFor="id_empleado">Empleado <span className="requerido">*</span></label>
        {editando ? (
          <input id="id_empleado" value={`${datosUsuario?.nombre} ${datosUsuario?.apellido}`} disabled />
        ) : (
          <SelectBuscable
            id="id_empleado"
            opciones={disponibles.map((e) => ({
              value: e.id_empleado,
              label: `${e.nombre_emp} ${e.apellido_emp}${e.dni ? ` · DNI ${e.dni}` : ' · sin DNI'}`,
            }))}
            value={form.id_empleado}
            onChange={(valor) => actualizar('id_empleado', valor)}
            placeholder="Buscar empleado por nombre o DNI..."
            sinResultados="No hay empleados sin usuario con ese nombre."
            required
          />
        )}
        {!editando && empleados.length > 0 && disponibles.length === 0 && (
          <span className="form-hint">
            Todos los empleados ya tienen usuario. <Link to="/empleados/nuevo">Registrá un empleado nuevo</Link> primero.
          </span>
        )}
        {errores.id_empleado && <span className="form-error">{errores.id_empleado}</span>}
      </div>

      {/* Datos que se toman del empleado elegido, para revisar antes de crear */}
      {(empleadoElegido || editando) && (
        <div className="datos-empleado">
          {/* Al crear se muestra cómo va a quedar el usuario; si ya existe, el sistema le agrega un número */}
          <div>
            <span>{editando ? 'Usuario' : 'Usuario (se genera solo)'}</span>
            <strong>{editando ? datosUsuario?.usuario : usuarioSugerido(empleadoElegido.nombre_emp, empleadoElegido.apellido_emp)}</strong>
          </div>
          <div><span>Correo</span><strong>{editando ? datosUsuario?.correo : empleadoElegido.email_emp || '—'}</strong></div>
        </div>
      )}
      {faltanDatos && (
        <div className="alert alert-error">
          A este empleado le falta el correo.{' '}
          <Link to={`/empleados/${empleadoElegido.id_empleado}/editar`}>Completalo en Empleados</Link> antes de crear el usuario.
        </div>
      )}

      <div className="form-field">
        <label htmlFor="id_perfil">Perfil <span className="requerido">*</span></label>
        <select id="id_perfil" value={form.id_perfil} onChange={(e) => actualizar('id_perfil', e.target.value)} required>
          <option value="">Seleccionar...</option>
          {perfiles.map((p) => (
            <option key={p.id_perfil} value={p.id_perfil}>{p.tipo_perfil}</option>
          ))}
        </select>
        {errores.id_perfil && <span className="form-error">{errores.id_perfil}</span>}
      </div>

      {!editando && (
        <p className="form-hint">
          La contraseña la genera el sistema y se le envía por mail al empleado. En su primer
          ingreso va a tener que cambiarla por una propia.
        </p>
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

      <div className="form-acciones">
        <button type="submit" className="btn btn-primary" disabled={guardando || faltanDatos}>
          {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear usuario y enviar mail'}
        </button>
        <button type="button" className="btn btn-outline" onClick={() => navigate('/usuarios')}>
          {editando ? 'Descartar cambios' : 'Cancelar'}
        </button>
      </div>
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
      <div className="card" style={{ padding: 28, maxWidth: 560 }}>
        {formulario}
      </div>
    </div>
  );
}
