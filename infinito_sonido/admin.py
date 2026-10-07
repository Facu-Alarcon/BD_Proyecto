# Configuración del panel /admin de Django: qué tablas aparecen y cómo se ven.
# No lo usa el frontend: sirve para revisar o corregir datos a mano mientras desarrollamos.
#
# En cada clase:
#   list_display  -> columnas que se ven en la lista
#   search_fields -> campos en los que busca el buscador de arriba
#   list_filter   -> filtros que aparecen a la derecha
# @admin.register(Modelo) es lo que hace que la tabla aparezca en el panel.
from django.contrib import admin

from .models import (
    Sueldos, Puestos, Empleados, Puestos_x_Empleados,
    Horarios, Perfiles, Usuarios, Horarios_x_Empleados,
    Tipo_Equipos, Estado_Equipos, Equipos, Servicios, Equipos_x_Servicios,
    Clientes, Reservas, Detalles_Reservas, Reservas_x_Servicios,
    Metodo_Pagos, Pagos, Detalles_de_Pago,
    Permisos, Permisos_x_Perfiles,
    Registro_Actividad,
)



class BajaLogicaAdmin(admin.ModelAdmin):
    """
    Base para las tablas con baja lógica (ver baja_logica.py). Acá el programador ve TODOS los
    registros, también los dados de baja que el frontend ya no muestra:
      - columnas "Activo" y "Fecha baja", y el filtro "Activo" a la derecha
        (Activo: No = los que se dieron de baja);
      - acción "Reactivar los seleccionados": recupera lo que se dio de baja por error;
      - acción "Dar de baja los seleccionados": lo mismo que el tachito del sistema.
    Para recuperar algo: entrar a /admin, abrir la tabla, filtrar por Activo = No, tildar el
    registro, elegir "Reactivar los seleccionados" en el desplegable de acciones y tocar "Ir".
    """
    actions = ['reactivar', 'dar_de_baja']

    # Suma las columnas de la baja a las que ya define cada tabla
    def get_list_display(self, request):
        return tuple(super().get_list_display(request)) + ('activo', 'fecha_baja')

    def get_list_filter(self, request):
        return ('activo',) + tuple(super().get_list_filter(request))

    @admin.action(description='Reactivar los seleccionados')
    def reactivar(self, request, queryset):
        for objeto in queryset:
            objeto.reactivar()
        self.message_user(request, f'Se reactivaron {queryset.count()} registro(s).')

    @admin.action(description='Dar de baja los seleccionados')
    def dar_de_baja(self, request, queryset):
        for objeto in queryset:
            objeto.dar_de_baja()
        self.message_user(request, f'Se dieron de baja {queryset.count()} registro(s).')

@admin.register(Sueldos)
class Sueldos_Admin(BajaLogicaAdmin):
    list_display = ('id_sueldo', 'monto_sueldo')


@admin.register(Puestos)
class Puestos_Admin(BajaLogicaAdmin):
    list_display = ('id_puesto', 'nombre_puesto', 'id_sueldo')
    search_fields = ('nombre_puesto',)


@admin.register(Empleados)
class Empleados_Admin(BajaLogicaAdmin):
    list_display = ('id_empleado', 'dni', 'nombre_emp', 'apellido_emp', 'email_emp')
    search_fields = ('dni', 'nombre_emp', 'apellido_emp')


@admin.register(Puestos_x_Empleados)
class Puestos_x_Empleados_Admin(admin.ModelAdmin):
    list_display = ('id_puesto_empleado', 'id_empleado', 'id_puesto')
    list_filter = ('id_puesto',)


@admin.register(Horarios)
class Horarios_Admin(BajaLogicaAdmin):
    list_display = ('id_horario', 'cantidad_horas')


@admin.register(Perfiles)
class Perfiles_Admin(BajaLogicaAdmin):
    list_display = ('id_perfil', 'tipo_perfil')
    search_fields = ('tipo_perfil',)


@admin.register(Usuarios)
class Usuarios_Admin(admin.ModelAdmin):
    # Nombre y apellido salen del empleado vinculado
    list_display = ('id_usuario', 'usuario', 'id_empleado', 'id_perfil', 'activo', 'debe_cambiar_clave')
    list_filter = ('id_perfil', 'activo')
    search_fields = ('usuario', 'id_empleado__dni', 'id_empleado__nombre_emp', 'id_empleado__apellido_emp')

@admin.register(Horarios_x_Empleados)
class Horarios_x_Empleados_Admin(admin.ModelAdmin):
    list_display = ('id_horario_empleado', 'id_empleado', 'id_horario')
    list_filter = ('id_horario',)


@admin.register(Tipo_Equipos)
class Tipo_Equipos_Admin(BajaLogicaAdmin):
    list_display = ('id_tipoeq', 'nombre_tipoeq')
    search_fields = ('nombre_tipoeq',)


@admin.register(Estado_Equipos)
class Estado_Equipos_Admin(BajaLogicaAdmin):
    list_display = ('id_estadoeq', 'nombre_estadoeq')
    search_fields = ('nombre_estadoeq',)


@admin.register(Equipos)
class Equipos_Admin(BajaLogicaAdmin):
    list_display = ('id_equipo', 'nombre_equipo', 'id_tipoeq', 'id_estadoeq', 'cantidad_equipo')
    list_filter = ('id_tipoeq', 'id_estadoeq')
    search_fields = ('nombre_equipo',)


@admin.register(Servicios)
class Servicios_Admin(BajaLogicaAdmin):
    list_display = ('id_servicio', 'tipo_servicio', 'precio_servicio')
    search_fields = ('tipo_servicio',)


@admin.register(Equipos_x_Servicios)
class Equipos_x_Servicios_Admin(admin.ModelAdmin):
    list_display = ('id_equipo_servicio', 'id_equipo', 'id_servicio')
    list_filter = ('id_servicio', 'id_equipo')


@admin.register(Clientes)
class Clientes_Admin(BajaLogicaAdmin):
    list_display = ('id_cliente', 'nombre_cliente', 'apellido_cliente', 'telefono_cliente', 'email_cliente')
    search_fields = ('nombre_cliente', 'apellido_cliente', 'email_cliente')


class Detalles_Reservas_Inline(admin.TabularInline):
    model = Detalles_Reservas
    extra = 1


@admin.register(Reservas)
class Reservas_Admin(admin.ModelAdmin):
    list_display = ('id_reserva', 'id_cliente', 'fecha_evento', 'monto_total', 'estado_reserva')
    list_filter = ('estado_reserva', 'fecha_evento')
    search_fields = ('id_cliente__nombre_cliente', 'id_cliente__apellido_cliente', 'direccion_evento')
    inlines = [Detalles_Reservas_Inline]


@admin.register(Detalles_Reservas)
class Detalles_Reservas_Admin(admin.ModelAdmin):
    list_display = ('id_detalle_reserva', 'id_reserva', 'id_empleado')
    list_filter = ('id_empleado',)


@admin.register(Reservas_x_Servicios)
class Reservas_x_Servicios_Admin(admin.ModelAdmin):
    list_display = ('id_reserva_servicio', 'id_reserva', 'id_servicio')
    list_filter = ('id_servicio',)


@admin.register(Metodo_Pagos)
class Metodo_Pagos_Admin(BajaLogicaAdmin):
    list_display = ('id_metodo_pago', 'metodo_pago')
    search_fields = ('metodo_pago',)


class Detalles_de_Pago_Inline(admin.TabularInline):
    model = Detalles_de_Pago
    extra = 1


@admin.register(Pagos)
class Pagos_Admin(BajaLogicaAdmin):
    list_display = ('id_pago', 'id_reserva', 'monto', 'saldo_pendiente')
    list_filter = ('id_reserva',)
    inlines = [Detalles_de_Pago_Inline]


@admin.register(Detalles_de_Pago)
class Detalles_de_Pago_Admin(admin.ModelAdmin):
    list_display = ('id_detalle_pago', 'id_pago', 'id_metodo_pago')
    list_filter = ('id_metodo_pago',)


@admin.register(Permisos)
class Permisos_Admin(BajaLogicaAdmin):
    list_display = ('id_permiso', 'nombre_permiso', 'estado_permiso')
    list_filter = ('estado_permiso',)
    search_fields = ('nombre_permiso',)


@admin.register(Permisos_x_Perfiles)
class Permisos_x_Perfiles_Admin(admin.ModelAdmin):
    list_display = ('id_permiso_perfil', 'id_perfil', 'id_permiso')
    list_filter = ('id_perfil', 'id_permiso')



# Registro de actividad: en el panel de Django también es solo de lectura
@admin.register(Registro_Actividad)
class Registro_Actividad_Admin(admin.ModelAdmin):
    list_display = ('fecha', 'usuario_texto', 'accion', 'modulo', 'descripcion', 'ip')
    list_filter = ('accion', 'modulo')
    search_fields = ('usuario_texto', 'descripcion', 'detalle')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
