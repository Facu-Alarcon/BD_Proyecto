import { useEffect, useState } from 'react';

// Tema claro u oscuro del sistema.
// El tema se marca en la página con data-theme="light" o "dark" (los colores de cada uno
// están en index.css). La elección se guarda en este navegador, así la próxima vez
// arranca igual. Si nunca se eligió, se usa el tema de la computadora (lo decide el
// script de index.html al abrir la página, antes de dibujar nada).
const CLAVE = 'infinito_tema';

function temaActual() {
  return document.documentElement.dataset.theme === 'dark' ? 'oscuro' : 'claro';
}

export function useTema() {
  const [tema, setTema] = useState(temaActual);

  // Si el usuario nunca eligió y cambia el tema de la computadora, el sistema lo sigue
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const alCambiar = (e) => {
      let elegido = null;
      try { elegido = localStorage.getItem(CLAVE); } catch { /* sin acceso: se sigue a la compu */ }
      if (elegido) return;
      document.documentElement.dataset.theme = e.matches ? 'dark' : 'light';
      setTema(e.matches ? 'oscuro' : 'claro');
    };
    mq.addEventListener('change', alCambiar);
    return () => mq.removeEventListener('change', alCambiar);
  }, []);

  // Pasa de claro a oscuro o al revés, y lo recuerda
  function cambiarTema() {
    const nuevo = tema === 'oscuro' ? 'claro' : 'oscuro';
    document.documentElement.dataset.theme = nuevo === 'oscuro' ? 'dark' : 'light';
    try { localStorage.setItem(CLAVE, nuevo); } catch { /* sin acceso: vale solo por esta vez */ }
    setTema(nuevo);
  }

  return { tema, cambiarTema };
}
