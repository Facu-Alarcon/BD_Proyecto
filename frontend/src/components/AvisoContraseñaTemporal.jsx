import { useState } from 'react';

// Muestra qué pasó con la contraseña temporal después de crear un usuario o de
// restablecerle la clave. Recibe lo que devuelve la API:
//   { mail_enviado, correo, contraseña_temporal (solo si el mail no salió) }
export default function AvisoContraseñaTemporal({ resultado }) {
  const [copiada, setCopiada] = useState(false);

  // Si el mail salió, el administrador no ve la contraseña: solo le llega al empleado
  if (resultado.mail_enviado) {
    return (
      <div className="alert alert-success">
        Se envió la contraseña temporal a <strong>{resultado.correo}</strong>. En su primer ingreso
        el sistema le va a pedir que la cambie.
      </div>
    );
  }

  // Copia la contraseña al portapapeles para pegarla en un WhatsApp o un mail
  async function copiar() {
    try {
      await navigator.clipboard.writeText(resultado.contraseña_temporal);
      setCopiada(true);
    } catch {
      setCopiada(false);
    }
  }

  // Si el mail no salió (no hay cuenta de Gmail configurada o falló el envío),
  // esta es la única vez que se puede ver la contraseña
  return (
    <div className="aviso-contraseña">
      <p>
        No se pudo enviar el mail a <strong>{resultado.correo}</strong>. Pasale esta contraseña
        temporal al empleado. <strong>Es la única vez que se muestra.</strong>
      </p>
      <div className="aviso-contraseña-valor">
        <code>{resultado.contraseña_temporal}</code>
        <button type="button" className="btn btn-secondary btn-sm" onClick={copiar}>
          {copiada ? 'Copiada' : 'Copiar'}
        </button>
      </div>
      <p className="form-hint">En su primer ingreso el sistema le va a pedir que la cambie.</p>
    </div>
  );
}
