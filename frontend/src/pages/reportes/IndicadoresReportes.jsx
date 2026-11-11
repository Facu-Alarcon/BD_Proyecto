import { useEffect, useId, useRef, useState } from 'react';
import api from '../../api/client';
import { IconCobros, IconConfirmar, IconPagos, IconReservas } from '../../components/icons';
import { formatearPesos } from '../../utils/formato';

// Los 4 indicadores de arriba del tablero de Reportes: reservas del mes, ingresos del mes,
// eventos realizados y saldo pendiente. No son links: solo muestran cómo viene el negocio.
//
// Los números los calcula el backend en el momento (ver IndicadoresView en reportes.py), y
// esta pantalla los vuelve a pedir cada 30 segundos y cada vez que se vuelve a la pestaña.
// Así, si se carga una reserva o se registra un pago, los números se actualizan solos.
//
// Ingresos y saldo son plata del negocio: el backend solo los manda a los perfiles con
// "Ver Reportes Financieros". Si no vienen, esas tarjetas no se muestran.

// Cada cuánto se vuelven a pedir los números (en milisegundos)
const CADA_CUANTO = 30000;

// Las 4 tarjetas, en orden. Para cada una:
//   clave    -> qué parte de la respuesta del backend usa
//   titulo   -> el nombre que se ve
//   Icono    -> el dibujito del círculo
//   color    -> el color del círculo y de la lineíta
//   formato  -> cómo se escribe el número grande
//   ayuda    -> el texto que aparece al dejar el mouse encima (qué se está contando)
//   pie      -> el texto de abajo del número (la comparación con el mes anterior)
const INDICADORES = [
  {
    clave: 'reservas',
    titulo: 'Reservas del mes',
    Icono: IconReservas,
    color: 'var(--navy-accent)',
    formato: (v) => v.toLocaleString('es-AR'),
    ayuda: 'Reservas cargadas este mes (sin las anuladas). La comparación es contra los mismos días del mes anterior.',
  },
  {
    clave: 'ingresos',
    titulo: 'Ingresos del mes',
    Icono: IconPagos,
    color: 'var(--verde)',
    formato: formatearPesos,
    ayuda: 'Lo contratado en las reservas con evento este mes, contra el mes anterior completo.',
  },
  {
    clave: 'eventos',
    titulo: 'Eventos realizados',
    Icono: IconConfirmar,
    color: '#7c5cd6',
    formato: (v) => v.toLocaleString('es-AR'),
    ayuda: 'Eventos de este mes que ya se finalizaron. La comparación es contra los mismos días del mes anterior.',
  },
  {
    clave: 'saldo',
    titulo: 'Saldo pendiente',
    Icono: IconCobros,
    color: 'var(--red)',
    formato: formatearPesos,
    ayuda: 'Lo que falta cobrar hoy de todas las reservas no anuladas. La lineíta muestra lo que se debe de los eventos de este mes y los 5 que siguen.',
  },
];

// Hace que el número grande "corra" desde el valor anterior hasta el nuevo cuando cambia,
// así se nota que se actualizó. Si la compu pide menos movimiento, cambia de una.
function useNumeroAnimado(valor) {
  const [mostrado, setMostrado] = useState(valor);
  const anterior = useRef(valor);

  useEffect(() => {
    const desde = anterior.current;
    anterior.current = valor;
    const sinMovimiento = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (desde === valor || sinMovimiento) {
      setMostrado(valor);
      return undefined;
    }
    const duracion = 700;
    const inicio = performance.now();
    let cuadro;
    const paso = (ahora) => {
      const t = Math.min((ahora - inicio) / duracion, 1);
      const suave = 1 - (1 - t) ** 3; // arranca rápido y frena al final
      setMostrado(desde + (valor - desde) * suave);
      if (t < 1) cuadro = requestAnimationFrame(paso);
    };
    cuadro = requestAnimationFrame(paso);
    return () => cancelAnimationFrame(cuadro);
  }, [valor]);

  return mostrado;
}

// Lineíta con el relleno degradé de abajo (sparkline). "valores" son los de los últimos meses.
function Lineita({ valores, color }) {
  const idDegrade = useId();
  if (!valores || valores.length < 2) return null;
  const maximo = Math.max(...valores, 1);
  // Se dibuja en una caja de 100 x 40 que después se estira al tamaño de la tarjeta.
  // Se deja 4 de margen arriba y abajo para que la línea no quede cortada.
  const puntos = valores.map((v, i) => [(i / (valores.length - 1)) * 100, 36 - (v / maximo) * 32]);
  const linea = puntos.map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`).join(' ');
  return (
    <svg className="indicador-lineita" viewBox="0 0 100 40" preserveAspectRatio="none" aria-hidden="true">
      <defs>
        <linearGradient id={idDegrade} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.35" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={`${linea} L100,40 L0,40 Z`} fill={`url(#${idDegrade})`} />
      <path d={linea} fill="none" stroke={color} strokeWidth="2.2" vectorEffect="non-scaling-stroke" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

// Una tarjeta de indicador
function Indicador({ config, datos, orden }) {
  const { titulo, Icono, color, formato, ayuda } = config;
  const numero = useNumeroAnimado(datos.valor);
  // Mientras "corre", el número tiene decimales: se redondea para mostrarlo
  const texto = formato(Math.round(numero));

  // Texto de abajo: la variación contra el mes anterior, o en el saldo, en cuántas reservas está
  let pie;
  if (config.clave === 'saldo') {
    pie = <span className="indicador-pie-texto">en {datos.reservas} {datos.reservas === 1 ? 'reserva' : 'reservas'}</span>;
  } else if (datos.variacion == null) {
    pie = <span className="indicador-pie-texto">sin datos del mes anterior</span>;
  } else {
    const sube = datos.variacion >= 0;
    pie = (
      <>
        <span className={`indicador-variacion ${sube ? 'sube' : 'baja'}`}>
          {sube ? '↑' : '↓'} {sube ? '+' : ''}{datos.variacion.toLocaleString('es-AR')}%
        </span>
        <span className="indicador-pie-texto">vs. mes anterior</span>
      </>
    );
  }

  return (
    <div className="card indicador" style={{ '--color': color, '--orden': orden }} title={ayuda}>
      <div className="indicador-cabecera">
        <span className="indicador-icono"><Icono /></span>
        <span className="indicador-titulo">{titulo}</span>
      </div>
      <div className="indicador-valor">{texto}</div>
      <div className="indicador-pie">{pie}</div>
      <Lineita valores={datos.linea} color={color} />
    </div>
  );
}

export default function IndicadoresReportes() {
  const [datos, setDatos] = useState(null);

  useEffect(() => {
    let vigente = true;
    const pedir = () => {
      api
        .get('/reportes/indicadores/')
        .then(({ data }) => { if (vigente) setDatos(data); })
        .catch(() => {}); // si falla una vez, se queda con los últimos números y prueba de nuevo en un rato
    };
    pedir();
    const intervalo = setInterval(pedir, CADA_CUANTO);
    // Al volver a la pestaña (por ejemplo, después de cargar una reserva en otra) se piden de nuevo
    const alVolver = () => { if (document.visibilityState === 'visible') pedir(); };
    document.addEventListener('visibilitychange', alVolver);
    return () => {
      vigente = false;
      clearInterval(intervalo);
      document.removeEventListener('visibilitychange', alVolver);
    };
  }, []);

  // Mientras llegan los primeros números, cuatro tarjetas vacías del mismo tamaño
  if (!datos) {
    return (
      <div className="indicadores">
        {INDICADORES.map((c) => <div key={c.clave} className="card indicador indicador-cargando" />)}
      </div>
    );
  }

  // Solo las que vinieron (ingresos y saldo no vienen para los perfiles sin permiso financiero)
  const visibles = INDICADORES.filter((c) => datos[c.clave]);

  return (
    <div className={`indicadores indicadores-${visibles.length}`}>
      {visibles.map((c, i) => <Indicador key={c.clave} config={c} datos={datos[c.clave]} orden={i} />)}
    </div>
  );
}
