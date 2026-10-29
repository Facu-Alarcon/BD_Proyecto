import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../../api/client';
import { IconVolver } from '../../components/icons';
import BotonImprimirReporte from '../../components/BotonImprimirReporte';
import GraficoBarras from '../../components/GraficoBarras';
import { formatearPesos } from '../../utils/formato';
import './Reportes.css';

// REPORTE: EVOLUCIÓN MENSUAL DE INGRESOS CONTRATADOS Y CANTIDAD DE EVENTOS
//
// Muestra mes a mes cuánta plata se contrató y cuántos eventos hubo, para ver si el
// negocio crece. Tiene tres partes: los filtros, dos gráficos (ingresos y eventos) y la
// tabla con la variación contra el mes anterior. Los números los calcula el backend
// (ver ReporteEvolucionIngresosView en infinito_sonido/reportes.py); esta pantalla solo los muestra.

const NOMBRES_MES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Años que se pueden elegir en los filtros: dos para atrás y dos para adelante del actual
const ANIO_ACTUAL = new Date().getFullYear();
const ANIOS = [ANIO_ACTUAL - 2, ANIO_ACTUAL - 1, ANIO_ACTUAL, ANIO_ACTUAL + 1, ANIO_ACTUAL + 2];

// Escribe un mes con palabras: (2026, 3) -> "marzo de 2026"
function mesEnPalabras(anio, mes) {
  return `${NOMBRES_MES[mes - 1].toLowerCase()} de ${anio}`;
}

// Escribe una variación como texto: 12.5 -> "+12,5 %", -8 -> "-8 %", null -> "—"
function textoVariacion(valor) {
  if (valor === null || valor === undefined) return '—';
  const numero = valor.toLocaleString('es-AR', { maximumFractionDigits: 1 });
  return `${valor > 0 ? '+' : ''}${numero} %`;
}

// Pastilla de color para una variación: verde si subió, roja si bajó, gris si no cambió
// o si no se puede calcular (cuando el mes anterior estaba en cero)
function Variacion({ valor }) {
  if (valor === null || valor === undefined) return <span className="cero">—</span>;
  const color = valor > 0 ? 'badge-green' : valor < 0 ? 'badge-red' : 'badge-gray';
  return <span className={`badge ${color} badge-chica`}>{textoVariacion(valor)}</span>;
}

// Los dos desplegables (mes y año) que se usan para elegir "Desde" y "Hasta"
function SelectorMes({ id, label, valor, onChange }) {
  return (
    <div className="form-field">
      <label htmlFor={id}>{label}</label>
      <div className="selector-mes">
        <select id={id} value={valor.mes} onChange={(e) => onChange({ ...valor, mes: Number(e.target.value) })}>
          {NOMBRES_MES.map((nombre, i) => <option key={nombre} value={i + 1}>{nombre}</option>)}
        </select>
        <select aria-label={`${label} (año)`} value={valor.anio} onChange={(e) => onChange({ ...valor, anio: Number(e.target.value) })}>
          {ANIOS.map((a) => <option key={a} value={a}>{a}</option>)}
        </select>
      </div>
    </div>
  );
}

export default function ReporteEvolucionIngresos() {
  const navigate = useNavigate();
  // Lo que está elegido en los filtros. Al entrar se muestra el año actual completo
  const [desde, setDesde] = useState({ anio: ANIO_ACTUAL, mes: 1 });
  const [hasta, setHasta] = useState({ anio: ANIO_ACTUAL, mes: 12 });

  const [datos, setDatos] = useState(null);  // lo que devuelve el backend
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  // Cada vez que cambia algún filtro se le vuelve a pedir el reporte al backend
  useEffect(() => {
    // "vigente" sirve por si el usuario cambia los filtros rápido: si llega una respuesta
    // vieja después de haber pedido otra, se la ignora
    let vigente = true;
    setCargando(true);
    setError('');
    const mes = (m) => `${m.anio}-${String(m.mes).padStart(2, '0')}`; // (2026, 3) -> "2026-03"
    api
      .get('/reportes/evolucion-ingresos/', { params: { desde: mes(desde), hasta: mes(hasta) } })
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch((err) => {
        // Por ejemplo, si se eligió un "Desde" posterior al "Hasta" el backend avisa con un mensaje
        if (vigente) setError(err.response?.data?.detail || 'No se pudo cargar el reporte.');
      })
      .finally(() => { if (vigente) setCargando(false); });
    return () => { vigente = false; };
  }, [desde, hasta]);

  const periodo = `De ${mesEnPalabras(desde.anio, desde.mes)} a ${mesEnPalabras(hasta.anio, hasta.mes)}`;
  // true cuando en el período no hay ningún evento
  const sinDatos = datos && datos.total_eventos === 0;
  const plural = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;

  // ---- Frases de la interpretación (se arman solas con los números del reporte) ----
  let interpretacion = [];
  if (datos && !sinDatos) {
    const mesTop = datos.meses.reduce((mayor, m) => (m.ingresos > mayor.ingresos ? m : mayor), datos.meses[0]);
    const mesesSinEventos = datos.meses.filter((m) => m.eventos === 0);
    const variacionTotal = datos.variacion_total_ingresos;
    const primero = datos.meses[0];
    const ultimo = datos.meses[datos.meses.length - 1];

    let crecimiento = null;
    if (datos.meses.length > 1) {
      if (variacionTotal === null) {
        crecimiento = `No se puede calcular el crecimiento entre ${mesEnPalabras(primero.anio, primero.mes)} y ${mesEnPalabras(ultimo.anio, ultimo.mes)}, porque el primer mes no tuvo ingresos.`;
      } else if (variacionTotal === 0) {
        crecimiento = `Los ingresos de ${mesEnPalabras(ultimo.anio, ultimo.mes)} son iguales a los de ${mesEnPalabras(primero.anio, primero.mes)}.`;
      } else {
        crecimiento = `Entre ${mesEnPalabras(primero.anio, primero.mes)} y ${mesEnPalabras(ultimo.anio, ultimo.mes)} los ingresos ${variacionTotal > 0 ? 'crecieron' : 'bajaron'} un ${Math.abs(variacionTotal).toLocaleString('es-AR', { maximumFractionDigits: 1 })} %.`;
      }
    }

    interpretacion = [
      `En el período se contrataron ${formatearPesos(datos.total_ingresos)} en ${plural(datos.total_eventos, 'evento', 'eventos')}, un promedio de ${formatearPesos(datos.promedio_mensual_ingresos)} por mes.`,
      `El mes con más ingresos fue ${mesEnPalabras(mesTop.anio, mesTop.mes)}: ${formatearPesos(mesTop.ingresos)} en ${plural(mesTop.eventos, 'evento', 'eventos')}.`,
      crecimiento,
      mesesSinEventos.length > 0
        ? `Meses sin eventos: ${mesesSinEventos.map((m) => mesEnPalabras(m.anio, m.mes)).join(', ')}.`
        : 'Hubo al menos un evento en cada mes del período.',
    ].filter(Boolean); // saca las frases que quedaron vacías
  }

  // Nombre que propone el navegador al guardar el PDF (ver BotonImprimirReporte.jsx)
  const nombreArchivo = `Reporte-Evolucion-de-ingresos-${desde.anio}-${String(desde.mes).padStart(2, '0')}-a-${hasta.anio}-${String(hasta.mes).padStart(2, '0')}`;

  return (
    <div className="reporte-pagina">
      <div className="page-header page-header-con-ruta">
        <div>
          {/* Flecha para volver a la pantalla principal de Reportes, al lado del título */}
          <div className="titulo-con-volver">
            <button type="button" className="btn-volver" onClick={() => navigate('/reportes')} title="Volver a Reportes" aria-label="Volver a Reportes">
              <IconVolver />
            </button>
            <h1>Evolución de ingresos y eventos</h1>
          </div>
          <div className="ruta"><Link to="/reportes">Reportes</Link> / <strong>Evolución de ingresos y eventos</strong></div>
        </div>
      </div>

      {/* Para qué sirve y qué es lo que se cuenta */}
      <div className="reporte-intro">
        <p className="reporte-descripcion">
          Muestra, mes a mes, cuánto se <strong>contrató</strong> (el total de las reservas, no lo que ya se cobró) y
          cuántos eventos hubo, para analizar el crecimiento del negocio. Cada reserva cuenta en el mes de su evento;
          las anuladas no se tienen en cuenta.
        </p>
        <BotonImprimirReporte nombreArchivo={nombreArchivo} deshabilitado={cargando || !!error || !datos || !!sinDatos} />
      </div>

      {/* ---- Filtros ---- */}
      <div className="card filtros reporte-filtros">
        <SelectorMes id="desde" label="Desde" valor={desde} onChange={setDesde} />
        <SelectorMes id="hasta" label="Hasta" valor={hasta} onChange={setHasta} />
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {cargando && !datos && <div className="card reporte-vacio">Cargando...</div>}

      {/* ---- Cuando no hay nada para mostrar en el período ---- */}
      {!error && sinDatos && (
        <div className="card reporte-vacio">
          <strong>No hay eventos para mostrar.</strong>
          <span>{periodo} no hay reservas. Probá con otro período.</span>
        </div>
      )}

      {!error && datos && !sinDatos && (
        <>
          {/* ---- Gráfico de ingresos contratados por mes ---- */}
          <div className="card reporte-bloque">
            <GraficoBarras
              titulo="Ingresos contratados por mes"
              periodo={`${periodo} · ${formatearPesos(datos.total_ingresos)} en total`}
              grafico={datos.graficos.ingresos}
              unidad=""
              formato={formatearPesos}
              datos={datos.meses.map((m) => ({
                anio: m.anio,
                mes: m.mes,
                valor: m.ingresos,
                detalle: plural(m.eventos, 'evento', 'eventos'),
              }))}
            />
          </div>

          {/* ---- Gráfico de cantidad de eventos por mes ---- */}
          <div className="card reporte-bloque">
            <GraficoBarras
              titulo="Cantidad de eventos por mes"
              periodo={`${periodo} · ${plural(datos.total_eventos, 'evento', 'eventos')} en total`}
              grafico={datos.graficos.eventos}
              unidad="eventos"
              datos={datos.meses.map((m) => ({
                anio: m.anio,
                mes: m.mes,
                valor: m.eventos,
                detalle: formatearPesos(m.ingresos),
              }))}
            />
          </div>

          {/* ---- Interpretación: qué nos dicen los números ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Qué muestra el reporte</h2>
            <ul className="reporte-interpretacion">
              {interpretacion.map((frase) => <li key={frase}>{frase}</li>)}
            </ul>
          </div>

          {/* ---- Tabla con el detalle de cada mes ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Detalle por mes</h2>
            <p className="form-hint">La variación compara cada mes con el anterior. Si el mes anterior no tuvo ingresos no se puede calcular (—).</p>
            <div className="reporte-tabla-scroll">
              <table className="data-table reporte-tabla">
                <thead>
                  <tr>
                    <th>Mes</th>
                    <th className="numero">Ingresos contratados</th>
                    <th className="numero">Variación</th>
                    <th className="numero">Eventos</th>
                    <th className="numero">Variación</th>
                  </tr>
                </thead>
                <tbody>
                  {datos.meses.map((m) => (
                    <tr key={m.etiqueta}>
                      <td>{m.etiqueta}</td>
                      <td className={`numero${m.ingresos === 0 ? ' cero' : ''}`}>{formatearPesos(m.ingresos)}</td>
                      <td className="numero"><Variacion valor={m.variacion_ingresos} /></td>
                      <td className={`numero${m.eventos === 0 ? ' cero' : ''}`}>{m.eventos}</td>
                      <td className="numero"><Variacion valor={m.variacion_eventos} /></td>
                    </tr>
                  ))}
                </tbody>
                {/* Los totales del período: tienen que coincidir con la suma de las columnas */}
                <tfoot>
                  <tr>
                    <td>Total</td>
                    <td className="numero">{formatearPesos(datos.total_ingresos)}</td>
                    <td />
                    <td className="numero">{datos.total_eventos}</td>
                    <td />
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
