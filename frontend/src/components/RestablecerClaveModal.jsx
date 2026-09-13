import { useState } from 'react';
import './ConfirmModal.css';

export default function RestablecerClaveModal({ usuario, onCancelar, onConfirmar }) {
  const [contraseña, setContraseña] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function confirmar(e) {
    e.preventDefault();
    if (contraseña.length < 4) {
      setError('La contraseña debe tener al menos 4 caracteres.');
      return;
    }
    setError('');
    setEnviando(true);
    try {
      await onConfirmar(contraseña);
    } catch (err) {
      setError(
        err.response?.data?.contraseña?.[0] ||
        err.response?.data?.detail ||
        'No se pudo restablecer la contraseña.'
      );
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="confirm-backdrop" onClick={onCancelar}>
      <form className="confirm-card" onClick={(e) => e.stopPropagation()} onSubmit={confirmar}>
        <h3>Restablecer clave</h3>
        <p>
          Definí una contraseña provisoria para <strong>{usuario.usuario}</strong>.
          Va a tener que cambiarla en su próximo inicio de sesión.
        </p>
        <div className="form-field">
          <label htmlFor="clave-provisoria">Contraseña provisoria</label>
          <input
            id="clave-provisoria"
            type="text"
            value={contraseña}
            onChange={(e) => setContraseña(e.target.value)}
            autoFocus
            required
          />
        </div>
        {error && <div className="alert alert-error">{error}</div>}
        <div className="confirm-actions">
          <button type="button" className="btn btn-secondary" onClick={onCancelar} disabled={enviando}>
            Cancelar
          </button>
          <button type="submit" className="btn btn-primary" disabled={enviando}>
            {enviando ? 'Guardando...' : 'Restablecer'}
          </button>
        </div>
      </form>
    </div>
  );
}