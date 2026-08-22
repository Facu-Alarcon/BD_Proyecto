from django.contrib import admin

from .models import (
    Sueldos, Puestos, Empleados, Puestos_x_Empleados,
    Horarios, Perfiles, Usuarios, Horarios_x_Empleados,
    Tipo_Equipos, Equipos, Servicios, Equipos_x_Servicios,
    Clientes, Reservas, Detalles_Reservas, Reservas_x_Servicios,
    Metodo_Pagos, Pagos, Detalles_de_Pago,
)


@admin.register(Sueldos)
class Sueldos_Admin(admin.ModelAdmin):
    list_display = ('id_sueldo', 'monto_sueldo')


@admin.register(Puestos)
class Puestos_Admin(admin.ModelAdmin):
    list_display = ('id_puesto', 'nombre_puesto', 'id_sueldo')
    search_fields = ('nombre_puesto',)


@admin.register(Empleados)
class Empleados_Admin(admin.ModelAdmin):
    list_display = ('id_empleado', 'nombre_emp', 'apellido_emp', 'email_emp')
    search_fields = ('nombre_emp', 'apellido_emp')


@admin.register(Puestos_x_Empleados)
class Puestos_x_Empleados_Admin(admin.ModelAdmin):
    list_display = ('id_puesto_empleado', 'id_empleado', 'id_puesto')
    list_filter = ('id_puesto',)


@admin.register(Horarios)
class Horarios_Admin(admin.ModelAdmin):
    list_display = ('id_horario', 'cantidad_horas')


@admin.register(Perfiles)
class Perfiles_Admin(admin.ModelAdmin):
    list_display = ('id_perfil', 'tipo_perfil')
    search_fields = ('tipo_perfil',)


@admin.register(Usuarios)
class Usuarios_Admin(admin.ModelAdmin):
    list_display = ('id_usuario', 'usuario', 'id_perfil')
    list_filter = ('id_perfil',)
    search_fields = ('usuario',)


@admin.register(Horarios_x_Empleados)
class Horarios_x_Empleados_Admin(admin.ModelAdmin):
    list_display = ('id_horario_empleado', 'id_empleado', 'id_horario')
    list_filter = ('id_horario',)


@admin.register(Tipo_Equipos)
class Tipo_Equipos_Admin(admin.ModelAdmin):
    list_display = ('id_tipoeq', 'nombre_tipoeq')
    search_fields = ('nombre_tipoeq',)


@admin.register(Equipos)
class Equipos_Admin(admin.ModelAdmin):
    list_display = ('id_equipo', 'nombre_equipo', 'id_tipoeq', 'estado_equipo', 'cantidad_equipo')
    list_filter = ('id_tipoeq', 'estado_equipo')
    search_fields = ('nombre_equipo',)


@admin.register(Servicios)
class Servicios_Admin(admin.ModelAdmin):
    list_display = ('id_servicio', 'tipo_servicio', 'precio_servicio')
    search_fields = ('tipo_servicio',)


@admin.register(Equipos_x_Servicios)
class Equipos_x_Servicios_Admin(admin.ModelAdmin):
    list_display = ('id_equipo_servicio', 'id_equipo', 'id_servicio')
    list_filter = ('id_servicio', 'id_equipo')


@admin.register(Clientes)
class Clientes_Admin(admin.ModelAdmin):
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
class Metodo_Pagos_Admin(admin.ModelAdmin):
    list_display = ('id_metodo_pago', 'metodo_pago')
    search_fields = ('metodo_pago',)


class Detalles_de_Pago_Inline(admin.TabularInline):
    model = Detalles_de_Pago
    extra = 1


@admin.register(Pagos)
class Pagos_Admin(admin.ModelAdmin):
    list_display = ('id_pago', 'id_reserva', 'monto', 'saldo_pendiente')
    list_filter = ('id_reserva',)
    inlines = [Detalles_de_Pago_Inline]


@admin.register(Detalles_de_Pago)
class Detalles_de_Pago_Admin(admin.ModelAdmin):
    list_display = ('id_detalle_pago', 'id_pago', 'id_metodo_pago')
    list_filter = ('id_metodo_pago',)