import { useState } from 'react';
import AvisoContraseñaTemporal from './AvisoContraseñaTemporal';
import './ConfirmModal.css';

// Ventana para restablecer la clave de un usuario. El administrador ya no escribe la
// contraseña: el sistema genera una temporal y se la manda por mail al empleado.
// Tiene dos pasos: primero se confirma, y después se muestra qué pasó con el mail.
// 'onConfirmar' tiene que devolver lo que responde la API ({ mail_enviado, correo, ... }).
export default function RestablecerClaveModal({ usuario, onCancelar, onConfirmar, onTerminar }) {
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [resultado, setResultado] = useState(null);

  async function confirmar() {
    setError('');
    setEnviando(true);
    try {
      setResultado(await onConfirmar());
    } catch (err) {
      setError(err.response?.data?.detail || 'No se pudo restablecer la contraseña.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="confirm-backdrop" onClick={resultado ? onTerminar : onCancelar}>
      <div className="confirm-card" onClick={(e) => e.stopPropagation()}>
        <h3>Restablecer clave</h3>

        {/* Paso 1: confirmar */}
        {!resultado && (
          <>
            <p>
              Se va a generar una contraseña temporal nueva para <strong>{usuario.usuario}</strong> y
              se le va a enviar a <strong>{usuario.correo}</strong>. La contraseña actual deja de
              funcionar y tiene que cambiarla en su próximo ingreso.
            </p>
            {error && <div className="alert alert-error">{error}</div>}
            <div className="confirm-actions">
              <button type="button" className="btn btn-secondary" onClick={onCancelar} disabled={enviando}>
                Cancelar
              </button>
              <button type="button" className="btn btn-primary" onClick={confirmar} disabled={enviando}>
                {enviando ? 'Enviando...' : 'Restablecer y enviar'}
              </button>
            </div>
          </>
        )}

        {/* Paso 2: qué pasó con el mail */}
        {resultado && (
          <>
            <AvisoContraseñaTemporal resultado={resultado} />
            <div className="confirm-actions">
              <button type="button" className="btn btn-primary" onClick={onTerminar}>
                Listo
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
