from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.views.decorators.http import require_POST
from django.db.models import ProtectedError
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


def editarEquipos(request, id_equipo):
    """
    Edita un equipo existente. Trae el objeto con get_object_or_404
    (si no existe, tira 404 en vez de romper con una excepción fea).
    """
    equipo = get_object_or_404(Equipos, pk=id_equipo)

    if request.method == 'POST':
        form = EquiposForm(request.POST, instance=equipo)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Equipo actualizado con éxito!')
            return redirect('lista_equipos')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = EquiposForm(instance=equipo)

    return render(request, 'infinito_sonido/equipos/edit_equipos.html', {'form': form, 'equipo': equipo})


@require_POST
def eliminarEquipos(request, id_equipo):
    """
    Elimina un equipo. Solo acepta POST (nunca GET) para que no se pueda
    borrar por accidente entrando a la URL directamente o por un bot/crawler.
    """
    equipo = get_object_or_404(Equipos, pk=id_equipo)
    nombre = equipo.nombre_equipo
    try:
        equipo.delete()
        messages.success(request, f'El equipo "{nombre}" fue eliminado del inventario.')
    except ProtectedError:
        messages.error(
            request,
            f'No se puede eliminar "{nombre}" porque tiene servicios asociados. '
            'Primero desvinculá o eliminá esos servicios.'
        )
    return redirect('lista_equipos')