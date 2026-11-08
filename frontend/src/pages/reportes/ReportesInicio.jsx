import { Link } from 'react-router-dom';
import { usePermiso } from '../../hooks/usePermiso';
import './Reportes.css';

// Pantalla de entrada a Reportes: una tarjeta por cada reporte, con para qué sirve.
// Para sumar un reporte nuevo se agrega acá a la lista y se le crea su pantalla
// (y su ruta en App.jsx).
// Si un reporte tiene "permiso", además de Ver Reportes hace falta ese permiso para verlo
// (es el caso de los reportes sensibles, como el de ingresos).
const REPORTES = [
  {
    to: '/reportes/uso-equipos',
    nombre: 'Uso de equipos por mes',
    descripcion: 'Cuántas unidades de cada equipo se usan en los eventos de cada mes. Sirve para decidir qué equipos comprar, cuáles sobran y cuándo conviene hacer mantenimiento.',
  },
  {
    to: '/reportes/demanda-servicios',
    nombre: 'Demanda de servicio por mes',
    descripcion: 'Cuántas veces se contrató cada servicio en cada mes y cuánto dejó. Sirve para saber qué servicios promocionar, en qué meses reforzar personal y equipos, y cuáles casi no se piden.',
  },
  {
    to: '/reportes/evolucion-ingresos',
    nombre: 'Evolución de ingresos y eventos',
    descripcion: 'Cuánto se contrata y cuántos eventos hay en cada mes, con la variación contra el mes anterior. Sirve para analizar el crecimiento del negocio.',
    permiso: 'ver_reportes_financieros',
  },
  {
    to: '/reportes/comparacion-periodos',
    nombre: 'Comparación de períodos',
    descripcion: 'Un trimestre o semestre contra el mismo del año anterior, servicio por servicio. Sirve para decidir en cuáles servicios concentrar los recursos.',
  },
  {
    to: '/reportes/carga-empleados',
    nombre: 'Carga de trabajo de los empleados',
    descripcion: 'A cuántos eventos fue asignado cada empleado en cada mes. Sirve para repartir mejor el trabajo, ver quién está sobrecargado y en qué meses hace falta más personal.',
  },
  {
    to: '/reportes/contratado-cobrado',
    nombre: 'Contratado vs. cobrado',
    descripcion: 'Lo que se contrató en las reservas al lado de lo que se cobró en los pagos, mes a mes, y cuánto falta cobrar. Sirve para controlar la cobranza y saber qué saldos reclamar.',
    permiso: 'ver_reportes_financieros',
  },
];

export default function ReportesInicio() {
  const { tiene } = usePermiso('reportes');
  // Solo se muestran las tarjetas de los reportes que el perfil puede abrir
  const visibles = REPORTES.filter((r) => !r.permiso || tiene(r.permiso));

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Reportes</h1>
        </div>
      </div>

      <div className="reportes-lista">
        {visibles.map((r) => (
          // Toda la tarjeta es un link al reporte
          <Link key={r.to} to={r.to} className="card reporte-tarjeta">
            <h2>{r.nombre}</h2>
            {/* Marca para que se note que es un reporte restringido */}
            {r.permiso && <span className="badge badge-amber badge-chica">Solo administración</span>}
            <p>{r.descripcion}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
