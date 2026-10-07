import './ConfirmModal.css';

// Ventana para confirmar una acción peligrosa (por ejemplo "¿Eliminar el cliente X?").
// Hacer clic afuera de la tarjeta cuenta como Cancelar.
// 'confirmando' deshabilita los botones mientras se espera la respuesta del backend.
export default function ConfirmModal({
  titulo = 'Confirmar',
  mensaje,
  textoConfirmar = 'Eliminar',
  confirmando = false,
  onConfirmar,
  onCancelar,
  // Clase del botón de la acción: rojo por defecto; Confirmar reserva lo usa verde (btn-primary)
  claseBoton = 'btn-danger',
}) {
  return (
    <div className="confirm-backdrop" onClick={onCancelar}>
      {/* stopPropagation: un clic adentro de la tarjeta no llega al fondo, así no se cierra sola */}
      <div className="confirm-card" onClick={(e) => e.stopPropagation()}>
        <h3>{titulo}</h3>
        <p>{mensaje}</p>
        <div className="confirm-actions">
          <button type="button" className="btn btn-secondary" onClick={onCancelar} disabled={confirmando}>
            Cancelar
          </button>
          <button type="button" className={`btn ${claseBoton}`} onClick={onConfirmar} disabled={confirmando}>
            {confirmando ? 'Eliminando...' : textoConfirmar}
          </button>
        </div>
      </div>
    </div>
  );
}
