from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages

from .models import Equipo, TipoEquipo
from .forms import EquipoForm, TipoEquipoForm


def inicio(request):
    """Página de inicio temporal"""
    return render(request, 'infinito_sonido/lista_alumnos.html')


def equipo_list(request):
    equipos = Equipo.objects.select_related('tipo_equipo').all()
    return render(request, 'infinito_sonido/pages/equipos/equipo_list.html', {
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

    return render(request, 'infinito_sonido/pages/equipos/equipo_form.html', {
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

    return render(request, 'infinito_sonido/pages/equipos/equipo_form.html', {
        'form': form,
        'titulo': 'Editar Equipo',
    })


def equipo_delete(request, pk):
    equipo = get_object_or_404(Equipo, pk=pk)

    if request.method == 'POST':
        equipo.delete()
        messages.success(request, 'Equipo eliminado correctamente.')
        return redirect('equipo_list')

    return render(request, 'infinito_sonido/pages/equipos/equipo_confirm_delete.html', {
        'equipo': equipo,
    })


#!Agregado por Aye

def tipoequipo_list(request):
    tipos = TipoEquipo.objects.all()
    return render(request, 'infinito_sonido/pages/tipoequipos/tipoequipo_list.html', {
        'tipos': tipos,
    })


def tipoequipo_create(request):
    if request.method == 'POST':
        form = TipoEquipoForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'Tipo de equipo creado correctamente.')
            return redirect('tipoequipo_list')
    else:
        form = TipoEquipoForm()

    return render(request, 'infinito_sonido/pages/tipoequipos/tipoequipo_form.html', {
        'form': form,
        'titulo': 'Nuevo Tipo de Equipo',
    })


def tipoequipo_update(request, pk):
    tipo = get_object_or_404(TipoEquipo, pk=pk)

    if request.method == 'POST':
        form = TipoEquipoForm(request.POST, instance=tipo)
        if form.is_valid():
            form.save()
            messages.success(request, 'Tipo de equipo actualizado correctamente.')
            return redirect('tipoequipo_list')
    else:
        form = TipoEquipoForm(instance=tipo)

    return render(request, 'infinito_sonido/pages/tipoequipos/tipoequipo_form.html', {
        'form': form,
        'titulo': 'Editar Tipo de Equipo',
    })


def tipoequipo_delete(request, pk):
    tipo = get_object_or_404(TipoEquipo, pk=pk)

    if request.method == 'POST':
        tipo.delete()
        messages.success(request, 'Tipo de equipo eliminado correctamente.')
        return redirect('tipoequipo_list')

    return render(request, 'infinito_sonido/pages/tipoequipos/tipoequipo_confirm_delete.html', {
        'tipo': tipo,
    })
