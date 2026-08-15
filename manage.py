#!/usr/bin/env python
"""Utilidad de linea de comandos de Django para tareas administrativas."""
import os
import sys


def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "No se pudo importar Django. ¿Esta instalado y disponible en la "
            "variable de entorno PYTHONPATH? ¿Olvidaste activar el entorno?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
