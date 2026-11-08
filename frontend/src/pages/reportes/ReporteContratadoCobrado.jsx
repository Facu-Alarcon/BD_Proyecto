import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../../api/client';
import { IconVolver } from '../../components/icons';
import BotonImprimirReporte from '../../components/BotonImprimirReporte';
import GraficoImagen from '../../components/GraficoImagen';
import { EncabezadoImpresion, PieImpresion } from '../../components/ImpresionReporte';
import Paginacion from '../../components/Paginacion';
import ResumenAgregados from '../../components/ResumenAgregados';
import { usePaginacion } from '../../hooks/usePaginacion';
import { formatearPesos } from '../../utils/formato';
import './Reportes.css';

// REPORTE: CONTRATADO VS. COBRADO POR MES
//
// Es el reporte que cruza los dos procesos del sistema: las Reservas (lo que se contrató) con
// los Pagos (lo que efectivamente se cobró). Por cada mes del evento muestra las dos cosas una
// al lado de la otra y lo que falta cobrar, para ver si las reservas se están pagando.
// Tiene: los filtros, el resumen del saldo, el gráfico de barras dobles y la tabla por mes.
// Los números los calcula el backend (ver ReporteContratadoCobradoView en
// infinito_sonido/reportes.py); esta pantalla solo los muestra.
// Es un reporte sensible: solo lo ven los perfiles con "Ver Reportes Financieros".

const NOMBRES_MES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Años que se pueden elegir en los filtros: dos para atrás y dos para adelante del actual
const ANIO_ACTUAL = new Date().getFullYear();
const ANIOS = [ANIO_ACTUAL - 2, ANIO_ACTUAL - 1, ANIO_ACTUAL, ANIO_ACTUAL + 1, ANIO_ACTUAL + 2];

// Escribe un mes con palabras: (2026, 3) -> "marzo de 2026"
function mesEnPalabras(anio, mes) {
  return `${NOMBRES_MES[mes - 1].toLowerCase()} de ${anio}`;
}

// Escribe un porcentaje: 57.3 -> "57,3 %", null -> "—"
function porcentaje(valor) {
  if (valor === null || valor === undefined) return '—';
  return `${valor.toLocaleString('es-AR', { maximumFractionDigits: 1 })} %`;
}

// Pastilla de color para el % cobrado: verde si está todo cobrado, ámbar si falta algo,
// roja si se cobró menos de la mitad
function PastillaCobrado({ valor }) {
  if (valor === null || valor === undefined) return <span className="cero">—</span>;
  const color = valor >= 100 ? 'badge-green' : valor >= 50 ? 'badge-amber' : 'badge-red';
  return <span className={`badge ${color} badge-chica`}>{porcentaje(valor)}</span>;
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

export default function ReporteContratadoCobrado() {
  const navigate = useNavigate();
  // Lo que está elegido en los filtros. Al entrar se muestra el año actual completo
  const [desde, setDesde] = useState({ anio: ANIO_ACTUAL, mes: 1 });
  const [hasta, setHasta] = useState({ anio: ANIO_ACTUAL, mes: 12 });
  const [estado, setEstado] = useState(''); // '' = todos los estados (menos anuladas)

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
      .get('/reportes/contratado-cobrado/', { params: { desde: mes(desde), hasta: mes(hasta), estado: estado || undefined } })
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch((err) => {
        // Por ejemplo, si se eligió un "Desde" posterior al "Hasta" el backend avisa con un mensaje
        if (vigente) setError(err.response?.data?.detail || 'No se pudo cargar el reporte.');
      })
      .finally(() => { if (vigente) setCargando(false); });
    return () => { vigente = false; };
  }, [desde, hasta, estado]);

  // La tabla va de a 12 meses por página. Cuando llegan datos nuevos (cambió algún filtro)
  // se vuelve a la primera página.
  const paginacion = usePaginacion(datos?.meses || [], datos, 12);
  const enPagina = new Set(paginacion.visibles);

  const periodo = `De ${mesEnPalabras(desde.anio, desde.mes)} a ${mesEnPalabras(hasta.anio, hasta.mes)}`;
  // true cuando en el período no hay ninguna reserva
  const sinDatos = datos && datos.total_reservas === 0;
  const plural = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;
  // Nombre del estado elegido, para el pie del PDF y los textos
  const nombreEstado = (datos?.opciones.estados || []).find((e) => e.id === estado)?.nombre;

  // ---- Frases de la interpretación (se arman solas con los números del reporte) ----
  let interpretacion = [];
  if (datos && !sinDatos) {
    // El mes que más debe: donde quedó más plata sin cobrar
    const mesMasDeuda = datos.meses.reduce((mayor, m) => (m.saldo > mayor.saldo ? m : mayor), datos.meses[0]);
    // Meses que ya pasaron y todavía tienen saldo: son los que hay que salir a cobrar
    const hoy = new Date();
    const mesActual = hoy.getFullYear() * 12 + hoy.getMonth() + 1;
    const vencidos = datos.meses.filter((m) => m.saldo > 0 && m.anio * 12 + m.mes < mesActual);

    interpretacion = [
      `En el período se contrataron ${formatearPesos(datos.total_contratado)} en ${plural(datos.total_reservas, 'reserva', 'reservas')} y se cobraron ${formatearPesos(datos.total_cobrado)} (${porcentaje(datos.porcentaje_cobrado)}).`,
      datos.total_saldo > 0
        ? `Falta cobrar ${formatearPesos(datos.total_saldo)}, repartido en ${plural(datos.total_reservas_con_saldo, 'reserva', 'reservas')}.`
        : 'Todas las reservas del período están pagadas por completo.',
      mesMasDeuda.saldo > 0
        ? `El mes con más saldo pendiente es ${mesEnPalabras(mesMasDeuda.anio, mesMasDeuda.mes)}: ${formatearPesos(mesMasDeuda.saldo)} sin cobrar (${plural(mesMasDeuda.reservas_con_saldo, 'reserva', 'reservas')}).`
        : null,
      vencidos.length > 0
        ? `Hay saldo de eventos que ya pasaron (conviene reclamarlo): ${vencidos.map((m) => `${mesEnPalabras(m.anio, m.mes)} (${formatearPesos(m.saldo)})`).join(', ')}.`
        : 'Los eventos que ya pasaron están cobrados: el saldo que queda es de eventos que todavía no se hicieron.',
    ].filter(Boolean); // saca las frases que quedaron vacías
  }

  // Nombre que propone el navegador al guardar el PDF (ver BotonImprimirReporte.jsx)
  const nombreArchivo = `Reporte-Contratado-vs-cobrado-${desde.anio}-${String(desde.mes).padStart(2, '0')}-a-${hasta.anio}-${String(hasta.mes).padStart(2, '0')}`;

  return (
    <div className="reporte-pagina">
      <div className="page-header page-header-con-ruta">
        <div>
          {/* Flecha para volver a la pantalla principal de Reportes, al lado del título */}
          <div className="titulo-con-volver">
            <button type="button" className="btn-volver" onClick={() => navigate('/reportes')} title="Volver a Reportes" aria-label="Volver a Reportes">
              <IconVolver />
            </button>
            <h1>Contratado vs. cobrado</h1>
          </div>
          <div className="ruta"><Link to="/reportes">Reportes</Link> / <strong>Contratado vs. cobrado</strong></div>
        </div>
      </div>

      {/* Para qué sirve y qué es lo que se cuenta */}
      <div className="reporte-intro">
        <p className="reporte-descripcion">
          Compara, mes a mes, lo que se <strong>contrató en las reservas</strong> con lo que <strong>efectivamente se
          cobró en los pagos</strong> de esas mismas reservas, para ver cuánto falta cobrar y de qué meses. Cada reserva
          cuenta en el mes de su evento, sin importar cuándo se pagó. Las reservas anuladas y los pagos anulados no se
          tienen en cuenta.
        </p>
        <BotonImprimirReporte nombreArchivo={nombreArchivo} deshabilitado={cargando || !!error || !datos || !!sinDatos} />
      </div>

      {/* Encabezado institucional: solo sale al imprimir */}
      <EncabezadoImpresion titulo="Reporte: Contratado vs. cobrado" />

      {/* ---- Filtros ---- */}
      <div className="card filtros reporte-filtros">
        <SelectorMes id="desde" label="Desde" valor={desde} onChange={setDesde} />
        <SelectorMes id="hasta" label="Hasta" valor={hasta} onChange={setHasta} />
        <div className="form-field">
          <label htmlFor="estado">Estado de la reserva</label>
          <select id="estado" value={estado} onChange={(e) => setEstado(e.target.value)}>
            <option value="">Todos los estados</option>
            {(datos?.opciones.estados || []).map((e) => <option key={e.id} value={e.id}>{e.nombre}</option>)}
          </select>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {cargando && !datos && <div className="card reporte-vacio">Cargando...</div>}

      {/* ---- Cuando no hay nada para mostrar en el período ---- */}
      {!error && sinDatos && (
        <div className="card reporte-vacio">
          <strong>No hay reservas para mostrar.</strong>
          <span>{periodo} no hay reservas{nombreEstado ? ` en estado ${nombreEstado.toLowerCase()}` : ''}. Probá con otro período o sacá el filtro.</span>
        </div>
      )}

      {!error && datos && !sinDatos && (
        <>
          {/* ---- Resumen: total, promedio, máximo, mínimo y desvío del saldo pendiente por mes (numpy) ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Resumen del saldo pendiente por mes</h2>
            <ResumenAgregados agregados={datos.agregados} formato={formatearPesos} unidad="saldo pendiente" />
          </div>

          {/* ---- Gráfico de barras dobles: por cada mes, lo contratado al lado de lo cobrado ---- */}
          <div className="card reporte-bloque">
            <GraficoImagen
              titulo="Contratado (reservas) vs. cobrado (pagos), por mes del evento"
              periodo={`${periodo} · ${formatearPesos(datos.total_contratado)} contratado · ${formatearPesos(datos.total_cobrado)} cobrado`}
              grafico={datos.grafico}
              nombreArchivo={`${nombreArchivo}-barras-dobles`}
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
            <p className="form-hint">El saldo se calcula reserva por reserva: si a una le pagaron de más, eso no descuenta lo que deben las otras.</p>
            <Paginacion paginacion={paginacion} posicion="arriba" />
            <div className="reporte-tabla-scroll">
              <table className="data-table reporte-tabla">
                <thead>
                  <tr>
                    <th>Mes del evento</th>
                    <th className="numero">Reservas</th>
                    <th className="numero">Contratado</th>
                    <th className="numero">Cobrado</th>
                    <th className="numero">Saldo pendiente</th>
                    <th className="numero">Reservas con saldo</th>
                    <th className="numero">% cobrado</th>
                  </tr>
                </thead>
                <tbody>
                  {/* Van todas las filas, pero las que no son de esta página quedan escondidas en
                      pantalla (al imprimir salen todas, ver Reportes.css) */}
                  {datos.meses.map((m) => (
                    <tr key={m.etiqueta} className={enPagina.has(m) ? undefined : 'fila-otra-pagina'}>
                      <td>{m.etiqueta}</td>
                      <td className={`numero${m.reservas === 0 ? ' cero' : ''}`}>{m.reservas}</td>
                      <td className={`numero${m.contratado === 0 ? ' cero' : ''}`}>{formatearPesos(m.contratado)}</td>
                      <td className={`numero${m.cobrado === 0 ? ' cero' : ''}`}>{formatearPesos(m.cobrado)}</td>
                      <td className={`numero${m.saldo === 0 ? ' cero' : ''}`}>{formatearPesos(m.saldo)}</td>
                      <td className={`numero${m.reservas_con_saldo === 0 ? ' cero' : ''}`}>{m.reservas_con_saldo}</td>
                      <td className="numero"><PastillaCobrado valor={m.porcentaje_cobrado} /></td>
                    </tr>
                  ))}
                </tbody>
                {/* Los totales del período: tienen que coincidir con la suma de las columnas */}
                <tfoot>
                  <tr>
                    <td>Total</td>
                    <td className="numero">{datos.total_reservas}</td>
                    <td className="numero">{formatearPesos(datos.total_contratado)}</td>
                    <td className="numero">{formatearPesos(datos.total_cobrado)}</td>
                    <td className="numero">{formatearPesos(datos.total_saldo)}</td>
                    <td className="numero">{datos.total_reservas_con_saldo}</td>
                    <td className="numero"><PastillaCobrado valor={datos.porcentaje_cobrado} /></td>
                  </tr>
                </tfoot>
              </table>
            </div>
            <Paginacion paginacion={paginacion} />
          </div>

          {/* Pie con los filtros, el usuario y la fecha y hora: solo sale al imprimir */}
          <PieImpresion filtros={[
            ['Período', `${mesEnPalabras(desde.anio, desde.mes)} a ${mesEnPalabras(hasta.anio, hasta.mes)}`],
            ['Estado de la reserva', nombreEstado || 'Todos (menos anuladas)'],
          ]} />
        </>
      )}
    </div>
  );
}
