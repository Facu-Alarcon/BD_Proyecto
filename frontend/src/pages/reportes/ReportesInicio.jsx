import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import IndicadoresReportes from './IndicadoresReportes';
import './Reportes.css';

// Pantalla de entrada a Reportes: un tablero con un recuadro por reporte (como el "Dashboard
// integrado" del Parcial 2). Cada recuadro muestra el nombre, una descripción corta y una vista
// previa de un gráfico del reporte, con los filtros por defecto (el año actual, o el trimestre
// actual en la comparación). Al tocar el recuadro se abre el reporte completo con sus filtros.
//
// Para que no quede todo igual, los recuadros tienen distintos anchos y altos, y no arrancan
// todos a la misma altura (quedan escalonados, como un mosaico). Además muestran distintos
// tipos de gráfico: líneas, torta, barras, barras dobles, mapa de calor y
// barras agrupadas. Todos son las mismas imágenes que arma matplotlib para cada reporte.
//
// Para sumar un reporte nuevo se agrega acá a la lista y se le crea su pantalla
// (y su ruta en App.jsx).
// Si un reporte tiene "permiso", además de Ver Reportes hace falta ese permiso para verlo
// (es el caso de los reportes sensibles, como el de ingresos).
//
// Cada reporte dice:
//   endpoint -> de dónde se piden los datos (el mismo que usa la pantalla del reporte)
//   imagen   -> cuál de los gráficos que manda el backend se muestra en el recuadro
//   lugar    -> dónde va en el mosaico, que tiene 12 columnas y filas bajitas (ver Reportes.css):
//               [columna donde empieza, cuántas columnas ocupa, fila donde empieza, cuántas filas ocupa].
//               Hay dos: "completo" para cuando se ven los 6 reportes, y "reducido" para cuando
//               el perfil no ve los financieros (se ven 4), así el mosaico no queda con huecos.
//               Así quedan con los 6:
//                 ┌───────────────────┬─────────────┐
//                 │ Evolución         │ Demanda     │
//                 │                   ├─────────────┤
//                 ├───────────────────┤ Contratado  │
//                 │ Uso de equipos    │ vs. cobrado │
//                 ├─────────────┬─────┴─────────────┤
//                 │ Carga       │ Comparación       │
//                 └─────────────┴───────────────────┘
//   acento   -> el color del recuadro (la línea de arriba, el degradé y el círculo de fondo)
// El orden de la lista es el orden en que se van acomodando en el mosaico.
const ANIO_ACTUAL = new Date().getFullYear();

const REPORTES = [
  {
    to: '/reportes/evolucion-ingresos',
    nombre: 'Evolución de ingresos y eventos',
    descripcion: 'Cómo crece el negocio mes a mes, con su tendencia.',
    permiso: 'ver_reportes_financieros',
    endpoint: '/reportes/evolucion-ingresos/',
    imagen: (d) => d.graficos?.ingresos?.imagen, // líneas con tendencia
    lugar: { completo: [1, 7, 1, 5] },
    acento: 'var(--navy-accent)',
  },
  {
    to: '/reportes/demanda-servicios',
    nombre: 'Demanda de servicio',
    descripcion: 'Qué servicios se piden más y cuáles conviene promocionar.',
    endpoint: '/reportes/demanda-servicios/',
    imagen: (d) => d.vista_previa?.imagen, // torta sin la leyenda dibujada adentro...
    leyenda: (d) => d.vista_previa?.leyenda, // ...porque la leyenda se arma acá, como texto al costado
    lugar: { completo: [8, 5, 1, 4], reducido: [1, 5, 1, 4] },
    acento: 'var(--verde)',
  },
  {
    to: '/reportes/uso-equipos',
    nombre: 'Uso de equipos por mes',
    descripcion: 'Qué equipos comprar, cuáles sobran y cuándo hacer mantenimiento.',
    endpoint: '/reportes/uso-equipos/',
    imagen: (d) => d.grafico?.imagen, // barras
    lugar: { completo: [1, 7, 6, 4], reducido: [6, 7, 1, 5] },
    acento: 'var(--blue-bar)',
  },
  {
    to: '/reportes/contratado-cobrado',
    nombre: 'Contratado vs. cobrado',
    descripcion: 'Lo contratado al lado de lo cobrado, y qué saldos falta reclamar.',
    permiso: 'ver_reportes_financieros',
    endpoint: '/reportes/contratado-cobrado/',
    imagen: (d) => d.grafico?.imagen, // barras dobles
    lugar: { completo: [8, 5, 5, 5] },
    acento: 'var(--amber)',
  },
  {
    to: '/reportes/carga-empleados',
    nombre: 'Carga de trabajo de los empleados',
    descripcion: 'Quién está sobrecargado y en qué meses hace falta más personal.',
    endpoint: '/reportes/carga-empleados/',
    imagen: (d) => d.heatmap?.imagen, // mapa de calor
    lugar: { completo: [1, 5, 10, 5], reducido: [1, 5, 5, 5] },
    acento: 'var(--red)',
  },
  {
    to: '/reportes/comparacion-periodos',
    nombre: 'Comparación de períodos',
    descripcion: 'Este trimestre contra el mismo del año anterior, servicio por servicio.',
    endpoint: '/reportes/comparacion-periodos/',
    imagen: (d) => d.grafico?.imagen, // barras agrupadas
    lugar: { completo: [6, 7, 10, 5], reducido: [6, 7, 6, 4] },
    acento: 'var(--navy-700)',
  },
];

// Un recuadro del tablero: pide los datos de su reporte y muestra la vista previa.
// Todo el recuadro es un link a la pantalla completa del reporte.
//   lugar -> [columna, ancho, fila, alto] en el mosaico (ver "lugar" arriba)
//   orden -> su posición, para que aparezcan uno detrás del otro al entrar
function TarjetaReporte({ reporte, lugar, orden }) {
  const [datos, setDatos] = useState(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    // "vigente" por si se sale de la pantalla antes de que llegue la respuesta
    let vigente = true;
    api
      .get(reporte.endpoint)
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch(() => { if (vigente) setError(true); });
    return () => { vigente = false; };
  }, [reporte.endpoint]);

  const imagen = datos ? reporte.imagen(datos) : null;
  // Solo la torta trae leyenda aparte: nombre, color y porcentaje de cada porción
  const leyenda = datos && reporte.leyenda ? reporte.leyenda(datos) : null;
  const [columna, ancho, fila, alto] = lugar;

  return (
    <Link
      to={reporte.to}
      className="card reporte-mosaico-item"
      // El lugar va en variables de CSS (y no directo en grid-column) para que en pantallas
      // chicas Reportes.css lo pueda ignorar y poner los recuadros uno debajo del otro
      style={{ '--acento': reporte.acento, '--orden': orden, '--columna': columna, '--ancho': ancho, '--fila': fila, '--alto': alto }}
    >
      <div className="reporte-tarjeta-cabecera">
        <h2>{reporte.nombre}</h2>
        {/* Marca para que se note que es un reporte restringido */}
        {reporte.permiso && <span className="badge badge-amber badge-chica">Solo administración</span>}
      </div>
      <p>{reporte.descripcion}</p>

      {/* Vista previa del gráfico (la misma imagen que arma matplotlib para el reporte) */}
      <div className={`reporte-tarjeta-grafico${leyenda ? ' con-leyenda' : ''}`}>
        {error && <span className="reporte-tarjeta-aviso">No se pudo cargar la vista previa.</span>}
        {/* Mientras carga, un rectángulo gris que "brilla" en lugar del gráfico */}
        {!error && !datos && <span className="reporte-tarjeta-cargando" aria-label="Cargando gráfico" />}
        {datos && imagen && <img src={imagen} alt={`Vista previa: ${reporte.nombre}`} />}
        {/* Leyenda de la torta: un cuadradito del color de cada porción, el nombre y el % */}
        {imagen && leyenda && (
          <ul className="reporte-tarjeta-leyenda">
            {leyenda.map((l) => (
              <li key={l.nombre} title={`${l.nombre}: ${l.porcentaje.toLocaleString('es-AR')} %`}>
                <span className="leyenda-color" style={{ background: l.color }} />
                <span className="leyenda-nombre">{l.nombre}</span>
                <span className="leyenda-porcentaje">{l.porcentaje.toLocaleString('es-AR')} %</span>
              </li>
            ))}
          </ul>
        )}
        {datos && !imagen && <span className="reporte-tarjeta-aviso">Sin datos en el período.</span>}
      </div>
    </Link>
  );
}

export default function ReportesInicio() {
  const { tiene } = usePermiso('reportes');
  // Solo se muestran (y se piden al backend) los reportes que el perfil puede abrir
  const visibles = REPORTES.filter((r) => !r.permiso || tiene(r.permiso));
  // Si se ven todos, se usa el mosaico completo; si no, el reducido (ver "lugar" arriba)
  const disposicion = visibles.length === REPORTES.length ? 'completo' : 'reducido';

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Reportes</h1>
          <p className="reporte-tablero-sub">Vista rápida del {ANIO_ACTUAL}. Tocá un reporte para ver el detalle, filtrarlo y exportarlo a PDF.</p>
        </div>
      </div>

      {/* Los 4 números de arriba (reservas, ingresos, eventos y saldo). Se actualizan solos */}
      <IndicadoresReportes />

      <div className="reportes-mosaico">
        {visibles.map((r, i) => (
          <TarjetaReporte key={r.to} reporte={r} lugar={r.lugar[disposicion]} orden={i} />
        ))}
      </div>
    </div>
  );
}
