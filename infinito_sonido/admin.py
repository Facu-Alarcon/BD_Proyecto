from django.contrib import admin

from .models import Puesto, Sueldo, Empleado, TipoEquipo, Equipo, Servicio, EquipoPorServicio


@admin.register(Sueldo)
class SueldoAdmin(admin.ModelAdmin):
    list_display = ('id', 'monto_sueldo')

@admin.register(Puesto)
class PuestoAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_puesto', 'id_sueldo')
    search_fields = ('nombre_puesto',)

@admin.register(Empleado)
class Empleadodmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_emp', 'apellido_emp', 'email_emp')
    search_fields = ('nombre_emp','apellido_emp')

@admin.register(TipoEquipo)
class TipoEquipoAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_tipoeq')
    search_fields = ('nombre_tipoeq',)


@admin.register(Equipo)
class EquipoAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_equipo', 'tipo_equipo', 'estado_equipo', 'cantidad_equipo')
    list_filter = ('tipo_equipo', 'estado_equipo')
    search_fields = ('nombre_equipo',)


# Permite agregar/editar los equipos y sus cantidades directamente al crear o ver un Servicio
class EquipoPorServicioInline(admin.TabularInline):
    model = EquipoPorServicio
    extra = 1  # Filas vacías adicionales para agregar equipos


@admin.register(Servicio)
class ServicioAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_servicio', 'precio_servicio')
    search_fields = ('nombre_servicio', 'descripcion_servicio')
    inlines = [EquipoPorServicioInline]


@admin.register(EquipoPorServicio)
class EquipoPorServicioAdmin(admin.ModelAdmin):
    list_display = ('id', 'servicio', 'equipo', 'cantidad')
    list_filter = ('servicio', 'equipo')
    search_fields = ('servicio__nombre_servicio', 'equipo__nombre_equipo')