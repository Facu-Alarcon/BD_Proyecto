import BotonDescargarPng from './BotonDescargarPng';
import './GraficoBarras.css';

// Gráfico de los reportes que se muestra como imagen, sin cartelito al pasar el mouse:
// barras agrupadas, torta, líneas con tendencia y mapa de calor.
// El dibujo lo hace el backend con pandas, numpy y matplotlib (ver infinito_sonido/graficos.py)
// y llega como imagen PNG. Debajo del título va el botón para descargarla.
//
// Recibe:
//   titulo        -> el título del gráfico
//   periodo       -> el texto que va debajo del título (ej: "De enero de 2026 a diciembre de 2026")
//   grafico       -> lo que manda el backend: { imagen }
//   nombreArchivo -> el nombre del .png que se descarga (sin la extensión)
//   angosto       -> true para los gráficos que no necesitan todo el ancho (la torta)
export default function GraficoImagen({ titulo, periodo, grafico, nombreArchivo, angosto = false }) {
  return (
    <figure className="grafico">
      <figcaption className="grafico-cabecera">
        <div>
          <div className="grafico-titulo">{titulo}</div>
          {periodo && <div className="grafico-periodo">{periodo}</div>}
        </div>
        <BotonDescargarPng imagen={grafico.imagen} nombreArchivo={nombreArchivo} />
      </figcaption>
      <div className={`grafico-lienzo${angosto ? ' grafico-lienzo-angosto' : ''}`}>
        <img src={grafico.imagen} alt={periodo ? `${titulo}. ${periodo}` : titulo} />
      </div>
    </figure>
  );
}
