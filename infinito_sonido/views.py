from django.shortcuts import render

from .models import Alumno

#Cambiar

def lista_alumnos(request):
    """Página de inicio: muestra todos los alumnos guardados en MySQL."""
    alumnos = Alumno.objects.all()
    contexto = {
        'alumnos': alumnos,
        'total': alumnos.count(),
    }
    return render(request, 'escuela/lista_alumnos.html', contexto)
