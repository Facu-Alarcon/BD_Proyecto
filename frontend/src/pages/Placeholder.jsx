// Pantalla de relleno para módulos que todavía no estaban hechos. Hoy no la usa ninguna
// ruta, pero se deja por si se agrega un módulo nuevo y se quiere mostrar "Próximamente".
export default function Placeholder({ titulo }) {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1>{titulo}</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 32, textAlign: 'center', color: 'var(--text-muted)' }}>
        Este módulo todavía no está implementado en el backend. Próximamente.
      </div>
    </div>
  );
}
