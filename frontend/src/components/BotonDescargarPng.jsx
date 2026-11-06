// Botón "Descargar PNG" de los gráficos de los reportes.
// El gráfico ya llega del backend como imagen PNG (en texto base64), así que alcanza con un
// link con "download": el navegador la guarda como archivo con el nombre que se le pasa.
// No sale al imprimir (clase "no-imprimir").
//
// Recibe:
//   imagen        -> la imagen que manda el backend ('data:image/png;base64,...')
//   nombreArchivo -> el nombre del archivo, sin la extensión (ej: "Reporte-Uso-de-equipos-2026-01-a-2026-12")
export default function BotonDescargarPng({ imagen, nombreArchivo }) {
  return (
    <a
      className="btn btn-secondary btn-sm grafico-descargar no-imprimir"
      href={imagen}
      download={`${nombreArchivo || 'grafico'}.png`}
      title="Descargar el gráfico como imagen PNG"
    >
      Descargar PNG
    </a>
  );
}
