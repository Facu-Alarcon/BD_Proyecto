// Fila de números de resumen de los reportes: total, promedio mensual, máximo, mínimo y desvío.
// Los calcula el backend con numpy (ver agregados() en infinito_sonido/graficos.py); acá solo
// se muestran.
//
// Recibe:
//   agregados -> lo que manda el backend: { total, promedio, maximo: {valor, etiqueta}, minimo: {...}, desvio }
//   formato   -> (opcional) cómo se escribe cada número, ej: formatearPesos. Si no se manda, va el
//                número con hasta un decimal.
//   unidad    -> (opcional) qué se cuenta, para el título (ej: "eventos")
const numero = (v) => v.toLocaleString('es-AR', { maximumFractionDigits: 1 });

export default function ResumenAgregados({ agregados, formato = numero, unidad = '' }) {
  if (!agregados) return null;
  const items = [
    { titulo: 'Total', valor: formato(agregados.total) },
    { titulo: 'Promedio mensual', valor: formato(agregados.promedio) },
    { titulo: 'Mes con más', valor: formato(agregados.maximo.valor), detalle: agregados.maximo.etiqueta },
    { titulo: 'Mes con menos', valor: formato(agregados.minimo.valor), detalle: agregados.minimo.etiqueta },
    {
      titulo: 'Desvío estándar',
      valor: formato(agregados.desvio),
      detalle: 'cuánto varían los meses',
    },
  ];
  return (
    <div className="agregados" aria-label={`Resumen${unidad ? ` de ${unidad}` : ''}`}>
      {items.map((it) => (
        <div key={it.titulo} className="agregado">
          <span className="agregado-titulo">{it.titulo}</span>
          <strong className="agregado-valor">{it.valor}</strong>
          {it.detalle && <span className="agregado-detalle">{it.detalle}</span>}
        </div>
      ))}
    </div>
  );
}
