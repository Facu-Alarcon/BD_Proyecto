import { useEffect } from 'react';

// Botón "Imprimir / Guardar PDF" de las pantallas de Reportes (mismo comportamiento que el del
// comprobante de reserva, ver ReservaComprobante.jsx). Abre la ventana de impresión del
// navegador; ahí se elige la impresora o "Guardar como PDF". Al imprimir se esconden el menú,
// la barra de arriba y este botón (clase "no-imprimir"), y los estilos de impresión de los
// reportes están en Reportes.css.
//
// Recibe:
//   nombreArchivo -> el título de la pestaña, que es el nombre que propone el navegador al
//                    guardar el PDF (ej: "Reporte-Uso-de-equipos-2026-01-a-2026-12")
//   deshabilitado -> true mientras no hay nada para imprimir (cargando, con error o sin datos)
export default function BotonImprimirReporte({ nombreArchivo, deshabilitado = false }) {
  // Mientras se está en la pantalla, el título de la pestaña es el nombre del archivo.
  // Al salir (o al cambiar los filtros) se vuelve a dejar el de siempre.
  useEffect(() => {
    if (!nombreArchivo) return undefined;
    const tituloAnterior = document.title;
    document.title = nombreArchivo;
    return () => {
      document.title = tituloAnterior;
    };
  }, [nombreArchivo]);

  return (
    <button
      type="button"
      className="btn btn-primary no-imprimir"
      onClick={() => window.print()}
      disabled={deshabilitado}
    >
      Imprimir / Guardar PDF
    </button>
  );
}
