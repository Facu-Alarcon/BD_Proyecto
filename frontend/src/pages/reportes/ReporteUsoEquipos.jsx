import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import GraficoBarras from '../../components/GraficoBarras';
import './Reportes.css';

// REPORTE: USO DE EQUIPOS POR MES
//
// Muestra cuántas unidades de equipos se usan en los eventos de cada mes.
// Tiene tres partes: los filtros, el gráfico (un total por mes) y la tabla con el detalle
// de cada equipo. Los números los calcula el backend (ver infinito_sonido/reportes.py,
// ahí está explicado cómo se hace la cuenta); esta pantalla solo los muestra.

const NOMBRES_MES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Años que se pueden elegir en los filtros: dos para atrás y dos para adelante del actual
const ANIO_ACTUAL = new Date().getFullYear();
const ANIOS = [ANIO_ACTUAL - 2, ANIO_ACTUAL - 1, ANIO_ACTUAL, ANIO_ACTUAL + 1, ANIO_ACTUAL + 2];

// Escribe un mes con palabras: (2026, 3) -> "marzo de 2026"
function mesEnPalabras(anio, mes) {
  return `${NOMBRES_MES[mes - 1].toLowerCase()} de ${anio}`;
}

// Escribe una fecha como 18/10/2026 (el backend la manda como 2026-10-18)
function fechaCorta(fecha) {
  const [anio, mes, dia] = fecha.split('-');
  return `${dia}/${mes}/${anio}`;
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

export default function ReporteUsoEquipos() {
  // Lo que está elegido en los filtros. Al entrar se muestra el año actual completo
  const [desde, setDesde] = useState({ anio: ANIO_ACTUAL, mes: 1 });
  const [hasta, setHasta] = useState({ anio: ANIO_ACTUAL, mes: 12 });
  const [tipo, setTipo] = useState('');     // '' = todos los tipos
  const [equipo, setEquipo] = useState(''); // '' = todos los equipos

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
      .get('/reportes/uso-equipos/', { params: { desde: mes(desde), hasta: mes(hasta), tipo: tipo || undefined, equipo: equipo || undefined } })
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch((err) => {
        // Por ejemplo, si se eligió un "Desde" posterior al "Hasta" el backend avisa con un mensaje
        if (vigente) setError(err.response?.data?.detail || 'No se pudo cargar el reporte.');
      })
      .finally(() => { if (vigente) setCargando(false); });
    return () => { vigente = false; };
  }, [desde, hasta, tipo, equipo]);

  // Al cambiar el tipo se vuelve a "todos los equipos", porque el equipo elegido puede ser de otro tipo
  function cambiarTipo(valor) {
    setTipo(valor);
    setEquipo('');
  }

  // Los equipos que se ofrecen en el desplegable: si hay un tipo elegido, solo los de ese tipo
  const equiposParaElegir = (datos?.opciones.equipos || []).filter((e) => !tipo || String(e.tipo) === String(tipo));

  const periodo = `De ${mesEnPalabras(desde.anio, desde.mes)} a ${mesEnPalabras(hasta.anio, hasta.mes)}`;
  // true cuando en el período no hay ninguna reserva que use los equipos elegidos
  const sinDatos = datos && datos.total_reservas === 0;

  // ---- Frases de la interpretación (se arman solas con los números del reporte) ----
  let interpretacion = [];
  if (datos && !sinDatos) {
    const masUsado = datos.equipos[0]; // ya vienen ordenados del más usado al menos usado
    const mesPico = datos.meses.reduce((mayor, m) => (m.unidades > mayor.unidades ? m : mayor), datos.meses[0]);
    const sinUso = datos.equipos.filter((e) => e.total === 0);
    // "Al tope": algún día se usaron todas las unidades que tenemos (o más) de ese equipo
    const alTope = datos.equipos.filter((e) => e.maximo_dia > 0 && e.maximo_dia >= e.stock);
    const mesesFlojos = datos.meses.filter((m) => m.unidades === 0);

    interpretacion = [
      `El equipo más usado fue ${masUsado.nombre_equipo}: ${masUsado.total} unidades en ${masUsado.eventos} ${masUsado.eventos === 1 ? 'evento' : 'eventos'}.`,
      `El mes con más uso fue ${mesEnPalabras(mesPico.anio, mesPico.mes)}, con ${mesPico.unidades} unidades en ${mesPico.reservas} ${mesPico.reservas === 1 ? 'reserva' : 'reservas'}.`,
      alTope.length > 0
        ? `Llegaron al tope de lo que tenemos (conviene evaluar comprar más): ${alTope.map((e) => e.nombre_equipo).join(', ')}.`
        : 'Ningún equipo llegó a usarse completo en un mismo día: por ahora alcanza con lo que hay.',
      sinUso.length > 0
        ? `No se usaron en el período (revisar si hacen falta): ${sinUso.map((e) => e.nombre_equipo).join(', ')}.`
        : 'Todos los equipos se usaron al menos una vez en el período.',
      mesesFlojos.length > 0
        ? `Meses sin uso, buenos para hacer mantenimiento: ${mesesFlojos.map((m) => mesEnPalabras(m.anio, m.mes)).join(', ')}.`
        : null,
    ].filter(Boolean); // saca las frases que quedaron vacías
  }

  return (
    <div>
      <div className="page-header page-header-con-ruta">
        <div>
          <h1>Uso de equipos por mes</h1>
          <div className="ruta"><Link to="/reportes">Reportes</Link> / <strong>Uso de equipos por mes</strong></div>
        </div>
      </div>

      {/* Para qué sirve y qué es lo que se cuenta */}
      <p className="reporte-descripcion">
        Muestra cuántas <strong>unidades de equipos</strong> se usan en los eventos de cada mes, para decidir qué
        equipos comprar, cuáles sobran y cuándo conviene hacer mantenimiento. Cuentan las reservas pendientes,
        confirmadas y finalizadas; las anuladas no.
      </p>

      {/* ---- Filtros ---- */}
      <div className="card filtros reporte-filtros">
        <SelectorMes id="desde" label="Desde" valor={desde} onChange={setDesde} />
        <SelectorMes id="hasta" label="Hasta" valor={hasta} onChange={setHasta} />
        <div className="form-field">
          <label htmlFor="tipo">Tipo de equipo</label>
          <select id="tipo" value={tipo} onChange={(e) => cambiarTipo(e.target.value)}>
            <option value="">Todos los tipos</option>
            {(datos?.opciones.tipos || []).map((t) => <option key={t.id} value={t.id}>{t.nombre}</option>)}
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="equipo">Equipo</label>
          <select id="equipo" value={equipo} onChange={(e) => setEquipo(e.target.value)}>
            <option value="">Todos los equipos</option>
            {equiposParaElegir.map((e) => <option key={e.id} value={e.id}>{e.nombre}</option>)}
          </select>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {cargando && !datos && <div className="card reporte-vacio">Cargando...</div>}

      {/* ---- Cuando no hay nada para mostrar en el período ---- */}
      {!error && sinDatos && (
        <div className="card reporte-vacio">
          <strong>No hay reservas para mostrar.</strong>
          <span>{periodo} no hay reservas que usen los equipos elegidos. Probá con otro período o sacá los filtros.</span>
        </div>
      )}

      {!error && datos && !sinDatos && (
        <>
          {/* ---- Gráfico: una barra por mes con el total de unidades ---- */}
          <div className="card reporte-bloque">
            <GraficoBarras
              titulo="Unidades de equipos comprometidas en eventos, por mes"
              periodo={`${periodo} · ${datos.total_unidades} unidades en ${datos.total_reservas} ${datos.total_reservas === 1 ? 'reserva' : 'reservas'}`}
              unidad="unidades"
              ejeX="Mes del evento"
              datos={datos.meses.map((m) => ({
                anio: m.anio,
                mes: m.mes,
                valor: m.unidades,
                detalle: `${m.reservas} ${m.reservas === 1 ? 'reserva' : 'reservas'}`,
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

          {/* ---- Tabla con el detalle de cada equipo ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Detalle por equipo</h2>
            {/* La tabla puede ser más ancha que la pantalla (una columna por mes): se desliza hacia el costado */}
            <div className="reporte-tabla-scroll">
              <table className="data-table reporte-tabla">
                <thead>
                  <tr>
                    <th>Equipo</th>
                    <th>Tipo</th>
                    {datos.meses.map((m) => <th key={m.etiqueta} className="numero">{m.etiqueta}</th>)}
                    <th className="numero">Total</th>
                    <th className="numero">Eventos</th>
                    <th className="numero">Tenemos</th>
                    <th className="numero">Máximo en un día</th>
                  </tr>
                </thead>
                <tbody>
                  {datos.equipos.map((e) => (
                    <tr key={e.id_equipo}>
                      <td>{e.nombre_equipo}</td>
                      <td>{e.tipo}</td>
                      {/* Los ceros van en gris clarito para que resalten los meses con uso */}
                      {e.por_mes.map((cantidad, i) => (
                        <td key={datos.meses[i].etiqueta} className={`numero${cantidad === 0 ? ' cero' : ''}`}>{cantidad}</td>
                      ))}
                      <td className="numero"><strong>{e.total}</strong></td>
                      <td className="numero">{e.eventos}</td>
                      <td className="numero">{e.stock}</td>
                      <td className="numero">
                        {e.maximo_dia > 0 ? (
                          <>
                            {e.maximo_dia} <span className="form-hint">({fechaCorta(e.fecha_maximo)})</span>
                            {/* Aviso cuando ese día se usó todo lo que hay */}
                            {e.maximo_dia >= e.stock && <span className="badge badge-amber badge-chica" style={{ marginLeft: 6 }}>Al tope</span>}
                          </>
                        ) : (
                          <span className="cero">Sin uso</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
                {/* Los totales de cada mes: tienen que coincidir con las barras del gráfico */}
                <tfoot>
                  <tr>
                    <td colSpan={2}>Total del mes</td>
                    {datos.meses.map((m) => <td key={m.etiqueta} className="numero">{m.unidades}</td>)}
                    <td className="numero">{datos.total_unidades}</td>
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
