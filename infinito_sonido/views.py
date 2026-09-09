from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.views.decorators.http import require_POST
from django.db import transaction
from django.db.models import ProtectedError
from .models import Equipos, Perfiles, Usuarios, Permisos, Permisos_x_Perfiles
from .forms import EquiposForm, PerfilesForm, PermisosForm, UsuariosForm

def inicio(request):
    """Página de inicio (Index general de la app)"""
    return render(request, 'infinito_sonido/pages/inicio.html')

def listaEquipos(request):
    """
    Lista todos los equipos del inventario.
    Usamos select_related('id_tipoeq') para traer los datos del Tipo_Equipo
    en una única consulta SQL (evita el problema de consultas N+1).
    """
    equipos = Equipos.objects.select_related('id_tipoeq').all().order_by('nombre_equipo')
    return render(request, 'infinito_sonido/pages/equipo_list.html', {'equipos': equipos})

def createEquipos(request):
    if request.method == 'POST':
        form = EquiposForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Equipo registrado con éxito en el inventario!')
            return redirect('equipo_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = EquiposForm()

    return render(request, 'infinito_sonido/pages/equipo_form.html', {'form': form, 'titulo': 'Nuevo Equipo'})


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
            return redirect('equipo_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = EquiposForm(instance=equipo)

    return render(request, 'infinito_sonido/pages/equipo_form.html', {'form': form, 'equipo': equipo, 'titulo': 'Editar Equipo'})


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
    return redirect('equipo_list')


# ==========================================================
# Módulo Perfiles (Gestionar Perfiles + Asignar Permisos)
# ==========================================================

def listaPerfiles(request):
    """Lista todos los perfiles de usuario."""
    perfiles = Perfiles.objects.all().order_by('tipo_perfil')
    return render(request, 'infinito_sonido/pages/perfil_list.html', {'perfiles': perfiles})


def crearPerfil(request):
    if request.method == 'POST':
        form = PerfilesForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Perfil creado con éxito!')
            return redirect('perfil_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = PerfilesForm()

    return render(request, 'infinito_sonido/pages/perfil_form.html', {'form': form, 'titulo': 'Nuevo Perfil'})


def editarPerfil(request, id_perfil):
    perfil = get_object_or_404(Perfiles, pk=id_perfil)

    if request.method == 'POST':
        form = PerfilesForm(request.POST, instance=perfil)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Perfil actualizado con éxito!')
            return redirect('perfil_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = PerfilesForm(instance=perfil)

    return render(request, 'infinito_sonido/pages/perfil_form.html', {'form': form, 'titulo': 'Editar Perfil'})


@require_POST
def eliminarPerfil(request, id_perfil):
    perfil = get_object_or_404(Perfiles, pk=id_perfil)
    nombre = perfil.tipo_perfil
    try:
        perfil.delete()
        messages.success(request, f'El perfil "{nombre}" fue eliminado.')
    except ProtectedError:
        messages.error(
            request,
            f'No se puede eliminar "{nombre}" porque hay usuarios asignados a ese perfil. '
            'Primero reasigná o eliminá esos usuarios.'
        )
    return redirect('perfil_list')


def asignarPermisos(request, id_perfil):
    """
    Pantalla de checkboxes para habilitar/deshabilitar los permisos
    de un perfil puntual (tabla intermedia Permisos_x_Perfiles).
    """
    perfil = get_object_or_404(Perfiles, pk=id_perfil)
    permisos = Permisos.objects.all().order_by('nombre_permiso')
    ids_asignados = set(
        Permisos_x_Perfiles.objects.filter(id_perfil=perfil).values_list('id_permiso_id', flat=True)
    )

    if request.method == 'POST':
        ids_seleccionados = {int(pk) for pk in request.POST.getlist('permisos')}

        with transaction.atomic():
            nuevos = ids_seleccionados - ids_asignados
            for id_permiso in nuevos:
                Permisos_x_Perfiles.objects.create(id_perfil=perfil, id_permiso_id=id_permiso)

            quitados = ids_asignados - ids_seleccionados
            if quitados:
                Permisos_x_Perfiles.objects.filter(id_perfil=perfil, id_permiso_id__in=quitados).delete()

        messages.success(request, f'Permisos actualizados para el perfil "{perfil.tipo_perfil}".')
        return redirect('perfil_list')

    permisos_con_estado = [
        {'permiso': permiso, 'asignado': permiso.pk in ids_asignados}
        for permiso in permisos
    ]
    return render(request, 'infinito_sonido/pages/perfil_permisos.html', {
        'perfil': perfil,
        'permisos_con_estado': permisos_con_estado,
    })


# ==========================================================
# Módulo Permisos (Gestionar Permisos)
# ==========================================================

def listaPermisos(request):
    """Lista el catálogo de permisos disponibles."""
    permisos = Permisos.objects.all().order_by('nombre_permiso')
    return render(request, 'infinito_sonido/pages/permiso_list.html', {'permisos': permisos})


def crearPermiso(request):
    if request.method == 'POST':
        form = PermisosForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Permiso creado con éxito!')
            return redirect('permiso_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = PermisosForm()

    return render(request, 'infinito_sonido/pages/permiso_form.html', {'form': form, 'titulo': 'Nuevo Permiso'})


def editarPermiso(request, id_permiso):
    permiso = get_object_or_404(Permisos, pk=id_permiso)

    if request.method == 'POST':
        form = PermisosForm(request.POST, instance=permiso)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Permiso actualizado con éxito!')
            return redirect('permiso_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = PermisosForm(instance=permiso)

    return render(request, 'infinito_sonido/pages/permiso_form.html', {'form': form, 'titulo': 'Editar Permiso'})


@require_POST
def eliminarPermiso(request, id_permiso):
    permiso = get_object_or_404(Permisos, pk=id_permiso)
    nombre = permiso.nombre_permiso
    permiso.delete()
    messages.success(request, f'El permiso "{nombre}" fue eliminado (se quitó de todos los perfiles que lo tenían).')
    return redirect('permiso_list')


# ==========================================================
# Módulo Usuarios (Gestionar Usuarios)
# ==========================================================

def listaUsuarios(request):
    """Lista todos los usuarios del sistema."""
    usuarios = Usuarios.objects.select_related('id_perfil').all().order_by('usuario')
    return render(request, 'infinito_sonido/pages/usuario_list.html', {'usuarios': usuarios})


def crearUsuario(request):
    if request.method == 'POST':
        form = UsuariosForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Usuario creado con éxito!')
            return redirect('usuario_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = UsuariosForm()

    return render(request, 'infinito_sonido/pages/usuario_form.html', {'form': form, 'titulo': 'Nuevo Usuario'})


def editarUsuario(request, id_usuario):
    usuario = get_object_or_404(Usuarios, pk=id_usuario)

    if request.method == 'POST':
        form = UsuariosForm(request.POST, instance=usuario)
        if form.is_valid():
            form.save()
            messages.success(request, '¡Usuario actualizado con éxito!')
            return redirect('usuario_list')
        else:
            messages.error(request, 'Por favor, revise los errores.')
    else:
        form = UsuariosForm(instance=usuario)

    return render(request, 'infinito_sonido/pages/usuario_form.html', {'form': form, 'titulo': 'Editar Usuario'})


@require_POST
def eliminarUsuario(request, id_usuario):
    usuario = get_object_or_404(Usuarios, pk=id_usuario)
    nombre = usuario.usuario
    usuario.delete()
    messages.success(request, f'El usuario "{nombre}" fue eliminado.')
    return redirect('usuario_list')