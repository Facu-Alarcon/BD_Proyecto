// Celda de uso de las listas de catálogos (Tipos y Estados de equipo, Horarios, Sueldos,
// Puestos, Perfiles): cuántos registros dependen de este, por ejemplo "6 equipos".
// Sirve también para saber de antemano que no se puede eliminar: el backend no deja
// borrar algo que está en uso.
//   cantidad -> el número que manda el backend (cantidad_equipos, cantidad_empleados...)
//   singular / plural -> cómo se escribe lo que se cuenta ("equipo" / "equipos")
export default function UsoCelda({ cantidad, singular, plural }) {
  if (cantidad === undefined || cantidad === null) return <span className="form-hint">—</span>;
  if (cantidad === 0) {
    return <span className="uso-ninguno" title="No está en uso: se puede eliminar">Sin uso</span>;
  }
  return (
    <span className="uso-chip" title="Está en uso: no se puede eliminar">
      <strong>{cantidad}</strong> {cantidad === 1 ? singular : plural}
    </span>
  );
}
