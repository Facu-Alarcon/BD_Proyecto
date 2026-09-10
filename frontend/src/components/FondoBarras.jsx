// Barras verticales pseudo-aleatorias (pero estables) para el fondo
// oscuro de pantallas tipo login/modal. Se reutiliza tal cual entre
// el login y los modales de crear/editar.
const BAR_HEIGHTS = Array.from({ length: 46 }, (_, i) => {
  const wave = Math.sin(i * 0.7) * 0.5 + Math.sin(i * 1.9) * 0.3;
  return 18 + Math.abs(wave) * 55;
});

export default function FondoBarras({ className }) {
  return (
    <div className={className} aria-hidden="true">
      {BAR_HEIGHTS.map((h, i) => (
        <span key={i} style={{ height: `${h}%` }} />
      ))}
    </div>
  );
}
