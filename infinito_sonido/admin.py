from django.contrib import admin

from .models import Puesto, Sueldo


@admin.register(Sueldo)
class SueldoAdmin(admin.ModelAdmin):
    list_display = ('id', 'monto_sueldo')

@admin.register(Puesto)
class PuestoAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_puesto', 'id_sueldo')
    search_fields = ('nombre_puesto',)
