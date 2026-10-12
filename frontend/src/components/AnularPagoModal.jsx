import { useState } from 'react';
import api from '../api/client';
import './ConfirmModal.css';

// Ventana para anular un pago. Pide el motivo, que es obligatorio, y se lo manda al backend.
// El pago no se borra: queda como "Anulado", con la fecha, el motivo y quién lo anuló, y
// deja de contar para lo que falta pagar de la reserva (ver "anular" en PagosViewSet, api.py).
// Está hecha igual que la ventana de anular reservas (AnularReservaModal.jsx).
//
// Recibe:
//   pago       -> el pago que se va a anular
//   onCancelar -> qué hacer si el usuario se arrepiente (cerrar la ventana)
//   onAnulado  -> qué hacer cuando el pago ya quedó anulado (cerrar y recargar la lista)
export default function AnularPagoModal({ pago, onCancelar, onAnulado }) {
  const [motivo, setMotivo] = useState('');      // lo que va escribiendo el usuario
  const [error, setError] = useState('');        // mensaje de error para mostrar en la ventana
  const [enviando, setEnviando] = useState(false); // true mientras esperamos la respuesta

  // Se ejecuta al apretar "Anular pago"
  async function confirmar(e) {
    // Para que el navegador no recargue la página al enviar el formulario
    e.preventDefault();
    // Revisamos el motivo antes de mandarlo, así el usuario se entera al toque
    // (el backend lo vuelve a controlar igual)
    if (motivo.trim().length < 10) {
      setError('Escribí el motivo de la anulación (al menos 10 caracteres).');
      return;
    }
    setError('');
    setEnviando(true);
    try {
      await api.post(`/pagos/${pago.id_pago}/anular/`, { motivo: motivo.trim() });
      // Salió bien: le avisamos a la pantalla de Pagos
      onAnulado();
    } catch (err) {
      // No se pudo: mostramos el motivo que devuelve el backend (por ejemplo, que ya estaba anulado)
      const datos = err.response?.data;
      setError(datos?.detail || datos?.motivo || 'No se pudo anular el pago.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    // El fondo oscuro: si se hace clic afuera de la tarjeta, se cancela
    <div className="confirm-backdrop" onClick={onCancelar}>
      {/* stopPropagation: para que un clic adentro de la tarjeta no la cierre */}
      <form className="confirm-card" onClick={(e) => e.stopPropagation()} onSubmit={confirmar}>
        <h3>Anular pago de ${Number(pago.monto).toLocaleString('es-AR')}</h3>
        <p>
          <strong>{pago.cliente_nombre}</strong>
          {pago.evento_nombre && ` · ${pago.evento_nombre}`}
          <br />
          El pago no se borra: queda <strong>Anulado</strong> y deja de contar para el saldo de la
          reserva. Esta acción no se puede deshacer.
        </p>

        <div className="form-field">
          <label htmlFor="motivo-anulacion-pago">Motivo de la anulación <span className="requerido">*</span></label>
          <textarea
            id="motivo-anulacion-pago"
            rows={3}
            maxLength={255}
            placeholder="Ej: Se cargó en la reserva equivocada."
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            autoFocus
          />
          {/* Contador de letras: el motivo puede tener hasta 255 */}
          <span className="form-hint">{motivo.length}/255</span>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {/* Mientras se está anulando los botones quedan bloqueados */}
        <div className="confirm-actions">
          <button type="button" className="btn btn-secondary" onClick={onCancelar} disabled={enviando}>
            Volver
          </button>
          <button type="submit" className="btn btn-danger" disabled={enviando}>
            {enviando ? 'Anulando...' : 'Anular pago'}
          </button>
        </div>
      </form>
    </div>
  );
}
