import { Fragment, useEffect, useState } from 'react';
import api from '../../api/client';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import Paginacion from '../../components/Paginacion';
import { PersonaCelda } from '../../components/Avatar';
import { useFiltros, opcionesDe } from '../../hooks/useFiltros';
import { usePaginacion } from '../../hooks/usePaginacion';

// Color de la etiqueta según la acción: verde las altas, rojo las bajas y los fallos, etc.
const BADGE_POR_ACCION = {
  ALTA: 'badge-green',
  MODIFICACION: 'badge-amber',
  BAJA: 'badge-red',
  LOGIN: 'badge-gray',
  LOGOUT: 'badge-gray',
  LOGIN_FALLIDO: 'badge-red',
  CLAVE: 'badge-amber',
  ERROR: 'badge-red',
};

// La API manda la fecha completa (con hora y zona); acá se muestra como 04/10/2026 19:45
function formatearFechaHora(iso) {
  const d = new Date(iso);
  const dosDigitos = (n) => String(n).padStart(2, '0');
  return `${dosDigitos(d.getDate())}/${dosDigitos(d.getMonth() + 1)}/${d.getFullYear()} ${dosDigitos(d.getHours())}:${dosDigitos(d.getMinutes())}`;
}

// Fecha local 'AAAA-MM-DD' de un registro, para el filtro de fechas
function diaLocal(iso) {
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Pantalla "Registro de actividad": quién hizo qué y cuándo dentro del sistema.
// Es solo de consulta. Tiene dos pestañas: la actividad de los usuarios (altas,
// modificaciones, bajas, sesiones) y los errores del servidor (para el programador).
export default function RegistroActividad() {
  const [registros, setRegistros] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [pestaña, setPestaña] = useState('actividad');
  const [expandido, setExpandido] = useState(null); // id del registro con el detalle abierto

  function cargar() {
    setCargando(true);
    api
      .get('/registro/')
      .then(({ data }) => setRegistros(data))
      .catch(() => setError('No se pudo cargar el registro de actividad.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  // Separamos los errores del resto para mostrarlos en su propia pestaña
  const actividad = registros.filter((r) => r.accion !== 'ERROR');
  const errores = registros.filter((r) => r.accion === 'ERROR');
  const filas = pestaña === 'actividad' ? actividad : errores;

  // Filtros: en Actividad se puede buscar por acción, módulo y usuario; en Errores alcanza con texto y fechas
  const configFiltros =
    pestaña === 'actividad'
      ? [
          {
            tipo: 'texto', id: 'texto', placeholder: 'Usuario, persona, registro o detalle',
            campos: (r) => [r.usuario_texto, r.persona, r.descripcion, r.detalle],
          },
          { tipo: 'select', id: 'accion', label: 'Acción', valor: (r) => r.accion_display, opciones: opcionesDe(actividad, (r) => r.accion_display) },
          { tipo: 'select', id: 'modulo', label: 'Módulo', valor: (r) => r.modulo, opciones: opcionesDe(actividad, (r) => r.modulo) },
          { tipo: 'select', id: 'usuario', label: 'Usuario', valor: (r) => r.usuario_texto, opciones: opcionesDe(actividad, (r) => r.usuario_texto) },
          { tipo: 'rango', id: 'fecha', label: 'Fecha', input: 'date', valor: (r) => diaLocal(r.fecha) },
        ]
      : [
          { tipo: 'texto', id: 'texto', placeholder: 'Error, ruta o usuario', campos: (r) => [r.descripcion, r.modulo, r.usuario_texto, r.detalle] },
          { tipo: 'rango', id: 'fecha', label: 'Fecha', input: 'date', valor: (r) => diaLocal(r.fecha) },
        ];
  const filtros = useFiltros(filas, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  // Al cambiar de pestaña se limpian los filtros y se cierra el detalle abierto
  function cambiarPestaña(nueva) {
    filtros.limpiar();
    setExpandido(null);
    setPestaña(nueva);
  }

  const columnas = pestaña === 'actividad' ? 6 : 5;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Registro de actividad</h1>
          <p>Altas, modificaciones, bajas, inicios de sesión y errores del sistema.</p>
        </div>
        <button type="button" className="btn btn-secondary" onClick={cargar} disabled={cargando}>
          {cargando ? 'Actualizando...' : 'Actualizar'}
        </button>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {/* Pestañas: actividad de los usuarios / errores del servidor */}
      <div className="pestañas" role="tablist">
        <button type="button" role="tab" aria-selected={pestaña === 'actividad'} className={pestaña === 'actividad' ? 'activa' : ''} onClick={() => cambiarPestaña('actividad')}>
          Actividad <span className="pestaña-cantidad">{actividad.length}</span>
        </button>
        <button type="button" role="tab" aria-selected={pestaña === 'errores'} className={pestaña === 'errores' ? 'activa' : ''} onClick={() => cambiarPestaña('errores')}>
          Errores <span className={`pestaña-cantidad${errores.length ? ' hay-errores' : ''}`}>{errores.length}</span>
        </button>
      </div>

      {/* key: al cambiar de pestaña la barra se arma de nuevo con los filtros de esa pestaña */}
      <BarraFiltros key={pestaña} config={configFiltros} filtros={filtros} total={filas.length} cargando={cargando} nombreItems="registros" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        <table className="data-table">
          <thead>
            {pestaña === 'actividad' ? (
              <tr>
                <th>Fecha</th>
                <th>Usuario</th>
                <th>Acción</th>
                <th>Módulo</th>
                <th>Registro</th>
                <th>Detalle</th>
              </tr>
            ) : (
              <tr>
                <th>Fecha</th>
                <th>Usuario</th>
                <th>Dónde</th>
                <th>Error</th>
                <th>Detalle</th>
              </tr>
            )}
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={columnas} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && filas.length === 0 && (
              <tr>
                <td colSpan={columnas} style={{ textAlign: 'center' }}>
                  {pestaña === 'actividad' ? 'Todavía no hay actividad registrada.' : 'No se registraron errores.'}
                </td>
              </tr>
            )}
            <FilaSinResultados filtros={filtros} total={filas.length} cargando={cargando} columnas={columnas} nombreItems="registros" />
            {paginacion.visibles.map((r) => (
              <Fragment key={r.id_registro}>
                <tr>
                  <td style={{ whiteSpace: 'nowrap', fontVariantNumeric: 'tabular-nums' }}>{formatearFechaHora(r.fecha)}</td>
                  <td>
                    {/* Si el usuario existe se muestra la persona; si fue un login con un usuario inventado, solo el texto */}
                    {r.persona
                      ? <PersonaCelda nombre={r.persona} texto={r.persona} detalle={r.usuario_texto} />
                      : <span className="form-hint">{r.usuario_texto || '—'}</span>}
                  </td>
                  {pestaña === 'actividad' && (
                    <td><span className={`badge ${BADGE_POR_ACCION[r.accion] || 'badge-gray'}`}>{r.accion_display}</span></td>
                  )}
                  <td>{pestaña === 'actividad' ? r.modulo : <code className="registro-ruta">{r.modulo}</code>}</td>
                  <td>{r.descripcion}</td>
                  <td>
                    {r.detalle ? (
                      <button type="button" className="btn btn-secondary btn-sm" onClick={() => setExpandido(expandido === r.id_registro ? null : r.id_registro)}>
                        {expandido === r.id_registro ? 'Ocultar' : 'Ver'}
                      </button>
                    ) : (
                      <span className="form-hint">—</span>
                    )}
                  </td>
                </tr>
                {/* Fila extra con el detalle: qué campos cambiaron, o el error completo */}
                {expandido === r.id_registro && (
                  <tr className="registro-detalle-fila">
                    <td colSpan={columnas}>
                      <pre className="registro-detalle">{r.detalle}</pre>
                      {r.ip && <span className="form-hint">IP: {r.ip}</span>}
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
        <Paginacion paginacion={paginacion} />
      </div>
    </div>
  );
}
