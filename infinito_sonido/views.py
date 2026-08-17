from django.shortcuts import render

def inicio(request):
    """Página de inicio temporal"""
    return render(request, 'infinito_sonido/lista_alumnos.html')
