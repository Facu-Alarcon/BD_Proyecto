import { useState } from 'react';

// Barra de búsqueda y filtros que va arriba de las tablas.
// Recibe la misma 'config' que useFiltros y lo que devuelve ese hook ('filtros').
// Arriba queda siempre a la vista el buscador de texto, con los botones "Filtros" y "Limpiar".
// El resto de los filtros (listas y rangos) van en un panel que se abre con el botón "Filtros",
// así la barra ocupa poco lugar cuando no se está filtrando.
export default function BarraFiltros({ config, filtros, total, cargando, nombreItems }) {
  const { valores, cambiar, limpiar, filtradas, hayFiltros, rangoInvalido } = filtros;
  const [panelAbierto, setPanelAbierto] = useState(false);

  // Separamos el buscador del resto: el buscador va arriba y lo demás adentro del panel
  const buscadores = config.filter((f) => f.tipo === 'texto');
  const delPanel = config.filter((f) => f.tipo !== 'texto');

  // Si la pantalla no tiene buscador (ej: Horarios o Sueldos), no tiene sentido esconder
  // lo único que hay, así que el panel se muestra siempre y no aparece el botón
  const panelVisible = buscadores.length === 0 || panelAbierto;

  // Cuántos filtros del panel están en uso, para mostrarlo en el botón (ej: "Filtros (2)")
  // y que se note que hay algo filtrado aunque el panel esté cerrado
  const activosEnPanel = delPanel.filter((f) =>
    f.tipo === 'rango' ? valores[`${f.id}Desde`] !== '' || valores[`${f.id}Hasta`] !== '' : valores[f.id] !== ''
  ).length;

  return (
    <>
      <div className="card filtros">
        {/* Fila de arriba: buscador + botones */}
        <div className="filtros-fila">
          {buscadores.map((f) => (
            <div key={f.id} className="form-field filtros-buscar">
              <label htmlFor={`filtro-${f.id}`}>{f.label || 'Buscar'}</label>
              <input
                id={`filtro-${f.id}`}
                type="search"
                placeholder={f.placeholder}
                value={valores[f.id]}
                onChange={(e) => cambiar(f.id, e.target.value)}
              />
            </div>
          ))}

          {/* El botón solo aparece si hay filtros para esconder y hay un buscador arriba */}
          {delPanel.length > 0 && buscadores.length > 0 && (
            <button
              type="button"
              className={`btn btn-secondary filtros-boton${panelAbierto ? ' abierto' : ''}`}
              onClick={() => setPanelAbierto((a) => !a)}
              aria-expanded={panelAbierto}
            >
              Filtros{activosEnPanel > 0 ? ` (${activosEnPanel})` : ''} <span className="filtros-flecha">▾</span>
            </button>
          )}

          <button type="button" className="btn btn-secondary" onClick={limpiar} disabled={!hayFiltros}>
            Limpiar
          </button>
        </div>

        {/* Panel con el resto de los filtros */}
        {delPanel.length > 0 && panelVisible && (
          <div className={`filtros-panel${buscadores.length > 0 ? ' con-borde' : ''}`}>
            {delPanel.map((f) => (
              <CampoFiltro key={f.id} filtro={f} valores={valores} cambiar={cambiar} />
            ))}
          </div>
        )}
      </div>

      {rangoInvalido && (
        <div className="alert alert-error">El valor "desde" no puede ser mayor que el valor "hasta".</div>
      )}

      {/* Contador para saber cuántas filas quedan después de filtrar */}
      {!cargando && hayFiltros && !rangoInvalido && (
        <p className="filtros-resultado">
          Mostrando {filtradas.length} de {total} {nombreItems}
        </p>
      )}
    </>
  );
}

// Dibuja un filtro del panel según su tipo: lista desplegable o rango desde/hasta
function CampoFiltro({ filtro: f, valores, cambiar }) {
  // Lista desplegable con la opción "Todos" para no filtrar
  if (f.tipo === 'select') {
    return (
      <div className="form-field">
        <label htmlFor={`filtro-${f.id}`}>{f.label}</label>
        <select id={`filtro-${f.id}`} value={valores[f.id]} onChange={(e) => cambiar(f.id, e.target.value)}>
          <option value="">{f.todos || 'Todos'}</option>
          {f.opciones.map((o) => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
      </div>
    );
  }

  // Rango: dos campos "desde" y "hasta" (fechas o números)
  if (f.tipo === 'rango') {
    const desde = `${f.id}Desde`;
    const hasta = `${f.id}Hasta`;
    const esNumero = f.input === 'number';
    return (
      <div className="filtros-rango">
        <div className="form-field">
          <label htmlFor={`filtro-${desde}`}>{f.label} desde</label>
          <input
            id={`filtro-${desde}`}
            type={f.input}
            min={esNumero ? 0 : undefined}
            // En las fechas el calendario no deja elegir un "desde" posterior al "hasta"
            max={!esNumero ? valores[hasta] || undefined : undefined}
            placeholder={esNumero ? 'Mín.' : undefined}
            value={valores[desde]}
            onChange={(e) => cambiar(desde, e.target.value)}
          />
        </div>
        <div className="form-field">
          <label htmlFor={`filtro-${hasta}`}>{f.label} hasta</label>
          <input
            id={`filtro-${hasta}`}
            type={f.input}
            min={esNumero ? 0 : valores[desde] || undefined}
            placeholder={esNumero ? 'Máx.' : undefined}
            value={valores[hasta]}
            onChange={(e) => cambiar(hasta, e.target.value)}
          />
        </div>
      </div>
    );
  }
  return null;
}

// Fila que va en la tabla cuando hay datos cargados pero ninguno pasa los filtros
export function FilaSinResultados({ filtros, total, cargando, columnas, nombreItems }) {
  if (cargando || total === 0 || filtros.filtradas.length > 0 || filtros.rangoInvalido) return null;
  return (
    <tr>
      <td colSpan={columnas} style={{ textAlign: 'center' }}>
        No hay {nombreItems} que coincidan con la búsqueda.
      </td>
    </tr>
  );
}
