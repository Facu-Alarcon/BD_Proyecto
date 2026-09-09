import { useAuth } from '../context/AuthContext';

/**
 * Traduce la lista de códigos de permiso del usuario logueado
 * (ver_<modulo> / gestionar_<modulo>, definidos en el backend) a algo
 * fácil de usar en los componentes.
 */
export function usePermiso(modulo) {
  const { usuario } = useAuth();
  const permisos = usuario?.permisos || [];
  const puedeGestionar = permisos.includes(`gestionar_${modulo}`);
  const puedeVer = puedeGestionar || permisos.includes(`ver_${modulo}`);
  return { puedeVer, puedeGestionar };
}
