import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../../api/client';
import { IconVolver } from '../../components/icons';
import { formatearPesos } from '../../utils/formato';
import './Reportes.css';

// REPORTE: COMPARACIÓN DE PERÍODOS
//
// Compara un trimestre o semestre contra el mismo del año anterior, servicio por servicio,
// para decidir en cuáles conviene concentrar los recursos. Tiene tres partes: los filtros,
// un gráfico de barras por servicio (este año contra el anterior) y la tabla con el detalle.
// Los números los calcula el backend (ver ReporteComparacionPeriodosView en
// infinito_sonido/reportes.py); esta pantalla solo los muestra.

// Años que se pueden elegir: dos para atrás y uno para adelante del actual
const ANIO_ACTUAL = new Date().getFullYear();
const ANIOS = [ANIO_ACTUAL - 2, ANIO_ACTUAL - 1, ANIO_ACTUAL, ANIO_ACTUAL + 1];

// Cuántos períodos tiene un año según el tipo: 4 trimestres o 2 semestres
const CANTIDAD_POR_TIPO = { trimestre: 4, semestre: 2 };
const MESES_DEL_PERIODO = {
  trimestre: ['Enero a marzo', 'Abril a junio', 'Julio a septiembre', 'Octubre a diciembre'],
  semestre: ['Enero a junio', 'Julio a diciembre'],
};

// El trimestre en el que estamos hoy (1 a 4): enero, febrero y marzo son el 1, etc.
const TRIMESTRE_ACTUAL = Math.floor(new Date().getMonth() / 3) + 1;

// Escribe una variación como texto: 12.5 -> "+12,5 %", -8 -> "-8 %", null -> "—"
function textoVariacion(valor) {
  if (valor === null || valor === undefined) return '—';
  const numero = valor.toLocaleString('es-AR', { maximumFractionDigits: 1 });
  return `${valor > 0 ? '+' : ''}${numero} %`;
}

// Pastilla de color para una variación: verde si subió, roja si bajó, gris si no cambió
// o si no se puede calcular (cuando antes estaba en cero)
function Variacion({ valor }) {
  if (valor === null || valor === undefined) return <span className="cero">—</span>;
  const color = valor > 0 ? 'badge-green' : valor < 0 ? 'badge-red' : 'badge-gray';
  return <span className={`badge ${color} badge-chica`}>{textoVariacion(valor)}</span>;
}

export default function ReporteComparacionPeriodos() {
  const navigate = useNavigate();
  // Lo que está elegido en los filtros. Al entrar se compara el trimestre actual
  const [tipo, setTipo] = useState('trimestre');
  const [numero, setNumero] = useState(TRIMESTRE_ACTUAL);
  const [anio, setAnio] = useState(ANIO_ACTUAL);

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
    api
      .get('/reportes/comparacion-periodos/', { params: { tipo, numero, anio } })
      .then(({ data }) => { if (vigente) setDatos(data); })
      .catch((err) => {
        if (vigente) setError(err.response?.data?.detail || 'No se pudo cargar el reporte.');
      })
      .finally(() => { if (vigente) setCargando(false); });
    return () => { vigente = false; };
  }, [tipo, numero, anio]);

  // Al pasar de trimestre a semestre (o al revés) se empieza por el primero, porque el
  // número elegido puede no existir en el otro tipo (no hay "semestre 3")
  function cambiarTipo(valor) {
    setTipo(valor);
    setNumero(1);
  }

  const sinDatos = datos && datos.servicios.length === 0;
  const plural = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;

  // Para dibujar las barras: la más larga ocupa todo el ancho y las demás se achican en proporción
  const maximo = datos ? Math.max(...datos.servicios.flatMap((s) => [s.actual.ingresos, s.anterior.ingresos]), 1) : 1;
  const ancho = (valor) => `${(valor / maximo) * 100}%`;

  // ---- Frases de la interpretación (se arman solas con los números del reporte) ----
  let interpretacion = [];
  if (datos && !sinDatos) {
    const { actual, anterior } = datos.periodo;
    const totales = datos.totales;
    const masIngresos = datos.servicios[0]; // ya vienen ordenados del que más ingresos dio al que menos
    const peso = totales.actual.ingresos > 0 ? Math.round((masIngresos.actual.ingresos / totales.actual.ingresos) * 100) : 0;
    // El que más creció y el que más cayó, según la diferencia en pesos
    const porDiferencia = [...datos.servicios].sort((a, b) => b.diferencia_ingresos - a.diferencia_ingresos);
    const mejor = porDiferencia[0];
    const peor = porDiferencia[porDiferencia.length - 1];
    const sinContratar = datos.servicios.filter((s) => s.actual.contrataciones === 0);
    const nuevos = datos.servicios.filter((s) => s.anterior.contrataciones === 0);

    interpretacion = [
      totales.variacion_ingresos === null
        ? `En el ${actual.etiqueta} se contrataron ${formatearPesos(totales.actual.ingresos)}; en el ${anterior.etiqueta} no hubo ingresos, así que no se puede calcular la variación.`
        : `En el ${actual.etiqueta} se contrataron ${formatearPesos(totales.actual.ingresos)}, ${totales.diferencia_ingresos >= 0 ? 'una suba' : 'una baja'} del ${Math.abs(totales.variacion_ingresos).toLocaleString('es-AR', { maximumFractionDigits: 1 })} % contra el ${anterior.etiqueta} (${formatearPesos(totales.anterior.ingresos)}).`,
      totales.actual.ingresos > 0
        ? `El servicio que más ingresos dio fue ${masIngresos.nombre_servicio}: ${formatearPesos(masIngresos.actual.ingresos)} (${peso} % del total) en ${plural(masIngresos.actual.contrataciones, 'contratación', 'contrataciones')}.`
        : null,
      mejor.diferencia_ingresos > 0
        ? `El que más creció fue ${mejor.nombre_servicio}: ${formatearPesos(mejor.diferencia_ingresos)} más que el año anterior.`
        : 'Ningún servicio creció respecto del año anterior.',
      peor.diferencia_ingresos < 0
        ? `El que más cayó fue ${peor.nombre_servicio}: ${formatearPesos(Math.abs(peor.diferencia_ingresos))} menos que el año anterior.`
        : 'Ningún servicio cayó respecto del año anterior.',
      sinContratar.length > 0
        ? `No se contrataron en este período, pero sí en el anterior (revisar si hacen falta): ${sinContratar.map((s) => s.nombre_servicio).join(', ')}.`
        : null,
      nuevos.length > 0
        ? `Se contrataron por primera vez frente al período anterior: ${nuevos.map((s) => s.nombre_servicio).join(', ')}.`
        : null,
    ].filter(Boolean); // saca las frases que quedaron vacías
  }

  return (
    <div>
      <div className="page-header page-header-con-ruta">
        <div>
          {/* Flecha para volver a la pantalla principal de Reportes, al lado del título */}
          <div className="titulo-con-volver">
            <button type="button" className="btn-volver" onClick={() => navigate('/reportes')} title="Volver a Reportes" aria-label="Volver a Reportes">
              <IconVolver />
            </button>
            <h1>Comparación de períodos</h1>
          </div>
          <div className="ruta"><Link to="/reportes">Reportes</Link> / <strong>Comparación de períodos</strong></div>
        </div>
      </div>

      {/* Para qué sirve y qué es lo que se cuenta */}
      <p className="reporte-descripcion">
        Compara un <strong>trimestre o semestre</strong> contra el mismo del año anterior, servicio por servicio,
        para decidir en cuáles conviene concentrar los recursos. Los ingresos son lo contratado (el precio del
        servicio al reservar); cada reserva cuenta en el período de su evento y las anuladas no entran.
      </p>

      {/* ---- Filtros ---- */}
      <div className="card filtros reporte-filtros">
        <div className="form-field">
          <label htmlFor="tipo">Tipo de período</label>
          <select id="tipo" value={tipo} onChange={(e) => cambiarTipo(e.target.value)}>
            <option value="trimestre">Trimestre</option>
            <option value="semestre">Semestre</option>
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="numero">Período</label>
          <select id="numero" value={numero} onChange={(e) => setNumero(Number(e.target.value))}>
            {Array.from({ length: CANTIDAD_POR_TIPO[tipo] }, (_, i) => i + 1).map((n) => (
              <option key={n} value={n}>{n}º {tipo} ({MESES_DEL_PERIODO[tipo][n - 1]})</option>
            ))}
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="anio">Año</label>
          <select id="anio" value={anio} onChange={(e) => setAnio(Number(e.target.value))}>
            {ANIOS.map((a) => <option key={a} value={a}>{a}</option>)}
          </select>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {cargando && !datos && <div className="card reporte-vacio">Cargando...</div>}

      {/* ---- Cuando no hay nada para mostrar en ninguno de los dos períodos ---- */}
      {!error && sinDatos && (
        <div className="card reporte-vacio">
          <strong>No hay servicios contratados para mostrar.</strong>
          <span>Ni en el {datos.periodo.actual.etiqueta} ni en el {datos.periodo.anterior.etiqueta} hay reservas. Probá con otro período.</span>
        </div>
      )}

      {!error && datos && !sinDatos && (
        <>
          {/* ---- Gráfico: por cada servicio, una barra de este período y otra del año anterior ---- */}
          <div className="card reporte-bloque">
            <h2 className="reporte-subtitulo">Ingresos contratados por servicio</h2>
            <div className="comparacion-leyenda">
              <span><i className="comparacion-muestra actual" />{datos.periodo.actual.etiqueta}</span>
              <span><i className="comparacion-muestra anterior" />{datos.periodo.anterior.etiqueta}</span>
            </div>
            <div className="comparacion-lista">
              {datos.servicios.map((s) => (
                <div key={s.id_servicio} className="comparacion-fila">
                  <div className="comparacion-nombre">{s.nombre_servicio}</div>
                  <div className="comparacion-barras">
                    <div className="comparacion-barra-linea">
                      <div className="comparacion-pista"><div className="comparacion-barra actual" style={{ width: ancho(s.actual.ingresos) }} /></div>
                      <span>{formatearPesos(s.actual.ingresos)}</span>
                    </div>
                    <div className="comparacion-barra-linea">
                      <div className="comparacion-pista"><div className="comparacion-barra anterior" style={{ width: ancho(s.anterior.ingresos) }} /></div>
                      <span>{formatearPesos(s.anterior.ingresos)}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
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
            <h2 className="reporte-subtitulo">Detalle por servicio</h2>
            <p className="form-hint">La variación compara este período con el del año anterior. Si antes no hubo ingresos no se puede calcular (—).</p>
            <div className="reporte-tabla-scroll">
              <table className="data-table reporte-tabla">
                <thead>
                  <tr>
                    <th>Servicio</th>
                    <th className="numero">Ingresos {datos.periodo.actual.etiqueta}</th>
                    <th className="numero">Ingresos {datos.periodo.anterior.etiqueta}</th>
                    <th className="numero">Diferencia</th>
                    <th className="numero">Variación</th>
                    <th className="numero">Contrataciones {datos.periodo.actual.etiqueta}</th>
                    <th className="numero">Contrataciones {datos.periodo.anterior.etiqueta}</th>
                    <th className="numero">Variación</th>
                  </tr>
                </thead>
                <tbody>
                  {datos.servicios.map((s) => (
                    <tr key={s.id_servicio}>
                      <td>{s.nombre_servicio}</td>
                      <td className={`numero${s.actual.ingresos === 0 ? ' cero' : ''}`}>{formatearPesos(s.actual.ingresos)}</td>
                      <td className={`numero${s.anterior.ingresos === 0 ? ' cero' : ''}`}>{formatearPesos(s.anterior.ingresos)}</td>
                      <td className="numero">{s.diferencia_ingresos > 0 ? '+' : ''}{formatearPesos(s.diferencia_ingresos)}</td>
                      <td className="numero"><Variacion valor={s.variacion_ingresos} /></td>
                      <td className={`numero${s.actual.contrataciones === 0 ? ' cero' : ''}`}>{s.actual.contrataciones}</td>
                      <td className={`numero${s.anterior.contrataciones === 0 ? ' cero' : ''}`}>{s.anterior.contrataciones}</td>
                      <td className="numero"><Variacion valor={s.variacion_contrataciones} /></td>
                    </tr>
                  ))}
                </tbody>
                {/* Los totales: tienen que coincidir con la suma de las filas */}
                <tfoot>
                  <tr>
                    <td>Total</td>
                    <td className="numero">{formatearPesos(datos.totales.actual.ingresos)}</td>
                    <td className="numero">{formatearPesos(datos.totales.anterior.ingresos)}</td>
                    <td className="numero">{datos.totales.diferencia_ingresos > 0 ? '+' : ''}{formatearPesos(datos.totales.diferencia_ingresos)}</td>
                    <td className="numero"><Variacion valor={datos.totales.variacion_ingresos} /></td>
                    <td className="numero">{datos.totales.actual.contrataciones}</td>
                    <td className="numero">{datos.totales.anterior.contrataciones}</td>
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
