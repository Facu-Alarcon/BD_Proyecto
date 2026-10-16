import { useState } from 'react';
import './GraficoBarras.css';

// Gráfico de barras de los reportes: una barra por mes.
// Lo pueden usar todos los reportes que muestren un número por mes.
//
// El dibujo lo hace el backend con pandas y matplotlib (ver infinito_sonido/graficos.py) y
// llega como imagen. Junto con la imagen viene dónde quedó cada barra, y con eso acá se ponen
// encima unas zonas invisibles: al pasar el mouse por un mes, la barra se resalta y aparece
// el cartelito con el detalle.
//
// Recibe:
//   titulo   -> el título del gráfico (qué se está mostrando)
//   periodo  -> el texto del período, que va debajo del título (ej: "De enero de 2026 a diciembre de 2026")
//   grafico  -> lo que manda el backend: { imagen, barras }
//   datos    -> la lista de barras, en el mismo orden: [{ anio, mes, valor, detalle }]
//               "detalle" es un texto extra que aparece al pasar el mouse (ej: "3 reservas")
//   unidad   -> qué se está contando, para el cartelito (ej: "unidades")
//   formato  -> (opcional) cómo se escribe el número en el cartelito. Por ejemplo, para plata:
//               (v) => `$ ${v.toLocaleString('es-AR')}`. Si no se manda, va el número tal cual.

const NOMBRES_MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

// Pasa una proporción que manda el backend (0.25) a porcentaje para el CSS ("25%")
const pct = (valor) => `${valor * 100}%`;

export default function GraficoBarras({ titulo, periodo, grafico, datos, unidad = 'unidades', formato = (v) => v }) {
  // La barra sobre la que está el mouse (su posición en la lista), o null si no hay ninguna
  const [activa, setActiva] = useState(null);

  const datoActivo = activa !== null ? datos[activa] : null;
  const barraActiva = activa !== null ? grafico.barras[activa] : null;

  return (
    <figure className="grafico">
      {/* Título y período arriba del gráfico */}
      <figcaption>
        <div className="grafico-titulo">{titulo}</div>
        <div className="grafico-periodo">{periodo}</div>
      </figcaption>

      {/* position: relative para poder ubicar encima las zonas del mouse y el cartelito.
          Todo se ubica en porcentajes, así acompaña a la imagen cuando se agranda o se achica */}
      <div className="grafico-lienzo">
        <img src={grafico.imagen} alt={`${titulo}. ${periodo}`} />

        {/* La barra activa se oscurece un poco, como en el gráfico de antes */}
        {barraActiva && barraActiva.piso > barraActiva.arriba && (
          <div
            className="grafico-resaltado"
            style={{
              left: pct(barraActiva.izquierda),
              width: pct(barraActiva.derecha - barraActiva.izquierda),
              top: pct(barraActiva.arriba),
              height: pct(barraActiva.piso - barraActiva.arriba),
            }}
          />
        )}

        {/* Zona invisible que ocupa todo el casillero de cada mes: así el cartelito aparece
            aunque el mouse no esté justo arriba de la barra (sirve para las barras bajitas) */}
        {grafico.barras.map((b, i) => (
          <div
            key={`${datos[i].anio}-${datos[i].mes}`}
            className="grafico-zona"
            style={{
              left: pct(b.casillero_izquierda),
              width: pct(b.casillero_derecha - b.casillero_izquierda),
              top: pct(b.zona_arriba),
              height: pct(b.piso - b.zona_arriba),
            }}
            onMouseEnter={() => setActiva(i)}
            onMouseLeave={() => setActiva(null)}
          />
        ))}

        {/* Cartelito que aparece al pasar el mouse por un mes, arriba de esa barra */}
        {datoActivo && (
          <div
            className="grafico-cartel"
            style={{
              left: pct((barraActiva.izquierda + barraActiva.derecha) / 2),
              top: pct(barraActiva.arriba),
            }}
          >
            <strong>{NOMBRES_MES[datoActivo.mes - 1]} {datoActivo.anio}</strong>
            <span>{formato(datoActivo.valor)} {unidad}</span>
            {datoActivo.detalle && <span className="grafico-cartel-detalle">{datoActivo.detalle}</span>}
          </div>
        )}
      </div>
    </figure>
  );
}
