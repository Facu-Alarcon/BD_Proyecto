import { Link } from 'react-router-dom';
import './Reportes.css';

// Pantalla de entrada a Reportes: una tarjeta por cada reporte, con para qué sirve.
// Para sumar un reporte nuevo se agrega acá a la lista y se le crea su pantalla
// (y su ruta en App.jsx).
const REPORTES = [
  {
    to: '/reportes/uso-equipos',
    nombre: 'Uso de equipos por mes',
    descripcion: 'Cuántas unidades de cada equipo se usan en los eventos de cada mes. Sirve para decidir qué equipos comprar, cuáles sobran y cuándo conviene hacer mantenimiento.',
  },
];

export default function ReportesInicio() {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Reportes</h1>
        </div>
      </div>

      <div className="reportes-lista">
        {REPORTES.map((r) => (
          // Toda la tarjeta es un link al reporte
          <Link key={r.to} to={r.to} className="card reporte-tarjeta">
            <h2>{r.nombre}</h2>
            <p>{r.descripcion}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
