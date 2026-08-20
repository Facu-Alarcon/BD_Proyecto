from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from .models import Equipo
from .forms import EquipoForm

def inicio(request):
    """Página de inicio temporal"""
    return render(request, 'infinito_sonido/lista_alumnos.html')

def equipo_list(request):
    equipos = Equipo.objects.select_related('tipo_equipo').all()
    return render(request, 'infinito_sonido/equipo_list.html', {
        'equipos': equipos,
    })


def equipo_create(request):
    if request.method == 'POST':
        form = EquipoForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'Equipo creado correctamente.')
            return redirect('equipo_list')
    else:
        form = EquipoForm()

    return render(request, 'infinito_sonido/equipo_form.html', {
        'form': form,
        'titulo': 'Nuevo Equipo',
    })


def equipo_update(request, pk):
    equipo = get_object_or_404(Equipo, pk=pk)

    if request.method == 'POST':
        form = EquipoForm(request.POST, instance=equipo)
        if form.is_valid():
            form.save()
            messages.success(request, 'Equipo actualizado correctamente.')
            return redirect('equipo_list')
    else:
        form = EquipoForm(instance=equipo)

    return render(request, 'infinito_sonido/equipo_form.html', {
        'form': form,
        'titulo': 'Editar Equipo',
    })


def equipo_delete(request, pk):
    equipo = get_object_or_404(Equipo, pk=pk)

    if request.method == 'POST':
        equipo.delete()
        messages.success(request, 'Equipo eliminado correctamente.')
        return redirect('equipo_list')

    return render(request, 'infinito_sonido/equipo_confirm_delete.html', {
        'equipo': equipo,
    })
