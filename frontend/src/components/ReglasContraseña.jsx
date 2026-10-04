import { REGLAS_CONTRASEÑA } from '../utils/contraseña';

// Lista de requisitos de la contraseña que se va tildando en verde a medida que
// el usuario escribe, así sabe qué le falta sin tener que enviar el formulario
export default function ReglasContraseña({ contraseña }) {
  return (
    <ul className="reglas-contraseña" aria-label="Requisitos de la contraseña">
      {REGLAS_CONTRASEÑA.map((regla) => {
        const ok = regla.cumple(contraseña);
        return (
          <li key={regla.texto} className={ok ? 'cumple' : ''}>
            <span aria-hidden="true">{ok ? '✓' : '○'}</span> {regla.texto}
          </li>
        );
      })}
    </ul>
  );
}
