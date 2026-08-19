from django.contrib import admin

from .models import Puesto, Sueldo, Empleado, TipoEquipo, Equipo, Servicio, Equipo_x_Servicio, Clientes, Reservas, DetallesReservas, Pagos, DetallesDePago, MetodoPago, Horarios_x_Empleados, Puestos_x_Empleados, Reservas_x_Servicios, Perfil, Usuario, Horario


@admin.register(Sueldo)
class SueldoAdmin(admin.ModelAdmin):
    list_display = ('id', 'monto_sueldo')

@admin.register(Puesto)
class PuestoAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_puesto', 'id_sueldo')
    search_fields = ('nombre_puesto',)

@admin.register(Empleado)
class EmpleadoAdmin(admin.ModelAdmin):
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
class Equipo_x_Servicio(admin.TabularInline):
    model = Equipo_x_Servicio
    extra = 1  # Filas vacías adicionales para agregar equipos


@admin.register(Servicio)
class ServicioAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_servicio', 'precio_servicio')
    search_fields = ('nombre_servicio', 'descripcion_servicio')
    inlines = [Equipo_x_Servicio]


@admin.register(EquipoPorServicio)
class EquipoPorServicioAdmin(admin.ModelAdmin):
    list_display = ('id', 'servicio', 'equipo', 'cantidad')
    list_filter = ('servicio', 'equipo')
    search_fields = ('servicio__nombre_servicio', 'equipo__nombre_equipo')


@admin.register(Clientes)
class ClientesAdmin(admin.ModelAdmin):
    list_display = ('id', 'nombre_cliente', 'apellido_cliente', 'telefono_cliente', 'email_cliente')
    search_fields = ('nombre_cliente', 'apellido_cliente', 'email_cliente')


# Permite agregar/editar los detalles (empleados) directamente al crear o ver una Reserva
class DetallesReservasInline(admin.TabularInline):
    model = DetallesReservas
    extra = 1  # Filas vacías adicionales para agregar empleados


@admin.register(Reservas)
class ReservasAdmin(admin.ModelAdmin):
    list_display = ('id', 'cliente', 'fecha_evento', 'monto_total', 'estado_reserva')
    list_filter = ('estado_reserva', 'fecha_evento')
    search_fields = ('cliente__nombre_cliente', 'cliente__apellido_cliente', 'direccion_evento')
    inlines = [DetallesReservasInline]


@admin.register(DetallesReservas)
class DetallesReservasAdmin(admin.ModelAdmin):
    list_display = ('id_detalle_reserva', 'reserva', 'empleado')
    list_filter = ('empleado',)
    search_fields = ('reserva__id', 'empleado__nombre_empleado')

@admin.register(MetodoPago)
class MetodoPagoAdmin(admin.ModelAdmin):
    list_display = ('id_metodo_pago','metodo_pago')
    search_fields = ('metodo_pago')

#PErmite agregar/editar los metodos de pago directamente al crear o ver un pago
class DetallesDePagoInline(admin.TabularInline):
    model = DetallesDePago
    extra = 1 #filas vacias adicionales oara agregar métodos de pago

@admin.register(Pagos)
class PagosAdmin(admin.ModelAdmin):
    list_display = ('id_pago','reserva','monto')
    list_filter = ('reserva')
    search_fields = ('reserva_id',)
    inlines = [DetallesDePagoInline]

@admin.register(DetallesDePago)
class DetallesDePagoAdmin(admin.ModelAdmin):
    list_display = ('id_detelle_pago','pago','metodo_pago')
    list_filter = ('metodo_pago',)
    search_fields = ('pago__id_pago')

@admin.register(Horarios_x_Empleados)
class HorariosXEmpleadosAdmin(admin.ModelAdmin):
    list_display = ('id', 'id_empleado', 'id_horario')

@admin.register(Puestos_x_Empleados)
class PuestosXEmpleadosAdmin(admin.ModelAdmin):
    list_display = ('id', 'id_empleado', 'id_puesto')

@admin.register(Reservas_x_Servicios)
class ReservasXServiciosAdmin(admin.ModelAdmin):
    list_display = ('id', 'id_reserva', 'id_servicio')

@admin.register(Perfil)
class PerfilAdmin(admin.ModelAdmin):
    list_display = ('id_perfil', 'tipo_perfil')
    search_fields = ('tipo_perfil',)


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    list_display = ('id_usuario', 'usuario', 'id_perfil')
    list_filter = ('id_perfil',)
    search_fields = ('usuario',)


@admin.register(Horario)
class HorarioAdmin(admin.ModelAdmin):
    list_display = ('id_horario', 'cantidad_horas')