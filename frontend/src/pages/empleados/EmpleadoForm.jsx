import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';

const VACIO = { nombre_emp: '', apellido_emp: '', telefono_emp: '', email_emp: '' };

export default function EmpleadoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState(VACIO);
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/empleados/${id}/`).then(({ data }) => {
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
        await api.put(`/empleados/${id}/`, form);
      } else {
        await api.post('/empleados/', form);
      }
      navigate('/empleados');
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el empleado.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>{editando ? 'Editar Empleado' : 'Nuevo Empleado'}</h1>
        </div>
      </div>

      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        <form onSubmit={handleSubmit}>
          {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

          <div className="form-field">
            <label htmlFor="nombre_emp">Nombre</label>
            <input id="nombre_emp" value={form.nombre_emp} onChange={(e) => actualizar('nombre_emp', e.target.value)} required />
            {errores.nombre_emp && <span className="form-error">{errores.nombre_emp}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="apellido_emp">Apellido</label>
            <input id="apellido_emp" value={form.apellido_emp} onChange={(e) => actualizar('apellido_emp', e.target.value)} required />
            {errores.apellido_emp && <span className="form-error">{errores.apellido_emp}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="telefono_emp">Teléfono</label>
            <input id="telefono_emp" type="number" value={form.telefono_emp} onChange={(e) => actualizar('telefono_emp', e.target.value)} required />
            {errores.telefono_emp && <span className="form-error">{errores.telefono_emp}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="email_emp">Email</label>
            <input id="email_emp" type="email" value={form.email_emp} onChange={(e) => actualizar('email_emp', e.target.value)} required />
            {errores.email_emp && <span className="form-error">{errores.email_emp}</span>}
          </div>

          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>{' '}
          <button type="button" className="btn btn-secondary" onClick={() => navigate('/empleados')}>
            Cancelar
          </button>
        </form>
      </div>
    </div>
  );
}
