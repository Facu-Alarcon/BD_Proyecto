import { useEffect, useState } from 'react';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

// Nombre lindo de cada parámetro para mostrar en pantalla (en la base está la clave)
const NOMBRES = {
  DIAS_AVISO_SALDO: 'Días de aviso de saldo pendiente',
  DIAS_AVISO_CONFIRMACION: 'Días de aviso de reserva sin confirmar',
  FACTOR_MONTO_INUSUAL: 'Desvíos para considerar un monto inusual',
  MINIMO_RESERVAS_COMPARAR: 'Reservas mínimas para comparar montos',
};

// Pantalla "Configuración de alertas": los umbrales de las reglas de aviso (tabla Configuracion).
// Se cambian acá sin tocar el código. Quien solo tiene permiso de ver, los ve pero no los edita.
export default function ConfiguracionAlertas() {
  const [parametros, setParametros] = useState([]);
  // Lo que está escrito en cada casillero (puede no estar guardado todavía): { clave: valor }
  const [valores, setValores] = useState({});
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [mensaje, setMensaje] = useState('');
  const { puedeGestionar } = usePermiso('configuracion');

  useEffect(() => {
    api
      .get('/configuracion/')
      .then(({ data }) => {
        setParametros(data);
        setValores(Object.fromEntries(data.map((p) => [p.clave, p.valor])));
      })
      .catch(() => setError('No se pudo cargar la configuración.'))
      .finally(() => setCargando(false));
  }, []);

  // Guarda un parámetro. Si el servidor lo rechaza (ej: no es un número), muestra el motivo abajo del casillero
  function guardar(clave) {
    setMensaje('');
    setErrores((e) => ({ ...e, [clave]: '' }));
    api
      .patch(`/configuracion/${clave}/`, { valor: valores[clave] })
      .then(({ data }) => {
        setParametros((anteriores) => anteriores.map((p) => (p.clave === clave ? data : p)));
        setValores((v) => ({ ...v, [clave]: data.valor }));
        setMensaje(`Se guardó "${NOMBRES[clave] || clave}". Se aplica desde la próxima revisión de alertas.`);
      })
      .catch((err) => {
        const detalle = err.response?.data?.valor?.[0] || err.response?.data?.detail || 'No se pudo guardar.';
        setErrores((e) => ({ ...e, [clave]: detalle }));
      });
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Configuración de alertas</h1>
          <p>Umbrales que usan las reglas de aviso. Se guardan en la base de datos, no en el código.</p>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {mensaje && <div className="alert alert-success">{mensaje}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Parámetro</th>
              <th>Para qué sirve</th>
              <th style={{ width: 220 }}>Valor</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {parametros.map((p) => {
              const cambiado = valores[p.clave] !== p.valor;
              return (
                <tr key={p.clave}>
                  <td>
                    <strong>{NOMBRES[p.clave] || p.clave}</strong>
                    <div className="form-hint"><code>{p.clave}</code></div>
                  </td>
                  <td>{p.descripcion}</td>
                  <td>
                    {puedeGestionar ? (
                      <div className="form-field">
                        <div style={{ display: 'flex', gap: 8 }}>
                          <input
                            type="text"
                            inputMode="decimal"
                            value={valores[p.clave] ?? ''}
                            onChange={(e) => setValores((v) => ({ ...v, [p.clave]: e.target.value }))}
                            style={{ width: 90 }}
                            aria-label={NOMBRES[p.clave] || p.clave}
                          />
                          <button type="button" className="btn btn-primary btn-sm" onClick={() => guardar(p.clave)} disabled={!cambiado}>
                            Guardar
                          </button>
                        </div>
                        {errores[p.clave] && <span className="form-error">{errores[p.clave]}</span>}
                      </div>
                    ) : (
                      <strong>{p.valor}</strong>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
