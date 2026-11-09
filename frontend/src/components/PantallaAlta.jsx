import { Link, useNavigate } from 'react-router-dom';
import { IconVolver } from './icons';

// Pantalla de alta ("Nuevo equipo", "Nuevo empleado", "Nuevo servicio", "Nueva reserva"):
// el formulario va a la izquierda y a la derecha un panel de ayuda con tres tarjetas, igual
// que en "Nuevo cliente" (ver ClienteForm.jsx). Los estilos están en index.css (.alta-*, .aside-*).
//
// Recibe:
//   titulo, seccion, rutaSeccion -> el título de la pantalla ("Nuevo equipo"), el nombre de la
//                                   sección ("Equipos") y su ruta ("/equipos"): arman la flecha
//                                   de volver y la ruta de arriba ("Equipos / Nuevo equipo")
//   tituloFormulario, subtituloFormulario -> encabezado de la tarjeta del formulario
//   aviso    -> texto de la tarjeta azul "Antes de guardar"
//   resumen  -> { titulo, filas: [{ etiqueta, valor, verde }] }: la tarjeta blanca con los números.
//               Si el valor todavía no llegó (o no se pudo calcular) se muestra "—".
//               "verde" pinta la pastillita en verde claro.
//   ultimo   -> { etiqueta, texto, vacio }: la tarjeta verde con el último registro cargado.
//               Mientras los datos no llegaron (texto undefined) se muestra "—"; si llegaron y
//               no hay ningún registro (texto null) se muestra "vacio" (ej: "Todavía no hay equipos").
//   children -> el formulario
export default function PantallaAlta({
  titulo,
  seccion,
  rutaSeccion,
  tituloFormulario,
  subtituloFormulario,
  aviso,
  resumen,
  ultimo,
  children,
}) {
  const navigate = useNavigate();

  return (
    <div>
      <div className="page-header page-header-con-ruta">
        <div>
          {/* Flecha para volver a la lista, al lado del título */}
          <div className="titulo-con-volver">
            <button type="button" className="btn-volver" onClick={() => navigate(rutaSeccion)} title={`Volver a ${seccion}`} aria-label={`Volver a ${seccion}`}>
              <IconVolver />
            </button>
            <h1>{titulo}</h1>
          </div>
          {/* Ruta para saber dónde estamos y volver a la lista con un clic */}
          <nav className="ruta" aria-label="Ruta">
            <Link to={rutaSeccion}>{seccion}</Link> / <strong>{titulo}</strong>
          </nav>
        </div>
      </div>

      <div className="alta-layout">
        <section className="card alta-form">
          <h2 className="alta-titulo">{tituloFormulario}</h2>
          <p className="alta-subtitulo">{subtituloFormulario}</p>
          {children}
        </section>

        <aside className="alta-aside">
          {/* Recordatorio antes de guardar */}
          <div className="aside-aviso">
            <h3>Antes de guardar</h3>
            <p>{aviso}</p>
          </div>

          {/* Números rápidos */}
          <div className="card aside-resumen">
            <h3>{resumen.titulo}</h3>
            {resumen.filas.map((fila) => (
              <div className="aside-fila" key={fila.etiqueta}>
                <span>{fila.etiqueta}</span>
                <span className={`aside-numero${fila.verde ? ' aside-numero-verde' : ''}`}>{fila.valor ?? '—'}</span>
              </div>
            ))}
          </div>

          {/* Último registro que se dio de alta */}
          <div className="aside-ultimo">
            <span>{ultimo.etiqueta}</span>
            <strong>{ultimo.texto === undefined ? '—' : ultimo.texto || ultimo.vacio}</strong>
          </div>
        </aside>
      </div>
    </div>
  );
}
