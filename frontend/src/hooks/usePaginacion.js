import { useState } from 'react';

// Paginación de las tablas: de todas las filas (ya filtradas) devuelve solo las de la
// página actual, de a 'porPagina' filas (10 por defecto).
//
// 'reinicio' es cualquier valor que, cuando cambia, nos tiene que llevar de vuelta a la
// página 1. Se le pasan los valores de los filtros: si el usuario busca algo nuevo no
// tiene sentido quedarse en la página 4. Si en cambio se borra una fila, se queda en la
// misma página (solo se corrige si esa página dejó de existir).
export function usePaginacion(filas, reinicio, porPagina = 10) {
  const [pagina, setPagina] = useState(1);
  const [reinicioAnterior, setReinicioAnterior] = useState(reinicio);

  // Si cambiaron los filtros volvemos a la primera página.
  // (Es la forma que recomienda React de "resetear" un estado cuando cambia un dato,
  // sin usar un useEffect)
  if (reinicio !== reinicioAnterior) {
    setReinicioAnterior(reinicio);
    setPagina(1);
  }

  const totalPaginas = Math.max(1, Math.ceil(filas.length / porPagina));

  // Si estábamos en una página que ya no existe (ej: se borró la última fila de la
  // última página) mostramos la última que sí existe
  const actual = Math.min(pagina, totalPaginas);

  const inicio = (actual - 1) * porPagina;
  const visibles = filas.slice(inicio, inicio + porPagina);

  return {
    pagina: actual,
    totalPaginas,
    visibles,
    total: filas.length,
    // Números que se muestran en "Mostrando 11–20 de 34"
    desde: filas.length === 0 ? 0 : inicio + 1,
    hasta: inicio + visibles.length,
    irA: (n) => setPagina(Math.min(Math.max(1, n), totalPaginas)),
  };
}
