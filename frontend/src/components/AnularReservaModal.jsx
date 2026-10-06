import { useState } from 'react';
import api from '../api/client';
import './ConfirmModal.css';

// Ventana para anular una reserva. Pide el motivo (obligatorio) y llama a la API.
// La reserva no se borra: queda Anulada con fecha, motivo y usuario (ver "anular" en api.py).
// Si la API no deja anular (tiene pagos, ya se realizó, etc.) el motivo se muestra acá mismo.
export default function AnularReservaModal({ reserva, onCancelar, onAnulada }) {
  const [motivo, setMotivo] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function confirmar(e) {
    e.preventDefault();
    // Se revisa antes de mandar (el backend lo vuelve a controlar)
    if (motivo.trim().length < 10) {
      setError('Escribí el motivo de la anulación (al menos 10 caracteres).');
      return;
    }
    setError('');
    setEnviando(true);
    try {
      await api.post(`/reservas/${reserva.id_reserva}/anular/`, { motivo: motivo.trim() });
      onAnulada();
    } catch (err) {
      const datos = err.response?.data;
      setError(datos?.detail || datos?.motivo || 'No se pudo anular la reserva.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="confirm-backdrop" onClick={onCancelar}>
      <form className="confirm-card" onClick={(e) => e.stopPropagation()} onSubmit={confirmar}>
        <h3>Anular reserva N° {String(reserva.id_reserva).padStart(6, '0')}</h3>
        <p>
          <strong>{reserva.cliente_nombre}</strong>
          {reserva.nombre_evento && ` · ${reserva.nombre_evento}`}
          <br />
          La reserva no se borra: queda <strong>Anulada</strong> y sus equipos y personal vuelven a
          estar disponibles para ese día. Esta acción no se puede deshacer.
        </p>

        <div className="form-field">
          <label htmlFor="motivo-anulacion">Motivo de la anulación <span className="requerido">*</span></label>
          <textarea
            id="motivo-anulacion"
            rows={3}
            maxLength={255}
            placeholder="Ej: El cliente canceló el evento."
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            autoFocus
          />
          <span className="form-hint">{motivo.length}/255</span>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <div className="confirm-actions">
          <button type="button" className="btn btn-secondary" onClick={onCancelar} disabled={enviando}>
            Volver
          </button>
          <button type="submit" className="btn btn-danger" disabled={enviando}>
            {enviando ? 'Anulando...' : 'Anular reserva'}
          </button>
        </div>
      </form>
    </div>
  );
}
