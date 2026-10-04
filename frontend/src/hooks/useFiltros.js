import { useMemo, useState } from 'react';

// Lógica de los filtros de las tablas. Cada pantalla arma una lista de filtros
// ('config') y este hook se encarga de guardar lo que se eligió y de devolver
// las filas que pasan todos los filtros juntos.
//
// Tipos de filtro que entiende:
//   { tipo: 'texto', id, campos: (fila) => [textos donde buscar] }
//   { tipo: 'select', id, valor: (fila) => valor (o lista de valores) a comparar, opciones: [{ value, label }] }
//   { tipo: 'rango', id, input: 'date' | 'number', valor: (fila) => fecha o número }
// Un filtro de rango guarda dos valores: '<id>Desde' y '<id>Hasta'.

// Pasa el texto a minúsculas y le saca los acentos, así "perez" encuentra a "Pérez"
export function normalizar(texto) {
  return String(texto ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

// Arma las opciones de un desplegable con los valores distintos que aparecen en las filas,
// ordenadas alfabéticamente (ej: los tipos de equipo que hay cargados)
export function opcionesDe(filas, obtenerValor) {
  const distintos = new Set();
  for (const fila of filas) {
    const v = obtenerValor(fila);
    for (const item of Array.isArray(v) ? v : [v]) {
      if (item != null && item !== '') distintos.add(String(item));
    }
  }
  return [...distintos].sort((a, b) => a.localeCompare(b, 'es')).map((v) => ({ value: v, label: v }));
}

// Arma el objeto con todos los filtros vacíos (también se usa para el botón "Limpiar")
function valoresVacios(config) {
  const vacios = {};
  for (const f of config) {
    if (f.tipo === 'rango') {
      vacios[`${f.id}Desde`] = '';
      vacios[`${f.id}Hasta`] = '';
    } else {
      vacios[f.id] = '';
    }
  }
  return vacios;
}

// Los números se comparan como números y las fechas ('AAAA-MM-DD') como texto, que da el mismo orden
function comparable(valor, input) {
  return input === 'number' ? Number(valor) : String(valor);
}

export function useFiltros(filas, config) {
  const [valores, setValores] = useState(() => valoresVacios(config));

  // Cambia un solo filtro y deja los demás como estaban
  function cambiar(campo, valor) {
    setValores((v) => ({ ...v, [campo]: valor }));
  }

  function limpiar() {
    setValores(valoresVacios(config));
  }

  const hayFiltros = Object.values(valores).some((v) => v !== '');

  // Si en algún rango el "desde" quedó más alto que el "hasta" no tiene sentido filtrar
  const rangoInvalido = config.some((f) => {
    if (f.tipo !== 'rango') return false;
    const desde = valores[`${f.id}Desde`];
    const hasta = valores[`${f.id}Hasta`];
    return desde !== '' && hasta !== '' && comparable(desde, f.input) > comparable(hasta, f.input);
  });

  // Acá se aplican todos los filtros a la vez: una fila queda si pasa cada uno de ellos
  const filtradas = useMemo(() => {
    if (rangoInvalido) return [];
    return filas.filter((fila) =>
      config.every((f) => {
        if (f.tipo === 'texto') {
          const buscado = normalizar(valores[f.id].trim());
          return !buscado || f.campos(fila).some((t) => normalizar(t).includes(buscado));
        }
        if (f.tipo === 'select') {
          if (valores[f.id] === '') return true;
          // Si la fila tiene varios valores (ej: un pago con dos métodos) alcanza con que uno coincida
          const v = f.valor(fila);
          return Array.isArray(v) ? v.map(String).includes(valores[f.id]) : String(v) === valores[f.id];
        }
        if (f.tipo === 'rango') {
          const desde = valores[`${f.id}Desde`];
          const hasta = valores[`${f.id}Hasta`];
          const valor = f.valor(fila);
          if (desde !== '' && (valor == null || comparable(valor, f.input) < comparable(desde, f.input))) return false;
          if (hasta !== '' && (valor == null || comparable(valor, f.input) > comparable(hasta, f.input))) return false;
          return true;
        }
        return true;
      })
    );
    // config se arma en cada render de la pantalla, pero lo que importa para filtrar
    // son las filas y lo que eligió el usuario
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filas, valores, rangoInvalido]);

  return { valores, cambiar, limpiar, filtradas, hayFiltros, rangoInvalido };
}
