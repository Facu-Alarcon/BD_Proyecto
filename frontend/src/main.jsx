// Punto de entrada del frontend: Vite arranca por acá.
// Carga los estilos generales (index.css) y dibuja la aplicación (App) adentro del
// <div id="root"> que está en index.html.
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

// StrictMode solo actúa mientras desarrollamos: hace chequeos extra y avisa en la consola
// si algo está mal usado. En la versión compilada no hace nada.
createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
