import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../../api/client';
import GraficoBarras from '../../components/GraficoBarras';
import { IconVolver } from '../../components/icons';
import BotonImprimirReporte from '../../components/BotonImprimirReporte';
import './Reportes.css';

// REPORTE TÁCTICO: DEMANDA POR SERVICIO POR MES
//
// Muestra cuántas veces se contrató cada servicio en los eventos de cada mes y cuánta plata dejó.
// Tiene tres partes: los filtros, el gráfico (un total por mes) y la tabla con el detalle
// de cada servicio. Se puede mirar por "Contrataciones" o por "Ingresos" con el selector
// "Ver por". Los números los calcula el backend (ver infinito_sonido/reportes.py);
// esta pantalla solo los muestra.

const NOMBRES_MES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Años que se pueden elegir en los filtros: dos para atrás y dos para adelante del actual
const ANIO_ACTUAL = new Date().getFullYear();
const ANIOS = [ANIO_ACTUAL - 2, ANIO_ACTUAL - 1, ANIO_ACTUAL, ANIO_ACTUAL + 1, ANIO_ACTUAL + 2];

// Escribe un mes con palabras: (2026, 3) -> "marzo de 2026"
function mesEnPalabras(anio, mes) {
  return `${NOMBRES_MES[mes - 1].toLowerCase()} de ${anio}`;
}

// Escribe plata completa: 1500000 -> "$ 1.500.000"
function pesos(valor) {
  return `$ ${valor.toLocaleString('es-AR', { maximumFractionDigits: 2 })}`;
}

// "1 contratación" / "3 contrataciones" (y lo mismo con reservas)
function contar(cantidad, singular, plural) {
  return `${cantidad} ${cantidad === 1 ? singular : plural}`;
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

export default function ReporteDemandaServicios() {
  const navigate = useNavigate();
  // Lo que está elegido en los filtros. Al entrar se muestra el año actual completo
  const [desde, setDesde] = useState({ anio: ANIO_ACTUAL, mes: 1 });
  const [hasta, setHasta] = useState({ anio: ANIO_ACTUAL, mes: 12 });
  const [servicio, setServicio] = useState(''); // '' = todos los servicios
  // Qué se muestra en el gráfico y en la tabla: 'contrataciones' o 'ingresos'.
  // No hace falta volver a pedirle nada al backend: ya manda los dos números.
  const [verPor, setVerPor] = useState('contrataciones');

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
      .get('/reportes/demanda-servicios/', { params: { desde: mes(desde), hasta: mes(hasta), servicio: servicio || undefined } })
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch((err) => {
        // Por ejemplo, si se eligió un "Desde" posterior al "Hasta" el backend avisa con un mensaje
        if (vigente) setError(err.response?.data?.detail || 'No se pudo cargar el reporte.');
      })
      .finally(() => { if (vigente) setCargando(false); });
    return () => { vigente = false; };
  }, [desde, hasta, servicio]);

  const porPlata = verPor === 'ingresos';
  // Cómo se escribe cada número de la tabla según lo que se esté mirando
  const escribir = porPlata ? pesos : (v) => v;

  const periodo = `De ${mesEnPalabras(desde.anio, desde.mes)} a ${mesEnPalabras(hasta.anio, hasta.mes)}`;
  // true cuando en el período no se contrató ninguno de los servicios elegidos
  const sinDatos = datos && datos.total_contrataciones === 0;

  // ---- Frases de la interpretación (se arman solas con los números del reporte) ----
  let interpretacion = [];
  if (datos && !sinDatos) {
    const masPedido = datos.servicios[0]; // ya vienen ordenados del más pedido al menos pedido
    const masPlata = datos.servicios.reduce((mayor, s) => (s.ingresos > mayor.ingresos ? s : mayor), datos.servicios[0]);
    const mesPico = datos.meses.reduce((mayor, m) => (m.contrataciones > mayor.contrataciones ? m : mayor), datos.meses[0]);
    const mesesConDemanda = datos.meses.filter((m) => m.contrataciones > 0);
    const mesFlojo = mesesConDemanda.reduce((menor, m) => (m.contrataciones < menor.contrataciones ? m : menor), mesesConDemanda[0]);
    const mesesSinDemanda = datos.meses.filter((m) => m.contrataciones === 0);
    // Los servicios activos que no se pidieron nunca (los dados de baja no importan acá)
    const sinDemanda = datos.servicios.filter((s) => s.total === 0 && s.activo);
    const promedioMes = datos.total_contrataciones / datos.meses.length;

    interpretacion = [
      datos.servicios.length > 1
        ? `El servicio más pedido fue ${masPedido.nombre_servicio}: ${contar(masPedido.total, 'contratación', 'contrataciones')}, el ${masPedido.porcentaje}% de toda la demanda del período.`
        : `${masPedido.nombre_servicio} se contrató ${contar(masPedido.total, 'vez', 'veces')} y dejó ${pesos(masPedido.ingresos)}.`,
      datos.servicios.length > 1 && masPlata.id_servicio !== masPedido.id_servicio
        ? `El que más ingresos dejó fue ${masPlata.nombre_servicio} (${pesos(masPlata.ingresos)}), aunque se pidió menos veces: conviene cuidarlo y promocionarlo.`
        : null,
      `El mes de más demanda fue ${mesEnPalabras(mesPico.anio, mesPico.mes)}, con ${contar(mesPico.contrataciones, 'contratación', 'contrataciones')} en ${contar(mesPico.reservas, 'reserva', 'reservas')}: hay que prever personal y equipos para esa época.`,
      mesesConDemanda.length > 1 && mesFlojo.contrataciones < mesPico.contrataciones
        ? `El mes con menos demanda (de los que tuvieron alguna) fue ${mesEnPalabras(mesFlojo.anio, mesFlojo.mes)}, con ${contar(mesFlojo.contrataciones, 'contratación', 'contrataciones')}.`
        : null,
      `En promedio se contrataron ${promedioMes.toLocaleString('es-AR', { maximumFractionDigits: 1 })} servicios por mes.`,
      mesesSinDemanda.length > 0
        ? `Meses sin ninguna contratación, buenos para lanzar promociones: ${mesesSinDemanda.map((m) => mesEnPalabras(m.anio, m.mes)).join(', ')}.`
        : null,
      sinDemanda.length > 0
        ? `No se contrataron en el período (revisar precio o si conviene seguir ofreciéndolos): ${sinDemanda.map((s) => s.nombre_servicio).join(', ')}.`
        : null,
    ].filter(Boolean); // saca las frases que quedaron vacías
  }

  // Nombre que propone el navegador al guardar el PDF (ver BotonImprimirReporte.jsx)
  const nombreArchivo = `Reporte-Demanda-por-servicio-${desde.anio}-${String(desde.mes).padStart(2, '0')}-a-${hasta.anio}-${String(hasta.mes).padStart(2, '0')}`;

  return (
    <div className="reporte-pagina">
      <div className="page-header page-header-con-ruta">
        <div>
          {/* Flecha para volver a la pantalla principal de Reportes, al lado del título */}
          <div className="titulo-con-volver">
            <button type="button" className="btn-volver" onClick={() => navigate('/reportes')} title="Volver a Reportes" aria-label="Volver a Reportes">
              <IconVolver />
            </button>
            <h1>Demanda por servicio por mes</h1>
          </div>
          <div className="ruta"><Link to="/reportes">Reportes</Link> / <strong>Demanda por servicio por mes</strong></div>
        </div>
      </div>

      {/* Para qué sirve y qué es lo que se cuenta */}
      <div className="reporte-intro">
        <p className="reporte-descripcion">
          Muestra cuántas veces se <strong>contrató cada servicio</strong> en los eventos de cada mes y cuánto dejó,
          para saber qué servicios conviene promocionar, en qué meses reforzar el personal y los equipos, y cuáles casi
          no se piden. Cuentan las reservas pendientes, confirmadas y finalizadas; las anuladas no. Los ingresos se
          calculan con el precio que se cobró en cada reserva.
        </p>
        <BotonImprimirReporte nombreArchivo={nombreArchivo} deshabilitado={cargando || !!error || !datos || !!sinDatos} />
      </div>

      {/* ---- Filtros ---- */}
      <div className="card filtros reporte-filtros">
        <SelectorMes id="desde" label="Desde" valor={desde} onChange={setDesde} />
        <SelectorMes id="hasta" label="Hasta" valor={hasta} onChange={setHasta} />
        <div className="form-field">
          <label htmlFor="servicio">Servicio</label>
          <select id="servicio" value={servicio} onChange={(e) => setServicio(e.target.value)}>
            <option value="">Todos los servicios</option>
            {(datos?.opciones.servicios || []).map((s) => (
              <option key={s.id} value={s.id}>{s.nombre}{s.activo ? '' : ' (dado de baja)'}</option>
            ))}
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="ver-por">Ver por</label>
          <select id="ver-por" value={verPor} onChange={(e) => setVerPor(e.target.value)}>
            <option value="contrataciones">Contrataciones</option>
            <option value="ingresos">Ingresos</option>
          </select>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {cargando && !datos && <div className="card reporte-vacio">Cargando...</div>}

      {/* ---- Cuando no hay nada para mostrar en el período ---- */}
      {!error && sinDatos && (
        <div className="card reporte-vacio">
          <strong>No hay contrataciones para mostrar.</strong>
          <span>{periodo} no se contrató ninguno de los servicios elegidos. Probá con otro período o sacá los filtros.</span>
        </div>
      )}

      {!error && datos && !sinDatos && (
        <>
          {/* ---- Gráfico: una barra por mes con el total (contrataciones o ingresos) ---- */}
          <div className="card reporte-bloque">
            <GraficoBarras
              titulo={porPlata ? 'Ingresos por servicios contratados, por mes' : 'Servicios contratados en eventos, por mes'}
              periodo={`${periodo} · ${contar(datos.total_contrataciones, 'contratación', 'contrataciones')} en ${contar(datos.total_reservas, 'reserva', 'reservas')} · ${pesos(datos.total_ingresos)}`}
              grafico={porPlata ? datos.graficos.ingresos : datos.graficos.contrataciones}
              unidad={porPlata ? 'en ingresos' : 'contrataciones'}
              formato={porPlata ? pesos : undefined}
              datos={datos.meses.map((m) => ({
                anio: m.anio,
                mes: m.mes,
                valor: porPlata ? m.ingresos : m.contrataciones,
                // Al pasar el mouse se ve el otro número también
                detalle: porPlata
                  ? `${contar(m.contrataciones, 'contratación', 'contrataciones')} · ${contar(m.reservas, 'reserva', 'reservas')}`
                  : `${contar(m.reservas, 'reserva', 'reservas')} · ${pesos(m.ingresos)}`,
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

          {/* ---- Tabla con el detalle de cada servicio ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Detalle por servicio {porPlata ? '(ingresos)' : '(contrataciones)'}</h2>
            {/* La tabla puede ser más ancha que la pantalla (una columna por mes): se desliza hacia el costado */}
            <div className="reporte-tabla-scroll">
              <table className="data-table reporte-tabla">
                <thead>
                  <tr>
                    <th>Servicio</th>
                    {datos.meses.map((m) => <th key={m.etiqueta} className="numero">{m.etiqueta}</th>)}
                    <th className="numero">Total</th>
                    <th className="numero">% de la demanda</th>
                    <th className="numero">{porPlata ? 'Contrataciones' : 'Ingresos'}</th>
                    <th className="numero">Precio promedio cobrado</th>
                    <th className="numero">Precio actual</th>
                    <th>Mes de más demanda</th>
                  </tr>
                </thead>
                <tbody>
                  {datos.servicios.map((s) => {
                    const valores = porPlata ? s.ingresos_por_mes : s.por_mes;
                    return (
                      <tr key={s.id_servicio}>
                        <td>
                          {s.nombre_servicio}
                          {!s.activo && <span className="badge badge-gray badge-chica" style={{ marginLeft: 6 }}>Dado de baja</span>}
                        </td>
                        {/* Los ceros van en gris clarito para que resalten los meses con demanda */}
                        {valores.map((valor, i) => (
                          <td key={datos.meses[i].etiqueta} className={`numero${valor === 0 ? ' cero' : ''}`}>{escribir(valor)}</td>
                        ))}
                        <td className="numero"><strong>{escribir(porPlata ? s.ingresos : s.total)}</strong></td>
                        <td className={`numero${s.total === 0 ? ' cero' : ''}`}>{s.porcentaje.toLocaleString('es-AR')}%</td>
                        <td className="numero">{porPlata ? s.total : pesos(s.ingresos)}</td>
                        <td className="numero">
                          {s.precio_promedio !== null ? pesos(s.precio_promedio) : <span className="cero">—</span>}
                        </td>
                        <td className="numero">{pesos(s.precio_actual)}</td>
                        <td>
                          {s.mes_pico
                            ? `${mesEnPalabras(s.mes_pico.anio, s.mes_pico.mes)} (${s.mes_pico.contrataciones})`
                            : <span className="cero">Sin demanda</span>}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
                {/* Los totales de cada mes: tienen que coincidir con las barras del gráfico */}
                <tfoot>
                  <tr>
                    <td>Total del mes</td>
                    {datos.meses.map((m) => (
                      <td key={m.etiqueta} className="numero">{escribir(porPlata ? m.ingresos : m.contrataciones)}</td>
                    ))}
                    <td className="numero">{escribir(porPlata ? datos.total_ingresos : datos.total_contrataciones)}</td>
                    <td className="numero">100%</td>
                    <td className="numero">{porPlata ? datos.total_contrataciones : pesos(datos.total_ingresos)}</td>
                    <td colSpan={3} />
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
