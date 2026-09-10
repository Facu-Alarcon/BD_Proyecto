import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

const VACIO = { nombre_emp: '', apellido_emp: '', telefono_emp: '', email_emp: '' };

export default function EmpleadoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState(VACIO);
  const [puestos, setPuestos] = useState([]);
  const [seleccionados, setSeleccionados] = useState(new Set());
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

  useEffect(() => {
    if (editando) {
      Promise.all([
        api.get(`/empleados/${id}/`),
        api.get(`/empleados/${id}/puestos/`),
      ]).then(([empleadoRes, puestosRes]) => {
        setForm(empleadoRes.data);
        setPuestos(puestosRes.data);
        setSeleccionados(new Set(puestosRes.data.filter((p) => p.asignado).map((p) => p.id_puesto)));
        setCargando(false);
      });
    } else {
      api.get('/puestos/').then(({ data }) => {
        setPuestos(data);
        setCargando(false);
      });
    }
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  function togglePuesto(idPuesto) {
    setSeleccionados((prev) => {
      const next = new Set(prev);
      next.has(idPuesto) ? next.delete(idPuesto) : next.add(idPuesto);
      return next;
    });
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      let empleadoId = id;
      if (editando) {
        await api.put(`/empleados/${id}/`, form);
      } else {
        const { data } = await api.post('/empleados/', form);
        empleadoId = data.id_empleado;
      }
      await api.put(`/empleados/${empleadoId}/puestos/`, { puestos: Array.from(seleccionados) });

      if (editando) {
        setGuardadoOk(true);
      } else {
        navigate('/empleados');
      }
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

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Empleado modificado correctamente"
        subtitulo={`${form.nombre_emp} ${form.apellido_emp}`}
        textoBoton="Volver a empleados"
        onContinuar={() => navigate('/empleados')}
      />
    );
  }

  const formulario = (
    <form onSubmit={handleSubmit}>
      {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

      <div className="form-field">
        <label htmlFor="nombre_emp">Nombre</label>
        <input id="nombre_emp" placeholder="Ej: Facundo" maxLength={30} pattern="[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+" title="Solo letras, sin números" value={form.nombre_emp} onChange={(e) => actualizar('nombre_emp', e.target.value)} required />
        {errores.nombre_emp && <span className="form-error">{errores.nombre_emp}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="apellido_emp">Apellido</label>
        <input id="apellido_emp" placeholder="Ej: Alarcón" maxLength={30} pattern="[A-Za-zÁÉÍÓÚáéíóúÑñÜü' -]+" title="Solo letras, sin números" value={form.apellido_emp} onChange={(e) => actualizar('apellido_emp', e.target.value)} required />
        {errores.apellido_emp && <span className="form-error">{errores.apellido_emp}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="telefono_emp">Teléfono</label>
        <input id="telefono_emp" placeholder="Ej: 3871234567" type="tel" inputMode="numeric" minLength={10} maxLength={12} pattern="[0-9]{10,12}" value={form.telefono_emp} onChange={(e) => actualizar('telefono_emp', e.target.value)} required />
        {errores.telefono_emp && <span className="form-error">{errores.telefono_emp}</span>}
      </div>

      <div className="form-field">
        <label htmlFor="email_emp">Email</label>
        <input id="email_emp" placeholder="Ej: facundo@infinito.com" type="email" value={form.email_emp} onChange={(e) => actualizar('email_emp', e.target.value)} required />
        {errores.email_emp && <span className="form-error">{errores.email_emp}</span>}
      </div>

      <div className="form-field">
        <label>Puestos</label>
        <div className="checkbox-list">
          {puestos.length === 0 && <p className="form-hint">No hay puestos cargados todavía.</p>}
          {puestos.map((puesto) => (
            <label key={puesto.id_puesto} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, padding: '6px 0' }}>
              <span>{puesto.nombre_puesto}</span>
              <span style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                  ${Number(puesto.sueldo_monto).toLocaleString('es-AR')}
                </span>
                <input type="checkbox" checked={seleccionados.has(puesto.id_puesto)} onChange={() => togglePuesto(puesto.id_puesto)} />
              </span>
            </label>
          ))}
        </div>
      </div>

      <button type="submit" className="btn btn-primary" disabled={guardando}>
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear empleado'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/empleados')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal
        titulo="Editar empleado"
        subtitulo={`${form.nombre_emp} ${form.apellido_emp}`}
        onClose={() => navigate('/empleados')}
        wide
      >
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Empleado</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28 }}>
        {formulario}
      </div>
    </div>
  );
}
