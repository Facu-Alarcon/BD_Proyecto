// Botones para moverse entre las páginas de una tabla. Se pone dos veces en cada tabla:
// arriba (posicion="arriba") y abajo, así no hace falta scrollear hasta el final para
// cambiar de página. Recibe lo que devuelve usePaginacion.
// Si todo entra en una sola página no se muestra nada.
export default function Paginacion({ paginacion, posicion = 'abajo' }) {
  const { pagina, totalPaginas, total, desde, hasta, irA } = paginacion;

  if (totalPaginas <= 1) return null;

  return (
    <div className={`paginacion paginacion-${posicion}`}>
      <span className="paginacion-info">
        Mostrando {desde}–{hasta} de {total}
      </span>

      <div className="paginacion-botones">
        <button type="button" className="paginacion-btn" onClick={() => irA(pagina - 1)} disabled={pagina === 1} aria-label="Página anterior">
          ‹
        </button>

        {numerosAMostrar(pagina, totalPaginas).map((n, i) =>
          n === '…' ? (
            <span key={`puntos-${i}`} className="paginacion-puntos">…</span>
          ) : (
            <button
              key={n}
              type="button"
              className={`paginacion-btn${n === pagina ? ' activa' : ''}`}
              onClick={() => irA(n)}
              aria-current={n === pagina ? 'page' : undefined}
            >
              {n}
            </button>
          )
        )}

        <button type="button" className="paginacion-btn" onClick={() => irA(pagina + 1)} disabled={pagina === totalPaginas} aria-label="Página siguiente">
          ›
        </button>
      </div>
    </div>
  );
}

// Decide qué números de página se ven. Con pocas páginas van todas (1 2 3 4 5);
// con muchas se muestran la primera, la última y las de alrededor de la actual,
// y el resto se reemplaza por "…" (ej: 1 … 6 7 8 … 20)
function numerosAMostrar(actual, total) {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const numeros = [1];
  const desde = Math.max(2, actual - 1);
  const hasta = Math.min(total - 1, actual + 1);
  if (desde > 2) numeros.push('…');
  for (let n = desde; n <= hasta; n++) numeros.push(n);
  if (hasta < total - 1) numeros.push('…');
  numeros.push(total);
  return numeros;
}
