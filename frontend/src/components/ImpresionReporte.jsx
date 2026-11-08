import { useEffect, useState } from 'react';
import { flushSync } from 'react-dom';
import { useAuth } from '../context/AuthContext';
import logo from '../assets/img/logonuevo.png';
import { formatearFechaHora } from '../utils/formato';

// ENCABEZADO Y PIE DE LOS REPORTES IMPRESOS (Parcial 2, módulo M2)
//
// Lo que pide el parcial para el PDF de cada reporte: arriba el encabezado institucional
// (logo, nombre de la empresa y título del reporte) y abajo un pie con los filtros que se
// usaron, quién lo generó y la fecha y hora. En la pantalla no se ven (clase "solo-imprimir",
// ver Reportes.css): aparecen solo al imprimir o al guardar como PDF.

// Encabezado de la hoja: logo a la izquierda, a la derecha el nombre del reporte
export function EncabezadoImpresion({ titulo }) {
  return (
    <header className="solo-imprimir impresion-encabezado">
      <img src={logo} alt="Infinito Sonido e Iluminación" className="impresion-logo" />
      <div className="impresion-titulo">
        <strong>Infinito Sonido e Iluminación</strong>
        <span>{titulo}</span>
      </div>
    </header>
  );
}

// Pie de la hoja. Recibe los filtros como lista de pares, por ejemplo
// [['Período', 'enero de 2026 a junio de 2026'], ['Servicio', 'Todos']].
// El usuario sale de la sesión y la fecha y hora es la del momento en que se imprime.
export function PieImpresion({ filtros }) {
  const { usuario } = useAuth();
  const [momento, setMomento] = useState(() => new Date());

  // Justo antes de imprimir se actualiza la hora. Va con flushSync para que el cambio se
  // dibuje en ese mismo momento y el navegador no imprima la hora vieja.
  useEffect(() => {
    const actualizar = () => flushSync(() => setMomento(new Date()));
    window.addEventListener('beforeprint', actualizar);
    return () => window.removeEventListener('beforeprint', actualizar);
  }, []);

  const nombre = usuario
    ? `${usuario.nombre || ''} ${usuario.apellido || ''}`.trim() || usuario.usuario
    : '—';

  return (
    <footer className="solo-imprimir impresion-pie">
      <p>
        <strong>Filtros aplicados: </strong>
        {filtros.map(([nombreFiltro, valor]) => `${nombreFiltro}: ${valor}`).join(' · ')}
      </p>
      <p>
        <strong>Generado por: </strong>
        {nombre}{usuario?.usuario ? ` (${usuario.usuario})` : ''}
        {usuario?.perfil_nombre ? ` · Perfil: ${usuario.perfil_nombre}` : ''}
        <strong> · Fecha y hora: </strong>
        {formatearFechaHora(momento)}
      </p>
      <p>Infinito Sonido e Iluminación · Salta, Argentina</p>
    </footer>
  );
}
