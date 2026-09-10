import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
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

export default function ClienteForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState(VACIO);
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/clientes/${id}/`).then(({ data }) => {
      setForm(data);
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

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="nombre_cliente">Nombre</label>
        <input id="nombre_cliente" placeholder="Ej: Juan" maxLength={30} pattern="[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+" title="Solo letras, sin números" value={form.nombre_cliente} onChange={(e) => actualizar('nombre_cliente', e.target.value)} required />
        {errores.nombre_cliente && <span className="form-error">{errores.nombre_cliente}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="apellido_cliente">Apellido</label>
        <input id="apellido_cliente" placeholder="Ej: Pérez" maxLength={30} pattern="[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+" title="Solo letras, sin números" value={form.apellido_cliente} onChange={(e) => actualizar('apellido_cliente', e.target.value)} required />
        {errores.apellido_cliente && <span className="form-error">{errores.apellido_cliente}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="domicilio_cliente">Domicilio</label>
        <input id="domicilio_cliente" placeholder="Ej: Av. Belgrano 123" maxLength={60} value={form.domicilio_cliente} onChange={(e) => actualizar('domicilio_cliente', e.target.value)} required />
        {errores.domicilio_cliente && <span className="form-error">{errores.domicilio_cliente}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="telefono_cliente">Teléfono</label>
        <input id="telefono_cliente" placeholder="Ej: 3871234567" type="tel" inputMode="numeric" minLength={10} maxLength={12} pattern="[0-9]{10,12}" value={form.telefono_cliente} onChange={(e) => actualizar('telefono_cliente', e.target.value)} required />
        {errores.telefono_cliente && <span className="form-error">{errores.telefono_cliente}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="email_cliente">Email</label>
        <input id="email_cliente" placeholder="Ej: juan.perez@gmail.com" type="email" value={form.email_cliente} onChange={(e) => actualizar('email_cliente', e.target.value)} required />
        {errores.email_cliente && <span className="form-error">{errores.email_cliente}</span>}
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear cliente'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/clientes')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar cliente" subtitulo={`${form.nombre_cliente} ${form.apellido_cliente}`} onClose={() => navigate('/clientes')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Cliente</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 520 }}>
        {formulario}
      </div>
    </div>
  );
}
