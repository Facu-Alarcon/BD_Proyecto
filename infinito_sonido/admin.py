from django.contrib import admin

from .models import Alumno

#Agregar las nuevas vistas al panel de admin

@admin.register(Alumno)
class AlumnoAdmin(admin.ModelAdmin):
    """Configura cómo se muestra el modelo Alumno en el panel /admin."""

    list_display = ('id', 'nombre', 'nota', 'fecha_alta')
    list_filter = ('fecha_alta',)
    search_fields = ('nombre',)
