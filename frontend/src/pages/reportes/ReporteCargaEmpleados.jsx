import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../../api/client';
import GraficoBarras from '../../components/GraficoBarras';
import { IconVolver } from '../../components/icons';
import BotonImprimirReporte from '../../components/BotonImprimirReporte';
import './Reportes.css';

// REPORTE TÁCTICO: CARGA DE TRABAJO DE LOS EMPLEADOS
//
// Muestra a cuántos eventos fue asignado cada empleado en cada mes, para repartir mejor el
// trabajo, ver quién está sobrecargado y en qué meses hace falta más personal.
// Tiene tres partes: los filtros, el gráfico (un total por mes) y la tabla con el detalle.
// Con el selector "Ver por" la tabla se mira por empleado o por puesto.
// Los números los calcula el backend (ver infinito_sonido/reportes.py);
// esta pantalla solo los muestra.

const NOMBRES_MES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Años que se pueden elegir en los filtros: dos para atrás y dos para adelante del actual
const ANIO_ACTUAL = new Date().getFullYear();
const ANIOS = [ANIO_ACTUAL - 2, ANIO_ACTUAL - 1, ANIO_ACTUAL, ANIO_ACTUAL + 1, ANIO_ACTUAL + 2];

// Escribe un mes con palabras: (2026, 3) -> "marzo de 2026"
function mesEnPalabras(anio, mes) {
  return `${NOMBRES_MES[mes - 1].toLowerCase()} de ${anio}`;
}

// "1 evento" / "3 eventos" (y lo mismo con reservas, empleados, etc.)
function contar(cantidad, singular, plural) {
  return `${cantidad.toLocaleString('es-AR')} ${cantidad === 1 ? singular : plural}`;
}

// Escribe una lista con comas y "y": ["A", "B", "C"] -> "A, B y C". Si son muchos, muestra los primeros.
function lista(nombres, maximo = 6) {
  const mostrar = nombres.slice(0, maximo);
  const resto = nombres.length - mostrar.length;
  if (resto > 0) return `${mostrar.join(', ')} y ${resto} más`;
  if (mostrar.length > 1) return `${mostrar.slice(0, -1).join(', ')} y ${mostrar[mostrar.length - 1]}`;
  return mostrar.join('');
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

export default function ReporteCargaEmpleados() {
  const navigate = useNavigate();
  // Lo que está elegido en los filtros. Al entrar se muestra el año actual completo
  const [desde, setDesde] = useState({ anio: ANIO_ACTUAL, mes: 1 });
  const [hasta, setHasta] = useState({ anio: ANIO_ACTUAL, mes: 12 });
  const [puesto, setPuesto] = useState('');     // '' = todos los puestos
  const [empleado, setEmpleado] = useState(''); // '' = todos los empleados
  // Cómo se agrupa la tabla: 'empleado' o 'puesto'.
  // No hace falta volver a pedirle nada al backend: ya manda las dos listas.
  const [verPor, setVerPor] = useState('empleado');

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
      .get('/reportes/carga-empleados/', {
        params: { desde: mes(desde), hasta: mes(hasta), puesto: puesto || undefined, empleado: empleado || undefined },
      })
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch((err) => {
        // Por ejemplo, si se eligió un "Desde" posterior al "Hasta" el backend avisa con un mensaje
        if (vigente) setError(err.response?.data?.detail || 'No se pudo cargar el reporte.');
      })
      .finally(() => { if (vigente) setCargando(false); });
    return () => { vigente = false; };
  }, [desde, hasta, puesto, empleado]);

  // Al cambiar de puesto se limpia el empleado, porque el elegido puede no ser de ese puesto
  const cambiarPuesto = (valor) => {
    setPuesto(valor);
    setEmpleado('');
  };

  const porPuesto = verPor === 'puesto';
  const periodo = `De ${mesEnPalabras(desde.anio, desde.mes)} a ${mesEnPalabras(hasta.anio, hasta.mes)}`;
  // true cuando en el período no hay ningún evento con personal asignado
  const sinDatos = datos && datos.total_asignaciones === 0;
  // Los empleados que se pueden elegir: solo los del puesto elegido (si hay uno)
  const opcionesEmpleado = (datos?.opciones.empleados || []).filter((e) => !puesto || e.puestos.includes(Number(puesto)));

  // ---- Frases de la interpretación (se arman solas con los números del reporte) ----
  let interpretacion = [];
  if (datos && !sinDatos) {
    const mesPico = datos.meses.reduce((mayor, m) => (m.asignaciones > mayor.asignaciones ? m : mayor), datos.meses[0]);
    const mesesConCarga = datos.meses.filter((m) => m.asignaciones > 0);
    const mesFlojo = mesesConCarga.reduce((menor, m) => (m.asignaciones < menor.asignaciones ? m : menor), mesesConCarga[0]);
    const mesesSinCarga = datos.meses.filter((m) => m.asignaciones === 0);

    // Las frases sobre empleados o sobre puestos, según lo que se esté mirando
    let frasesTabla = [];
    if (!porPuesto) {
      const filas = datos.empleados; // ya vienen ordenados del que más trabajó al que menos
      const masCarga = filas[0];
      // Los empleados dados de baja no importan para repartir el trabajo
      const activos = filas.filter((e) => e.activo);
      const conEventos = activos.filter((e) => e.total > 0);
      const menosCarga = conEventos.reduce((menor, e) => (e.total < menor.total ? e : menor), conEventos[0]);
      const sinEventos = activos.filter((e) => e.total === 0);
      const promedio = activos.length ? datos.total_asignaciones / activos.length : 0;

      frasesTabla = [
        filas.length > 1
          ? `Quien más trabajó fue ${masCarga.nombre_empleado}: ${contar(masCarga.total, 'evento', 'eventos')}, el ${masCarga.porcentaje.toLocaleString('es-AR')}% de toda la carga del período.`
          : `${masCarga.nombre_empleado} trabajó en ${contar(masCarga.total, 'evento', 'eventos')} en el período.`,
        conEventos.length > 1 && masCarga.total - menosCarga.total >= 2
          ? `Entre quien más y quien menos trabajó (${menosCarga.nombre_empleado}, con ${contar(menosCarga.total, 'evento', 'eventos')}) hay ${masCarga.total - menosCarga.total} eventos de diferencia: conviene repartir mejor el trabajo.`
          : null,
        activos.length > 1
          ? `En promedio cada empleado activo fue asignado a ${promedio.toLocaleString('es-AR', { maximumFractionDigits: 1 })} eventos.`
          : null,
        sinEventos.length > 0 && activos.length > 1
          ? `No tuvieron ningún evento en el período (hay margen para asignarles más trabajo): ${lista(sinEventos.map((e) => e.nombre_empleado))}.`
          : null,
      ];
    } else {
      const filas = datos.puestos; // ya vienen ordenados del que más trabajó al que menos
      const masCarga = filas[0];
      // El puesto donde a cada persona le tocan más eventos: es el que más se esfuerza
      const masPorPersona = filas.reduce((mayor, p) => (p.promedio_por_empleado > mayor.promedio_por_empleado ? p : mayor), filas[0]);
      frasesTabla = [
        filas.length > 1
          ? `El puesto con más carga fue ${masCarga.nombre_puesto}: ${contar(masCarga.total, 'asignación', 'asignaciones')}, el ${masCarga.porcentaje.toLocaleString('es-AR')}% de toda la carga del período.`
          : `${masCarga.nombre_puesto} sumó ${contar(masCarga.total, 'asignación', 'asignaciones')} en el período.`,
        filas.length > 1 && masPorPersona.id_puesto !== masCarga.id_puesto
          ? `Por persona, el puesto más exigido fue ${masPorPersona.nombre_puesto}: ${masPorPersona.promedio_por_empleado.toLocaleString('es-AR')} eventos por empleado. Puede hacer falta sumar gente ahí.`
          : null,
        filas.length > 1 && masPorPersona.id_puesto === masCarga.id_puesto
          ? `También es el puesto más exigido por persona (${masPorPersona.promedio_por_empleado.toLocaleString('es-AR')} eventos por empleado): puede hacer falta sumar gente ahí.`
          : null,
      ];
    }

    interpretacion = [
      ...frasesTabla,
      `El mes de más carga fue ${mesEnPalabras(mesPico.anio, mesPico.mes)}, con ${contar(mesPico.asignaciones, 'asignación', 'asignaciones')} en ${contar(mesPico.reservas, 'reserva', 'reservas')} y ${contar(mesPico.empleados, 'empleado', 'empleados')} trabajando: hay que tener el personal disponible para esa época.`,
      mesesConCarga.length > 1 && mesFlojo.asignaciones < mesPico.asignaciones
        ? `El mes con menos carga (de los que tuvieron alguna) fue ${mesEnPalabras(mesFlojo.anio, mesFlojo.mes)}, con ${contar(mesFlojo.asignaciones, 'asignación', 'asignaciones')}.`
        : null,
      mesesSinCarga.length > 0
        ? `Meses sin ningún evento con personal asignado: ${lista(mesesSinCarga.map((m) => mesEnPalabras(m.anio, m.mes)), 12)}.`
        : null,
      datos.reservas_sin_personal > 0
        ? `Hay ${contar(datos.reservas_sin_personal, 'reserva', 'reservas')} del período sin ningún empleado asignado: conviene revisarlas.`
        : null,
    ].filter(Boolean); // saca las frases que quedaron vacías
  }

  // Nombre que propone el navegador al guardar el PDF (ver BotonImprimirReporte.jsx)
  const nombreArchivo = `Reporte-Carga-de-empleados-${desde.anio}-${String(desde.mes).padStart(2, '0')}-a-${hasta.anio}-${String(hasta.mes).padStart(2, '0')}`;

  return (
    <div className="reporte-pagina">
      <div className="page-header page-header-con-ruta">
        <div>
          {/* Flecha para volver a la pantalla principal de Reportes, al lado del título */}
          <div className="titulo-con-volver">
            <button type="button" className="btn-volver" onClick={() => navigate('/reportes')} title="Volver a Reportes" aria-label="Volver a Reportes">
              <IconVolver />
            </button>
            <h1>Carga de trabajo de los empleados</h1>
          </div>
          <div className="ruta"><Link to="/reportes">Reportes</Link> / <strong>Carga de trabajo de los empleados</strong></div>
        </div>
      </div>

      {/* Para qué sirve y qué es lo que se cuenta */}
      <div className="reporte-intro">
        <p className="reporte-descripcion">
          Muestra a <strong>cuántos eventos fue asignado cada empleado</strong> en cada mes, para repartir mejor el trabajo,
          ver quién está sobrecargado y en qué meses hace falta más personal. Cuentan las reservas pendientes,
          confirmadas y finalizadas; las anuladas no. Cada evento se cuenta en el mes de su fecha.
        </p>
        <BotonImprimirReporte nombreArchivo={nombreArchivo} deshabilitado={cargando || !!error || !datos || !!sinDatos} />
      </div>

      {/* ---- Filtros ---- */}
      <div className="card filtros reporte-filtros">
        <SelectorMes id="desde" label="Desde" valor={desde} onChange={setDesde} />
        <SelectorMes id="hasta" label="Hasta" valor={hasta} onChange={setHasta} />
        <div className="form-field">
          <label htmlFor="puesto">Puesto</label>
          <select id="puesto" value={puesto} onChange={(e) => cambiarPuesto(e.target.value)}>
            <option value="">Todos los puestos</option>
            {(datos?.opciones.puestos || []).map((p) => (
              <option key={p.id} value={p.id}>{p.nombre}</option>
            ))}
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="empleado">Empleado</label>
          <select id="empleado" value={empleado} onChange={(e) => setEmpleado(e.target.value)}>
            <option value="">Todos los empleados</option>
            {opcionesEmpleado.map((e) => (
              <option key={e.id} value={e.id}>{e.nombre}{e.activo ? '' : ' (dado de baja)'}</option>
            ))}
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="ver-por">Ver por</label>
          <select id="ver-por" value={verPor} onChange={(e) => setVerPor(e.target.value)}>
            <option value="empleado">Empleado</option>
            <option value="puesto">Puesto</option>
          </select>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {cargando && !datos && <div className="card reporte-vacio">Cargando...</div>}

      {/* ---- Cuando no hay nada para mostrar en el período ---- */}
      {!error && sinDatos && (
        <div className="card reporte-vacio">
          <strong>No hay eventos con personal para mostrar.</strong>
          <span>{periodo} no hubo empleados asignados a eventos con estos filtros. Probá con otro período o sacá los filtros.</span>
        </div>
      )}

      {!error && datos && !sinDatos && (
        <>
          {/* ---- Gráfico: una barra por mes con el total de eventos asignados ---- */}
          <div className="card reporte-bloque">
            <GraficoBarras
              titulo="Eventos asignados al personal, por mes"
              periodo={`${periodo} · ${contar(datos.total_asignaciones, 'asignación', 'asignaciones')} en ${contar(datos.total_reservas, 'reserva', 'reservas')}`}
              grafico={datos.grafico}
              unidad="eventos asignados"
              datos={datos.meses.map((m) => ({
                anio: m.anio,
                mes: m.mes,
                valor: m.asignaciones,
                // Al pasar el mouse se ve cuántas reservas y cuántos empleados hay ese mes
                detalle: `${contar(m.reservas, 'reserva', 'reservas')} · ${contar(m.empleados, 'empleado', 'empleados')}`,
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

          {/* ---- Tabla con el detalle de cada empleado o puesto ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Detalle por {porPuesto ? 'puesto' : 'empleado'} (eventos asignados)</h2>
            {/* La tabla puede ser más ancha que la pantalla (una columna por mes): se desliza hacia el costado */}
            <div className="reporte-tabla-scroll">
              <table className="data-table reporte-tabla">
                <thead>
                  <tr>
                    <th>{porPuesto ? 'Puesto' : 'Empleado'}</th>
                    <th>{porPuesto ? 'Empleados' : 'Puesto'}</th>
                    {datos.meses.map((m) => <th key={m.etiqueta} className="numero">{m.etiqueta}</th>)}
                    <th className="numero">Total</th>
                    <th className="numero">% de la carga</th>
                    <th className="numero">{porPuesto ? 'Promedio por empleado' : 'Promedio por mes'}</th>
                    <th>Mes de más carga</th>
                  </tr>
                </thead>
                <tbody>
                  {(porPuesto ? datos.puestos : datos.empleados).map((f) => (
                    <tr key={porPuesto ? f.id_puesto : f.id_empleado}>
                      <td>
                        {porPuesto ? f.nombre_puesto : f.nombre_empleado}
                        {!porPuesto && !f.activo && <span className="badge badge-gray badge-chica" style={{ marginLeft: 6 }}>Dado de baja</span>}
                      </td>
                      <td>{porPuesto ? f.empleados : (f.puestos.join(', ') || <span className="cero">Sin puesto</span>)}</td>
                      {/* Los ceros van en gris clarito para que resalten los meses con trabajo */}
                      {f.por_mes.map((valor, i) => (
                        <td key={datos.meses[i].etiqueta} className={`numero${valor === 0 ? ' cero' : ''}`}>{valor}</td>
                      ))}
                      <td className="numero"><strong>{f.total}</strong></td>
                      <td className={`numero${f.total === 0 ? ' cero' : ''}`}>{f.porcentaje.toLocaleString('es-AR')}%</td>
                      <td className="numero">
                        {(porPuesto ? f.promedio_por_empleado : f.promedio_mensual).toLocaleString('es-AR')}
                      </td>
                      <td>
                        {f.mes_pico
                          ? `${mesEnPalabras(f.mes_pico.anio, f.mes_pico.mes)} (${f.mes_pico.eventos})`
                          : <span className="cero">Sin eventos</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
                {/* Los totales de cada mes: tienen que coincidir con las barras del gráfico */}
                <tfoot>
                  <tr>
                    <td>Total del mes</td>
                    <td />
                    {datos.meses.map((m) => (
                      <td key={m.etiqueta} className="numero">{m.asignaciones}</td>
                    ))}
                    <td className="numero">{datos.total_asignaciones}</td>
                    <td className="numero">100%</td>
                    <td colSpan={2} />
                  </tr>
                </tfoot>
              </table>
            </div>
            {porPuesto && (
              <p className="reporte-descripcion" style={{ margin: '12px 0 0' }}>
                Cada empleado asignado a un evento suma una asignación a su puesto. Si un empleado tiene más de un puesto, suma en cada uno.
              </p>
            )}
          </div>
        </>
      )}
    </div>
  );
}