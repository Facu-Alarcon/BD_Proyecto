from django.shortcuts import render, redirect
from django.contrib import messages
from .models import Equipos
from .forms import EquiposForm

def inicio(request):
    """Página de inicio (Index general de la app)"""
    return render(request, 'infinito_sonido/infinito_sonido.html')

def listaEquipos(request):
    """
    Lista todos los equipos del inventario.
    Usamos select_related('id_tipoeq') para traer los datos del Tipo_Equipo 
    en una única consulta SQL (evita el problema de consultas N+1).
    """
    equipos = Equipos.objects.select_related('id_tipoeq').all().order_by('nombre_equipo')
    return render(request, 'infinito_sonido/equipos/lista_equipos.html', {'equipos': equipos})

def createEquipos(request):
    if request.method == 'POST':
        form = EquiposForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Equipo registrado con éxito en el inventario!')
            return redirect('lista_equipos')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = EquiposForm()

    return render(request, 'infinito_sonido/equipos/create_equipos.html', {'form': form})