import { useState } from 'react';
import './GraficoBarras.css';

// Gráfico de barras hecho a mano (sin instalar ninguna librería): una barra por mes.
// Lo pueden usar todos los reportes que muestren un número por mes.
//
// Recibe:
//   titulo   -> el título del gráfico (qué se está mostrando)
//   periodo  -> el texto del período, que va debajo del título (ej: "Enero 2026 a diciembre 2026")
//   datos    -> la lista de barras: [{ anio, mes, valor, detalle }]
//               "detalle" es un texto extra que aparece al pasar el mouse (ej: "3 reservas")
//   unidad   -> qué se está contando, para el eje y el cartelito (ej: "unidades")
//   ejeX     -> nombre del eje de abajo (ej: "Mes del evento")
//
// El dibujo se hace sobre una "hoja" de 900 x 360. Después el navegador la agranda o la
// achica sola según el ancho de la pantalla, sin que se deforme.

const ANCHO = 900;
const ALTO = 360;
// Lugar que se deja alrededor del dibujo para los números y los nombres de los ejes
const MARGEN = { arriba: 28, derecha: 16, abajo: 78, izquierda: 62 };

const NOMBRES_MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

// Elige los números que se escriben en el eje de la izquierda, para que queden "redondos"
// (de 1 en 1, de 2 en 2, de 5 en 5, de 10 en 10, de 20 en 20...) y no sean más de 5 o 6.
// Ejemplo: si la barra más alta vale 37, devuelve [0, 10, 20, 30, 40].
function marcasDelEje(maximo) {
  if (maximo <= 0) return [0, 1];
  let paso = 1;
  const candidatos = [1, 2, 5];
  let potencia = 1;
  // Vamos probando pasos cada vez más grandes hasta que entren 5 marcas o menos
  for (;;) {
    const encontrado = candidatos.map((c) => c * potencia).find((p) => maximo / p <= 5);
    if (encontrado) {
      paso = encontrado;
      break;
    }
    potencia *= 10;
  }
  const marcas = [];
  for (let v = 0; v < maximo + paso; v += paso) marcas.push(v);
  return marcas;
}

export default function GraficoBarras({ titulo, periodo, datos, unidad = 'unidades', ejeX = 'Mes' }) {
  // La barra sobre la que está el mouse (su posición en la lista), o null si no hay ninguna
  const [activa, setActiva] = useState(null);

  // Tamaño de la zona donde van las barras (la hoja menos los márgenes)
  const anchoZona = ANCHO - MARGEN.izquierda - MARGEN.derecha;
  const altoZona = ALTO - MARGEN.arriba - MARGEN.abajo;

  const maximo = Math.max(...datos.map((d) => d.valor), 0);
  const marcas = marcasDelEje(maximo);
  const tope = marcas[marcas.length - 1];

  // Cada mes ocupa un "casillero" del mismo ancho; la barra va centrada y es más angosta
  const casillero = anchoZona / datos.length;
  const anchoBarra = Math.min(casillero * 0.6, 46);

  // Convierte un valor (ej: 24 unidades) en la altura del dibujo que le corresponde
  const y = (valor) => MARGEN.arriba + altoZona - (valor / tope) * altoZona;
  const base = MARGEN.arriba + altoZona; // la línea del piso, donde apoyan las barras

  // Para escribir el año debajo de los meses: juntamos los meses seguidos del mismo año.
  // Así se ve clarito dónde termina un año y empieza el otro.
  const anios = [];
  datos.forEach((d, i) => {
    const ultimo = anios[anios.length - 1];
    if (ultimo && ultimo.anio === d.anio) ultimo.hasta = i;
    else anios.push({ anio: d.anio, desde: i, hasta: i });
  });

  const datoActivo = activa !== null ? datos[activa] : null;

  return (
    <figure className="grafico">
      {/* Título y período arriba del gráfico */}
      <figcaption>
        <div className="grafico-titulo">{titulo}</div>
        <div className="grafico-periodo">{periodo}</div>
      </figcaption>

      <div className="grafico-lienzo">
        <svg viewBox={`0 0 ${ANCHO} ${ALTO}`} role="img" aria-label={`${titulo}. ${periodo}`}>
          {/* Líneas horizontales de fondo con su número a la izquierda */}
          {marcas.map((m) => (
            <g key={m}>
              <line className="grafico-grilla" x1={MARGEN.izquierda} x2={ANCHO - MARGEN.derecha} y1={y(m)} y2={y(m)} />
              <text className="grafico-eje" x={MARGEN.izquierda - 8} y={y(m)} textAnchor="end" dominantBaseline="middle">{m}</text>
            </g>
          ))}

          {/* Nombre del eje de la izquierda (qué se cuenta), escrito de costado */}
          <text
            className="grafico-nombre-eje"
            transform={`translate(16 ${MARGEN.arriba + altoZona / 2}) rotate(-90)`}
            textAnchor="middle"
          >
            {unidad.charAt(0).toUpperCase() + unidad.slice(1)}
          </text>

          {/* Las barras, una por mes */}
          {datos.map((d, i) => {
            const centro = MARGEN.izquierda + casillero * i + casillero / 2;
            const alto = base - y(d.valor);
            return (
              <g key={`${d.anio}-${d.mes}`}>
                {d.valor > 0 && (
                  // Barra con las puntas de arriba redondeadas (el piso queda recto)
                  <path
                    className={`grafico-barra${activa === i ? ' activa' : ''}`}
                    d={`M ${centro - anchoBarra / 2} ${base}
                        V ${y(d.valor) + Math.min(4, alto)}
                        Q ${centro - anchoBarra / 2} ${y(d.valor)} ${centro - anchoBarra / 2 + Math.min(4, alto)} ${y(d.valor)}
                        H ${centro + anchoBarra / 2 - Math.min(4, alto)}
                        Q ${centro + anchoBarra / 2} ${y(d.valor)} ${centro + anchoBarra / 2} ${y(d.valor) + Math.min(4, alto)}
                        V ${base} Z`}
                  />
                )}
                {/* El número arriba de cada barra, para poder comprobarlo contra la tabla */}
                <text className="grafico-valor" x={centro} y={y(d.valor) - 7} textAnchor="middle">{d.valor}</text>
                {/* El mes debajo de la barra */}
                <text className="grafico-eje" x={centro} y={base + 18} textAnchor="middle">{NOMBRES_MES[d.mes - 1]}</text>
                {/* Zona invisible que ocupa todo el casillero: así el cartelito aparece aunque
                    el mouse no esté justo arriba de la barra (sirve para las barras bajitas) */}
                <rect
                  x={MARGEN.izquierda + casillero * i} y={MARGEN.arriba} width={casillero} height={altoZona + 24}
                  fill="transparent"
                  onMouseEnter={() => setActiva(i)}
                  onMouseLeave={() => setActiva(null)}
                />
              </g>
            );
          })}

          {/* La línea del piso */}
          <line className="grafico-base" x1={MARGEN.izquierda} x2={ANCHO - MARGEN.derecha} y1={base} y2={base} />

          {/* El año debajo de sus meses, con una rayita que marca hasta dónde llega */}
          {anios.map((a) => {
            const x1 = MARGEN.izquierda + casillero * a.desde + 6;
            const x2 = MARGEN.izquierda + casillero * (a.hasta + 1) - 6;
            return (
              <g key={a.anio}>
                <line className="grafico-anio-linea" x1={x1} x2={x2} y1={base + 30} y2={base + 30} />
                <text className="grafico-anio" x={(x1 + x2) / 2} y={base + 46} textAnchor="middle">{a.anio}</text>
              </g>
            );
          })}

          {/* Nombre del eje de abajo */}
          <text className="grafico-nombre-eje" x={MARGEN.izquierda + anchoZona / 2} y={ALTO - 8} textAnchor="middle">{ejeX}</text>
        </svg>

        {/* Cartelito que aparece al pasar el mouse por un mes. Se ubica arriba de esa barra
            (la posición se calcula en porcentaje para que acompañe el tamaño de la pantalla) */}
        {datoActivo && (
          <div
            className="grafico-cartel"
            style={{
              left: `${((MARGEN.izquierda + casillero * activa + casillero / 2) / ANCHO) * 100}%`,
              top: `${(y(datoActivo.valor) / ALTO) * 100}%`,
            }}
          >
            <strong>{NOMBRES_MES[datoActivo.mes - 1]} {datoActivo.anio}</strong>
            <span>{datoActivo.valor} {unidad}</span>
            {datoActivo.detalle && <span className="grafico-cartel-detalle">{datoActivo.detalle}</span>}
          </div>
        )}
      </div>
    </figure>
  );
}
