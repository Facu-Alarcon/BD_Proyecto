-- ======================================================================
-- DATOS DE PRUEBA - INFINITO SONIDO E ILUMINACION
-- ======================================================================
-- Como usarlo:
--   1. Levantar los contenedores (docker compose up -d). El contenedor web
--      corre las migraciones solo, asi que las tablas ya estan creadas y
--      ya tienen cargados los 36 permisos, los 3 estados de equipo y los
--      4 parametros de las alertas (tabla configuracion).
--      (Sin Docker: cargar antes 01_estructura.sql y 02_datos_iniciales.sql)
--   2. Entrar a phpMyAdmin (http://localhost:8080), elegir la base del
--      proyecto, ir a la pestana SQL, pegar TODO este archivo y Continuar.
--      Tiene que ejecutarse todo junto de una sola vez: los ids se van
--      guardando en variables (@...) que se usan en los insert siguientes.
--   3. Usuario: admin / Contrasena: admin123
--      El resto de los usuarios entran con su usuario (primer apellido + inicial,
--      ej: alarconf, herrerav) y la contrasena: Clave#2026
--
-- Pensado para una base recien migrada (sin datos cargados a mano).
-- Si ya existe un usuario "admin" o algun DNI repetido, ese insert falla.
-- Las contrasenas van hasheadas porque el login usa check_password de Django.
-- Las notificaciones no se cargan aca: las genera el sistema solo al arrancar el
-- contenedor (python manage.py evaluar_alertas) y al registrar o modificar reservas.
--
-- Que trae (armado al 08/11/2026, respetando las mismas reglas que controla el sistema):
--   - 26 empleados (2 dados de baja), 19 usuarios, 3 perfiles
--   - 31 equipos (4 en reparacion, que ningun servicio usa) y 20 servicios (2 desactivados)
--   - 98 clientes y 371 reservas de ene-2025 a may-2027:
--     269 finalizadas, 39 confirmadas, 32 pendientes, 31 anuladas
--   - Entre 10 y 20 reservas por mes, salvo de enero a marzo (temporada baja) que bajan a 5-8.
--     El pico es en noviembre y diciembre (egresados, fiestas de fin de año y casamientos).
--   - 711 pagos (16 anulados). Los saldos estan calculados igual que recalcular_saldos()
--   - Ningun empleado esta en dos eventos el mismo dia y ningun dia se reservan
--     mas unidades de un equipo de las que hay.
--   - Los precios de los servicios en las reservas viejas son mas bajos que los
--     actuales (se guarda el precio del momento), asi los reportes muestran la suba.
-- ======================================================================

START TRANSACTION;

-- ======================================================================
-- 1. PERFILES Y SUS PERMISOS
-- ======================================================================
INSERT INTO infinito_sonido_perfiles (tipo_perfil) VALUES ('Administrador');
SET @perfil_admin = LAST_INSERT_ID();
-- El administrador tiene todos los permisos, incluido Ver Registro de actividad
INSERT INTO infinito_sonido_permisos_x_perfiles (id_perfil, id_permiso)
  SELECT @perfil_admin, id_permiso FROM infinito_sonido_permisos;

INSERT INTO infinito_sonido_perfiles (tipo_perfil) VALUES ('Encargado');
SET @perfil_encargado = LAST_INSERT_ID();
-- El encargado maneja reservas, clientes y pagos, y consulta el resto (sin seguridad ni registro).
-- Ve los reportes pero no el de ingresos (no tiene ver_reportes_financieros) ni la Configuracion
INSERT INTO infinito_sonido_permisos_x_perfiles (id_perfil, id_permiso)
  SELECT @perfil_encargado, id_permiso FROM infinito_sonido_permisos WHERE codigo IN ('ver_reservas','gestionar_reservas','anular_reservas','ver_clientes','gestionar_clientes','ver_pagos','gestionar_pagos','ver_metodos_pago','ver_equipos','gestionar_equipos','ver_servicios','ver_tipos_equipo','ver_estados_equipo','ver_empleados','ver_horarios','ver_reportes');

INSERT INTO infinito_sonido_perfiles (tipo_perfil) VALUES ('Empleado');
SET @perfil_empleado = LAST_INSERT_ID();
-- El empleado solo consulta: reservas, clientes, equipos, servicios y horarios
INSERT INTO infinito_sonido_permisos_x_perfiles (id_perfil, id_permiso)
  SELECT @perfil_empleado, id_permiso FROM infinito_sonido_permisos WHERE codigo IN ('ver_reservas','ver_clientes','ver_equipos','ver_servicios','ver_tipos_equipo','ver_estados_equipo','ver_horarios');

-- ======================================================================
-- 2. USUARIO ADMINISTRADOR  (usuario: admin / contrasena: admin123)
-- ======================================================================
-- Cada usuario es la cuenta de un empleado, asi que primero va el empleado del admin
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('12345678', 'Admin', 'Sistema', '3870000000', 'admin@infinito.com', 1, NULL);
SET @emp_admin = LAST_INSERT_ID();
INSERT INTO infinito_sonido_usuarios (id_empleado, id_perfil, usuario, `contraseña`, activo, debe_cambiar_clave, fecha_ultima_modificacion, fecha_baja)
  VALUES (@emp_admin, @perfil_admin, 'admin', 'pbkdf2_sha256$600000$ImHryuoGzb4nbbVctCV6KQ$j4xSCKv3Y1k6frCDc2wiT1aWWoAQRHJQlkcsVmkiTb0=', 1, 0, CURDATE(), NULL);
SET @usr_admin = LAST_INSERT_ID();

-- ======================================================================
-- 3. SUELDOS
-- ======================================================================
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (540000); SET @sueldo1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (680000); SET @sueldo2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (760000); SET @sueldo3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (850000); SET @sueldo4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (980000); SET @sueldo5 = LAST_INSERT_ID();

-- ======================================================================
-- 4. PUESTOS
-- ======================================================================
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo4, 'DJ'); SET @puesto1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo3, 'Iluminación'); SET @puesto2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo2, 'Operario'); SET @puesto3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo3, 'Sonidista'); SET @puesto4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo1, 'Administración'); SET @puesto5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo5, 'Encargado de Eventos'); SET @puesto6 = LAST_INSERT_ID();

-- ======================================================================
-- 5. EMPLEADOS (los dos ultimos estan dados de baja: ya trabajaron en eventos, por eso no se borran)
-- ======================================================================
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('44801891', 'Facundo', 'Alarcón', '3874955685', 'facundo.alarcon@gmail.com', 1, NULL); SET @emp1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('36916564', 'Valentina', 'Herrera', '3874477065', 'valentina.herrera@gmail.com', 1, NULL); SET @emp2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('29199921', 'Matías', 'Sosa', '3874988784', 'matias.sosa@gmail.com', 1, NULL); SET @emp3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('33827098', 'Camila', 'Rojas', '3876092897', 'camila.rojas@gmail.com', 1, NULL); SET @emp4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('30787860', 'Joaquín', 'Benítez', '3876451942', 'joaquin.benitez@gmail.com', 1, NULL); SET @emp5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('32909846', 'Lucía', 'Fernández', '3875992015', 'lucia.fernandez@gmail.com', 1, NULL); SET @emp6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('33503201', 'Tomás', 'Acosta', '3875095221', 'tomas.acosta@gmail.com', 1, NULL); SET @emp7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('35836445', 'Sofía', 'Medina', '3876766671', 'sofia.medina@gmail.com', 1, NULL); SET @emp8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('33722424', 'Nicolás', 'Romero', '3876573880', 'nicolas.romero@gmail.com', 1, NULL); SET @emp9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('41174701', 'Agustina', 'Torres', '3876682107', 'agustina.torres@gmail.com', 1, NULL); SET @emp10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('42067788', 'Gonzalo', 'Flores', '3875966546', 'gonzalo.flores@gmail.com', 1, NULL); SET @emp11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('29187680', 'Martina', 'Gutiérrez', '3874986828', 'martina.gutierrez@gmail.com', 1, NULL); SET @emp12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('41000891', 'Lautaro', 'Ruiz', '3875109108', 'lautaro.ruiz@gmail.com', 1, NULL); SET @emp13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('32379175', 'Florencia', 'Castro', '3876008739', 'florencia.castro@gmail.com', 1, NULL); SET @emp14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('29242840', 'Santiago', 'Ortiz', '3875536588', 'santiago.ortiz@gmail.com', 1, NULL); SET @emp15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('44424728', 'Rocío', 'Núñez', '3875322087', 'rocio.nunez@gmail.com', 1, NULL); SET @emp16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('38882015', 'Maximiliano', 'Silva', '3875152580', 'maximiliano.silva@gmail.com', 1, NULL); SET @emp17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('28663357', 'Julieta', 'Molina', '3876236603', 'julieta.molina@gmail.com', 1, NULL); SET @emp18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('30936780', 'Diego', 'Luna', '3876564753', 'diego.luna@gmail.com', 1, NULL); SET @emp19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('39346660', 'Carolina', 'De la Fuente', '3874011512', 'carolina.delafuente@gmail.com', 1, NULL); SET @emp20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('44640216', 'Federico', 'Cruz', '3874958564', 'federico.cruz@gmail.com', 1, NULL); SET @emp21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('33852221', 'Micaela', 'Vargas', '3876385600', 'micaela.vargas@gmail.com', 1, NULL); SET @emp22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('32834522', 'Ignacio', 'Barrios', '3874967519', 'ignacio.barrios@gmail.com', 1, NULL); SET @emp23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('32147791', 'Luciano', 'Reyes', '3874485819', 'luciano.reyes@gmail.com', 0, '2026-07-31 18:00:00'); SET @emp24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp, activo, fecha_baja) VALUES ('34822058', 'Brenda', 'Quiroga', '3874296653', 'brenda.quiroga@gmail.com', 0, '2026-09-15 17:30:00'); SET @emp25 = LAST_INSERT_ID();

-- ======================================================================
-- 6. USUARIOS DE LOS EMPLEADOS (usuario = primer apellido + inicial, contrasena: Clave#2026)
-- ======================================================================
-- No todos los empleados tienen usuario. Los de los empleados dados de baja quedan desactivados.
-- herrerav tiene que cambiar la clave en el proximo ingreso (como si el admin se la hubiera restablecido).
INSERT INTO infinito_sonido_usuarios (id_empleado, id_perfil, usuario, `contraseña`, activo, debe_cambiar_clave, fecha_ultima_modificacion, fecha_baja) VALUES
  (@emp1, @perfil_admin, 'alarconf', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp2, @perfil_encargado, 'herrerav', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 1, CURDATE(), NULL),
  (@emp3, @perfil_empleado, 'sosam', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp4, @perfil_empleado, 'rojasc', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp5, @perfil_empleado, 'benitezj', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp6, @perfil_empleado, 'fernandezl', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp7, @perfil_empleado, 'acostat', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp8, @perfil_empleado, 'medinas', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp9, @perfil_empleado, 'romeron', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp10, @perfil_empleado, 'torresa', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp11, @perfil_empleado, 'floresg', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp12, @perfil_encargado, 'gutierrezm', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp13, @perfil_empleado, 'ruizl', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp14, @perfil_empleado, 'castrof', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp15, @perfil_empleado, 'ortizs', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp20, @perfil_encargado, 'delafuentec', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp24, @perfil_empleado, 'reyesl', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 0, 0, CURDATE(), '2026-07-31'),
  (@emp25, @perfil_empleado, 'quirogab', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 0, 0, CURDATE(), '2026-09-15');
SET @usr_alarconf = (SELECT id_usuario FROM infinito_sonido_usuarios WHERE usuario = 'alarconf');
SET @usr_herrerav = (SELECT id_usuario FROM infinito_sonido_usuarios WHERE usuario = 'herrerav');
SET @usr_gutierrezm = (SELECT id_usuario FROM infinito_sonido_usuarios WHERE usuario = 'gutierrezm');
SET @usr_delafuentec = (SELECT id_usuario FROM infinito_sonido_usuarios WHERE usuario = 'delafuentec');

-- ======================================================================
-- 7. PUESTO DE CADA EMPLEADO (el encargado de eventos tambien hace de DJ)
-- ======================================================================
INSERT INTO infinito_sonido_puestos_x_empleados (id_empleado, id_puesto) VALUES
  (@emp1, @puesto6),
  (@emp2, @puesto5),
  (@emp3, @puesto1),
  (@emp4, @puesto2),
  (@emp5, @puesto3),
  (@emp6, @puesto4),
  (@emp7, @puesto1),
  (@emp8, @puesto2),
  (@emp9, @puesto3),
  (@emp10, @puesto4),
  (@emp11, @puesto3),
  (@emp12, @puesto6),
  (@emp13, @puesto1),
  (@emp14, @puesto2),
  (@emp15, @puesto3),
  (@emp16, @puesto4),
  (@emp17, @puesto3),
  (@emp18, @puesto2),
  (@emp19, @puesto3),
  (@emp20, @puesto5),
  (@emp21, @puesto1),
  (@emp22, @puesto3),
  (@emp23, @puesto4),
  (@emp24, @puesto3),
  (@emp25, @puesto2),
  (@emp1, @puesto1);

-- ======================================================================
-- 8. HORARIOS
-- ======================================================================
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (4); SET @horario1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (5); SET @horario2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (6); SET @horario3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (8); SET @horario4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (10); SET @horario5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (12); SET @horario6 = LAST_INSERT_ID();

-- ======================================================================
-- 9. HORARIO DE CADA EMPLEADO
-- ======================================================================
INSERT INTO infinito_sonido_horarios_x_empleados (id_empleado, id_horario) VALUES
  (@emp1, @horario4),
  (@emp2, @horario4),
  (@emp3, @horario3),
  (@emp4, @horario3),
  (@emp5, @horario5),
  (@emp6, @horario4),
  (@emp7, @horario2),
  (@emp8, @horario3),
  (@emp9, @horario6),
  (@emp10, @horario4),
  (@emp11, @horario5),
  (@emp12, @horario4),
  (@emp13, @horario3),
  (@emp14, @horario2),
  (@emp15, @horario6),
  (@emp16, @horario3),
  (@emp17, @horario5),
  (@emp18, @horario1),
  (@emp19, @horario5),
  (@emp20, @horario4),
  (@emp21, @horario3),
  (@emp22, @horario4),
  (@emp23, @horario3),
  (@emp24, @horario5),
  (@emp25, @horario3);

-- ======================================================================
-- 10. TIPOS DE EQUIPO
-- ======================================================================
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Sonido'); SET @tipo1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Iluminación'); SET @tipo2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Estructuras y Soportes'); SET @tipo3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Efectos Especiales'); SET @tipo4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Cables y Accesorios'); SET @tipo5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Video y Pantallas'); SET @tipo6 = LAST_INSERT_ID();

-- ======================================================================
-- 11. ESTADOS DE EQUIPO (ya los cargan las migraciones, solo se toman sus ids)
-- ======================================================================
SET @disponible = (SELECT id_estadoeq FROM infinito_sonido_estado_equipos WHERE nombre_estadoeq = 'Disponible');
SET @en_uso = (SELECT id_estadoeq FROM infinito_sonido_estado_equipos WHERE nombre_estadoeq = 'En uso');
SET @reparacion = (SELECT id_estadoeq FROM infinito_sonido_estado_equipos WHERE nombre_estadoeq = 'En reparación');

-- ======================================================================
-- 12. EQUIPOS (cantidad_equipo = unidades que hay, se usa para controlar la disponibilidad)
-- ======================================================================
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Consola Digital Behringer X32 32 Canales', @disponible, 2); SET @eq1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Consola Yamaha MG16XU 16 Canales', @disponible, 2); SET @eq2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Bafle Activo RCF ART 715-A MK4 15"', @disponible, 10); SET @eq3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Bafle Activo JBL EON715 15"', @en_uso, 8); SET @eq4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Subwoofer Activo Electro-Voice ELX200 18"', @disponible, 6); SET @eq5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Micrófono Inalámbrico Shure SLXD24 (Par)', @disponible, 6); SET @eq6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Micrófono Shure SM58 con Cable', @disponible, 10); SET @eq7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Monitor de Piso Wharfedale EVP-X15', @reparacion, 2); SET @eq8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Controladora DJ Pioneer DDJ-FLX10', @disponible, 3); SET @eq9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Potencia Crown XLi 2500', @reparacion, 1); SET @eq10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Cabezal Móvil Beam 7R 230W', @disponible, 12); SET @eq11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Tacho PAR LED 18x10W RGBW', @disponible, 24); SET @eq12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Barra LED Pixel Sweep 8x10W', @en_uso, 8); SET @eq13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Consola DMX Chamsys QuickQ 10', @disponible, 3); SET @eq14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Láser RGB 2W Animación', @disponible, 3); SET @eq15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Seguidor 575W con Trípode', @disponible, 2); SET @eq16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Efecto LED Derby Doble RGB', @reparacion, 2); SET @eq17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Tramo Truss Cuadrada Q30 2m', @disponible, 16); SET @eq18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Torre Elevadora Telescópica 5.3m', @disponible, 6); SET @eq19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Trípode Reforzado para Bafle', @disponible, 14); SET @eq20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Tarima Modular 2x1m', @disponible, 8); SET @eq21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Máquina de Humo 1500W DMX', @disponible, 4); SET @eq22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Máquina de Chispas Frías Sparkular', @disponible, 4); SET @eq23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Lanza Papelitos Confetti Fan', @disponible, 3); SET @eq24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Máquina de Burbujas Doble Rotor', @reparacion, 2); SET @eq25 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo5, 'Medusa Snake 16 Canales XLR 30m', @disponible, 3); SET @eq26 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo5, 'Pack Cables DMX 10m (10u)', @disponible, 6); SET @eq27 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo5, 'Cable Speakon 15m', @disponible, 20); SET @eq28 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo6, 'Pantalla LED Modular P3.9 3x2m', @disponible, 1); SET @eq29 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo6, 'Proyector Epson 5000 Lúmenes con Telón', @disponible, 2); SET @eq30 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo6, 'TV LED 65" con Pie', @disponible, 4); SET @eq31 = LAST_INSERT_ID();

-- ======================================================================
-- 13. SERVICIOS (precio actual; los dos ultimos se desactivaron y ya no se ofrecen)
-- ======================================================================
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Combo Fiesta de 15 (Sonido + Iluminación + DJ)', 780000, 1, NULL); SET @serv1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Combo Boda Clásica (Sonido + Iluminación + DJ)', 850000, 1, NULL); SET @serv2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Boda Premium con Pista LED y Efectos', 1450000, 1, NULL); SET @serv3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Fiesta de Egresados Completa', 720000, 1, NULL); SET @serv4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Cumpleaños de 18 (DJ + Pista LED)', 620000, 1, NULL); SET @serv5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Sonido Básico para Bautismos y Almuerzos', 210000, 1, NULL); SET @serv6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Cumpleaños Infantil (Sonido + Luces)', 180000, 1, NULL); SET @serv7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Evento Empresarial Premium', 1100000, 1, NULL); SET @serv8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Sonido para Conferencias y Charlas', 230000, 1, NULL); SET @serv9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Acto de Graduación (Sonido + Microfonía)', 320000, 1, NULL); SET @serv10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Festival / Peña al Aire Libre', 980000, 1, NULL); SET @serv11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Fiesta de Fin de Año Empresarial', 890000, 1, NULL); SET @serv12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Iluminación Arquitectónica de Salón', 340000, 1, NULL); SET @serv13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Pantalla LED y Proyección', 420000, 1, NULL); SET @serv14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Efectos Especiales: Humo, Chispas y Confetti', 260000, 1, NULL); SET @serv15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('DJ por Hora Extra', 75000, 1, NULL); SET @serv16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Sonido para Pool Party', 350000, 1, NULL); SET @serv17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Show en Vivo (Banda + Monitoreo)', 690000, 1, NULL); SET @serv18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Combo Fiesta de 15 Económico', 520000, 0, '2026-06-30 19:00:00'); SET @serv19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio, activo, fecha_baja) VALUES ('Karaoke para Fiestas Privadas', 200000, 0, '2026-06-30 19:00:00'); SET @serv20 = LAST_INSERT_ID();

-- ======================================================================
-- 14. EQUIPOS QUE USA CADA SERVICIO (con cuantas unidades de cada uno)
-- ======================================================================
INSERT INTO infinito_sonido_equipos_x_servicios (id_equipo, id_servicio, cantidad) VALUES
  (@eq1, @serv1, 1),
  (@eq3, @serv1, 4),
  (@eq5, @serv1, 2),
  (@eq9, @serv1, 1),
  (@eq11, @serv1, 4),
  (@eq12, @serv1, 6),
  (@eq19, @serv1, 2),
  (@eq27, @serv1, 1),
  (@eq28, @serv1, 6),
  (@eq1, @serv2, 1),
  (@eq3, @serv2, 4),
  (@eq5, @serv2, 2),
  (@eq6, @serv2, 1),
  (@eq9, @serv2, 1),
  (@eq12, @serv2, 8),
  (@eq13, @serv2, 2),
  (@eq28, @serv2, 6),
  (@eq1, @serv3, 1),
  (@eq3, @serv3, 6),
  (@eq5, @serv3, 2),
  (@eq6, @serv3, 2),
  (@eq9, @serv3, 1),
  (@eq11, @serv3, 8),
  (@eq13, @serv3, 4),
  (@eq14, @serv3, 1),
  (@eq18, @serv3, 6),
  (@eq19, @serv3, 2),
  (@eq23, @serv3, 2),
  (@eq28, @serv3, 8),
  (@eq2, @serv4, 1),
  (@eq4, @serv4, 4),
  (@eq5, @serv4, 2),
  (@eq9, @serv4, 1),
  (@eq11, @serv4, 4),
  (@eq12, @serv4, 6),
  (@eq15, @serv4, 1),
  (@eq22, @serv4, 1),
  (@eq28, @serv4, 6),
  (@eq2, @serv5, 1),
  (@eq4, @serv5, 2),
  (@eq5, @serv5, 1),
  (@eq9, @serv5, 1),
  (@eq12, @serv5, 6),
  (@eq13, @serv5, 2),
  (@eq22, @serv5, 1),
  (@eq28, @serv5, 4),
  (@eq2, @serv6, 1),
  (@eq4, @serv6, 2),
  (@eq7, @serv6, 2),
  (@eq20, @serv6, 2),
  (@eq28, @serv6, 2),
  (@eq2, @serv7, 1),
  (@eq4, @serv7, 2),
  (@eq12, @serv7, 4),
  (@eq20, @serv7, 2),
  (@eq24, @serv7, 1),
  (@eq28, @serv7, 2),
  (@eq1, @serv8, 1),
  (@eq3, @serv8, 4),
  (@eq6, @serv8, 2),
  (@eq12, @serv8, 8),
  (@eq19, @serv8, 2),
  (@eq21, @serv8, 4),
  (@eq26, @serv8, 1),
  (@eq28, @serv8, 6),
  (@eq29, @serv8, 1),
  (@eq2, @serv9, 1),
  (@eq3, @serv9, 2),
  (@eq6, @serv9, 2),
  (@eq7, @serv9, 2),
  (@eq20, @serv9, 2),
  (@eq30, @serv9, 1),
  (@eq1, @serv10, 1),
  (@eq3, @serv10, 4),
  (@eq6, @serv10, 1),
  (@eq7, @serv10, 3),
  (@eq20, @serv10, 4),
  (@eq21, @serv10, 2),
  (@eq28, @serv10, 4),
  (@eq1, @serv11, 1),
  (@eq3, @serv11, 6),
  (@eq5, @serv11, 4),
  (@eq7, @serv11, 4),
  (@eq12, @serv11, 10),
  (@eq18, @serv11, 8),
  (@eq19, @serv11, 2),
  (@eq21, @serv11, 6),
  (@eq26, @serv11, 1),
  (@eq28, @serv11, 10),
  (@eq1, @serv12, 1),
  (@eq3, @serv12, 4),
  (@eq5, @serv12, 2),
  (@eq9, @serv12, 1),
  (@eq11, @serv12, 4),
  (@eq12, @serv12, 6),
  (@eq14, @serv12, 1),
  (@eq23, @serv12, 2),
  (@eq28, @serv12, 6),
  (@eq12, @serv13, 12),
  (@eq14, @serv13, 1),
  (@eq27, @serv13, 2),
  (@eq29, @serv14, 1),
  (@eq30, @serv14, 1),
  (@eq31, @serv14, 2),
  (@eq22, @serv15, 2),
  (@eq23, @serv15, 2),
  (@eq24, @serv15, 1),
  (@eq9, @serv16, 1),
  (@eq2, @serv17, 1),
  (@eq4, @serv17, 4),
  (@eq5, @serv17, 1),
  (@eq9, @serv17, 1),
  (@eq20, @serv17, 2),
  (@eq28, @serv17, 4),
  (@eq1, @serv18, 1),
  (@eq3, @serv18, 4),
  (@eq5, @serv18, 2),
  (@eq7, @serv18, 6),
  (@eq16, @serv18, 1),
  (@eq21, @serv18, 4),
  (@eq26, @serv18, 1),
  (@eq28, @serv18, 8),
  (@eq2, @serv19, 1),
  (@eq4, @serv19, 4),
  (@eq9, @serv19, 1),
  (@eq12, @serv19, 6),
  (@eq28, @serv19, 4),
  (@eq2, @serv20, 1),
  (@eq4, @serv20, 2),
  (@eq7, @serv20, 2),
  (@eq31, @serv20, 1);

-- ======================================================================
-- 15. CLIENTES (los dos ultimos son una institucion y una empresa, con varios eventos)
-- ======================================================================
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ayelén', 'Saez', 'Ituzaingó 198, Vaqueros', '3874202364', 'ayelensaez@gmail.com'); SET @cli1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Juan', 'Pérez', 'La Rioja 1181, Salta', '3876698174', 'juanperez@gmail.com'); SET @cli2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Laura', 'Gómez', 'Ituzaingó 386, Salta', '3876782907', 'lauragomez@gmail.com'); SET @cli3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Jesús', 'González', 'Av. Virrey Toledo 657, Salta', '3876481204', 'jesusgonzalez@gmail.com'); SET @cli4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Mariana', 'López', 'Av. Sarmiento 1150, Vaqueros', '3874880911', 'marianalopez@gmail.com'); SET @cli5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Pablo', 'Martínez', 'Zuviría 613, Salta', '3875194892', 'pablomartinez@gmail.com'); SET @cli6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Gabriela', 'Díaz', 'Av. Belgrano 1069, Salta', '3876223094', 'gabrieladiaz@gmail.com'); SET @cli7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ricardo', 'Morales', 'Córdoba 772, Vaqueros', '3874708287', 'ricardomorales@gmail.com'); SET @cli8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Silvina', 'Ríos', 'Leguizamón 976, Salta', '3874337155', 'silvinarios@gmail.com'); SET @cli9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Esteban', 'Vera', 'Alvarado 259, Salta', '3876819777', 'estebanvera@gmail.com'); SET @cli10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Andrea', 'Cabrera', 'Ituzaingó 627, Salta', '3876024060', 'andreacabrera@gmail.com'); SET @cli11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Marcelo', 'Ojeda', 'Mitre 305, Salta', '3875991162', 'marceloojeda@gmail.com'); SET @cli12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Verónica', 'Soria', 'Jujuy 916, Salta', '3875548507', 'veronicasoria@gmail.com'); SET @cli13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Claudio', 'Navarro', 'Caseros 594, Salta', '3876560712', 'claudionavarro@gmail.com'); SET @cli14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Romina', 'Paz', 'Alvarado 1246, Salta', '3876620509', 'rominapaz@gmail.com'); SET @cli15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Fernando', 'Ibarra', 'Mitre 1705, Salta', '3874945030', 'fernandoibarra@gmail.com'); SET @cli16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Lorena', 'Méndez', 'San Martín 605, Cerrillos', '3875082621', 'lorenamendez@gmail.com'); SET @cli17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Damián', 'Coronel', 'Caseros 1120, Salta', '3876162096', 'damiancoronel@gmail.com'); SET @cli18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Cecilia', 'Bravo', 'Jujuy 1401, Rosario de Lerma', '3876246299', 'ceciliabravo@gmail.com'); SET @cli19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Alejandro', 'Funes', 'Av. Belgrano 547, Salta', '3876707498', 'alejandrofunes@gmail.com'); SET @cli20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Noelia', 'Rivero', 'Alvarado 661, Rosario de Lerma', '3875133986', 'noeliarivero@gmail.com'); SET @cli21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Gustavo', 'Aráoz', 'Av. Entre Ríos 1370, Salta', '3875319045', 'gustavoaraoz@gmail.com'); SET @cli22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Mónica', 'Chávez', 'Zuviría 797, Salta', '3875283999', 'monicachavez@gmail.com'); SET @cli23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Hugo', 'Saravia', 'Av. Bolivia 1065, Salta', '3874722313', 'hugosaravia@gmail.com'); SET @cli24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Patricia', 'Cornejo', 'Av. Belgrano 444, Salta', '3876708764', 'patriciacornejo@gmail.com'); SET @cli25 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Walter', 'Burgos', 'Caseros 537, Salta', '3874891916', 'walterburgos@gmail.com'); SET @cli26 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Yanina', 'Sulca', 'Alvarado 349, Salta', '3875168639', 'yaninasulca@gmail.com'); SET @cli27 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Oscar', 'Mamaní', 'Av. Entre Ríos 1321, Salta', '3876736462', 'oscarmamani@gmail.com'); SET @cli28 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Elena', 'Gareca', 'Pueyrredón 1709, Salta', '3876651388', 'elenagareca@gmail.com'); SET @cli29 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Iara', 'Tapia', 'La Rioja 582, Salta', '3876048567', 'iaratapia@gmail.com'); SET @cli30 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Rodrigo', 'Zapata', 'Ituzaingó 1032, Salta', '3874207132', 'rodrigozapata@gmail.com'); SET @cli31 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Daniela', 'Zerpa', 'España 611, Cerrillos', '3874614344', 'danielazerpa@gmail.com'); SET @cli32 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Emilio', 'Guaymás', 'Av. Bolivia 582, Salta', '3876463834', 'emilioguaymas@gmail.com'); SET @cli33 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Natalia', 'Yapura', 'Leguizamón 229, La Caldera', '3876759905', 'nataliayapura@gmail.com'); SET @cli34 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Sergio', 'Choque', 'Pueyrredón 116, Salta', '3876725531', 'sergiochoque@gmail.com'); SET @cli35 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Paola', 'Lamas', 'Av. Entre Ríos 564, Vaqueros', '3874165690', 'paolalamas@gmail.com'); SET @cli36 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Martín', 'Tejerina', 'Pueyrredón 1136, Salta', '3876279220', 'martintejerina@gmail.com'); SET @cli37 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Carla', 'Arias', 'Av. Entre Ríos 1093, Salta', '3875851536', 'carlaarias@gmail.com'); SET @cli38 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Javier', 'Lobo', 'Balcarce 199, Cerrillos', '3875282399', 'javierlobo@gmail.com'); SET @cli39 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Milagros', 'Copa', 'Urquiza 865, Salta', '3876258020', 'milagroscopa@gmail.com'); SET @cli40 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Colegio', 'Santa Teresa', 'Av. Sarmiento 838, Vaqueros', '3874114762', 'eventos@colegiosantateresa.edu.ar'); SET @cli41 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Bodega', 'Los Cardones', 'Av. Paraguay 1006, Salta', '3875310691', 'contacto@loscardones.com.ar'); SET @cli42 = LAST_INSERT_ID();
-- Clientes agregados para tener mas movimiento (los ultimos seis son instituciones y empresas)
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Agustín', 'Aguirre', 'Las Rosas 1609, Vaqueros', '3875319901', 'agustinaguirre@hotmail.com'); SET @cli43 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Belén', 'Burgos', 'Córdoba 243, Salta', '3874518969', 'belenburgos@hotmail.com'); SET @cli44 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Bruno', 'Cáceres', 'Santiago del Estero 849, Salta', '3875989872', 'brunocaceres@gmail.com'); SET @cli45 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Candela', 'Chocobar', 'Pellegrini 568, Rosario de Lerma', '3875862681', 'candelachocobar@gmail.com'); SET @cli46 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Daniel', 'Delgado', 'Deán Funes 2269, Rosario de Lerma', '3874435433', 'danieldelgado@gmail.com'); SET @cli47 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Emilia', 'Escobar', 'Av. Reyes Católicos 2261, San Lorenzo', '3876907439', 'emiliaescobar@yahoo.com.ar'); SET @cli48 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ezequiel', 'Figueroa', 'Santiago del Estero 1138, Cerrillos', '3875370154', 'ezequielfigueroa@hotmail.com'); SET @cli49 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Gabriela', 'Guanuco', 'Santiago del Estero 795, Rosario de Lerma', '3875693150', 'gabrielaguanuco@yahoo.com.ar'); SET @cli50 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Hernán', 'Ibarra', 'Los Ceibos 423, Salta', '3874537446', 'hernanibarra@hotmail.com'); SET @cli51 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Inés', 'Juárez', 'Caseros 1717, Salta', '3876186990', 'inesjuarez@hotmail.com'); SET @cli52 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Jimena', 'Lamas', 'España 1436, San Lorenzo', '3876474395', 'jimenalamas@hotmail.com'); SET @cli53 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Leandro', 'Maidana', 'Belgrano 761, Salta', '3874293723', 'leandromaidana@hotmail.com'); SET @cli54 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Lorena', 'Nieva', 'Pellegrini 619, Cerrillos', '3876949516', 'lorenanieva@hotmail.com'); SET @cli55 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Marcos', 'Olmos', 'Alvarado 1393, Salta', '3874470553', 'marcosolmos@yahoo.com.ar'); SET @cli56 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Natalia', 'Paz', 'Belgrano 790, Salta', '3875628130', 'nataliapaz@yahoo.com.ar'); SET @cli57 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Óscar', 'Quispe', 'Av. Bolivia 584, Cerrillos', '3876908096', 'oscarquispe@yahoo.com.ar'); SET @cli58 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Paula', 'Ríos', 'Mitre 1877, Vaqueros', '3875047701', 'paularios@gmail.com'); SET @cli59 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ramiro', 'Sarapura', 'Mitre 1110, Rosario de Lerma', '3875343491', 'ramirosarapura@yahoo.com.ar'); SET @cli60 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Romina', 'Tolaba', 'Santiago del Estero 2048, Cerrillos', '3874121243', 'rominatolaba@yahoo.com.ar'); SET @cli61 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Sebastián', 'Uriburu', 'Caseros 2260, Rosario de Lerma', '3874354524', 'sebastianuriburu@hotmail.com'); SET @cli62 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Silvina', 'Vilte', 'España 972, Salta', '3876628515', 'silvinavilte@hotmail.com'); SET @cli63 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Tatiana', 'Yapura', 'Mitre 1073, Salta', '3876469916', 'tatianayapura@gmail.com'); SET @cli64 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ulises', 'Zerpa', 'Buenos Aires 909, Vaqueros', '3875115285', 'uliseszerpa@gmail.com'); SET @cli65 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Verónica', 'Alanís', 'Caseros 962, Salta', '3874390253', 'veronicaalanis@yahoo.com.ar'); SET @cli66 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Walter', 'Bustos', 'Deán Funes 573, Vaqueros', '3876145453', 'walterbustos@yahoo.com.ar'); SET @cli67 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ximena', 'Cardozo', 'Mitre 600, Salta', '3875706275', 'ximenacardozo@hotmail.com'); SET @cli68 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Yamila', 'Díaz Vélez', 'Alvarado 1568, Vaqueros', '3876025376', 'yamiladiazvelez@hotmail.com'); SET @cli69 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Rodrigo', 'Echenique', 'Alvarado 2296, Salta', '3874272036', 'rodrigoechenique@yahoo.com.ar'); SET @cli70 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Daniela', 'Farfán', 'España 2314, Salta', '3875363166', 'danielafarfan@gmail.com'); SET @cli71 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Esteban', 'Guaymás', 'Lerma 1965, Vaqueros', '3875052289', 'estebanguaymas@gmail.com'); SET @cli72 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Fernanda', 'Herrera Cornejo', 'Av. Tavella 1186, Salta', '3875332544', 'fernandaherreracornejo@yahoo.com.ar'); SET @cli73 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Germán', 'Isasmendi', 'España 1760, Salta', '3875778866', 'germanisasmendi@gmail.com'); SET @cli74 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Mónica', 'Liendro', 'Lerma 2305, Rosario de Lerma', '3874361265', 'monicaliendro@yahoo.com.ar'); SET @cli75 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Luis', 'Mendoza', 'Av. San Martín 1563, Rosario de Lerma', '3876607192', 'luismendoza@hotmail.com'); SET @cli76 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Andrea', 'Ontiveros', 'Córdoba 1592, San Lorenzo', '3874170034', 'andreaontiveros@hotmail.com'); SET @cli77 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Cristian', 'Patrón Costas', 'Av. San Martín 232, Salta', '3874282570', 'cristianpatroncostas@yahoo.com.ar'); SET @cli78 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Noelia', 'Rueda', 'Caseros 756, Cerrillos', '3875051396', 'noeliarueda@gmail.com'); SET @cli79 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Franco', 'Sajama', 'Belgrano 1671, Salta', '3875018673', 'francosajama@gmail.com'); SET @cli80 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Antonella', 'Torino', 'Buenos Aires 868, Cerrillos', '3876928609', 'antonellatorino@gmail.com'); SET @cli81 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Alejandro', 'Valdez', 'Av. Bolivia 687, Salta', '3874329639', 'alejandrovaldez@hotmail.com'); SET @cli82 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Celeste', 'Arce', 'Mitre 1400, Salta', '3874111738', 'celestearce@gmail.com'); SET @cli83 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Mauricio', 'Bravo', 'Los Ceibos 1844, Salta', '3875027941', 'mauriciobravo@yahoo.com.ar'); SET @cli84 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Victoria', 'Colque', 'Mitre 1934, Salta', '3875619789', 'victoriacolque@hotmail.com'); SET @cli85 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Emanuel', 'Cruz Mamaní', 'Santiago del Estero 2125, La Caldera', '3876886758', 'emanuelcruzmamani@hotmail.com'); SET @cli86 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Soledad', 'Fleming', 'Las Rosas 1009, Vaqueros', '3874602915', 'soledadfleming@yahoo.com.ar'); SET @cli87 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Gustavo', 'Gareca', 'Los Ceibos 2033, Vaqueros', '3874990748', 'gustavogareca@hotmail.com'); SET @cli88 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Pilar', 'Humacata', 'Córdoba 787, Salta', '3874615300', 'pilarhumacata@gmail.com'); SET @cli89 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Hugo', 'Llanos', 'Las Rosas 2112, Salta', '3874069754', 'hugollanos@gmail.com'); SET @cli90 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ariana', 'Morales', 'España 246, Salta', '3876040353', 'arianamorales@hotmail.com'); SET @cli91 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Raúl', 'Ovejero', 'Deán Funes 734, Salta', '3874504569', 'raulovejero@hotmail.com'); SET @cli92 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Colegio', 'Del Milagro', 'Deán Funes 617, Salta', '3876161150', 'eventos@colegiodelmilagro.edu.ar'); SET @cli93 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Escuela', 'Normal Gral. Güemes', 'Santiago del Estero 2204, Salta', '3874699274', 'direccion@normalguemes.edu.ar'); SET @cli94 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Universidad', 'Católica de Salta', 'Belgrano 305, San Lorenzo', '3875214449', 'ceremonial@ucasal.edu.ar'); SET @cli95 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Cooperativa', 'Agrícola Cerrillos', 'Av. Tavella 2183, San Lorenzo', '3876225478', 'administracion@coopcerrillos.com.ar'); SET @cli96 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Club', 'Juventud Antoniana', 'Santiago del Estero 1729, Cerrillos', '3876899609', 'secretaria@juventudantoniana.com.ar'); SET @cli97 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Constructora', 'Andina', 'Alvarado 1713, Salta', '3875706357', 'rrhh@constructoraandina.com.ar'); SET @cli98 = LAST_INSERT_ID();

-- ======================================================================
-- 16. METODOS DE PAGO (el cheque se dejo de aceptar, pero quedan pagos viejos con cheque)
-- ======================================================================
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago, activo, fecha_baja) VALUES ('Efectivo', 1, NULL); SET @mp1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago, activo, fecha_baja) VALUES ('Transferencia Bancaria', 1, NULL); SET @mp2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago, activo, fecha_baja) VALUES ('Tarjeta de Débito', 1, NULL); SET @mp3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago, activo, fecha_baja) VALUES ('Tarjeta de Crédito', 1, NULL); SET @mp4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago, activo, fecha_baja) VALUES ('Mercado Pago', 1, NULL); SET @mp5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago, activo, fecha_baja) VALUES ('Cheque', 0, '2026-03-31 12:00:00'); SET @mp6 = LAST_INSERT_ID();

-- ======================================================================
-- 17. RESERVAS (ordenadas por fecha de carga; monto_total = suma de los precios de sus servicios)
-- ======================================================================
-- Las finalizadas y anuladas son eventos que ya pasaron (o se cancelaron); las confirmadas
-- y pendientes son a futuro. El numero de comprobante es el propio id_reserva.
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli86, 'Casamiento Cruz Mamaní', '2025-04-20', '21:00:00', 'Club 20 de Febrero', '07:00:00', 470000, 'FINALIZADA', '2024-09-05 17:40:00', @usr_gutierrezm, NULL, '', NULL); SET @res1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli83, 'Fiesta de 15 Arce', '2025-03-25', '21:30:00', 'Finca La Encantada', '06:00:00', 815000, 'FINALIZADA', '2024-09-09 11:00:00', @usr_admin, NULL, '', NULL); SET @res2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli61, 'Casamiento Tolaba', '2025-01-24', '20:30:00', 'Hotel Alejandro I', '07:00:00', 665000, 'FINALIZADA', '2024-09-15 16:15:00', @usr_delafuentec, NULL, '', NULL); SET @res3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli8, 'Casamiento Morales', '2025-03-21', '21:30:00', 'Quinta Las Moritas', '06:00:00', 855000, 'FINALIZADA', '2024-09-19 13:50:00', @usr_alarconf, NULL, '', NULL); SET @res4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Festival Los Cardones', '2025-01-04', '19:00:00', 'Hotel Sheraton Salta', '10:00:00', 695000, 'ANULADA', '2024-09-20 14:15:00', @usr_alarconf, '2024-10-24 19:40:00', 'Se suspendió el evento por pronóstico de lluvia.', @usr_delafuentec); SET @res5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli30, 'Pool Party Tapia', '2025-01-03', '15:00:00', 'Salón Golden', '06:00:00', 195000, 'FINALIZADA', '2024-09-21 12:30:00', @usr_admin, NULL, '', NULL); SET @res6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli78, 'Casamiento Patrón Costas', '2025-02-22', '21:00:00', 'Salón Golden', '07:00:00', 485000, 'FINALIZADA', '2024-09-30 20:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli36, 'Casamiento Lamas', '2025-05-04', '21:30:00', 'Club 20 de Febrero', '07:00:00', 1035000, 'FINALIZADA', '2024-10-16 14:50:00', @usr_herrerav, NULL, '', NULL); SET @res8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli53, 'Cumpleaños Infantil Lamas', '2025-01-05', '17:00:00', 'Salón Il Divo', '04:00:00', 105000, 'FINALIZADA', '2024-10-26 10:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli56, 'Peña Folclórica Olmos', '2025-01-28', '22:00:00', 'Finca La Encantada', '06:00:00', 410000, 'FINALIZADA', '2024-11-01 15:30:00', @usr_delafuentec, NULL, '', NULL); SET @res10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli58, 'Fiesta de 15 Quispe', '2025-03-16', '22:00:00', 'Complejo Ruta 51', '06:00:00', 465000, 'FINALIZADA', '2024-11-13 19:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli35, 'Casamiento Choque', '2025-04-06', '21:30:00', 'Hotel Sheraton Salta', '06:00:00', 875000, 'FINALIZADA', '2024-11-19 18:40:00', @usr_alarconf, NULL, '', NULL); SET @res12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli72, 'Peña Folclórica Guaymás', '2025-02-01', '22:00:00', 'Club 20 de Febrero', '06:00:00', 595000, 'FINALIZADA', '2024-11-22 18:00:00', @usr_herrerav, NULL, '', NULL); SET @res13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli46, 'Casamiento Chocobar', '2025-02-23', '20:30:00', 'Quinta San Lorenzo', '06:00:00', 720000, 'FINALIZADA', '2024-11-24 10:50:00', @usr_admin, NULL, '', NULL); SET @res14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli31, 'Cumpleaños Infantil Zapata', '2025-01-05', '16:00:00', 'Salón Los Álamos', '03:00:00', 110000, 'ANULADA', '2024-11-24 15:40:00', @usr_herrerav, '2024-12-25 16:00:00', 'Se suspendió el evento por pronóstico de lluvia.', @usr_herrerav); SET @res15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli50, 'Pool Party Guanuco', '2025-02-09', '16:00:00', 'Quinta San Lorenzo', '05:00:00', 215000, 'FINALIZADA', '2024-11-30 16:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli26, 'Pool Party Burgos', '2025-01-19', '16:00:00', 'Finca La Encantada', '05:00:00', 215000, 'FINALIZADA', '2024-12-04 16:20:00', @usr_alarconf, NULL, '', NULL); SET @res17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli7, 'Karaoke Díaz', '2025-02-08', '22:00:00', 'Centro de Convenciones Salta', '04:00:00', 125000, 'FINALIZADA', '2024-12-08 17:30:00', @usr_alarconf, NULL, '', NULL); SET @res18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli38, 'Bautismo Arias', '2025-03-02', '12:30:00', 'Salón Il Divo', '05:00:00', 130000, 'FINALIZADA', '2024-12-14 10:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli12, 'Fiesta de 15 Ojeda', '2025-04-05', '22:00:00', 'Centro de Convenciones Salta', '06:00:00', 655000, 'FINALIZADA', '2024-12-23 16:40:00', @usr_delafuentec, NULL, '', NULL); SET @res20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli85, 'Fiesta de 15 Colque', '2025-07-12', '22:00:00', 'Salón Il Divo', '06:00:00', 335000, 'FINALIZADA', '2024-12-28 15:20:00', @usr_admin, NULL, '', NULL); SET @res21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Evento Corporativo Los Cardones', '2025-04-07', '09:00:00', 'Quinta Las Moritas', '05:00:00', 695000, 'FINALIZADA', '2025-01-03 17:15:00', @usr_herrerav, NULL, '', NULL); SET @res22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli71, 'Karaoke Farfán', '2025-02-07', '21:00:00', 'Salón Golden', '04:00:00', 130000, 'FINALIZADA', '2025-01-04 16:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli21, 'Casamiento Rivero', '2025-03-29', '21:30:00', 'Centro de Convenciones Salta', '06:00:00', 1135000, 'FINALIZADA', '2025-01-04 16:30:00', @usr_herrerav, NULL, '', NULL); SET @res24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Evento Corporativo Andina', '2025-04-01', '20:00:00', 'Club Gimnasia y Tiro', '08:00:00', 700000, 'FINALIZADA', '2025-01-09 14:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res25 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli37, 'Cumpleaños Infantil Tejerina', '2025-02-16', '17:00:00', 'Hotel Alejandro I', '04:00:00', 115000, 'FINALIZADA', '2025-01-11 11:45:00', @usr_herrerav, NULL, '', NULL); SET @res26 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli89, 'Peña Folclórica Humacata', '2025-02-17', '21:30:00', 'Finca La Encantada', '06:00:00', 625000, 'FINALIZADA', '2025-01-12 09:15:00', @usr_alarconf, NULL, '', NULL); SET @res27 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli6, 'Casamiento Martínez', '2025-09-14', '21:30:00', 'Centro de Convenciones Salta', '07:00:00', 935000, 'FINALIZADA', '2025-01-20 09:50:00', @usr_delafuentec, NULL, '', NULL); SET @res28 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli23, 'Casamiento Chávez', '2025-04-20', '20:30:00', 'Hotel Sheraton Salta', '06:00:00', 720000, 'FINALIZADA', '2025-01-23 11:15:00', @usr_admin, NULL, '', NULL); SET @res29 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli25, 'Fiesta de 15 Cornejo', '2025-06-29', '21:30:00', 'Hotel Sheraton Salta', '06:00:00', 825000, 'FINALIZADA', '2025-01-24 15:40:00', @usr_gutierrezm, NULL, '', NULL); SET @res30 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli51, 'Cumpleaños Infantil Ibarra', '2025-05-17', '17:00:00', 'Quinta Las Moritas', '03:00:00', 115000, 'FINALIZADA', '2025-01-24 20:20:00', @usr_alarconf, NULL, '', NULL); SET @res31 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli91, 'Casamiento Morales', '2025-09-07', '21:00:00', 'Salón Fénix', '06:00:00', 1165000, 'FINALIZADA', '2025-01-28 19:45:00', @usr_herrerav, NULL, '', NULL); SET @res32 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli13, 'Casamiento Soria', '2025-05-09', '21:00:00', 'Salón Del Valle', '06:00:00', 1440000, 'FINALIZADA', '2025-01-31 11:30:00', @usr_admin, NULL, '', NULL); SET @res33 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli27, 'Peña Folclórica Sulca', '2025-04-13', '21:30:00', 'Finca La Encantada', '07:00:00', 450000, 'FINALIZADA', '2025-02-03 10:30:00', @usr_alarconf, NULL, '', NULL); SET @res34 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli87, 'Karaoke Fleming', '2025-05-09', '22:00:00', 'Quinta San Lorenzo', '04:00:00', 135000, 'FINALIZADA', '2025-02-10 12:40:00', @usr_herrerav, NULL, '', NULL); SET @res35 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli79, 'Cumpleaños de 18 Rueda', '2025-06-08', '23:00:00', 'Finca La Encantada', '04:00:00', 460000, 'FINALIZADA', '2025-02-11 09:40:00', @usr_gutierrezm, NULL, '', NULL); SET @res36 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli21, 'Fiesta de 15 Rivero', '2025-03-29', '21:30:00', 'Finca La Encantada', '06:00:00', 515000, 'FINALIZADA', '2025-02-12 09:45:00', @usr_herrerav, NULL, '', NULL); SET @res37 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli78, 'Cumpleaños de 18 Patrón Costas', '2025-06-01', '22:00:00', 'Salón Del Valle', '05:00:00', 410000, 'FINALIZADA', '2025-02-18 09:30:00', @usr_alarconf, NULL, '', NULL); SET @res38 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli67, 'Fiesta de 15 Bustos', '2025-04-04', '21:30:00', 'Salón Del Valle', '06:00:00', 695000, 'FINALIZADA', '2025-02-20 11:40:00', @usr_delafuentec, NULL, '', NULL); SET @res39 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli25, 'Fiesta de 15 Cornejo', '2025-05-25', '21:30:00', 'Club 20 de Febrero', '06:00:00', 520000, 'FINALIZADA', '2025-02-21 13:50:00', @usr_delafuentec, NULL, '', NULL); SET @res40 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli70, 'Fiesta de 15 Echenique', '2025-08-17', '21:30:00', 'Quinta Las Moritas', '06:00:00', 580000, 'FINALIZADA', '2025-02-25 12:20:00', @usr_admin, NULL, '', NULL); SET @res41 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli65, 'Cumpleaños de 18 Zerpa', '2025-05-02', '23:00:00', 'Quinta Las Moritas', '05:00:00', 590000, 'FINALIZADA', '2025-02-26 09:20:00', @usr_alarconf, NULL, '', NULL); SET @res42 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli86, 'Casamiento Cruz Mamaní', '2025-09-12', '21:00:00', 'Salón Del Valle', '06:00:00', 970000, 'FINALIZADA', '2025-02-26 17:20:00', @usr_delafuentec, NULL, '', NULL); SET @res43 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli9, 'Fiesta de 15 Ríos', '2025-07-04', '22:00:00', 'Hotel Alejandro I', '06:00:00', 525000, 'FINALIZADA', '2025-02-27 19:30:00', @usr_admin, NULL, '', NULL); SET @res44 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli95, 'Evento Corporativo Católica de Salta', '2025-05-23', '20:00:00', 'Complejo Ruta 51', '04:00:00', 155000, 'FINALIZADA', '2025-03-04 15:45:00', @usr_delafuentec, NULL, '', NULL); SET @res45 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli57, 'Cumpleaños de 18 Paz', '2025-04-26', '22:00:00', 'Salón Il Divo', '04:00:00', 470000, 'FINALIZADA', '2025-03-05 13:30:00', @usr_alarconf, NULL, '', NULL); SET @res46 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli39, 'Casamiento Lobo', '2025-07-27', '21:30:00', 'Salón Del Valle', '06:00:00', 625000, 'FINALIZADA', '2025-03-08 17:00:00', @usr_alarconf, NULL, '', NULL); SET @res47 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli37, 'Cumpleaños Infantil Tejerina', '2025-04-26', '17:00:00', 'Salón Il Divo', '04:00:00', 120000, 'FINALIZADA', '2025-03-11 20:00:00', @usr_gutierrezm, NULL, '', NULL); SET @res48 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli61, 'Fiesta de 15 Tolaba', '2025-08-24', '21:30:00', 'Hotel Alejandro I', '06:00:00', 410000, 'FINALIZADA', '2025-03-12 09:15:00', @usr_admin, NULL, '', NULL); SET @res49 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli51, 'Cumpleaños Infantil Ibarra', '2025-05-31', '16:00:00', 'Hotel Sheraton Salta', '04:00:00', 120000, 'FINALIZADA', '2025-03-12 11:20:00', @usr_admin, NULL, '', NULL); SET @res50 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli47, 'Fiesta de 15 Delgado', '2025-10-05', '22:00:00', 'Salón Il Divo', '06:00:00', 815000, 'FINALIZADA', '2025-03-12 13:50:00', @usr_delafuentec, NULL, '', NULL); SET @res51 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli75, 'Cumpleaños Infantil Liendro', '2025-04-06', '16:00:00', 'Salón Golden', '03:00:00', 120000, 'FINALIZADA', '2025-03-13 20:15:00', @usr_delafuentec, NULL, '', NULL); SET @res52 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli10, 'Fiesta de 15 Vera', '2025-11-08', '22:00:00', 'Salón Golden', '06:00:00', 755000, 'FINALIZADA', '2025-03-14 13:30:00', @usr_admin, NULL, '', NULL); SET @res53 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli41, 'Acto de Graduación Santa Teresa', '2025-06-30', '10:00:00', 'Club Gimnasia y Tiro', '03:00:00', 220000, 'FINALIZADA', '2025-03-14 19:20:00', @usr_admin, NULL, '', NULL); SET @res54 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli76, 'Casamiento Mendoza', '2025-10-31', '20:30:00', 'Quinta San Lorenzo', '06:00:00', 1040000, 'FINALIZADA', '2025-03-15 10:10:00', @usr_alarconf, NULL, '', NULL); SET @res55 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli90, 'Fiesta de 15 Llanos', '2025-11-02', '22:00:00', 'Complejo Ruta 51', '06:00:00', 715000, 'FINALIZADA', '2025-03-17 19:45:00', @usr_delafuentec, NULL, '', NULL); SET @res56 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli82, 'Fiesta de Egresados Valdez', '2025-10-24', '22:30:00', 'Hotel Alejandro I', '05:00:00', 675000, 'FINALIZADA', '2025-03-22 11:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res57 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli27, 'Bautismo Sulca', '2025-05-17', '12:30:00', 'Quinta Las Moritas', '05:00:00', 145000, 'FINALIZADA', '2025-03-22 18:40:00', @usr_delafuentec, NULL, '', NULL); SET @res58 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli34, 'Bautismo Yapura', '2025-05-18', '13:00:00', 'Quinta Las Moritas', '05:00:00', 145000, 'FINALIZADA', '2025-03-22 19:00:00', @usr_alarconf, NULL, '', NULL); SET @res59 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli32, 'Fiesta de 15 Zerpa', '2025-06-14', '21:30:00', 'Salón Del Valle', '06:00:00', 535000, 'FINALIZADA', '2025-03-24 13:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res60 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli72, 'Fiesta de 15 Guaymás', '2025-06-01', '21:30:00', 'Club 20 de Febrero', '06:00:00', 825000, 'ANULADA', '2025-03-24 14:00:00', @usr_gutierrezm, '2025-03-30 11:40:00', 'El cliente no confirmó y no respondió los llamados.', @usr_delafuentec); SET @res61 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli50, 'Casamiento Guanuco', '2025-10-17', '20:30:00', 'Hotel Sheraton Salta', '06:00:00', 1295000, 'FINALIZADA', '2025-04-01 12:30:00', @usr_herrerav, NULL, '', NULL); SET @res62 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli20, 'Peña Folclórica Funes', '2025-06-20', '22:00:00', 'Quinta Las Moritas', '07:00:00', 480000, 'FINALIZADA', '2025-04-01 16:15:00', @usr_herrerav, NULL, '', NULL); SET @res63 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli34, 'Cumpleaños Infantil Yapura', '2025-06-29', '17:00:00', 'Quinta San Lorenzo', '03:00:00', 125000, 'FINALIZADA', '2025-04-02 15:15:00', @usr_alarconf, NULL, '', NULL); SET @res64 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli45, 'Fiesta de Egresados Cáceres', '2025-10-19', '22:00:00', 'Finca La Encantada', '05:00:00', 970000, 'FINALIZADA', '2025-04-03 10:15:00', @usr_admin, NULL, '', NULL); SET @res65 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli16, 'Cumpleaños de 18 Ibarra', '2025-05-16', '23:00:00', 'Hotel Alejandro I', '05:00:00', 430000, 'FINALIZADA', '2025-04-05 17:30:00', @usr_herrerav, NULL, '', NULL); SET @res66 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli58, 'Bautismo Quispe', '2025-06-28', '13:00:00', 'Hotel Alejandro I', '04:00:00', 145000, 'FINALIZADA', '2025-04-08 09:10:00', @usr_herrerav, NULL, '', NULL); SET @res67 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli20, 'Casamiento Funes', '2025-05-24', '20:30:00', 'Salón Golden', '07:00:00', 595000, 'FINALIZADA', '2025-04-10 18:20:00', @usr_admin, NULL, '', NULL); SET @res68 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli55, 'Fiesta de Egresados Nieva', '2025-10-18', '22:30:00', 'Hotel Sheraton Salta', '06:00:00', 800000, 'FINALIZADA', '2025-04-12 12:15:00', @usr_delafuentec, NULL, '', NULL); SET @res69 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli65, 'Cumpleaños Infantil Zerpa', '2025-06-21', '16:00:00', 'Salón Fénix', '04:00:00', 125000, 'FINALIZADA', '2025-04-15 10:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res70 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli5, 'Cumpleaños Infantil López', '2025-07-26', '17:00:00', 'Finca La Encantada', '04:00:00', 125000, 'FINALIZADA', '2025-04-22 20:45:00', @usr_alarconf, NULL, '', NULL); SET @res71 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli57, 'Show en Vivo Paz', '2025-07-27', '21:00:00', 'Salón Golden', '04:00:00', 490000, 'FINALIZADA', '2025-04-24 14:00:00', @usr_admin, NULL, '', NULL); SET @res72 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli62, 'Cumpleaños de 18 Uriburu', '2025-06-07', '23:00:00', 'Club Gimnasia y Tiro', '04:00:00', 440000, 'FINALIZADA', '2025-04-24 18:50:00', @usr_delafuentec, NULL, '', NULL); SET @res73 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Evento Corporativo Andina', '2025-07-03', '19:00:00', 'Club Gimnasia y Tiro', '08:00:00', 460000, 'FINALIZADA', '2025-04-24 18:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res74 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli14, 'Casamiento Navarro', '2025-11-09', '20:30:00', 'Salón Los Álamos', '07:00:00', 1325000, 'FINALIZADA', '2025-04-25 17:45:00', @usr_herrerav, NULL, '', NULL); SET @res75 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli12, 'Casamiento Ojeda', '2025-05-25', '21:30:00', 'Quinta San Lorenzo', '07:00:00', 1030000, 'FINALIZADA', '2025-04-28 18:20:00', @usr_admin, NULL, '', NULL); SET @res76 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli46, 'Bautismo Chocobar', '2025-08-17', '13:00:00', 'Quinta San Lorenzo', '04:00:00', 150000, 'FINALIZADA', '2025-04-29 09:40:00', @usr_herrerav, NULL, '', NULL); SET @res77 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli75, 'Fiesta de Egresados Liendro', '2025-11-01', '22:30:00', 'Salón Fénix', '05:00:00', 815000, 'FINALIZADA', '2025-05-02 13:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res78 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli48, 'Fiesta de 15 Escobar', '2025-06-06', '21:30:00', 'Quinta Las Moritas', '06:00:00', 560000, 'FINALIZADA', '2025-05-06 09:20:00', @usr_herrerav, NULL, '', NULL); SET @res79 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli71, 'Bautismo Farfán', '2025-06-15', '12:30:00', 'Centro de Convenciones Salta', '04:00:00', 150000, 'FINALIZADA', '2025-05-06 11:45:00', @usr_alarconf, NULL, '', NULL); SET @res80 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli28, 'Karaoke Mamaní', '2025-07-31', '21:00:00', 'Salón Il Divo', '04:00:00', 145000, 'FINALIZADA', '2025-05-06 19:50:00', @usr_herrerav, NULL, '', NULL); SET @res81 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli16, 'Cumpleaños de 18 Ibarra', '2025-07-04', '22:00:00', 'Quinta San Lorenzo', '05:00:00', 445000, 'ANULADA', '2025-05-08 09:00:00', @usr_herrerav, '2025-05-11 10:20:00', 'El cliente canceló el evento por problemas personales.', @usr_gutierrezm); SET @res82 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli36, 'Cumpleaños Infantil Lamas', '2025-07-13', '17:00:00', 'Finca La Encantada', '04:00:00', 130000, 'FINALIZADA', '2025-05-13 19:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res83 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli89, 'Karaoke Humacata', '2025-08-03', '22:00:00', 'Hotel Sheraton Salta', '04:00:00', 145000, 'FINALIZADA', '2025-05-14 17:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res84 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli40, 'Cumpleaños de 18 Copa', '2025-08-09', '23:00:00', 'Finca La Encantada', '04:00:00', 695000, 'FINALIZADA', '2025-05-17 14:15:00', @usr_herrerav, NULL, '', NULL); SET @res85 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli68, 'Cumpleaños de 18 Cardozo', '2025-08-16', '23:00:00', 'Salón Del Valle', '05:00:00', 450000, 'FINALIZADA', '2025-05-17 20:10:00', @usr_herrerav, NULL, '', NULL); SET @res86 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli13, 'Fiesta de 15 Soria', '2025-12-05', '21:30:00', 'Finca La Encantada', '06:00:00', 385000, 'FINALIZADA', '2025-05-23 14:30:00', @usr_admin, NULL, '', NULL); SET @res87 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli19, 'Fiesta de 15 Bravo', '2025-07-24', '22:00:00', 'Salón Golden', '06:00:00', 1120000, 'FINALIZADA', '2025-05-23 18:30:00', @usr_delafuentec, NULL, '', NULL); SET @res88 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli4, 'Cumpleaños Infantil González', '2025-07-26', '16:00:00', 'Centro de Convenciones Salta', '03:00:00', 130000, 'FINALIZADA', '2025-05-24 12:45:00', @usr_alarconf, NULL, '', NULL); SET @res89 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli90, 'Cumpleaños de 18 Llanos', '2025-06-28', '23:00:00', 'Centro de Convenciones Salta', '05:00:00', 640000, 'FINALIZADA', '2025-05-25 18:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res90 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli68, 'Casamiento Cardozo', '2025-06-13', '21:00:00', 'Quinta Las Moritas', '06:00:00', 1365000, 'FINALIZADA', '2025-05-26 11:10:00', @usr_herrerav, NULL, '', NULL); SET @res91 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli52, 'Show en Vivo Juárez', '2025-07-12', '21:00:00', 'Complejo Ruta 51', '04:00:00', 505000, 'FINALIZADA', '2025-05-27 14:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res92 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli17, 'Cumpleaños de 18 Méndez', '2025-09-22', '23:00:00', 'Club Gimnasia y Tiro', '05:00:00', 455000, 'ANULADA', '2025-05-29 19:45:00', @usr_delafuentec, '2025-08-09 20:40:00', 'Se suspendió el evento por pronóstico de lluvia.', @usr_gutierrezm); SET @res93 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli11, 'Casamiento Cabrera', '2025-11-01', '21:00:00', 'Quinta Las Moritas', '07:00:00', 1060000, 'FINALIZADA', '2025-05-30 12:20:00', @usr_delafuentec, NULL, '', NULL); SET @res94 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli17, 'Peña Folclórica Méndez', '2025-08-22', '21:30:00', 'Complejo Ruta 51', '06:00:00', 560000, 'FINALIZADA', '2025-05-31 11:00:00', @usr_delafuentec, NULL, '', NULL); SET @res95 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli91, 'Cumpleaños de 18 Morales', '2025-09-05', '22:00:00', 'Quinta San Lorenzo', '04:00:00', 455000, 'FINALIZADA', '2025-06-01 11:45:00', @usr_admin, NULL, '', NULL); SET @res96 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli15, 'Peña Folclórica Paz', '2025-08-28', '22:00:00', 'Complejo Ruta 51', '06:00:00', 505000, 'FINALIZADA', '2025-06-02 13:10:00', @usr_admin, NULL, '', NULL); SET @res97 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli32, 'Karaoke Zerpa', '2025-07-19', '22:00:00', 'Salón Los Álamos', '04:00:00', 150000, 'FINALIZADA', '2025-06-04 09:30:00', @usr_alarconf, NULL, '', NULL); SET @res98 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli88, 'Cumpleaños de 18 Gareca', '2025-09-19', '23:00:00', 'Salón Fénix', '04:00:00', 460000, 'FINALIZADA', '2025-06-10 09:45:00', @usr_herrerav, NULL, '', NULL); SET @res99 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli9, 'Bautismo Ríos', '2025-09-27', '13:00:00', 'Quinta San Lorenzo', '04:00:00', 155000, 'FINALIZADA', '2025-06-10 10:15:00', @usr_herrerav, NULL, '', NULL); SET @res100 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli2, 'Casamiento Pérez', '2025-09-26', '20:30:00', 'Salón Il Divo', '06:00:00', 685000, 'FINALIZADA', '2025-06-10 17:45:00', @usr_herrerav, NULL, '', NULL); SET @res101 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli69, 'Show en Vivo Díaz Vélez', '2025-09-26', '21:00:00', 'Complejo Ruta 51', '04:00:00', 510000, 'FINALIZADA', '2025-06-12 17:00:00', @usr_alarconf, NULL, '', NULL); SET @res102 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli59, 'Karaoke Ríos', '2025-08-15', '21:00:00', 'Hotel Alejandro I', '04:00:00', 150000, 'FINALIZADA', '2025-06-15 19:00:00', @usr_delafuentec, NULL, '', NULL); SET @res103 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli52, 'Peña Folclórica Juárez', '2025-08-29', '21:30:00', 'Finca La Encantada', '06:00:00', 730000, 'FINALIZADA', '2025-06-15 20:00:00', @usr_gutierrezm, NULL, '', NULL); SET @res104 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli84, 'Casamiento Bravo', '2025-11-10', '21:00:00', 'Hotel Alejandro I', '06:00:00', 1205000, 'FINALIZADA', '2025-06-17 10:15:00', @usr_admin, NULL, '', NULL); SET @res105 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli8, 'Karaoke Morales', '2025-08-15', '21:00:00', 'Salón Golden', '04:00:00', 155000, 'ANULADA', '2025-06-24 19:15:00', @usr_herrerav, '2025-07-13 14:40:00', 'Se cargó por error, el cliente pidió otra fecha.', @usr_gutierrezm); SET @res106 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli49, 'Casamiento Figueroa', '2025-09-08', '21:00:00', 'Club 20 de Febrero', '07:00:00', 1340000, 'FINALIZADA', '2025-06-25 09:10:00', @usr_herrerav, NULL, '', NULL); SET @res107 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli44, 'Fiesta de 15 Burgos', '2025-10-05', '21:30:00', 'Finca La Encantada', '06:00:00', 585000, 'FINALIZADA', '2025-06-26 14:40:00', @usr_delafuentec, NULL, '', NULL); SET @res108 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli59, 'Peña Folclórica Ríos', '2025-07-26', '22:00:00', 'Salón Fénix', '07:00:00', 575000, 'FINALIZADA', '2025-06-30 19:10:00', @usr_admin, NULL, '', NULL); SET @res109 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli44, 'Cumpleaños Infantil Burgos', '2025-09-07', '16:00:00', 'Hotel Alejandro I', '03:00:00', 135000, 'FINALIZADA', '2025-07-02 16:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res110 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli74, 'Bautismo Isasmendi', '2025-08-03', '13:00:00', 'Quinta Las Moritas', '04:00:00', 160000, 'ANULADA', '2025-07-07 19:50:00', @usr_alarconf, '2025-07-20 14:20:00', 'El cliente no confirmó y no respondió los llamados.', @usr_delafuentec); SET @res111 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli48, 'Cumpleaños de 18 Escobar', '2025-08-31', '23:00:00', 'Complejo Ruta 51', '04:00:00', 665000, 'FINALIZADA', '2025-07-09 10:15:00', @usr_delafuentec, NULL, '', NULL); SET @res112 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli26, 'Bautismo Burgos', '2025-09-20', '13:00:00', 'Complejo Ruta 51', '04:00:00', 160000, 'FINALIZADA', '2025-07-10 15:30:00', @usr_admin, NULL, '', NULL); SET @res113 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli80, 'Cumpleaños Infantil Sajama', '2025-09-21', '16:00:00', 'Salón Del Valle', '03:00:00', 140000, 'FINALIZADA', '2025-07-23 09:45:00', @usr_herrerav, NULL, '', NULL); SET @res114 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli63, 'Cumpleaños Infantil Vilte', '2025-10-25', '17:00:00', 'Salón Los Álamos', '03:00:00', 140000, 'FINALIZADA', '2025-07-23 19:30:00', @usr_delafuentec, NULL, '', NULL); SET @res115 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli67, 'Karaoke Bustos', '2025-08-16', '21:00:00', 'Complejo Ruta 51', '04:00:00', 155000, 'FINALIZADA', '2025-07-25 13:30:00', @usr_admin, NULL, '', NULL); SET @res116 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli53, 'Cumpleaños Infantil Lamas', '2025-08-23', '17:00:00', 'Centro de Convenciones Salta', '03:00:00', 140000, 'FINALIZADA', '2025-07-27 20:40:00', @usr_delafuentec, NULL, '', NULL); SET @res117 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli92, 'Casamiento Ovejero', '2025-12-05', '20:30:00', 'Complejo Ruta 51', '06:00:00', 1120000, 'FINALIZADA', '2025-07-29 20:15:00', @usr_alarconf, NULL, '', NULL); SET @res118 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli23, 'Cumpleaños Infantil Chávez', '2025-09-13', '17:00:00', 'Quinta Las Moritas', '03:00:00', 140000, 'FINALIZADA', '2025-07-30 20:30:00', @usr_delafuentec, NULL, '', NULL); SET @res119 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli35, 'Cumpleaños de 18 Choque', '2025-09-13', '22:00:00', 'Complejo Ruta 51', '04:00:00', 540000, 'FINALIZADA', '2025-08-03 14:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res120 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli2, 'Casamiento Pérez', '2025-11-02', '21:00:00', 'Hotel Alejandro I', '07:00:00', 660000, 'FINALIZADA', '2025-08-06 14:20:00', @usr_alarconf, NULL, '', NULL); SET @res121 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Festival Los Cardones', '2025-08-30', '19:00:00', 'Quinta San Lorenzo', '08:00:00', 970000, 'FINALIZADA', '2025-08-10 16:50:00', @usr_admin, NULL, '', NULL); SET @res122 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli69, 'Bautismo Díaz Vélez', '2025-12-07', '13:00:00', 'Salón Los Álamos', '05:00:00', 165000, 'FINALIZADA', '2025-08-10 18:20:00', @usr_alarconf, NULL, '', NULL); SET @res123 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli11, 'Casamiento Cabrera', '2025-10-03', '21:00:00', 'Club Gimnasia y Tiro', '06:00:00', 1460000, 'FINALIZADA', '2025-08-13 16:10:00', @usr_delafuentec, NULL, '', NULL); SET @res124 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Fiesta de Fin de Año Los Cardones', '2025-12-20', '21:30:00', 'Club Gimnasia y Tiro', '05:00:00', 695000, 'FINALIZADA', '2025-08-13 17:45:00', @usr_herrerav, NULL, '', NULL); SET @res125 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli82, 'Cumpleaños Infantil Valdez', '2025-09-20', '17:00:00', 'Salón Del Valle', '03:00:00', 140000, 'FINALIZADA', '2025-08-15 09:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res126 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli93, 'Acto de Graduación Del Milagro', '2025-12-09', '10:00:00', 'Complejo Ruta 51', '04:00:00', 585000, 'FINALIZADA', '2025-08-23 17:15:00', @usr_alarconf, NULL, '', NULL); SET @res127 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Fiesta de Fin de Año Los Cardones', '2025-12-14', '21:00:00', 'Hotel Alejandro I', '05:00:00', 705000, 'FINALIZADA', '2025-08-25 15:50:00', @usr_herrerav, NULL, '', NULL); SET @res128 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli81, 'Fiesta de 15 Torino', '2026-04-18', '22:00:00', 'Hotel Sheraton Salta', '06:00:00', 480000, 'FINALIZADA', '2025-08-26 09:10:00', @usr_admin, NULL, '', NULL); SET @res129 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli55, 'Pool Party Nieva', '2025-10-19', '15:00:00', 'Salón Los Álamos', '06:00:00', 275000, 'FINALIZADA', '2025-08-26 13:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res130 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli29, 'Fiesta de 15 Gareca', '2025-12-06', '21:30:00', 'Quinta Las Moritas', '06:00:00', 955000, 'FINALIZADA', '2025-08-31 13:00:00', @usr_admin, NULL, '', NULL); SET @res131 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli22, 'Cumpleaños de 18 Aráoz', '2025-10-11', '23:00:00', 'Club Gimnasia y Tiro', '05:00:00', 495000, 'FINALIZADA', '2025-08-31 13:30:00', @usr_delafuentec, NULL, '', NULL); SET @res132 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli85, 'Bautismo Colque', '2025-12-27', '13:00:00', 'Salón Il Divo', '05:00:00', 170000, 'FINALIZADA', '2025-09-06 09:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res133 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli49, 'Casamiento Figueroa', '2025-11-21', '21:30:00', 'Salón Golden', '06:00:00', 1220000, 'FINALIZADA', '2025-09-06 10:20:00', @usr_delafuentec, NULL, '', NULL); SET @res134 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli47, 'Pool Party Delgado', '2025-12-07', '16:00:00', 'Finca La Encantada', '06:00:00', 340000, 'FINALIZADA', '2025-09-06 19:00:00', @usr_alarconf, NULL, '', NULL); SET @res135 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli19, 'Fiesta de 15 Bravo', '2025-10-12', '21:30:00', 'Salón Fénix', '06:00:00', 625000, 'FINALIZADA', '2025-09-10 13:40:00', @usr_alarconf, NULL, '', NULL); SET @res136 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli10, 'Cumpleaños Infantil Vera', '2025-12-21', '17:00:00', 'Salón Il Divo', '03:00:00', 145000, 'ANULADA', '2025-09-10 20:50:00', @usr_admin, '2025-12-03 09:00:00', 'Se suspendió el evento por pronóstico de lluvia.', @usr_delafuentec); SET @res137 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli83, 'Show en Vivo Arce', '2025-10-03', '21:00:00', 'Centro de Convenciones Salta', '05:00:00', 555000, 'FINALIZADA', '2025-09-11 18:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res138 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli6, 'Fiesta de 15 Martínez', '2025-12-21', '22:00:00', 'Quinta San Lorenzo', '06:00:00', 625000, 'FINALIZADA', '2025-09-12 11:20:00', @usr_admin, NULL, '', NULL); SET @res139 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli40, 'Fiesta de 15 Copa', '2026-05-10', '22:00:00', 'Club Gimnasia y Tiro', '06:00:00', 635000, 'FINALIZADA', '2025-09-12 12:40:00', @usr_admin, NULL, '', NULL); SET @res140 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli31, 'Cumpleaños Infantil Zapata', '2025-11-02', '17:00:00', 'Quinta Las Moritas', '04:00:00', 145000, 'FINALIZADA', '2025-09-13 11:10:00', @usr_delafuentec, NULL, '', NULL); SET @res141 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli76, 'Pool Party Mendoza', '2025-10-11', '15:00:00', 'Quinta San Lorenzo', '06:00:00', 280000, 'ANULADA', '2025-09-13 19:00:00', @usr_alarconf, '2025-09-20 14:40:00', 'El cliente no confirmó y no respondió los llamados.', @usr_delafuentec); SET @res142 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli93, 'Acto de Graduación Del Milagro', '2025-11-14', '10:00:00', 'Club 20 de Febrero', '03:00:00', 255000, 'FINALIZADA', '2025-09-13 19:45:00', @usr_delafuentec, NULL, '', NULL); SET @res143 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli18, 'Pool Party Coronel', '2025-11-14', '15:00:00', 'Quinta San Lorenzo', '05:00:00', 280000, 'FINALIZADA', '2025-09-17 17:10:00', @usr_alarconf, NULL, '', NULL); SET @res144 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli62, 'Peña Folclórica Uriburu', '2025-10-26', '22:00:00', 'Complejo Ruta 51', '07:00:00', 855000, 'FINALIZADA', '2025-09-26 11:00:00', @usr_alarconf, NULL, '', NULL); SET @res145 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli33, 'Cumpleaños Infantil Guaymás', '2025-11-30', '17:00:00', 'Salón Los Álamos', '04:00:00', 145000, 'FINALIZADA', '2025-09-30 10:45:00', @usr_delafuentec, NULL, '', NULL); SET @res146 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli93, 'Acto de Graduación Del Milagro', '2025-11-06', '19:00:00', 'Quinta San Lorenzo', '03:00:00', 260000, 'FINALIZADA', '2025-10-01 17:00:00', @usr_gutierrezm, NULL, '', NULL); SET @res147 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli33, 'Fiesta de Egresados Guaymás', '2025-10-26', '22:00:00', 'Complejo Ruta 51', '05:00:00', 1150000, 'FINALIZADA', '2025-10-06 19:00:00', @usr_alarconf, NULL, '', NULL); SET @res148 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli48, 'Casamiento Escobar', '2026-05-01', '21:30:00', 'Salón Fénix', '06:00:00', 1320000, 'FINALIZADA', '2025-10-07 09:10:00', @usr_delafuentec, NULL, '', NULL); SET @res149 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli64, 'Casamiento Yapura', '2025-11-07', '20:30:00', 'Club 20 de Febrero', '06:00:00', 1815000, 'FINALIZADA', '2025-10-08 14:30:00', @usr_alarconf, NULL, '', NULL); SET @res150 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli63, 'Fiesta de Egresados Vilte', '2025-11-16', '22:30:00', 'Salón Fénix', '06:00:00', 935000, 'FINALIZADA', '2025-10-09 18:15:00', @usr_alarconf, NULL, '', NULL); SET @res151 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli41, 'Acto de Graduación Santa Teresa', '2025-11-25', '19:00:00', 'Salón Del Valle', '03:00:00', 610000, 'FINALIZADA', '2025-10-09 19:15:00', @usr_herrerav, NULL, '', NULL); SET @res152 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli38, 'Cumpleaños de 18 Arias', '2026-01-10', '23:00:00', 'Quinta San Lorenzo', '04:00:00', 510000, 'ANULADA', '2025-10-10 19:10:00', @usr_admin, '2025-12-21 11:00:00', 'El cliente contrató otra empresa.', @usr_admin); SET @res153 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli24, 'Cumpleaños Infantil Saravia', '2025-12-28', '17:00:00', 'Salón Fénix', '04:00:00', 150000, 'FINALIZADA', '2025-10-11 17:00:00', @usr_gutierrezm, NULL, '', NULL); SET @res154 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli41, 'Acto de Graduación Santa Teresa', '2025-12-11', '19:00:00', 'Salón Fénix', '04:00:00', 265000, 'FINALIZADA', '2025-10-11 20:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res155 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli41, 'Acto de Graduación Santa Teresa', '2025-12-17', '10:00:00', 'Salón Del Valle', '03:00:00', 265000, 'FINALIZADA', '2025-10-14 20:00:00', @usr_delafuentec, NULL, '', NULL); SET @res156 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli54, 'Cumpleaños de 18 Maidana', '2025-12-05', '22:00:00', 'Club 20 de Febrero', '04:00:00', 510000, 'FINALIZADA', '2025-10-15 16:30:00', @usr_admin, NULL, '', NULL); SET @res157 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli94, 'Acto de Graduación Normal Gral. Güemes', '2025-12-04', '10:00:00', 'Finca La Encantada', '03:00:00', 265000, 'FINALIZADA', '2025-10-17 16:40:00', @usr_delafuentec, NULL, '', NULL); SET @res158 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli43, 'Cumpleaños Infantil Aguirre', '2025-12-27', '16:00:00', 'Club 20 de Febrero', '04:00:00', 150000, 'FINALIZADA', '2025-10-20 14:50:00', @usr_herrerav, NULL, '', NULL); SET @res159 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli14, 'Fiesta de 15 Navarro', '2026-04-24', '22:00:00', 'Salón Del Valle', '06:00:00', 645000, 'FINALIZADA', '2025-10-21 14:40:00', @usr_delafuentec, NULL, '', NULL); SET @res160 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli73, 'Fiesta de 15 Herrera Cornejo', '2025-11-14', '21:30:00', 'Salón Il Divo', '06:00:00', 865000, 'FINALIZADA', '2025-10-26 16:30:00', @usr_alarconf, NULL, '', NULL); SET @res161 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli41, 'Acto de Graduación Santa Teresa', '2025-12-09', '10:00:00', 'Club 20 de Febrero', '04:00:00', 270000, 'FINALIZADA', '2025-10-31 18:45:00', @usr_admin, NULL, '', NULL); SET @res162 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli40, 'Peña Folclórica Copa', '2026-02-13', '22:00:00', 'Complejo Ruta 51', '07:00:00', 885000, 'FINALIZADA', '2025-11-04 15:00:00', @usr_delafuentec, NULL, '', NULL); SET @res163 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli3, 'Cumpleaños Infantil Gómez', '2026-01-24', '16:00:00', 'Hotel Sheraton Salta', '03:00:00', 150000, 'FINALIZADA', '2025-11-06 17:20:00', @usr_delafuentec, NULL, '', NULL); SET @res164 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli96, 'Fiesta de Fin de Año Agrícola Cerrillos', '2025-12-27', '21:30:00', 'Salón Golden', '05:00:00', 1105000, 'FINALIZADA', '2025-11-07 20:45:00', @usr_alarconf, NULL, '', NULL); SET @res165 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli64, 'Peña Folclórica Yapura', '2026-02-14', '22:00:00', 'Finca La Encantada', '06:00:00', 825000, 'FINALIZADA', '2025-11-08 16:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res166 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli28, 'Pool Party Mamaní', '2026-01-17', '15:00:00', 'Quinta Las Moritas', '06:00:00', 360000, 'FINALIZADA', '2025-11-13 13:00:00', @usr_herrerav, NULL, '', NULL); SET @res167 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli43, 'Pool Party Aguirre', '2026-02-01', '16:00:00', 'Salón Los Álamos', '06:00:00', 295000, 'FINALIZADA', '2025-11-15 19:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res168 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli22, 'Peña Folclórica Aráoz', '2026-02-22', '22:00:00', 'Salón Il Divo', '07:00:00', 835000, 'FINALIZADA', '2025-11-24 18:30:00', @usr_delafuentec, NULL, '', NULL); SET @res169 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli73, 'Cumpleaños Infantil Herrera Cornejo', '2026-01-17', '16:00:00', 'Salón Il Divo', '03:00:00', 155000, 'FINALIZADA', '2025-11-25 16:15:00', @usr_admin, NULL, '', NULL); SET @res170 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli80, 'Cumpleaños de 18 Sajama', '2026-03-27', '22:00:00', 'Quinta Las Moritas', '04:00:00', 750000, 'FINALIZADA', '2025-11-28 19:20:00', @usr_admin, NULL, '', NULL); SET @res171 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli77, 'Karaoke Ontiveros', '2026-03-20', '22:00:00', 'Quinta San Lorenzo', '04:00:00', 175000, 'FINALIZADA', '2025-12-09 17:10:00', @usr_herrerav, NULL, '', NULL); SET @res172 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli60, 'Pool Party Sarapura', '2026-01-12', '15:00:00', 'Quinta Las Moritas', '06:00:00', 305000, 'FINALIZADA', '2025-12-13 18:00:00', @usr_herrerav, NULL, '', NULL); SET @res173 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli54, 'Cumpleaños Infantil Maidana', '2026-04-12', '17:00:00', 'Club Gimnasia y Tiro', '03:00:00', 155000, 'FINALIZADA', '2025-12-23 18:10:00', @usr_alarconf, NULL, '', NULL); SET @res174 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli84, 'Pool Party Bravo', '2026-01-18', '15:00:00', 'Quinta Las Moritas', '06:00:00', 370000, 'FINALIZADA', '2025-12-24 14:45:00', @usr_admin, NULL, '', NULL); SET @res175 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Evento Corporativo Andina', '2026-04-01', '09:00:00', 'Complejo Ruta 51', '05:00:00', 965000, 'FINALIZADA', '2025-12-29 18:50:00', @usr_herrerav, NULL, '', NULL); SET @res176 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli56, 'Fiesta de 15 Olmos', '2026-07-10', '22:00:00', 'Salón Golden', '06:00:00', 685000, 'FINALIZADA', '2025-12-30 15:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res177 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli15, 'Karaoke Paz', '2026-02-20', '22:00:00', 'Complejo Ruta 51', '04:00:00', 180000, 'FINALIZADA', '2025-12-31 11:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res178 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli24, 'Casamiento Saravia', '2026-03-21', '21:30:00', 'Salón Los Álamos', '06:00:00', 1120000, 'FINALIZADA', '2026-01-03 14:50:00', @usr_admin, NULL, '', NULL); SET @res179 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli28, 'Bautismo Mamaní', '2026-05-02', '12:30:00', 'Salón Del Valle', '04:00:00', 185000, 'FINALIZADA', '2026-01-17 10:40:00', @usr_alarconf, NULL, '', NULL); SET @res180 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli29, 'Peña Folclórica Gareca', '2026-02-15', '22:00:00', 'Finca La Encantada', '06:00:00', 875000, 'FINALIZADA', '2026-01-26 19:50:00', @usr_delafuentec, NULL, '', NULL); SET @res181 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Evento Corporativo Los Cardones', '2026-05-12', '19:00:00', 'Salón Golden', '05:00:00', 205000, 'FINALIZADA', '2026-01-27 09:40:00', @usr_admin, NULL, '', NULL); SET @res182 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli74, 'Cumpleaños Infantil Isasmendi', '2026-03-15', '17:00:00', 'Quinta San Lorenzo', '03:00:00', 160000, 'FINALIZADA', '2026-01-27 16:00:00', @usr_delafuentec, NULL, '', NULL); SET @res183 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli1, 'Casamiento Saez', '2026-09-25', '21:00:00', 'Hotel Alejandro I', '06:00:00', 1065000, 'ANULADA', '2026-01-30 14:00:00', @usr_admin, '2026-09-18 14:00:00', 'El cliente no confirmó y no respondió los llamados.', @usr_herrerav); SET @res184 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli45, 'Cumpleaños Infantil Cáceres', '2026-04-05', '16:00:00', 'Centro de Convenciones Salta', '04:00:00', 160000, 'FINALIZADA', '2026-02-02 20:00:00', @usr_alarconf, NULL, '', NULL); SET @res185 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Evento Corporativo Los Cardones', '2026-04-16', '09:00:00', 'Salón Fénix', '04:00:00', 205000, 'ANULADA', '2026-02-04 15:15:00', @usr_admin, '2026-02-06 14:20:00', 'Se suspendió el evento por pronóstico de lluvia.', @usr_delafuentec); SET @res186 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli38, 'Cumpleaños Infantil Arias', '2026-05-31', '16:00:00', 'Salón Il Divo', '03:00:00', 160000, 'FINALIZADA', '2026-02-04 19:50:00', @usr_herrerav, NULL, '', NULL); SET @res187 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli4, 'Cumpleaños de 18 González', '2026-04-26', '23:00:00', 'Quinta Las Moritas', '04:00:00', 630000, 'FINALIZADA', '2026-02-08 10:40:00', @usr_herrerav, NULL, '', NULL); SET @res188 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli70, 'Fiesta de 15 Echenique', '2026-03-07', '22:00:00', 'Salón Los Álamos', '06:00:00', 705000, 'FINALIZADA', '2026-02-08 14:15:00', @usr_herrerav, NULL, '', NULL); SET @res189 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli1, 'Cumpleaños de 18 Saez', '2026-05-29', '23:00:00', 'Salón Golden', '04:00:00', 795000, 'FINALIZADA', '2026-02-09 13:20:00', @usr_admin, NULL, '', NULL); SET @res190 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli81, 'Bautismo Torino', '2026-04-04', '12:30:00', 'Salón Fénix', '05:00:00', 190000, 'FINALIZADA', '2026-02-12 12:20:00', @usr_alarconf, NULL, '', NULL); SET @res191 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli25, 'Karaoke Cornejo', '2026-06-05', '21:00:00', 'Finca La Encantada', '04:00:00', 185000, 'FINALIZADA', '2026-02-13 18:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res192 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli4, 'Fiesta de 15 González', '2026-10-09', '22:00:00', 'Salón Golden', '06:00:00', 860000, 'FINALIZADA', '2026-02-14 09:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res193 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli39, 'Cumpleaños de 18 Lobo', '2026-06-06', '22:00:00', 'Centro de Convenciones Salta', '04:00:00', 800000, 'FINALIZADA', '2026-02-16 18:10:00', @usr_alarconf, NULL, '', NULL); SET @res194 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli81, 'Casamiento Torino', '2026-09-26', '20:30:00', 'Club Gimnasia y Tiro', '07:00:00', 1080000, 'FINALIZADA', '2026-02-17 17:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res195 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli80, 'Fiesta de Egresados Sajama', '2026-10-04', '22:00:00', 'Salón Golden', '06:00:00', 1035000, 'FINALIZADA', '2026-02-18 10:10:00', @usr_herrerav, NULL, '', NULL); SET @res196 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli5, 'Fiesta de 15 López', '2026-04-18', '21:30:00', 'Complejo Ruta 51', '06:00:00', 715000, 'ANULADA', '2026-02-24 14:45:00', @usr_delafuentec, '2026-03-04 10:40:00', 'El cliente canceló el evento por problemas personales.', @usr_gutierrezm); SET @res197 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli69, 'Casamiento Díaz Vélez', '2026-08-28', '20:30:00', 'Hotel Sheraton Salta', '07:00:00', 1400000, 'ANULADA', '2026-02-24 17:40:00', @usr_herrerav, '2026-07-31 11:20:00', 'El cliente no confirmó y no respondió los llamados.', @usr_admin); SET @res198 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli65, 'Casamiento Zerpa', '2026-10-23', '21:30:00', 'Hotel Sheraton Salta', '06:00:00', 1020000, 'FINALIZADA', '2026-02-25 15:45:00', @usr_alarconf, NULL, '', NULL); SET @res199 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli18, 'Cumpleaños de 18 Coronel', '2026-03-29', '23:00:00', 'Salón Il Divo', '05:00:00', 570000, 'FINALIZADA', '2026-02-28 12:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res200 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli7, 'Peña Folclórica Díaz', '2026-04-10', '21:30:00', 'Hotel Sheraton Salta', '07:00:00', 635000, 'FINALIZADA', '2026-03-03 19:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res201 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli56, 'Cumpleaños de 18 Olmos', '2026-04-30', '23:00:00', 'Salón Del Valle', '05:00:00', 810000, 'ANULADA', '2026-03-06 15:00:00', @usr_admin, '2026-04-13 18:40:00', 'El cliente no confirmó y no respondió los llamados.', @usr_delafuentec); SET @res202 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli9, 'Cumpleaños Infantil Ríos', '2026-06-21', '17:00:00', 'Quinta Las Moritas', '03:00:00', 165000, 'FINALIZADA', '2026-03-06 17:30:00', @usr_herrerav, NULL, '', NULL); SET @res203 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli79, 'Casamiento Rueda', '2026-04-03', '21:00:00', 'Complejo Ruta 51', '07:00:00', 1960000, 'FINALIZADA', '2026-03-07 09:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res204 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli66, 'Fiesta de 15 Alanís', '2026-04-03', '21:30:00', 'Complejo Ruta 51', '06:00:00', 720000, 'FINALIZADA', '2026-03-09 09:30:00', @usr_herrerav, NULL, '', NULL); SET @res205 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli66, 'Casamiento Alanís', '2026-04-10', '21:30:00', 'Salón Los Álamos', '07:00:00', 1100000, 'FINALIZADA', '2026-03-12 12:40:00', @usr_herrerav, NULL, '', NULL); SET @res206 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli74, 'Fiesta de Egresados Isasmendi', '2026-09-26', '22:00:00', 'Club Gimnasia y Tiro', '05:00:00', 665000, 'FINALIZADA', '2026-03-12 20:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res207 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli5, 'Fiesta de 15 López', '2026-06-12', '21:30:00', 'Complejo Ruta 51', '06:00:00', 725000, 'FINALIZADA', '2026-03-14 14:20:00', @usr_delafuentec, NULL, '', NULL); SET @res208 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli14, 'Fiesta de 15 Navarro', '2026-08-07', '22:00:00', 'Salón Fénix', '06:00:00', 725000, 'FINALIZADA', '2026-03-15 09:15:00', @usr_admin, NULL, '', NULL); SET @res209 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli3, 'Karaoke Gómez', '2026-04-05', '21:00:00', 'Salón Los Álamos', '04:00:00', 190000, 'FINALIZADA', '2026-03-18 20:10:00', @usr_alarconf, NULL, '', NULL); SET @res210 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli71, 'Bautismo Farfán', '2026-06-27', '13:00:00', 'Club Gimnasia y Tiro', '05:00:00', 195000, 'FINALIZADA', '2026-03-20 11:30:00', @usr_alarconf, NULL, '', NULL); SET @res211 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli52, 'Cumpleaños de 18 Juárez', '2026-06-13', '23:00:00', 'Quinta Las Moritas', '05:00:00', 815000, 'FINALIZADA', '2026-03-21 13:10:00', @usr_alarconf, NULL, '', NULL); SET @res212 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli92, 'Fiesta de 15 Ovejero', '2026-10-02', '22:00:00', 'Club 20 de Febrero', '06:00:00', 565000, 'FINALIZADA', '2026-03-24 13:15:00', @usr_delafuentec, NULL, '', NULL); SET @res213 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli97, 'Festival Juventud Antoniana', '2026-07-10', '18:00:00', 'Quinta San Lorenzo', '08:00:00', 1160000, 'FINALIZADA', '2026-03-27 11:20:00', @usr_admin, NULL, '', NULL); SET @res214 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli27, 'Show en Vivo Sulca', '2026-06-12', '21:00:00', 'Quinta Las Moritas', '05:00:00', 645000, 'FINALIZADA', '2026-03-29 16:45:00', @usr_delafuentec, NULL, '', NULL); SET @res215 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli87, 'Casamiento Fleming', '2026-09-12', '21:30:00', 'Salón Golden', '06:00:00', 1605000, 'FINALIZADA', '2026-03-30 20:45:00', @usr_delafuentec, NULL, '', NULL); SET @res216 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli39, 'Fiesta de 15 Lobo', '2026-05-07', '21:30:00', 'Finca La Encantada', '06:00:00', 1125000, 'FINALIZADA', '2026-04-01 12:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res217 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli55, 'Casamiento Nieva', '2026-05-12', '20:30:00', 'Salón Los Álamos', '07:00:00', 1430000, 'FINALIZADA', '2026-04-02 10:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res218 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli57, 'Cumpleaños de 18 Paz', '2026-07-17', '23:00:00', 'Club Gimnasia y Tiro', '04:00:00', 585000, 'ANULADA', '2026-04-04 19:40:00', @usr_alarconf, '2026-05-01 19:40:00', 'El salón canceló la fecha.', @usr_admin); SET @res219 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli60, 'Bautismo Sarapura', '2026-05-02', '12:30:00', 'Quinta San Lorenzo', '05:00:00', 200000, 'FINALIZADA', '2026-04-07 14:45:00', @usr_delafuentec, NULL, '', NULL); SET @res220 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli67, 'Bautismo Bustos', '2026-05-31', '13:00:00', 'Quinta Las Moritas', '05:00:00', 200000, 'ANULADA', '2026-04-08 15:45:00', @usr_delafuentec, '2026-05-19 12:00:00', 'El salón canceló la fecha.', @usr_admin); SET @res221 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Evento Corporativo Andina', '2026-05-14', '09:00:00', 'Quinta Las Moritas', '08:00:00', 1360000, 'FINALIZADA', '2026-04-10 18:00:00', @usr_delafuentec, NULL, '', NULL); SET @res222 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli16, 'Bautismo Ibarra', '2026-06-14', '13:00:00', 'Hotel Alejandro I', '05:00:00', 200000, 'FINALIZADA', '2026-04-11 13:10:00', @usr_admin, NULL, '', NULL); SET @res223 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli86, 'Fiesta de Egresados Cruz Mamaní', '2026-11-20', '22:30:00', 'Salón Del Valle', '05:00:00', 1320000, 'CONFIRMADA', '2026-04-12 09:40:00', @usr_alarconf, NULL, '', NULL); SET @res224 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli29, 'Peña Folclórica Gareca', '2026-07-12', '21:30:00', 'Quinta San Lorenzo', '07:00:00', 655000, 'FINALIZADA', '2026-04-12 12:15:00', @usr_delafuentec, NULL, '', NULL); SET @res225 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Evento Corporativo Andina', '2026-06-12', '20:00:00', 'Salón Del Valle', '05:00:00', 220000, 'FINALIZADA', '2026-04-12 17:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res226 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli20, 'Cumpleaños Infantil Funes', '2026-07-26', '17:00:00', 'Salón Fénix', '04:00:00', 170000, 'FINALIZADA', '2026-04-13 16:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res227 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli92, 'Karaoke Ovejero', '2026-08-08', '22:00:00', 'Complejo Ruta 51', '04:00:00', 195000, 'FINALIZADA', '2026-04-13 17:00:00', @usr_herrerav, NULL, '', NULL); SET @res228 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli88, 'Fiesta de 15 Gareca', '2026-09-06', '22:00:00', 'Club Gimnasia y Tiro', '06:00:00', 575000, 'FINALIZADA', '2026-04-14 10:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res229 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli97, 'Festival Juventud Antoniana', '2026-07-25', '19:00:00', 'Club 20 de Febrero', '08:00:00', 1175000, 'FINALIZADA', '2026-04-14 10:40:00', @usr_admin, NULL, '', NULL); SET @res230 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli72, 'Cumpleaños de 18 Guaymás', '2026-07-18', '23:00:00', 'Salón Del Valle', '04:00:00', 830000, 'FINALIZADA', '2026-04-14 17:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res231 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Festival Los Cardones', '2026-07-18', '19:00:00', 'Hotel Sheraton Salta', '08:00:00', 930000, 'FINALIZADA', '2026-04-14 20:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res232 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli37, 'Karaoke Tejerina', '2026-05-25', '22:00:00', 'Salón Golden', '04:00:00', 195000, 'FINALIZADA', '2026-04-18 16:00:00', @usr_herrerav, NULL, '', NULL); SET @res233 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli90, 'Cumpleaños Infantil Llanos', '2026-06-21', '16:00:00', 'Quinta Las Moritas', '04:00:00', 170000, 'FINALIZADA', '2026-04-25 09:10:00', @usr_alarconf, NULL, '', NULL); SET @res234 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli95, 'Fiesta de Fin de Año Católica de Salta', '2026-12-12', '21:30:00', 'Finca La Encantada', '06:00:00', 1500000, 'CONFIRMADA', '2026-04-28 17:50:00', @usr_herrerav, NULL, '', NULL); SET @res235 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli4, 'Fiesta de Egresados González', '2026-10-25', '22:30:00', 'Salón Los Álamos', '05:00:00', 1345000, 'FINALIZADA', '2026-05-01 12:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res236 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli80, 'Cumpleaños Infantil Sajama', '2026-05-24', '17:00:00', 'Salón Fénix', '03:00:00', 175000, 'FINALIZADA', '2026-05-04 20:50:00', @usr_herrerav, NULL, '', NULL); SET @res237 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli11, 'Cumpleaños de 18 Cabrera', '2026-07-11', '23:00:00', 'Centro de Convenciones Salta', '05:00:00', 595000, 'FINALIZADA', '2026-05-05 18:00:00', @usr_delafuentec, NULL, '', NULL); SET @res238 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli87, 'Show en Vivo Fleming', '2026-05-21', '21:00:00', 'Club 20 de Febrero', '05:00:00', 665000, 'FINALIZADA', '2026-05-06 18:00:00', @usr_delafuentec, NULL, '', NULL); SET @res239 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli91, 'Fiesta de 15 Morales', '2026-08-09', '21:30:00', 'Quinta San Lorenzo', '06:00:00', 1405000, 'FINALIZADA', '2026-05-07 13:40:00', @usr_delafuentec, NULL, '', NULL); SET @res240 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Fiesta de Fin de Año Andina', '2026-12-27', '21:00:00', 'Club Gimnasia y Tiro', '06:00:00', 1110000, 'CONFIRMADA', '2026-05-09 17:15:00', @usr_admin, NULL, '', NULL); SET @res241 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli7, 'Show en Vivo Díaz', '2026-07-03', '21:00:00', 'Salón Los Álamos', '05:00:00', 665000, 'FINALIZADA', '2026-05-09 18:30:00', @usr_delafuentec, NULL, '', NULL); SET @res242 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli49, 'Cumpleaños Infantil Figueroa', '2026-08-15', '16:00:00', 'Salón Del Valle', '04:00:00', 175000, 'FINALIZADA', '2026-05-11 16:30:00', @usr_delafuentec, NULL, '', NULL); SET @res243 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli30, 'Cumpleaños de 18 Tapia', '2026-07-31', '22:00:00', 'Salón Fénix', '04:00:00', 850000, 'FINALIZADA', '2026-05-13 11:50:00', @usr_admin, NULL, '', NULL); SET @res244 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli43, 'Cumpleaños Infantil Aguirre', '2026-08-01', '16:00:00', 'Salón Del Valle', '03:00:00', 175000, 'ANULADA', '2026-05-14 18:20:00', @usr_herrerav, '2026-06-02 09:20:00', 'El salón canceló la fecha.', @usr_herrerav); SET @res245 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli88, 'Fiesta de Egresados Gareca', '2026-10-16', '22:00:00', 'Salón Los Álamos', '06:00:00', 1105000, 'FINALIZADA', '2026-05-17 17:15:00', @usr_alarconf, NULL, '', NULL); SET @res246 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli78, 'Fiesta de 15 Patrón Costas', '2026-08-02', '22:00:00', 'Salón Il Divo', '06:00:00', 1500000, 'FINALIZADA', '2026-05-20 14:30:00', @usr_alarconf, NULL, '', NULL); SET @res247 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli54, 'Bautismo Maidana', '2026-09-06', '13:00:00', 'Salón Fénix', '04:00:00', 205000, 'ANULADA', '2026-05-20 20:10:00', @usr_alarconf, '2026-06-22 09:20:00', 'El cliente contrató otra empresa.', @usr_admin); SET @res248 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli95, 'Evento Corporativo Católica de Salta', '2026-09-01', '20:00:00', 'Complejo Ruta 51', '05:00:00', 635000, 'FINALIZADA', '2026-05-21 09:15:00', @usr_delafuentec, NULL, '', NULL); SET @res249 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli93, 'Acto de Graduación Del Milagro', '2026-07-03', '18:00:00', 'Salón Il Divo', '03:00:00', 720000, 'FINALIZADA', '2026-05-24 10:15:00', @usr_delafuentec, NULL, '', NULL); SET @res250 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli36, 'Karaoke Lamas', '2026-06-10', '21:00:00', 'Salón Il Divo', '04:00:00', 200000, 'ANULADA', '2026-05-24 10:50:00', @usr_alarconf, '2026-06-06 12:20:00', 'El cliente no confirmó y no respondió los llamados.', @usr_gutierrezm); SET @res251 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli64, 'Cumpleaños de 18 Yapura', '2026-08-16', '22:00:00', 'Club 20 de Febrero', '05:00:00', 860000, 'FINALIZADA', '2026-05-24 20:30:00', @usr_gutierrezm, NULL, '', NULL); SET @res252 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli8, 'Fiesta de 15 Morales', '2026-06-18', '21:30:00', 'Salón Del Valle', '06:00:00', 1170000, 'ANULADA', '2026-05-25 15:30:00', @usr_gutierrezm, '2026-05-31 15:00:00', 'El cliente canceló el evento por problemas personales.', @usr_gutierrezm); SET @res253 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli1, 'Casamiento Saez', '2026-08-15', '21:30:00', 'Quinta Las Moritas', '06:00:00', 1745000, 'FINALIZADA', '2026-05-26 09:45:00', @usr_admin, NULL, '', NULL); SET @res254 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli90, 'Fiesta de Egresados Llanos', '2026-12-27', '22:00:00', 'Salón Golden', '05:00:00', 705000, 'CONFIRMADA', '2026-05-26 12:20:00', @usr_delafuentec, NULL, '', NULL); SET @res255 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli46, 'Bautismo Chocobar', '2026-08-23', '12:30:00', 'Club Gimnasia y Tiro', '04:00:00', 205000, 'FINALIZADA', '2026-05-26 20:45:00', @usr_delafuentec, NULL, '', NULL); SET @res256 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli51, 'Cumpleaños Infantil Ibarra', '2026-07-18', '16:00:00', 'Salón Fénix', '04:00:00', 175000, 'FINALIZADA', '2026-05-28 10:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res257 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli81, 'Fiesta de 15 Torino', '2026-11-21', '22:00:00', 'Salón Del Valle', '06:00:00', 835000, 'PENDIENTE', '2026-05-28 16:50:00', @usr_delafuentec, NULL, '', NULL); SET @res258 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli34, 'Cumpleaños de 18 Yapura', '2026-06-14', '23:00:00', 'Salón Del Valle', '05:00:00', 605000, 'FINALIZADA', '2026-05-31 10:30:00', @usr_gutierrezm, NULL, '', NULL); SET @res259 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Evento Corporativo Los Cardones', '2026-09-17', '19:00:00', 'Quinta San Lorenzo', '04:00:00', 225000, 'FINALIZADA', '2026-05-31 17:45:00', @usr_herrerav, NULL, '', NULL); SET @res260 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli53, 'Casamiento Lamas', '2026-12-13', '20:30:00', 'Salón Fénix', '07:00:00', 1420000, 'CONFIRMADA', '2026-06-01 09:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res261 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli77, 'Casamiento Ontiveros', '2026-08-15', '20:30:00', 'Club Gimnasia y Tiro', '07:00:00', 910000, 'FINALIZADA', '2026-06-01 10:20:00', @usr_herrerav, NULL, '', NULL); SET @res262 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli23, 'Bautismo Chávez', '2026-09-26', '12:30:00', 'Hotel Sheraton Salta', '05:00:00', 205000, 'FINALIZADA', '2026-06-03 15:10:00', @usr_alarconf, NULL, '', NULL); SET @res263 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli50, 'Fiesta de 15 Guanuco', '2026-06-27', '21:30:00', 'Salón Fénix', '06:00:00', 765000, 'FINALIZADA', '2026-06-07 12:20:00', @usr_admin, NULL, '', NULL); SET @res264 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli68, 'Fiesta de 15 Cardozo', '2026-09-20', '21:30:00', 'Salón Del Valle', '06:00:00', 770000, 'FINALIZADA', '2026-06-08 10:45:00', @usr_gutierrezm, NULL, '', NULL); SET @res265 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli47, 'Bautismo Delgado', '2026-07-05', '13:00:00', 'Finca La Encantada', '05:00:00', 210000, 'FINALIZADA', '2026-06-16 09:10:00', @usr_delafuentec, NULL, '', NULL); SET @res266 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli76, 'Cumpleaños de 18 Mendoza', '2026-08-01', '23:00:00', 'Centro de Convenciones Salta', '05:00:00', 615000, 'ANULADA', '2026-06-16 12:30:00', @usr_gutierrezm, '2026-06-26 20:20:00', 'El cliente contrató otra empresa.', @usr_gutierrezm); SET @res267 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli53, 'Cumpleaños Infantil Lamas', '2026-07-19', '17:00:00', 'Quinta San Lorenzo', '03:00:00', 180000, 'FINALIZADA', '2026-06-17 16:30:00', @usr_herrerav, NULL, '', NULL); SET @res268 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli24, 'Cumpleaños de 18 Saravia', '2026-07-25', '22:00:00', 'Club 20 de Febrero', '04:00:00', 615000, 'FINALIZADA', '2026-06-18 20:40:00', @usr_gutierrezm, NULL, '', NULL); SET @res269 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli79, 'Fiesta de Egresados Rueda', '2026-11-01', '22:00:00', 'Salón Los Álamos', '06:00:00', 1130000, 'FINALIZADA', '2026-06-19 14:50:00', @usr_delafuentec, NULL, '', NULL); SET @res270 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli60, 'Karaoke Sarapura', '2026-07-10', '21:00:00', 'Centro de Convenciones Salta', '04:00:00', 205000, 'ANULADA', '2026-06-23 14:50:00', @usr_delafuentec, '2026-06-27 13:20:00', 'Se cargó por error, el cliente pidió otra fecha.', @usr_gutierrezm); SET @res271 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli28, 'Fiesta de 15 Mamaní', '2026-11-07', '21:30:00', 'Complejo Ruta 51', '06:00:00', 605000, 'FINALIZADA', '2026-06-24 09:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res272 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli43, 'Casamiento Aguirre', '2026-11-06', '20:30:00', 'Salón Del Valle', '06:00:00', 920000, 'FINALIZADA', '2026-06-25 16:15:00', @usr_delafuentec, NULL, '', NULL); SET @res273 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli48, 'Fiesta de Egresados Escobar', '2026-12-06', '22:00:00', 'Salón Fénix', '06:00:00', 715000, 'ANULADA', '2026-06-25 19:40:00', @usr_alarconf, '2026-10-17 15:20:00', 'Se suspendió el evento por pronóstico de lluvia.', @usr_gutierrezm); SET @res274 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli94, 'Acto de Graduación Normal Gral. Güemes', '2026-10-02', '18:00:00', 'Salón Los Álamos', '03:00:00', 320000, 'FINALIZADA', '2026-06-26 09:30:00', @usr_delafuentec, NULL, '', NULL); SET @res275 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli62, 'Cumpleaños Infantil Uriburu', '2026-08-08', '16:00:00', 'Club 20 de Febrero', '04:00:00', 180000, 'FINALIZADA', '2026-06-26 19:30:00', @usr_alarconf, NULL, '', NULL); SET @res276 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli19, 'Peña Folclórica Bravo', '2026-08-02', '22:00:00', 'Centro de Convenciones Salta', '06:00:00', 980000, 'FINALIZADA', '2026-06-28 11:50:00', @usr_delafuentec, NULL, '', NULL); SET @res277 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli21, 'Casamiento Rivero', '2026-09-30', '20:30:00', 'Salón Del Valle', '06:00:00', 1270000, 'FINALIZADA', '2026-06-28 20:20:00', @usr_alarconf, NULL, '', NULL); SET @res278 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli66, 'Casamiento Alanís', '2026-09-13', '20:30:00', 'Salón Il Divo', '06:00:00', 1450000, 'ANULADA', '2026-06-30 14:10:00', @usr_admin, '2026-09-06 15:00:00', 'El cliente contrató otra empresa.', @usr_admin); SET @res279 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli18, 'Cumpleaños Infantil Coronel', '2026-08-29', '16:00:00', 'Finca La Encantada', '04:00:00', 180000, 'FINALIZADA', '2026-07-02 14:30:00', @usr_delafuentec, NULL, '', NULL); SET @res280 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli64, 'Casamiento Yapura', '2026-10-21', '21:00:00', 'Hotel Alejandro I', '07:00:00', 1270000, 'FINALIZADA', '2026-07-08 10:50:00', @usr_delafuentec, NULL, '', NULL); SET @res281 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli74, 'Casamiento Isasmendi', '2026-11-04', '21:30:00', 'Hotel Alejandro I', '07:00:00', 1710000, 'FINALIZADA', '2026-07-08 11:00:00', @usr_alarconf, NULL, '', NULL); SET @res282 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Fiesta de Fin de Año Los Cardones', '2026-12-25', '21:00:00', 'Club Gimnasia y Tiro', '06:00:00', 890000, 'PENDIENTE', '2026-07-09 14:40:00', @usr_alarconf, NULL, '', NULL); SET @res283 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli10, 'Fiesta de 15 Vera', '2026-09-18', '21:30:00', 'Hotel Alejandro I', '06:00:00', 780000, 'FINALIZADA', '2026-07-10 17:45:00', @usr_delafuentec, NULL, '', NULL); SET @res284 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli35, 'Fiesta de 15 Choque', '2026-10-04', '21:30:00', 'Hotel Alejandro I', '06:00:00', 780000, 'FINALIZADA', '2026-07-16 15:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res285 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli83, 'Fiesta de 15 Arce', '2026-08-30', '21:30:00', 'Finca La Encantada', '06:00:00', 780000, 'FINALIZADA', '2026-07-22 19:20:00', @usr_delafuentec, NULL, '', NULL); SET @res286 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli76, 'Cumpleaños de 18 Mendoza', '2026-10-09', '22:00:00', 'Salón Golden', '04:00:00', 695000, 'FINALIZADA', '2026-07-24 16:45:00', @usr_admin, NULL, '', NULL); SET @res287 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli44, 'Show en Vivo Burgos', '2026-09-20', '22:00:00', 'Hotel Sheraton Salta', '05:00:00', 1030000, 'FINALIZADA', '2026-07-25 17:50:00', @usr_alarconf, NULL, '', NULL); SET @res288 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Festival Los Cardones', '2026-08-23', '18:00:00', 'Quinta San Lorenzo', '08:00:00', 980000, 'FINALIZADA', '2026-07-27 10:10:00', @usr_delafuentec, NULL, '', NULL); SET @res289 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli26, 'Casamiento Burgos', '2027-03-07', '20:30:00', 'Quinta San Lorenzo', '07:00:00', 2130000, 'PENDIENTE', '2026-07-27 10:45:00', @usr_delafuentec, NULL, '', NULL); SET @res290 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli32, 'Fiesta de 15 Zerpa', '2026-09-19', '22:00:00', 'Salón Golden', '06:00:00', 1200000, 'FINALIZADA', '2026-07-28 12:00:00', @usr_gutierrezm, NULL, '', NULL); SET @res291 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli27, 'Fiesta de Egresados Sulca', '2026-11-13', '22:30:00', 'Quinta Las Moritas', '05:00:00', 720000, 'CONFIRMADA', '2026-07-30 16:45:00', @usr_herrerav, NULL, '', NULL); SET @res292 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Evento Corporativo Los Cardones', '2026-09-02', '19:00:00', 'Centro de Convenciones Salta', '04:00:00', 1100000, 'FINALIZADA', '2026-08-02 12:50:00', @usr_herrerav, NULL, '', NULL); SET @res293 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli51, 'Peña Folclórica Ibarra', '2026-11-07', '21:30:00', 'Finca La Encantada', '06:00:00', 980000, 'FINALIZADA', '2026-08-05 12:15:00', @usr_alarconf, NULL, '', NULL); SET @res294 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli49, 'Fiesta de 15 Figueroa', '2026-11-27', '22:00:00', 'Salón Del Valle', '06:00:00', 1200000, 'CONFIRMADA', '2026-08-08 10:30:00', @usr_gutierrezm, NULL, '', NULL); SET @res295 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli59, 'Fiesta de 15 Ríos', '2027-03-14', '22:00:00', 'Salón Los Álamos', '06:00:00', 780000, 'PENDIENTE', '2026-08-12 12:50:00', @usr_admin, NULL, '', NULL); SET @res296 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli75, 'Show en Vivo Liendro', '2026-09-25', '21:00:00', 'Salón Los Álamos', '04:00:00', 1030000, 'FINALIZADA', '2026-08-12 18:50:00', @usr_alarconf, NULL, '', NULL); SET @res297 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli91, 'Cumpleaños de 18 Morales', '2026-10-11', '23:00:00', 'Finca La Encantada', '04:00:00', 955000, 'ANULADA', '2026-08-13 13:15:00', @usr_herrerav, '2026-09-09 18:20:00', 'El cliente no confirmó y no respondió los llamados.', @usr_delafuentec); SET @res298 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli52, 'Cumpleaños Infantil Juárez', '2026-12-12', '16:00:00', 'Club Gimnasia y Tiro', '03:00:00', 180000, 'CONFIRMADA', '2026-08-14 11:00:00', @usr_delafuentec, NULL, '', NULL); SET @res299 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Festival Los Cardones', '2026-09-27', '18:00:00', 'Club 20 de Febrero', '08:00:00', 1240000, 'FINALIZADA', '2026-08-16 18:20:00', @usr_admin, NULL, '', NULL); SET @res300 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Evento Corporativo Los Cardones', '2026-09-04', '19:00:00', 'Centro de Convenciones Salta', '05:00:00', 1440000, 'FINALIZADA', '2026-08-18 14:10:00', @usr_herrerav, NULL, '', NULL); SET @res301 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli82, 'Fiesta de 15 Valdez', '2027-01-23', '22:00:00', 'Club 20 de Febrero', '06:00:00', 1040000, 'CONFIRMADA', '2026-08-18 18:40:00', @usr_herrerav, NULL, '', NULL); SET @res302 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli88, 'Fiesta de 15 Gareca', '2027-04-03', '21:30:00', 'Centro de Convenciones Salta', '06:00:00', 780000, 'PENDIENTE', '2026-08-19 13:40:00', @usr_gutierrezm, NULL, '', NULL); SET @res303 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli69, 'Show en Vivo Díaz Vélez', '2026-10-30', '21:00:00', 'Complejo Ruta 51', '05:00:00', 690000, 'FINALIZADA', '2026-08-21 09:10:00', @usr_alarconf, NULL, '', NULL); SET @res304 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli35, 'Cumpleaños Infantil Choque', '2026-10-10', '17:00:00', 'Centro de Convenciones Salta', '03:00:00', 180000, 'FINALIZADA', '2026-08-22 15:30:00', @usr_gutierrezm, NULL, '', NULL); SET @res305 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli59, 'Casamiento Ríos', '2027-04-10', '21:00:00', 'Salón Fénix', '06:00:00', 2130000, 'PENDIENTE', '2026-08-22 17:00:00', @usr_herrerav, NULL, '', NULL); SET @res306 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli19, 'Fiesta de 15 Bravo', '2027-02-26', '22:00:00', 'Salón Los Álamos', '06:00:00', 1275000, 'PENDIENTE', '2026-08-24 13:45:00', @usr_alarconf, NULL, '', NULL); SET @res307 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli60, 'Casamiento Sarapura', '2026-12-25', '20:30:00', 'Club 20 de Febrero', '06:00:00', 1110000, 'ANULADA', '2026-08-25 09:10:00', @usr_delafuentec, '2026-09-18 12:00:00', 'Se cargó por error, el cliente pidió otra fecha.', @usr_herrerav); SET @res308 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli16, 'Casamiento Ibarra', '2027-03-27', '20:30:00', 'Quinta San Lorenzo', '07:00:00', 1870000, 'CONFIRMADA', '2026-08-27 18:10:00', @usr_gutierrezm, NULL, '', NULL); SET @res309 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli42, 'Festival Los Cardones', '2026-10-25', '18:00:00', 'Finca La Encantada', '08:00:00', 980000, 'FINALIZADA', '2026-08-28 20:50:00', @usr_delafuentec, NULL, '', NULL); SET @res310 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli39, 'Casamiento Lobo', '2026-11-14', '20:30:00', 'Quinta San Lorenzo', '07:00:00', 1685000, 'PENDIENTE', '2026-08-29 13:00:00', @usr_delafuentec, NULL, '', NULL); SET @res311 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli17, 'Fiesta de 15 Méndez', '2027-03-13', '21:30:00', 'Salón Il Divo', '06:00:00', 1040000, 'CONFIRMADA', '2026-08-31 10:50:00', @usr_herrerav, NULL, '', NULL); SET @res312 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli72, 'Fiesta de 15 Guaymás', '2027-04-16', '22:00:00', 'Hotel Sheraton Salta', '06:00:00', 780000, 'CONFIRMADA', '2026-09-01 09:50:00', @usr_herrerav, NULL, '', NULL); SET @res313 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli23, 'Casamiento Chávez', '2026-10-10', '20:30:00', 'Club 20 de Febrero', '07:00:00', 850000, 'FINALIZADA', '2026-09-01 20:40:00', @usr_delafuentec, NULL, '', NULL); SET @res314 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli21, 'Cumpleaños de 18 Rivero', '2026-12-26', '23:00:00', 'Hotel Sheraton Salta', '05:00:00', 620000, 'CONFIRMADA', '2026-09-03 18:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res315 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Fiesta de Fin de Año Andina', '2026-12-13', '21:30:00', 'Salón Fénix', '06:00:00', 890000, 'PENDIENTE', '2026-09-04 12:10:00', @usr_alarconf, NULL, '', NULL); SET @res316 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli3, 'Casamiento Gómez', '2027-05-01', '20:30:00', 'Finca La Encantada', '06:00:00', 2210000, 'PENDIENTE', '2026-09-04 14:40:00', @usr_admin, NULL, '', NULL); SET @res317 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli37, 'Fiesta de 15 Tejerina', '2027-02-27', '22:00:00', 'Quinta San Lorenzo', '06:00:00', 780000, 'CONFIRMADA', '2026-09-06 15:20:00', @usr_herrerav, NULL, '', NULL); SET @res318 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli62, 'Fiesta de 15 Uriburu', '2027-04-23', '22:00:00', 'Salón Del Valle', '06:00:00', 1275000, 'CONFIRMADA', '2026-09-07 14:20:00', @usr_alarconf, NULL, '', NULL); SET @res319 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli87, 'Casamiento Fleming', '2026-11-13', '21:00:00', 'Centro de Convenciones Salta', '07:00:00', 1345000, 'CONFIRMADA', '2026-09-09 15:40:00', @usr_delafuentec, NULL, '', NULL); SET @res320 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli98, 'Fiesta de Fin de Año Andina', '2026-12-18', '21:30:00', 'Complejo Ruta 51', '05:00:00', 890000, 'PENDIENTE', '2026-09-09 19:50:00', @usr_admin, NULL, '', NULL); SET @res321 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli33, 'Fiesta de 15 Guaymás', '2027-05-02', '21:30:00', 'Club Gimnasia y Tiro', '06:00:00', 1115000, 'CONFIRMADA', '2026-09-10 17:50:00', @usr_admin, NULL, '', NULL); SET @res322 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli94, 'Acto de Graduación Normal Gral. Güemes', '2026-12-11', '10:00:00', 'Salón Del Valle', '03:00:00', 740000, 'CONFIRMADA', '2026-09-13 17:50:00', @usr_herrerav, NULL, '', NULL); SET @res323 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli25, 'Fiesta de Egresados Cornejo', '2026-12-04', '22:30:00', 'Quinta San Lorenzo', '05:00:00', 980000, 'PENDIENTE', '2026-09-15 12:10:00', @usr_admin, NULL, '', NULL); SET @res324 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli50, 'Pool Party Guanuco', '2026-12-19', '16:00:00', 'Salón Golden', '06:00:00', 425000, 'ANULADA', '2026-09-20 15:15:00', @usr_delafuentec, '2026-10-06 19:40:00', 'El cliente contrató otra empresa.', @usr_herrerav); SET @res325 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli24, 'Casamiento Saravia', '2027-05-07', '21:30:00', 'Centro de Convenciones Salta', '06:00:00', 1710000, 'CONFIRMADA', '2026-09-21 20:50:00', @usr_gutierrezm, NULL, '', NULL); SET @res326 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli73, 'Pool Party Herrera Cornejo', '2026-11-28', '16:00:00', 'Salón Los Álamos', '05:00:00', 350000, 'PENDIENTE', '2026-09-22 17:20:00', @usr_admin, NULL, '', NULL); SET @res327 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli38, 'Fiesta de Egresados Arias', '2026-11-07', '22:00:00', 'Club Gimnasia y Tiro', '06:00:00', 1140000, 'FINALIZADA', '2026-09-23 16:50:00', @usr_herrerav, NULL, '', NULL); SET @res328 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli47, 'Cumpleaños Infantil Delgado', '2026-10-31', '17:00:00', 'Club Gimnasia y Tiro', '03:00:00', 180000, 'FINALIZADA', '2026-09-23 19:30:00', @usr_admin, NULL, '', NULL); SET @res329 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli70, 'Casamiento Echenique', '2027-04-08', '21:30:00', 'Salón Golden', '06:00:00', 850000, 'PENDIENTE', '2026-09-24 16:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res330 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli44, 'Pool Party Burgos', '2027-01-24', '15:00:00', 'Quinta San Lorenzo', '06:00:00', 350000, 'CONFIRMADA', '2026-09-27 16:00:00', @usr_admin, NULL, '', NULL); SET @res331 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli61, 'Fiesta de 15 Tolaba', '2027-05-15', '22:00:00', 'Quinta Las Moritas', '06:00:00', 780000, 'CONFIRMADA', '2026-09-27 16:10:00', @usr_admin, NULL, '', NULL); SET @res332 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli8, 'Cumpleaños de 18 Morales', '2026-12-26', '23:00:00', 'Salón Fénix', '05:00:00', 880000, 'CONFIRMADA', '2026-09-30 10:30:00', @usr_herrerav, NULL, '', NULL); SET @res333 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli73, 'Fiesta de 15 Herrera Cornejo', '2027-04-24', '22:00:00', 'Salón Del Valle', '06:00:00', 780000, 'CONFIRMADA', '2026-09-30 16:20:00', @usr_delafuentec, NULL, '', NULL); SET @res334 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli63, 'Pool Party Vilte', '2026-11-15', '16:00:00', 'Finca La Encantada', '06:00:00', 350000, 'PENDIENTE', '2026-10-03 09:45:00', @usr_delafuentec, NULL, '', NULL); SET @res335 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli3, 'Cumpleaños de 18 Gómez', '2026-11-07', '22:00:00', 'Quinta Las Moritas', '05:00:00', 620000, 'ANULADA', '2026-10-04 17:45:00', @usr_delafuentec, '2026-10-21 13:20:00', 'El salón canceló la fecha.', @usr_admin); SET @res336 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli75, 'Fiesta de 15 Liendro', '2026-11-08', '22:00:00', 'Quinta Las Moritas', '06:00:00', 1115000, 'CONFIRMADA', '2026-10-04 20:45:00', @usr_herrerav, NULL, '', NULL); SET @res337 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli86, 'Casamiento Cruz Mamaní', '2026-12-04', '21:00:00', 'Quinta Las Moritas', '06:00:00', 2210000, 'CONFIRMADA', '2026-10-05 17:20:00', @usr_herrerav, NULL, '', NULL); SET @res338 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli85, 'Fiesta de 15 Colque', '2027-05-28', '22:00:00', 'Salón Los Álamos', '06:00:00', 1040000, 'CONFIRMADA', '2026-10-06 13:20:00', @usr_delafuentec, NULL, '', NULL); SET @res339 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli83, 'Bautismo Arce', '2026-11-15', '12:30:00', 'Hotel Sheraton Salta', '04:00:00', 210000, 'PENDIENTE', '2026-10-07 09:40:00', @usr_delafuentec, NULL, '', NULL); SET @res340 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli40, 'Fiesta de 15 Copa', '2027-05-22', '21:30:00', 'Complejo Ruta 51', '06:00:00', 780000, 'CONFIRMADA', '2026-10-07 11:15:00', @usr_admin, NULL, '', NULL); SET @res341 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli10, 'Casamiento Vera', '2027-05-10', '20:30:00', 'Quinta San Lorenzo', '07:00:00', 1450000, 'PENDIENTE', '2026-10-07 18:40:00', @usr_admin, NULL, '', NULL); SET @res342 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli32, 'Fiesta de 15 Zerpa', '2027-03-13', '22:00:00', 'Complejo Ruta 51', '06:00:00', 1275000, 'PENDIENTE', '2026-10-07 19:40:00', @usr_alarconf, NULL, '', NULL); SET @res343 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli70, 'Peña Folclórica Echenique', '2027-01-29', '22:00:00', 'Finca La Encantada', '07:00:00', 1055000, 'PENDIENTE', '2026-10-09 12:30:00', @usr_herrerav, NULL, '', NULL); SET @res344 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli7, 'Fiesta de 15 Díaz', '2027-04-25', '21:30:00', 'Quinta Las Moritas', '06:00:00', 1200000, 'CONFIRMADA', '2026-10-10 12:30:00', @usr_gutierrezm, NULL, '', NULL); SET @res345 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli45, 'Fiesta de 15 Cáceres', '2027-04-25', '21:30:00', 'Salón Golden', '06:00:00', 780000, 'CONFIRMADA', '2026-10-10 13:30:00', @usr_admin, NULL, '', NULL); SET @res346 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli94, 'Acto de Graduación Normal Gral. Güemes', '2026-12-29', '18:00:00', 'Salón Il Divo', '04:00:00', 320000, 'CONFIRMADA', '2026-10-11 13:00:00', @usr_delafuentec, NULL, '', NULL); SET @res347 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli34, 'Peña Folclórica Yapura', '2027-02-06', '21:30:00', 'Quinta Las Moritas', '07:00:00', 690000, 'PENDIENTE', '2026-10-11 13:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res348 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli96, 'Evento Corporativo Agrícola Cerrillos', '2026-10-30', '20:00:00', 'Salón Il Divo', '08:00:00', 650000, 'ANULADA', '2026-10-11 16:50:00', @usr_admin, '2026-10-23 12:00:00', 'El salón canceló la fecha.', @usr_herrerav); SET @res349 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli18, 'Casamiento Coronel', '2027-04-30', '20:30:00', 'Salón Los Álamos', '07:00:00', 1865000, 'CONFIRMADA', '2026-10-12 20:45:00', @usr_delafuentec, NULL, '', NULL); SET @res350 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli82, 'Casamiento Valdez', '2027-05-22', '20:30:00', 'Salón Golden', '07:00:00', 850000, 'PENDIENTE', '2026-10-13 14:00:00', @usr_alarconf, NULL, '', NULL); SET @res351 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli31, 'Pool Party Zapata', '2027-02-05', '15:00:00', 'Quinta Las Moritas', '05:00:00', 425000, 'ANULADA', '2026-10-14 15:10:00', @usr_gutierrezm, '2026-10-31 15:00:00', 'El cliente contrató otra empresa.', @usr_admin); SET @res352 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli92, 'Pool Party Ovejero', '2026-12-12', '16:00:00', 'Quinta San Lorenzo', '05:00:00', 350000, 'CONFIRMADA', '2026-10-19 09:45:00', @usr_admin, NULL, '', NULL); SET @res353 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli46, 'Pool Party Chocobar', '2027-01-03', '16:00:00', 'Salón Fénix', '06:00:00', 350000, 'PENDIENTE', '2026-10-19 13:15:00', @usr_admin, NULL, '', NULL); SET @res354 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli36, 'Bautismo Lamas', '2026-11-08', '13:00:00', 'Salón Golden', '04:00:00', 210000, 'PENDIENTE', '2026-10-20 19:30:00', @usr_admin, NULL, '', NULL); SET @res355 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli5, 'Fiesta de Egresados López', '2026-11-24', '22:00:00', 'Salón Golden', '05:00:00', 720000, 'PENDIENTE', '2026-10-21 11:50:00', @usr_delafuentec, NULL, '', NULL); SET @res356 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli26, 'Fiesta de 15 Burgos', '2027-05-14', '21:30:00', 'Finca La Encantada', '06:00:00', 1115000, 'PENDIENTE', '2026-10-21 20:45:00', @usr_alarconf, NULL, '', NULL); SET @res357 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli54, 'Fiesta de 15 Maidana', '2027-04-02', '21:30:00', 'Salón Golden', '06:00:00', 1200000, 'PENDIENTE', '2026-10-22 18:10:00', @usr_admin, NULL, '', NULL); SET @res358 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli9, 'Fiesta de 15 Ríos', '2027-01-31', '21:30:00', 'Complejo Ruta 51', '06:00:00', 1460000, 'CONFIRMADA', '2026-10-22 19:45:00', @usr_herrerav, NULL, '', NULL); SET @res359 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli1, 'Bautismo Saez', '2027-01-17', '13:00:00', 'Complejo Ruta 51', '04:00:00', 210000, 'PENDIENTE', '2026-10-23 20:40:00', @usr_gutierrezm, NULL, '', NULL); SET @res360 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli6, 'Fiesta de 15 Martínez', '2027-04-04', '22:00:00', 'Salón Golden', '06:00:00', 780000, 'PENDIENTE', '2026-10-26 13:45:00', @usr_delafuentec, NULL, '', NULL); SET @res361 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli29, 'Fiesta de 15 Gareca', '2027-05-28', '21:30:00', 'Centro de Convenciones Salta', '06:00:00', 1275000, 'CONFIRMADA', '2026-10-28 20:30:00', @usr_delafuentec, NULL, '', NULL); SET @res362 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli58, 'Cumpleaños de 18 Quispe', '2027-02-06', '23:00:00', 'Salón Golden', '04:00:00', 620000, 'CONFIRMADA', '2026-10-29 15:45:00', @usr_herrerav, NULL, '', NULL); SET @res363 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli11, 'Fiesta de 15 Cabrera', '2027-04-18', '21:30:00', 'Club 20 de Febrero', '06:00:00', 780000, 'PENDIENTE', '2026-10-31 14:20:00', @usr_gutierrezm, NULL, '', NULL); SET @res364 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli84, 'Casamiento Bravo', '2027-05-07', '21:00:00', 'Club Gimnasia y Tiro', '07:00:00', 1610000, 'CONFIRMADA', '2026-11-01 12:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res365 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli94, 'Acto de Graduación Normal Gral. Güemes', '2026-12-09', '18:00:00', 'Finca La Encantada', '04:00:00', 320000, 'CONFIRMADA', '2026-11-03 12:40:00', @usr_delafuentec, NULL, '', NULL); SET @res366 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli85, 'Fiesta de 15 Colque', '2027-05-21', '22:00:00', 'Salón Il Divo', '06:00:00', 780000, 'PENDIENTE', '2026-11-04 11:30:00', @usr_alarconf, NULL, '', NULL); SET @res367 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli13, 'Pool Party Soria', '2027-02-07', '16:00:00', 'Quinta Las Moritas', '05:00:00', 350000, 'CONFIRMADA', '2026-11-04 19:00:00', @usr_delafuentec, NULL, '', NULL); SET @res368 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli17, 'Show en Vivo Méndez', '2026-12-27', '21:00:00', 'Salón Fénix', '05:00:00', 690000, 'CONFIRMADA', '2026-11-04 20:30:00', @usr_delafuentec, NULL, '', NULL); SET @res369 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli66, 'Pool Party Alanís', '2027-02-20', '15:00:00', 'Finca La Encantada', '06:00:00', 425000, 'PENDIENTE', '2026-11-05 14:15:00', @usr_gutierrezm, NULL, '', NULL); SET @res370 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli67, 'Peña Folclórica Bustos', '2026-12-05', '22:00:00', 'Complejo Ruta 51', '06:00:00', 690000, 'PENDIENTE', '2026-11-07 19:40:00', @usr_alarconf, NULL, '', NULL); SET @res371 = LAST_INSERT_ID();

-- ======================================================================
-- 18. SERVICIOS DE CADA RESERVA (con el precio del servicio al momento de reservar)
-- ======================================================================
INSERT INTO infinito_sonido_reservas_x_servicios (id_reserva, id_servicio, precio_servicio) VALUES
  (@res1, @serv2, 470000),
  (@res2, @serv1, 435000),
  (@res2, @serv15, 145000),
  (@res2, @serv14, 235000),
  (@res3, @serv2, 475000),
  (@res3, @serv13, 190000),
  (@res4, @serv3, 815000),
  (@res4, @serv16, 40000),
  (@res5, @serv11, 550000),
  (@res5, @serv15, 145000),
  (@res6, @serv17, 195000),
  (@res7, @serv2, 485000),
  (@res8, @serv3, 840000),
  (@res8, @serv15, 150000),
  (@res8, @serv16, 45000),
  (@res9, @serv7, 105000),
  (@res10, @serv18, 410000),
  (@res11, @serv1, 465000),
  (@res12, @serv3, 875000),
  (@res13, @serv11, 595000),
  (@res14, @serv2, 515000),
  (@res14, @serv13, 205000),
  (@res15, @serv7, 110000),
  (@res16, @serv17, 215000),
  (@res17, @serv17, 215000),
  (@res18, @serv20, 125000),
  (@res19, @serv6, 130000),
  (@res20, @serv1, 490000),
  (@res20, @serv15, 165000),
  (@res21, @serv19, 335000),
  (@res22, @serv8, 695000),
  (@res23, @serv20, 130000),
  (@res24, @serv3, 920000),
  (@res24, @serv13, 215000),
  (@res25, @serv8, 700000),
  (@res26, @serv7, 115000),
  (@res27, @serv11, 625000),
  (@res28, @serv3, 935000),
  (@res29, @serv2, 550000),
  (@res29, @serv15, 170000),
  (@res30, @serv1, 505000),
  (@res30, @serv14, 270000),
  (@res30, @serv16, 50000),
  (@res31, @serv7, 115000),
  (@res32, @serv3, 945000),
  (@res32, @serv13, 220000),
  (@res33, @serv3, 945000),
  (@res33, @serv13, 220000),
  (@res33, @serv14, 275000),
  (@res34, @serv18, 450000),
  (@res35, @serv20, 135000),
  (@res36, @serv5, 410000),
  (@res36, @serv16, 50000),
  (@res37, @serv1, 515000),
  (@res38, @serv5, 410000),
  (@res39, @serv1, 520000),
  (@res39, @serv15, 175000),
  (@res40, @serv1, 520000),
  (@res41, @serv19, 355000),
  (@res41, @serv15, 175000),
  (@res41, @serv16, 50000),
  (@res42, @serv5, 415000),
  (@res42, @serv15, 175000),
  (@res43, @serv3, 970000),
  (@res44, @serv1, 525000),
  (@res45, @serv9, 155000),
  (@res46, @serv5, 420000),
  (@res46, @serv16, 50000),
  (@res47, @serv2, 575000),
  (@res47, @serv16, 50000),
  (@res48, @serv7, 120000),
  (@res49, @serv19, 360000),
  (@res49, @serv16, 50000),
  (@res50, @serv7, 120000),
  (@res51, @serv1, 530000),
  (@res51, @serv14, 285000),
  (@res52, @serv7, 120000),
  (@res53, @serv1, 530000),
  (@res53, @serv15, 175000),
  (@res53, @serv16, 50000),
  (@res54, @serv10, 220000),
  (@res55, @serv3, 990000),
  (@res55, @serv16, 50000),
  (@res56, @serv1, 535000),
  (@res56, @serv15, 180000),
  (@res57, @serv4, 495000),
  (@res57, @serv15, 180000),
  (@res58, @serv6, 145000),
  (@res59, @serv6, 145000),
  (@res60, @serv1, 535000),
  (@res61, @serv1, 535000),
  (@res61, @serv14, 290000),
  (@res62, @serv3, 1005000),
  (@res62, @serv14, 290000),
  (@res63, @serv18, 480000),
  (@res64, @serv7, 125000),
  (@res65, @serv4, 500000),
  (@res65, @serv15, 180000),
  (@res65, @serv14, 290000),
  (@res66, @serv5, 430000),
  (@res67, @serv6, 145000),
  (@res68, @serv2, 595000),
  (@res69, @serv4, 505000),
  (@res69, @serv14, 295000),
  (@res70, @serv7, 125000),
  (@res71, @serv7, 125000),
  (@res72, @serv18, 490000),
  (@res73, @serv5, 440000),
  (@res74, @serv9, 165000),
  (@res74, @serv14, 295000),
  (@res75, @serv3, 1030000),
  (@res75, @serv13, 240000),
  (@res75, @serv16, 55000),
  (@res76, @serv3, 1030000),
  (@res77, @serv6, 150000),
  (@res78, @serv4, 515000),
  (@res78, @serv14, 300000),
  (@res79, @serv1, 560000),
  (@res80, @serv6, 150000),
  (@res81, @serv20, 145000),
  (@res82, @serv5, 445000),
  (@res83, @serv7, 130000),
  (@res84, @serv20, 145000),
  (@res85, @serv5, 450000),
  (@res85, @serv15, 190000),
  (@res85, @serv16, 55000),
  (@res86, @serv5, 450000),
  (@res87, @serv19, 385000),
  (@res88, @serv1, 570000),
  (@res88, @serv15, 190000),
  (@res88, @serv14, 305000),
  (@res88, @serv16, 55000),
  (@res89, @serv7, 130000),
  (@res90, @serv5, 450000),
  (@res90, @serv15, 190000),
  (@res91, @serv3, 1060000),
  (@res91, @serv13, 250000),
  (@res91, @serv16, 55000),
  (@res92, @serv18, 505000),
  (@res93, @serv5, 455000),
  (@res94, @serv3, 1060000),
  (@res95, @serv18, 505000),
  (@res95, @serv16, 55000),
  (@res96, @serv5, 455000),
  (@res97, @serv18, 505000),
  (@res98, @serv20, 150000),
  (@res99, @serv5, 460000),
  (@res100, @serv6, 155000),
  (@res101, @serv2, 630000),
  (@res101, @serv16, 55000),
  (@res102, @serv18, 510000),
  (@res103, @serv20, 150000),
  (@res104, @serv11, 730000),
  (@res105, @serv2, 635000),
  (@res105, @serv13, 255000),
  (@res105, @serv14, 315000),
  (@res106, @serv20, 155000),
  (@res107, @serv3, 1090000),
  (@res107, @serv15, 195000),
  (@res107, @serv16, 55000),
  (@res108, @serv1, 585000),
  (@res109, @serv18, 520000),
  (@res109, @serv16, 55000),
  (@res110, @serv7, 135000),
  (@res111, @serv6, 160000),
  (@res112, @serv5, 470000),
  (@res112, @serv15, 195000),
  (@res113, @serv6, 160000),
  (@res114, @serv7, 140000),
  (@res115, @serv7, 140000),
  (@res116, @serv20, 155000),
  (@res117, @serv7, 140000),
  (@res118, @serv3, 1120000),
  (@res119, @serv7, 140000),
  (@res120, @serv5, 480000),
  (@res120, @serv16, 60000),
  (@res121, @serv2, 660000),
  (@res122, @serv11, 765000),
  (@res122, @serv15, 205000),
  (@res123, @serv6, 165000),
  (@res124, @serv3, 1135000),
  (@res124, @serv13, 265000),
  (@res124, @serv16, 60000),
  (@res125, @serv12, 695000),
  (@res126, @serv7, 140000),
  (@res127, @serv10, 255000),
  (@res127, @serv14, 330000),
  (@res128, @serv12, 705000),
  (@res129, @serv19, 420000),
  (@res129, @serv16, 60000),
  (@res130, @serv17, 275000),
  (@res131, @serv1, 620000),
  (@res131, @serv14, 335000),
  (@res132, @serv5, 495000),
  (@res133, @serv6, 170000),
  (@res134, @serv3, 1160000),
  (@res134, @serv16, 60000),
  (@res135, @serv17, 280000),
  (@res135, @serv16, 60000),
  (@res136, @serv1, 625000),
  (@res137, @serv7, 145000),
  (@res138, @serv18, 555000),
  (@res139, @serv1, 625000),
  (@res140, @serv19, 425000),
  (@res140, @serv15, 210000),
  (@res141, @serv7, 145000),
  (@res142, @serv17, 280000),
  (@res143, @serv10, 255000),
  (@res144, @serv17, 280000),
  (@res145, @serv11, 795000),
  (@res145, @serv16, 60000),
  (@res146, @serv7, 145000),
  (@res147, @serv10, 260000),
  (@res148, @serv4, 590000),
  (@res148, @serv15, 215000),
  (@res148, @serv14, 345000),
  (@res149, @serv2, 695000),
  (@res149, @serv13, 280000),
  (@res149, @serv14, 345000),
  (@res150, @serv3, 1190000),
  (@res150, @serv13, 280000),
  (@res150, @serv14, 345000),
  (@res151, @serv4, 590000),
  (@res151, @serv14, 345000),
  (@res152, @serv10, 265000),
  (@res152, @serv14, 345000),
  (@res153, @serv5, 510000),
  (@res154, @serv7, 150000),
  (@res155, @serv10, 265000),
  (@res156, @serv10, 265000),
  (@res157, @serv5, 510000),
  (@res158, @serv10, 265000),
  (@res159, @serv7, 150000),
  (@res160, @serv1, 645000),
  (@res161, @serv1, 650000),
  (@res161, @serv15, 215000),
  (@res162, @serv10, 270000),
  (@res163, @serv11, 820000),
  (@res163, @serv16, 65000),
  (@res164, @serv7, 150000),
  (@res165, @serv12, 750000),
  (@res165, @serv14, 355000),
  (@res166, @serv11, 825000),
  (@res167, @serv17, 295000),
  (@res167, @serv16, 65000),
  (@res168, @serv17, 295000),
  (@res169, @serv11, 835000),
  (@res170, @serv7, 155000),
  (@res171, @serv5, 530000),
  (@res171, @serv15, 220000),
  (@res172, @serv20, 175000),
  (@res173, @serv17, 305000),
  (@res174, @serv7, 155000),
  (@res175, @serv17, 305000),
  (@res175, @serv16, 65000),
  (@res176, @serv8, 965000),
  (@res177, @serv1, 685000),
  (@res178, @serv20, 180000),
  (@res179, @serv2, 750000),
  (@res179, @serv14, 370000),
  (@res180, @serv6, 185000),
  (@res181, @serv11, 875000),
  (@res182, @serv9, 205000),
  (@res183, @serv7, 160000),
  (@res184, @serv2, 765000),
  (@res184, @serv15, 235000),
  (@res184, @serv16, 65000),
  (@res185, @serv7, 160000),
  (@res186, @serv9, 205000),
  (@res187, @serv7, 160000),
  (@res188, @serv5, 560000),
  (@res188, @serv16, 70000),
  (@res189, @serv1, 705000),
  (@res190, @serv5, 560000),
  (@res190, @serv15, 235000),
  (@res191, @serv6, 190000),
  (@res192, @serv20, 185000),
  (@res193, @serv19, 480000),
  (@res193, @serv14, 380000),
  (@res194, @serv5, 565000),
  (@res194, @serv15, 235000),
  (@res195, @serv2, 775000),
  (@res195, @serv15, 235000),
  (@res195, @serv16, 70000),
  (@res196, @serv4, 655000),
  (@res196, @serv14, 380000),
  (@res197, @serv1, 715000),
  (@res198, @serv2, 775000),
  (@res198, @serv15, 240000),
  (@res198, @serv14, 385000),
  (@res199, @serv2, 780000),
  (@res199, @serv15, 240000),
  (@res200, @serv5, 570000),
  (@res201, @serv18, 635000),
  (@res202, @serv5, 570000),
  (@res202, @serv15, 240000),
  (@res203, @serv7, 165000),
  (@res204, @serv3, 1335000),
  (@res204, @serv15, 240000),
  (@res204, @serv14, 385000),
  (@res205, @serv1, 720000),
  (@res206, @serv2, 785000),
  (@res206, @serv13, 315000),
  (@res207, @serv4, 665000),
  (@res208, @serv1, 725000),
  (@res209, @serv1, 725000),
  (@res210, @serv20, 190000),
  (@res211, @serv6, 195000),
  (@res212, @serv5, 575000),
  (@res212, @serv15, 240000),
  (@res213, @serv19, 495000),
  (@res213, @serv16, 70000),
  (@res214, @serv11, 915000),
  (@res214, @serv15, 245000),
  (@res215, @serv18, 645000),
  (@res216, @serv3, 1360000),
  (@res216, @serv15, 245000),
  (@res217, @serv1, 730000),
  (@res217, @serv14, 395000),
  (@res218, @serv3, 1360000),
  (@res218, @serv16, 70000),
  (@res219, @serv5, 585000),
  (@res220, @serv6, 200000),
  (@res221, @serv6, 200000),
  (@res222, @serv8, 1040000),
  (@res222, @serv13, 320000),
  (@res223, @serv6, 200000),
  (@res224, @serv4, 680000),
  (@res224, @serv15, 245000),
  (@res224, @serv14, 395000),
  (@res225, @serv18, 655000),
  (@res226, @serv9, 220000),
  (@res227, @serv7, 170000),
  (@res228, @serv20, 195000),
  (@res229, @serv19, 505000),
  (@res229, @serv16, 70000),
  (@res230, @serv11, 930000),
  (@res230, @serv15, 245000),
  (@res231, @serv5, 585000),
  (@res231, @serv15, 245000),
  (@res232, @serv11, 930000),
  (@res233, @serv20, 195000),
  (@res234, @serv7, 170000),
  (@res235, @serv12, 850000),
  (@res235, @serv15, 250000),
  (@res235, @serv14, 400000),
  (@res236, @serv4, 690000),
  (@res236, @serv15, 250000),
  (@res236, @serv14, 405000),
  (@res237, @serv7, 175000),
  (@res238, @serv5, 595000),
  (@res239, @serv18, 665000),
  (@res240, @serv1, 750000),
  (@res240, @serv15, 250000),
  (@res240, @serv14, 405000),
  (@res241, @serv12, 860000),
  (@res241, @serv15, 250000),
  (@res242, @serv18, 665000),
  (@res243, @serv7, 175000),
  (@res244, @serv5, 600000),
  (@res244, @serv15, 250000),
  (@res245, @serv7, 175000),
  (@res246, @serv4, 700000),
  (@res246, @serv14, 405000),
  (@res247, @serv1, 760000),
  (@res247, @serv15, 255000),
  (@res247, @serv14, 410000),
  (@res247, @serv16, 75000),
  (@res248, @serv6, 205000),
  (@res249, @serv9, 225000),
  (@res249, @serv14, 410000),
  (@res250, @serv10, 310000),
  (@res250, @serv14, 410000),
  (@res251, @serv20, 200000),
  (@res252, @serv5, 605000),
  (@res252, @serv15, 255000),
  (@res253, @serv1, 760000),
  (@res253, @serv14, 410000),
  (@res254, @serv3, 1415000),
  (@res254, @serv13, 330000),
  (@res255, @serv4, 705000),
  (@res256, @serv6, 205000),
  (@res257, @serv7, 175000),
  (@res258, @serv1, 760000),
  (@res258, @serv16, 75000),
  (@res259, @serv5, 605000),
  (@res260, @serv9, 225000),
  (@res261, @serv3, 1420000),
  (@res262, @serv2, 835000),
  (@res262, @serv16, 75000),
  (@res263, @serv6, 205000),
  (@res264, @serv1, 765000),
  (@res265, @serv1, 770000),
  (@res266, @serv6, 210000),
  (@res267, @serv5, 615000),
  (@res268, @serv7, 180000),
  (@res269, @serv5, 615000),
  (@res270, @serv4, 715000),
  (@res270, @serv14, 415000),
  (@res271, @serv20, 205000),
  (@res272, @serv19, 530000),
  (@res272, @serv16, 75000),
  (@res273, @serv2, 845000),
  (@res273, @serv16, 75000),
  (@res274, @serv4, 715000),
  (@res275, @serv10, 320000),
  (@res276, @serv7, 180000),
  (@res277, @serv11, 980000),
  (@res278, @serv2, 850000),
  (@res278, @serv14, 420000),
  (@res279, @serv3, 1450000),
  (@res280, @serv7, 180000),
  (@res281, @serv2, 850000),
  (@res281, @serv14, 420000),
  (@res282, @serv3, 1450000),
  (@res282, @serv15, 260000),
  (@res283, @serv12, 890000),
  (@res284, @serv1, 780000),
  (@res285, @serv1, 780000),
  (@res286, @serv1, 780000),
  (@res287, @serv5, 620000),
  (@res287, @serv16, 75000),
  (@res288, @serv18, 690000),
  (@res288, @serv13, 340000),
  (@res289, @serv11, 980000),
  (@res290, @serv3, 1450000),
  (@res290, @serv15, 260000),
  (@res290, @serv14, 420000),
  (@res291, @serv1, 780000),
  (@res291, @serv14, 420000),
  (@res292, @serv4, 720000),
  (@res293, @serv8, 1100000),
  (@res294, @serv11, 980000),
  (@res295, @serv1, 780000),
  (@res295, @serv14, 420000),
  (@res296, @serv1, 780000),
  (@res297, @serv18, 690000),
  (@res297, @serv13, 340000),
  (@res298, @serv5, 620000),
  (@res298, @serv15, 260000),
  (@res298, @serv16, 75000),
  (@res299, @serv7, 180000),
  (@res300, @serv11, 980000),
  (@res300, @serv15, 260000),
  (@res301, @serv8, 1100000),
  (@res301, @serv13, 340000),
  (@res302, @serv1, 780000),
  (@res302, @serv15, 260000),
  (@res303, @serv1, 780000),
  (@res304, @serv18, 690000),
  (@res305, @serv7, 180000),
  (@res306, @serv3, 1450000),
  (@res306, @serv15, 260000),
  (@res306, @serv14, 420000),
  (@res307, @serv1, 780000),
  (@res307, @serv14, 420000),
  (@res307, @serv16, 75000),
  (@res308, @serv2, 850000),
  (@res308, @serv15, 260000),
  (@res309, @serv3, 1450000),
  (@res309, @serv14, 420000),
  (@res310, @serv11, 980000),
  (@res311, @serv2, 850000),
  (@res311, @serv13, 340000),
  (@res311, @serv14, 420000),
  (@res311, @serv16, 75000),
  (@res312, @serv1, 780000),
  (@res312, @serv15, 260000),
  (@res313, @serv1, 780000),
  (@res314, @serv2, 850000),
  (@res315, @serv5, 620000),
  (@res316, @serv12, 890000),
  (@res317, @serv3, 1450000),
  (@res317, @serv13, 340000),
  (@res317, @serv14, 420000),
  (@res318, @serv1, 780000),
  (@res319, @serv1, 780000),
  (@res319, @serv14, 420000),
  (@res319, @serv16, 75000),
  (@res320, @serv2, 850000),
  (@res320, @serv14, 420000),
  (@res320, @serv16, 75000),
  (@res321, @serv12, 890000),
  (@res322, @serv1, 780000),
  (@res322, @serv15, 260000),
  (@res322, @serv16, 75000),
  (@res323, @serv10, 320000),
  (@res323, @serv14, 420000),
  (@res324, @serv4, 720000),
  (@res324, @serv15, 260000),
  (@res325, @serv17, 350000),
  (@res325, @serv16, 75000),
  (@res326, @serv3, 1450000),
  (@res326, @serv15, 260000),
  (@res327, @serv17, 350000),
  (@res328, @serv4, 720000),
  (@res328, @serv14, 420000),
  (@res329, @serv7, 180000),
  (@res330, @serv2, 850000),
  (@res331, @serv17, 350000),
  (@res332, @serv1, 780000),
  (@res333, @serv5, 620000),
  (@res333, @serv15, 260000),
  (@res334, @serv1, 780000),
  (@res335, @serv17, 350000),
  (@res336, @serv5, 620000),
  (@res337, @serv1, 780000),
  (@res337, @serv15, 260000),
  (@res337, @serv16, 75000),
  (@res338, @serv3, 1450000),
  (@res338, @serv13, 340000),
  (@res338, @serv14, 420000),
  (@res339, @serv1, 780000),
  (@res339, @serv15, 260000),
  (@res340, @serv6, 210000),
  (@res341, @serv1, 780000),
  (@res342, @serv3, 1450000),
  (@res343, @serv1, 780000),
  (@res343, @serv14, 420000),
  (@res343, @serv16, 75000),
  (@res344, @serv11, 980000),
  (@res344, @serv16, 75000),
  (@res345, @serv1, 780000),
  (@res345, @serv14, 420000),
  (@res346, @serv1, 780000),
  (@res347, @serv10, 320000),
  (@res348, @serv18, 690000),
  (@res349, @serv9, 230000),
  (@res349, @serv14, 420000),
  (@res350, @serv3, 1450000),
  (@res350, @serv13, 340000),
  (@res350, @serv16, 75000),
  (@res351, @serv2, 850000),
  (@res352, @serv17, 350000),
  (@res352, @serv16, 75000),
  (@res353, @serv17, 350000),
  (@res354, @serv17, 350000),
  (@res355, @serv6, 210000),
  (@res356, @serv4, 720000),
  (@res357, @serv1, 780000),
  (@res357, @serv15, 260000),
  (@res357, @serv16, 75000),
  (@res358, @serv1, 780000),
  (@res358, @serv14, 420000),
  (@res359, @serv1, 780000),
  (@res359, @serv15, 260000),
  (@res359, @serv14, 420000),
  (@res360, @serv6, 210000),
  (@res361, @serv1, 780000),
  (@res362, @serv1, 780000),
  (@res362, @serv14, 420000),
  (@res362, @serv16, 75000),
  (@res363, @serv5, 620000),
  (@res364, @serv1, 780000),
  (@res365, @serv2, 850000),
  (@res365, @serv13, 340000),
  (@res365, @serv14, 420000),
  (@res366, @serv10, 320000),
  (@res367, @serv1, 780000),
  (@res368, @serv17, 350000),
  (@res369, @serv18, 690000),
  (@res370, @serv17, 350000),
  (@res370, @serv16, 75000),
  (@res371, @serv18, 690000);

-- ======================================================================
-- 19. PERSONAL ASIGNADO A CADA RESERVA (nadie esta en dos eventos el mismo dia)
-- ======================================================================
INSERT INTO infinito_sonido_detalles_reservas (id_reserva, id_empleado) VALUES
  (@res1, @emp7),
  (@res1, @emp16),
  (@res1, @emp8),
  (@res1, @emp14),
  (@res1, @emp19),
  (@res1, @emp15),
  (@res2, @emp1),
  (@res2, @emp16),
  (@res2, @emp14),
  (@res2, @emp24),
  (@res2, @emp17),
  (@res3, @emp13),
  (@res3, @emp23),
  (@res3, @emp25),
  (@res3, @emp4),
  (@res3, @emp17),
  (@res3, @emp11),
  (@res4, @emp7),
  (@res4, @emp6),
  (@res4, @emp18),
  (@res4, @emp8),
  (@res4, @emp9),
  (@res4, @emp19),
  (@res5, @emp21),
  (@res5, @emp16),
  (@res5, @emp14),
  (@res5, @emp18),
  (@res5, @emp11),
  (@res5, @emp19),
  (@res6, @emp13),
  (@res6, @emp23),
  (@res6, @emp8),
  (@res6, @emp24),
  (@res7, @emp3),
  (@res7, @emp16),
  (@res7, @emp4),
  (@res7, @emp18),
  (@res7, @emp11),
  (@res7, @emp9),
  (@res8, @emp12),
  (@res8, @emp6),
  (@res8, @emp14),
  (@res8, @emp25),
  (@res8, @emp11),
  (@res8, @emp9),
  (@res9, @emp23),
  (@res9, @emp14),
  (@res9, @emp15),
  (@res10, @emp13),
  (@res10, @emp23),
  (@res10, @emp18),
  (@res10, @emp17),
  (@res11, @emp13),
  (@res11, @emp16),
  (@res11, @emp14),
  (@res11, @emp5),
  (@res11, @emp19),
  (@res12, @emp1),
  (@res12, @emp10),
  (@res12, @emp4),
  (@res12, @emp14),
  (@res12, @emp19),
  (@res12, @emp17),
  (@res13, @emp3),
  (@res13, @emp10),
  (@res13, @emp4),
  (@res13, @emp5),
  (@res14, @emp3),
  (@res14, @emp10),
  (@res14, @emp25),
  (@res14, @emp8),
  (@res14, @emp22),
  (@res14, @emp17),
  (@res15, @emp23),
  (@res15, @emp25),
  (@res15, @emp24),
  (@res16, @emp13),
  (@res16, @emp6),
  (@res16, @emp14),
  (@res16, @emp24),
  (@res17, @emp7),
  (@res17, @emp23),
  (@res17, @emp18),
  (@res17, @emp22),
  (@res18, @emp1),
  (@res18, @emp23),
  (@res18, @emp9),
  (@res19, @emp16),
  (@res19, @emp9),
  (@res20, @emp13),
  (@res20, @emp16),
  (@res20, @emp4),
  (@res20, @emp9),
  (@res20, @emp22),
  (@res21, @emp3),
  (@res21, @emp10),
  (@res21, @emp8),
  (@res21, @emp19),
  (@res21, @emp11),
  (@res22, @emp16),
  (@res22, @emp14),
  (@res22, @emp19),
  (@res22, @emp5),
  (@res23, @emp13),
  (@res23, @emp16),
  (@res23, @emp22),
  (@res24, @emp12),
  (@res24, @emp16),
  (@res24, @emp18),
  (@res24, @emp8),
  (@res24, @emp5),
  (@res24, @emp11),
  (@res25, @emp16),
  (@res25, @emp25),
  (@res25, @emp5),
  (@res25, @emp15),
  (@res26, @emp23),
  (@res26, @emp18),
  (@res26, @emp22),
  (@res27, @emp1),
  (@res27, @emp23),
  (@res27, @emp8),
  (@res27, @emp24),
  (@res28, @emp13),
  (@res28, @emp16),
  (@res28, @emp14),
  (@res28, @emp8),
  (@res28, @emp19),
  (@res28, @emp17),
  (@res29, @emp12),
  (@res29, @emp23),
  (@res29, @emp18),
  (@res29, @emp25),
  (@res29, @emp11),
  (@res29, @emp22),
  (@res30, @emp3),
  (@res30, @emp16),
  (@res30, @emp18),
  (@res30, @emp15),
  (@res30, @emp11),
  (@res31, @emp10),
  (@res31, @emp25),
  (@res31, @emp19),
  (@res32, @emp1),
  (@res32, @emp23),
  (@res32, @emp8),
  (@res32, @emp25),
  (@res32, @emp24),
  (@res32, @emp19),
  (@res33, @emp13),
  (@res33, @emp23),
  (@res33, @emp4),
  (@res33, @emp14),
  (@res33, @emp22),
  (@res33, @emp11),
  (@res34, @emp13),
  (@res34, @emp23),
  (@res34, @emp14),
  (@res34, @emp11),
  (@res35, @emp21),
  (@res35, @emp6),
  (@res35, @emp24),
  (@res36, @emp3),
  (@res36, @emp6),
  (@res36, @emp14),
  (@res36, @emp11),
  (@res37, @emp7),
  (@res37, @emp6),
  (@res37, @emp25),
  (@res37, @emp9),
  (@res37, @emp24),
  (@res38, @emp1),
  (@res38, @emp23),
  (@res38, @emp18),
  (@res38, @emp19),
  (@res39, @emp21),
  (@res39, @emp10),
  (@res39, @emp8),
  (@res39, @emp9),
  (@res39, @emp11),
  (@res40, @emp1),
  (@res40, @emp6),
  (@res40, @emp14),
  (@res40, @emp22),
  (@res40, @emp5),
  (@res41, @emp1),
  (@res41, @emp6),
  (@res41, @emp18),
  (@res41, @emp17),
  (@res41, @emp5),
  (@res42, @emp7),
  (@res42, @emp10),
  (@res42, @emp14),
  (@res42, @emp22),
  (@res43, @emp7),
  (@res43, @emp16),
  (@res43, @emp4),
  (@res43, @emp25),
  (@res43, @emp17),
  (@res43, @emp22),
  (@res44, @emp1),
  (@res44, @emp6),
  (@res44, @emp8),
  (@res44, @emp19),
  (@res44, @emp15),
  (@res45, @emp10),
  (@res45, @emp4),
  (@res45, @emp24),
  (@res45, @emp9),
  (@res46, @emp13),
  (@res46, @emp23),
  (@res46, @emp18),
  (@res46, @emp15),
  (@res47, @emp12),
  (@res47, @emp6),
  (@res47, @emp14),
  (@res47, @emp8),
  (@res47, @emp9),
  (@res47, @emp15),
  (@res48, @emp6),
  (@res48, @emp4),
  (@res48, @emp5),
  (@res49, @emp1),
  (@res49, @emp10),
  (@res49, @emp4),
  (@res49, @emp15),
  (@res49, @emp17),
  (@res50, @emp23),
  (@res50, @emp14),
  (@res50, @emp19),
  (@res51, @emp21),
  (@res51, @emp10),
  (@res51, @emp14),
  (@res51, @emp24),
  (@res51, @emp19),
  (@res52, @emp23),
  (@res52, @emp18),
  (@res52, @emp11),
  (@res53, @emp13),
  (@res53, @emp23),
  (@res53, @emp25),
  (@res53, @emp19),
  (@res53, @emp22),
  (@res54, @emp23),
  (@res54, @emp9),
  (@res55, @emp21),
  (@res55, @emp23),
  (@res55, @emp14),
  (@res55, @emp25),
  (@res55, @emp17),
  (@res55, @emp15),
  (@res56, @emp3),
  (@res56, @emp10),
  (@res56, @emp8),
  (@res56, @emp9),
  (@res56, @emp15),
  (@res57, @emp3),
  (@res57, @emp16),
  (@res57, @emp8),
  (@res57, @emp11),
  (@res57, @emp5),
  (@res58, @emp6),
  (@res58, @emp17),
  (@res59, @emp16),
  (@res59, @emp24),
  (@res60, @emp3),
  (@res60, @emp6),
  (@res60, @emp25),
  (@res60, @emp19),
  (@res60, @emp22),
  (@res61, @emp21),
  (@res61, @emp16),
  (@res61, @emp4),
  (@res61, @emp24),
  (@res61, @emp9),
  (@res62, @emp13),
  (@res62, @emp6),
  (@res62, @emp25),
  (@res62, @emp18),
  (@res62, @emp5),
  (@res62, @emp11),
  (@res63, @emp7),
  (@res63, @emp23),
  (@res63, @emp8),
  (@res63, @emp9),
  (@res64, @emp23),
  (@res64, @emp4),
  (@res64, @emp19),
  (@res65, @emp7),
  (@res65, @emp10),
  (@res65, @emp18),
  (@res65, @emp9),
  (@res65, @emp19),
  (@res66, @emp3),
  (@res66, @emp23),
  (@res66, @emp14),
  (@res66, @emp19),
  (@res67, @emp10),
  (@res67, @emp9),
  (@res68, @emp21),
  (@res68, @emp16),
  (@res68, @emp4),
  (@res68, @emp8),
  (@res68, @emp5),
  (@res68, @emp24),
  (@res69, @emp21),
  (@res69, @emp6),
  (@res69, @emp8),
  (@res69, @emp9),
  (@res69, @emp11),
  (@res70, @emp23),
  (@res70, @emp8),
  (@res70, @emp11),
  (@res71, @emp6),
  (@res71, @emp25),
  (@res71, @emp17),
  (@res72, @emp23),
  (@res72, @emp25),
  (@res72, @emp17),
  (@res73, @emp7),
  (@res73, @emp10),
  (@res73, @emp25),
  (@res73, @emp22),
  (@res74, @emp6),
  (@res74, @emp4),
  (@res74, @emp22),
  (@res74, @emp9),
  (@res75, @emp13),
  (@res75, @emp16),
  (@res75, @emp14),
  (@res75, @emp25),
  (@res75, @emp22),
  (@res75, @emp19),
  (@res76, @emp3),
  (@res76, @emp16),
  (@res76, @emp8),
  (@res76, @emp18),
  (@res76, @emp15),
  (@res76, @emp19),
  (@res77, @emp23),
  (@res77, @emp9),
  (@res78, @emp3),
  (@res78, @emp6),
  (@res78, @emp25),
  (@res78, @emp24),
  (@res78, @emp15),
  (@res79, @emp13),
  (@res79, @emp23),
  (@res79, @emp25),
  (@res79, @emp5),
  (@res79, @emp9),
  (@res80, @emp16),
  (@res80, @emp5),
  (@res81, @emp13),
  (@res81, @emp10),
  (@res81, @emp19),
  (@res82, @emp3),
  (@res82, @emp23),
  (@res82, @emp8),
  (@res82, @emp24),
  (@res83, @emp6),
  (@res83, @emp4),
  (@res83, @emp9),
  (@res84, @emp7),
  (@res84, @emp6),
  (@res84, @emp17),
  (@res85, @emp7),
  (@res85, @emp6),
  (@res85, @emp25),
  (@res85, @emp9),
  (@res86, @emp13),
  (@res86, @emp23),
  (@res86, @emp25),
  (@res86, @emp19),
  (@res87, @emp7),
  (@res87, @emp10),
  (@res87, @emp4),
  (@res87, @emp15),
  (@res87, @emp24),
  (@res88, @emp13),
  (@res88, @emp23),
  (@res88, @emp4),
  (@res88, @emp22),
  (@res88, @emp24),
  (@res89, @emp10),
  (@res89, @emp18),
  (@res89, @emp11),
  (@res90, @emp3),
  (@res90, @emp23),
  (@res90, @emp4),
  (@res90, @emp11),
  (@res91, @emp7),
  (@res91, @emp10),
  (@res91, @emp14),
  (@res91, @emp18),
  (@res91, @emp15),
  (@res91, @emp11),
  (@res92, @emp23),
  (@res92, @emp18),
  (@res92, @emp17),
  (@res93, @emp1),
  (@res93, @emp16),
  (@res93, @emp18),
  (@res93, @emp5),
  (@res94, @emp12),
  (@res94, @emp16),
  (@res94, @emp4),
  (@res94, @emp18),
  (@res94, @emp5),
  (@res94, @emp22),
  (@res95, @emp21),
  (@res95, @emp6),
  (@res95, @emp14),
  (@res95, @emp11),
  (@res96, @emp13),
  (@res96, @emp23),
  (@res96, @emp4),
  (@res96, @emp19),
  (@res97, @emp13),
  (@res97, @emp10),
  (@res97, @emp4),
  (@res97, @emp17),
  (@res98, @emp21),
  (@res98, @emp16),
  (@res98, @emp5),
  (@res99, @emp1),
  (@res99, @emp16),
  (@res99, @emp25),
  (@res99, @emp24),
  (@res100, @emp23),
  (@res100, @emp9),
  (@res101, @emp1),
  (@res101, @emp6),
  (@res101, @emp4),
  (@res101, @emp14),
  (@res101, @emp11),
  (@res101, @emp5),
  (@res102, @emp23),
  (@res102, @emp8),
  (@res102, @emp15),
  (@res103, @emp3),
  (@res103, @emp6),
  (@res103, @emp22),
  (@res104, @emp13),
  (@res104, @emp6),
  (@res104, @emp25),
  (@res104, @emp5),
  (@res105, @emp3),
  (@res105, @emp10),
  (@res105, @emp4),
  (@res105, @emp18),
  (@res105, @emp5),
  (@res105, @emp24),
  (@res106, @emp1),
  (@res106, @emp10),
  (@res106, @emp15),
  (@res107, @emp1),
  (@res107, @emp16),
  (@res107, @emp8),
  (@res107, @emp18),
  (@res107, @emp15),
  (@res107, @emp22),
  (@res108, @emp3),
  (@res108, @emp23),
  (@res108, @emp25),
  (@res108, @emp11),
  (@res108, @emp15),
  (@res109, @emp7),
  (@res109, @emp16),
  (@res109, @emp4),
  (@res109, @emp5),
  (@res110, @emp6),
  (@res110, @emp4),
  (@res110, @emp17),
  (@res111, @emp23),
  (@res111, @emp24),
  (@res112, @emp1),
  (@res112, @emp10),
  (@res112, @emp14),
  (@res112, @emp9),
  (@res113, @emp16),
  (@res113, @emp9),
  (@res114, @emp16),
  (@res114, @emp25),
  (@res114, @emp19),
  (@res115, @emp10),
  (@res115, @emp4),
  (@res115, @emp15),
  (@res116, @emp7),
  (@res116, @emp16),
  (@res116, @emp5),
  (@res117, @emp10),
  (@res117, @emp4),
  (@res117, @emp11),
  (@res118, @emp12),
  (@res118, @emp6),
  (@res118, @emp25),
  (@res118, @emp14),
  (@res118, @emp9),
  (@res118, @emp17),
  (@res119, @emp16),
  (@res119, @emp18),
  (@res119, @emp9),
  (@res120, @emp1),
  (@res120, @emp23),
  (@res120, @emp14),
  (@res120, @emp11),
  (@res121, @emp12),
  (@res121, @emp16),
  (@res121, @emp14),
  (@res121, @emp25),
  (@res121, @emp19),
  (@res121, @emp5),
  (@res122, @emp13),
  (@res122, @emp6),
  (@res122, @emp8),
  (@res122, @emp25),
  (@res122, @emp5),
  (@res122, @emp24),
  (@res123, @emp16),
  (@res123, @emp5),
  (@res124, @emp7),
  (@res124, @emp23),
  (@res124, @emp8),
  (@res124, @emp25),
  (@res124, @emp15),
  (@res124, @emp19),
  (@res125, @emp21),
  (@res125, @emp23),
  (@res125, @emp25),
  (@res125, @emp9),
  (@res125, @emp17),
  (@res126, @emp23),
  (@res126, @emp14),
  (@res126, @emp22),
  (@res127, @emp6),
  (@res127, @emp24),
  (@res128, @emp3),
  (@res128, @emp16),
  (@res128, @emp18),
  (@res128, @emp22),
  (@res128, @emp11),
  (@res129, @emp13),
  (@res129, @emp6),
  (@res129, @emp18),
  (@res129, @emp22),
  (@res129, @emp9),
  (@res130, @emp3),
  (@res130, @emp16),
  (@res130, @emp4),
  (@res130, @emp22),
  (@res131, @emp7),
  (@res131, @emp23),
  (@res131, @emp4),
  (@res131, @emp17),
  (@res131, @emp15),
  (@res132, @emp13),
  (@res132, @emp16),
  (@res132, @emp8),
  (@res132, @emp17),
  (@res133, @emp23),
  (@res133, @emp24),
  (@res134, @emp7),
  (@res134, @emp23),
  (@res134, @emp25),
  (@res134, @emp18),
  (@res134, @emp19),
  (@res134, @emp5),
  (@res135, @emp7),
  (@res135, @emp10),
  (@res135, @emp14),
  (@res135, @emp9),
  (@res136, @emp13),
  (@res136, @emp6),
  (@res136, @emp4),
  (@res136, @emp19),
  (@res136, @emp11),
  (@res137, @emp10),
  (@res137, @emp18),
  (@res137, @emp19),
  (@res138, @emp16),
  (@res138, @emp4),
  (@res138, @emp5),
  (@res139, @emp7),
  (@res139, @emp23),
  (@res139, @emp25),
  (@res139, @emp24),
  (@res139, @emp17),
  (@res140, @emp3),
  (@res140, @emp6),
  (@res140, @emp4),
  (@res140, @emp15),
  (@res140, @emp19),
  (@res141, @emp23),
  (@res141, @emp18),
  (@res141, @emp11),
  (@res142, @emp3),
  (@res142, @emp6),
  (@res142, @emp25),
  (@res142, @emp22),
  (@res143, @emp16),
  (@res143, @emp24),
  (@res144, @emp1),
  (@res144, @emp23),
  (@res144, @emp25),
  (@res144, @emp22),
  (@res145, @emp7),
  (@res145, @emp16),
  (@res145, @emp25),
  (@res145, @emp11),
  (@res146, @emp10),
  (@res146, @emp4),
  (@res146, @emp24),
  (@res147, @emp23),
  (@res147, @emp9),
  (@res148, @emp1),
  (@res148, @emp23),
  (@res148, @emp4),
  (@res148, @emp17),
  (@res148, @emp5),
  (@res149, @emp13),
  (@res149, @emp6),
  (@res149, @emp14),
  (@res149, @emp8),
  (@res149, @emp15),
  (@res149, @emp24),
  (@res150, @emp12),
  (@res150, @emp23),
  (@res150, @emp25),
  (@res150, @emp18),
  (@res150, @emp11),
  (@res150, @emp9),
  (@res151, @emp7),
  (@res151, @emp10),
  (@res151, @emp18),
  (@res151, @emp5),
  (@res151, @emp19),
  (@res152, @emp23),
  (@res152, @emp11),
  (@res153, @emp3),
  (@res153, @emp10),
  (@res153, @emp25),
  (@res153, @emp17),
  (@res154, @emp10),
  (@res154, @emp4),
  (@res154, @emp22),
  (@res155, @emp23),
  (@res155, @emp24),
  (@res156, @emp23),
  (@res156, @emp9),
  (@res157, @emp13),
  (@res157, @emp16),
  (@res157, @emp8),
  (@res157, @emp11),
  (@res158, @emp16),
  (@res158, @emp17),
  (@res159, @emp16),
  (@res159, @emp14),
  (@res159, @emp11),
  (@res160, @emp3),
  (@res160, @emp23),
  (@res160, @emp8),
  (@res160, @emp17),
  (@res160, @emp24),
  (@res161, @emp3),
  (@res161, @emp10),
  (@res161, @emp8),
  (@res161, @emp9),
  (@res161, @emp5),
  (@res162, @emp23),
  (@res162, @emp22),
  (@res163, @emp1),
  (@res163, @emp16),
  (@res163, @emp8),
  (@res163, @emp9),
  (@res164, @emp16),
  (@res164, @emp18),
  (@res164, @emp22),
  (@res165, @emp12),
  (@res165, @emp10),
  (@res165, @emp8),
  (@res165, @emp17),
  (@res165, @emp19),
  (@res166, @emp1),
  (@res166, @emp16),
  (@res166, @emp25),
  (@res166, @emp9),
  (@res167, @emp3),
  (@res167, @emp23),
  (@res167, @emp8),
  (@res167, @emp24),
  (@res168, @emp21),
  (@res168, @emp23),
  (@res168, @emp8),
  (@res168, @emp24),
  (@res169, @emp13),
  (@res169, @emp23),
  (@res169, @emp4),
  (@res169, @emp9),
  (@res170, @emp6),
  (@res170, @emp25),
  (@res170, @emp19),
  (@res171, @emp7),
  (@res171, @emp16),
  (@res171, @emp18),
  (@res171, @emp9),
  (@res172, @emp7),
  (@res172, @emp16),
  (@res172, @emp19),
  (@res173, @emp7),
  (@res173, @emp16),
  (@res173, @emp8),
  (@res173, @emp19),
  (@res174, @emp6),
  (@res174, @emp25),
  (@res174, @emp24),
  (@res175, @emp3),
  (@res175, @emp23),
  (@res175, @emp4),
  (@res175, @emp15),
  (@res176, @emp23),
  (@res176, @emp25),
  (@res176, @emp24),
  (@res176, @emp11),
  (@res177, @emp21),
  (@res177, @emp6),
  (@res177, @emp8),
  (@res177, @emp15),
  (@res177, @emp24),
  (@res178, @emp13),
  (@res178, @emp6),
  (@res178, @emp17),
  (@res179, @emp7),
  (@res179, @emp23),
  (@res179, @emp18),
  (@res179, @emp8),
  (@res179, @emp15),
  (@res179, @emp19),
  (@res180, @emp10),
  (@res180, @emp22),
  (@res181, @emp13),
  (@res181, @emp23),
  (@res181, @emp18),
  (@res181, @emp17),
  (@res182, @emp23),
  (@res182, @emp4),
  (@res182, @emp19),
  (@res182, @emp9),
  (@res183, @emp6),
  (@res183, @emp18),
  (@res183, @emp15),
  (@res184, @emp13),
  (@res184, @emp16),
  (@res184, @emp8),
  (@res184, @emp18),
  (@res184, @emp5),
  (@res184, @emp11),
  (@res185, @emp10),
  (@res185, @emp4),
  (@res185, @emp22),
  (@res186, @emp6),
  (@res186, @emp4),
  (@res186, @emp9),
  (@res186, @emp5),
  (@res187, @emp6),
  (@res187, @emp14),
  (@res187, @emp5),
  (@res188, @emp3),
  (@res188, @emp16),
  (@res188, @emp14),
  (@res188, @emp11),
  (@res189, @emp1),
  (@res189, @emp16),
  (@res189, @emp8),
  (@res189, @emp11),
  (@res189, @emp5),
  (@res190, @emp21),
  (@res190, @emp16),
  (@res190, @emp4),
  (@res190, @emp5),
  (@res191, @emp6),
  (@res191, @emp24),
  (@res192, @emp7),
  (@res192, @emp23),
  (@res192, @emp5),
  (@res193, @emp7),
  (@res193, @emp10),
  (@res193, @emp14),
  (@res193, @emp19),
  (@res193, @emp17),
  (@res194, @emp7),
  (@res194, @emp16),
  (@res194, @emp25),
  (@res194, @emp5),
  (@res195, @emp7),
  (@res195, @emp16),
  (@res195, @emp18),
  (@res195, @emp8),
  (@res195, @emp19),
  (@res195, @emp15),
  (@res196, @emp3),
  (@res196, @emp6),
  (@res196, @emp4),
  (@res196, @emp19),
  (@res196, @emp9),
  (@res197, @emp21),
  (@res197, @emp23),
  (@res197, @emp4),
  (@res197, @emp24),
  (@res197, @emp17),
  (@res198, @emp21),
  (@res198, @emp10),
  (@res198, @emp14),
  (@res198, @emp18),
  (@res198, @emp17),
  (@res198, @emp5),
  (@res199, @emp21),
  (@res199, @emp16),
  (@res199, @emp18),
  (@res199, @emp4),
  (@res199, @emp9),
  (@res199, @emp17),
  (@res200, @emp1),
  (@res200, @emp10),
  (@res200, @emp14),
  (@res200, @emp11),
  (@res201, @emp1),
  (@res201, @emp10),
  (@res201, @emp4),
  (@res201, @emp9),
  (@res202, @emp7),
  (@res202, @emp10),
  (@res202, @emp4),
  (@res202, @emp5),
  (@res203, @emp10),
  (@res203, @emp4),
  (@res203, @emp15),
  (@res204, @emp3),
  (@res204, @emp23),
  (@res204, @emp25),
  (@res204, @emp18),
  (@res204, @emp15),
  (@res204, @emp24),
  (@res205, @emp1),
  (@res205, @emp10),
  (@res205, @emp14),
  (@res205, @emp9),
  (@res205, @emp17),
  (@res206, @emp13),
  (@res206, @emp6),
  (@res206, @emp8),
  (@res206, @emp25),
  (@res206, @emp24),
  (@res206, @emp22),
  (@res207, @emp21),
  (@res207, @emp6),
  (@res207, @emp14),
  (@res207, @emp11),
  (@res207, @emp22),
  (@res208, @emp1),
  (@res208, @emp6),
  (@res208, @emp8),
  (@res208, @emp24),
  (@res208, @emp17),
  (@res209, @emp1),
  (@res209, @emp10),
  (@res209, @emp8),
  (@res209, @emp17),
  (@res209, @emp9),
  (@res210, @emp7),
  (@res210, @emp6),
  (@res210, @emp9),
  (@res211, @emp16),
  (@res211, @emp9),
  (@res212, @emp21),
  (@res212, @emp16),
  (@res212, @emp25),
  (@res212, @emp15),
  (@res213, @emp13),
  (@res213, @emp16),
  (@res213, @emp18),
  (@res213, @emp9),
  (@res213, @emp17),
  (@res214, @emp13),
  (@res214, @emp10),
  (@res214, @emp4),
  (@res214, @emp25),
  (@res214, @emp19),
  (@res214, @emp5),
  (@res215, @emp10),
  (@res215, @emp4),
  (@res215, @emp19),
  (@res216, @emp13),
  (@res216, @emp10),
  (@res216, @emp4),
  (@res216, @emp18),
  (@res216, @emp9),
  (@res216, @emp22),
  (@res217, @emp13),
  (@res217, @emp10),
  (@res217, @emp4),
  (@res217, @emp15),
  (@res217, @emp9),
  (@res218, @emp12),
  (@res218, @emp10),
  (@res218, @emp18),
  (@res218, @emp8),
  (@res218, @emp5),
  (@res218, @emp15),
  (@res219, @emp1),
  (@res219, @emp10),
  (@res219, @emp4),
  (@res219, @emp22),
  (@res220, @emp23),
  (@res220, @emp19),
  (@res221, @emp6),
  (@res221, @emp5),
  (@res222, @emp10),
  (@res222, @emp14),
  (@res222, @emp24),
  (@res222, @emp19),
  (@res223, @emp23),
  (@res223, @emp22),
  (@res224, @emp13),
  (@res224, @emp23),
  (@res224, @emp8),
  (@res224, @emp17),
  (@res224, @emp9),
  (@res225, @emp1),
  (@res225, @emp10),
  (@res225, @emp4),
  (@res225, @emp24),
  (@res226, @emp23),
  (@res226, @emp14),
  (@res226, @emp5),
  (@res226, @emp15),
  (@res227, @emp6),
  (@res227, @emp18),
  (@res227, @emp17),
  (@res228, @emp3),
  (@res228, @emp10),
  (@res228, @emp22),
  (@res229, @emp21),
  (@res229, @emp16),
  (@res229, @emp8),
  (@res229, @emp17),
  (@res229, @emp22),
  (@res230, @emp13),
  (@res230, @emp16),
  (@res230, @emp8),
  (@res230, @emp25),
  (@res230, @emp17),
  (@res230, @emp5),
  (@res231, @emp3),
  (@res231, @emp16),
  (@res231, @emp25),
  (@res231, @emp22),
  (@res232, @emp13),
  (@res232, @emp6),
  (@res232, @emp4),
  (@res232, @emp8),
  (@res232, @emp17),
  (@res232, @emp9),
  (@res233, @emp1),
  (@res233, @emp23),
  (@res233, @emp17),
  (@res234, @emp23),
  (@res234, @emp14),
  (@res234, @emp24),
  (@res235, @emp1),
  (@res235, @emp10),
  (@res235, @emp8),
  (@res235, @emp22),
  (@res235, @emp9),
  (@res236, @emp21),
  (@res236, @emp23),
  (@res236, @emp14),
  (@res236, @emp5),
  (@res236, @emp11),
  (@res237, @emp16),
  (@res237, @emp4),
  (@res237, @emp15),
  (@res238, @emp1),
  (@res238, @emp6),
  (@res238, @emp8),
  (@res238, @emp19),
  (@res239, @emp10),
  (@res239, @emp8),
  (@res239, @emp11),
  (@res240, @emp7),
  (@res240, @emp10),
  (@res240, @emp14),
  (@res240, @emp9),
  (@res240, @emp5),
  (@res241, @emp12),
  (@res241, @emp23),
  (@res241, @emp18),
  (@res241, @emp22),
  (@res241, @emp15),
  (@res242, @emp10),
  (@res242, @emp25),
  (@res242, @emp5),
  (@res243, @emp16),
  (@res243, @emp8),
  (@res243, @emp17),
  (@res244, @emp7),
  (@res244, @emp10),
  (@res244, @emp4),
  (@res244, @emp17),
  (@res245, @emp6),
  (@res245, @emp18),
  (@res245, @emp11),
  (@res246, @emp21),
  (@res246, @emp10),
  (@res246, @emp18),
  (@res246, @emp11),
  (@res246, @emp17),
  (@res247, @emp7),
  (@res247, @emp10),
  (@res247, @emp8),
  (@res247, @emp17),
  (@res247, @emp22),
  (@res248, @emp23),
  (@res248, @emp17),
  (@res249, @emp23),
  (@res249, @emp4),
  (@res249, @emp5),
  (@res249, @emp15),
  (@res250, @emp16),
  (@res250, @emp15),
  (@res251, @emp3),
  (@res251, @emp23),
  (@res251, @emp17),
  (@res252, @emp1),
  (@res252, @emp16),
  (@res252, @emp18),
  (@res252, @emp5),
  (@res253, @emp13),
  (@res253, @emp16),
  (@res253, @emp14),
  (@res253, @emp5),
  (@res253, @emp17),
  (@res254, @emp13),
  (@res254, @emp10),
  (@res254, @emp25),
  (@res254, @emp4),
  (@res254, @emp22),
  (@res254, @emp15),
  (@res255, @emp7),
  (@res255, @emp6),
  (@res255, @emp8),
  (@res255, @emp5),
  (@res255, @emp19),
  (@res256, @emp23),
  (@res256, @emp15),
  (@res257, @emp23),
  (@res257, @emp18),
  (@res257, @emp5),
  (@res258, @emp21),
  (@res258, @emp6),
  (@res258, @emp18),
  (@res258, @emp15),
  (@res258, @emp22),
  (@res259, @emp1),
  (@res259, @emp16),
  (@res259, @emp18),
  (@res259, @emp5),
  (@res260, @emp6),
  (@res260, @emp18),
  (@res260, @emp22),
  (@res260, @emp15),
  (@res261, @emp12),
  (@res261, @emp6),
  (@res261, @emp14),
  (@res261, @emp18),
  (@res261, @emp17),
  (@res261, @emp15),
  (@res262, @emp1),
  (@res262, @emp6),
  (@res262, @emp14),
  (@res262, @emp18),
  (@res262, @emp19),
  (@res262, @emp5),
  (@res263, @emp23),
  (@res263, @emp9),
  (@res264, @emp3),
  (@res264, @emp10),
  (@res264, @emp8),
  (@res264, @emp15),
  (@res264, @emp24),
  (@res265, @emp21),
  (@res265, @emp23),
  (@res265, @emp4),
  (@res265, @emp17),
  (@res265, @emp5),
  (@res266, @emp16),
  (@res266, @emp17),
  (@res267, @emp3),
  (@res267, @emp6),
  (@res267, @emp8),
  (@res267, @emp11),
  (@res268, @emp23),
  (@res268, @emp8),
  (@res268, @emp9),
  (@res269, @emp7),
  (@res269, @emp6),
  (@res269, @emp14),
  (@res269, @emp19),
  (@res270, @emp13),
  (@res270, @emp6),
  (@res270, @emp18),
  (@res270, @emp15),
  (@res270, @emp22),
  (@res271, @emp3),
  (@res271, @emp16),
  (@res271, @emp9),
  (@res272, @emp21),
  (@res272, @emp23),
  (@res272, @emp14),
  (@res272, @emp5),
  (@res272, @emp22),
  (@res273, @emp13),
  (@res273, @emp23),
  (@res273, @emp8),
  (@res273, @emp14),
  (@res273, @emp9),
  (@res273, @emp22),
  (@res274, @emp1),
  (@res274, @emp16),
  (@res274, @emp8),
  (@res274, @emp19),
  (@res274, @emp15),
  (@res275, @emp6),
  (@res275, @emp15),
  (@res276, @emp6),
  (@res276, @emp8),
  (@res276, @emp5),
  (@res277, @emp21),
  (@res277, @emp23),
  (@res277, @emp25),
  (@res277, @emp19),
  (@res278, @emp12),
  (@res278, @emp23),
  (@res278, @emp14),
  (@res278, @emp8),
  (@res278, @emp22),
  (@res278, @emp9),
  (@res279, @emp21),
  (@res279, @emp6),
  (@res279, @emp4),
  (@res279, @emp14),
  (@res279, @emp5),
  (@res279, @emp19),
  (@res280, @emp10),
  (@res280, @emp14),
  (@res280, @emp19),
  (@res281, @emp3),
  (@res281, @emp23),
  (@res281, @emp18),
  (@res281, @emp14),
  (@res281, @emp15),
  (@res281, @emp17),
  (@res282, @emp3),
  (@res282, @emp16),
  (@res282, @emp18),
  (@res282, @emp4),
  (@res282, @emp15),
  (@res282, @emp22),
  (@res283, @emp13),
  (@res283, @emp10),
  (@res283, @emp14),
  (@res283, @emp5),
  (@res283, @emp15),
  (@res284, @emp13),
  (@res284, @emp23),
  (@res284, @emp14),
  (@res284, @emp9),
  (@res284, @emp11),
  (@res285, @emp21),
  (@res285, @emp10),
  (@res285, @emp14),
  (@res285, @emp22),
  (@res285, @emp17),
  (@res286, @emp13),
  (@res286, @emp6),
  (@res286, @emp25),
  (@res286, @emp5),
  (@res286, @emp19),
  (@res287, @emp3),
  (@res287, @emp6),
  (@res287, @emp4),
  (@res287, @emp11),
  (@res288, @emp16),
  (@res288, @emp18),
  (@res288, @emp11),
  (@res289, @emp3),
  (@res289, @emp10),
  (@res289, @emp4),
  (@res289, @emp14),
  (@res289, @emp11),
  (@res289, @emp22),
  (@res290, @emp21),
  (@res290, @emp10),
  (@res290, @emp4),
  (@res290, @emp18),
  (@res290, @emp17),
  (@res290, @emp19),
  (@res291, @emp13),
  (@res291, @emp10),
  (@res291, @emp8),
  (@res291, @emp15),
  (@res291, @emp19),
  (@res292, @emp1),
  (@res292, @emp6),
  (@res292, @emp4),
  (@res292, @emp17),
  (@res292, @emp11),
  (@res293, @emp10),
  (@res293, @emp25),
  (@res293, @emp22),
  (@res293, @emp11),
  (@res294, @emp13),
  (@res294, @emp10),
  (@res294, @emp4),
  (@res294, @emp19),
  (@res295, @emp7),
  (@res295, @emp6),
  (@res295, @emp4),
  (@res295, @emp5),
  (@res295, @emp9),
  (@res296, @emp7),
  (@res296, @emp10),
  (@res296, @emp4),
  (@res296, @emp9),
  (@res296, @emp17),
  (@res297, @emp6),
  (@res297, @emp14),
  (@res297, @emp15),
  (@res298, @emp3),
  (@res298, @emp23),
  (@res298, @emp14),
  (@res298, @emp5),
  (@res299, @emp6),
  (@res299, @emp4),
  (@res299, @emp19),
  (@res300, @emp7),
  (@res300, @emp16),
  (@res300, @emp4),
  (@res300, @emp8),
  (@res300, @emp9),
  (@res300, @emp11),
  (@res301, @emp10),
  (@res301, @emp18),
  (@res301, @emp5),
  (@res301, @emp9),
  (@res302, @emp7),
  (@res302, @emp6),
  (@res302, @emp8),
  (@res302, @emp11),
  (@res302, @emp5),
  (@res303, @emp13),
  (@res303, @emp6),
  (@res303, @emp8),
  (@res303, @emp15),
  (@res303, @emp9),
  (@res304, @emp16),
  (@res304, @emp14),
  (@res304, @emp22),
  (@res305, @emp10),
  (@res305, @emp8),
  (@res305, @emp22),
  (@res306, @emp7),
  (@res306, @emp23),
  (@res306, @emp18),
  (@res306, @emp4),
  (@res306, @emp22),
  (@res306, @emp11),
  (@res307, @emp7),
  (@res307, @emp10),
  (@res307, @emp18),
  (@res307, @emp22),
  (@res307, @emp11),
  (@res308, @emp3),
  (@res308, @emp6),
  (@res308, @emp18),
  (@res308, @emp4),
  (@res308, @emp11),
  (@res308, @emp17),
  (@res309, @emp13),
  (@res309, @emp23),
  (@res309, @emp8),
  (@res309, @emp18),
  (@res309, @emp19),
  (@res309, @emp15),
  (@res310, @emp13),
  (@res310, @emp16),
  (@res310, @emp8),
  (@res310, @emp18),
  (@res310, @emp15),
  (@res310, @emp19),
  (@res311, @emp12),
  (@res311, @emp6),
  (@res311, @emp8),
  (@res311, @emp18),
  (@res311, @emp19),
  (@res311, @emp15),
  (@res312, @emp3),
  (@res312, @emp16),
  (@res312, @emp18),
  (@res312, @emp22),
  (@res312, @emp9),
  (@res313, @emp1),
  (@res313, @emp10),
  (@res313, @emp8),
  (@res313, @emp5),
  (@res313, @emp17),
  (@res314, @emp1),
  (@res314, @emp6),
  (@res314, @emp14),
  (@res314, @emp18),
  (@res314, @emp17),
  (@res314, @emp11),
  (@res315, @emp1),
  (@res315, @emp6),
  (@res315, @emp14),
  (@res315, @emp17),
  (@res316, @emp1),
  (@res316, @emp23),
  (@res316, @emp4),
  (@res316, @emp22),
  (@res316, @emp11),
  (@res317, @emp12),
  (@res317, @emp10),
  (@res317, @emp14),
  (@res317, @emp18),
  (@res317, @emp11),
  (@res317, @emp9),
  (@res318, @emp21),
  (@res318, @emp6),
  (@res318, @emp14),
  (@res318, @emp15),
  (@res318, @emp9),
  (@res319, @emp1),
  (@res319, @emp6),
  (@res319, @emp18),
  (@res319, @emp9),
  (@res319, @emp5),
  (@res320, @emp3),
  (@res320, @emp23),
  (@res320, @emp18),
  (@res320, @emp14),
  (@res320, @emp19),
  (@res320, @emp9),
  (@res321, @emp1),
  (@res321, @emp10),
  (@res321, @emp14),
  (@res321, @emp11),
  (@res321, @emp22),
  (@res322, @emp3),
  (@res322, @emp23),
  (@res322, @emp18),
  (@res322, @emp15),
  (@res322, @emp22),
  (@res323, @emp10),
  (@res323, @emp5),
  (@res324, @emp13),
  (@res324, @emp10),
  (@res324, @emp14),
  (@res324, @emp15),
  (@res324, @emp5),
  (@res325, @emp3),
  (@res325, @emp16),
  (@res325, @emp8),
  (@res325, @emp5),
  (@res326, @emp21),
  (@res326, @emp10),
  (@res326, @emp8),
  (@res326, @emp14),
  (@res326, @emp19),
  (@res326, @emp9),
  (@res327, @emp1),
  (@res327, @emp23),
  (@res327, @emp14),
  (@res327, @emp5),
  (@res328, @emp3),
  (@res328, @emp6),
  (@res328, @emp18),
  (@res328, @emp11),
  (@res328, @emp15),
  (@res329, @emp10),
  (@res329, @emp14),
  (@res329, @emp5),
  (@res330, @emp3),
  (@res330, @emp23),
  (@res330, @emp14),
  (@res330, @emp18),
  (@res330, @emp5),
  (@res330, @emp22),
  (@res331, @emp1),
  (@res331, @emp23),
  (@res331, @emp14),
  (@res331, @emp9),
  (@res332, @emp3),
  (@res332, @emp23),
  (@res332, @emp14),
  (@res332, @emp17),
  (@res332, @emp5),
  (@res333, @emp7),
  (@res333, @emp16),
  (@res333, @emp8),
  (@res333, @emp19),
  (@res334, @emp3),
  (@res334, @emp16),
  (@res334, @emp8),
  (@res334, @emp17),
  (@res334, @emp22),
  (@res335, @emp7),
  (@res335, @emp10),
  (@res335, @emp4),
  (@res335, @emp9),
  (@res336, @emp1),
  (@res336, @emp23),
  (@res336, @emp18),
  (@res336, @emp22),
  (@res337, @emp3),
  (@res337, @emp16),
  (@res337, @emp4),
  (@res337, @emp15),
  (@res337, @emp22),
  (@res338, @emp1),
  (@res338, @emp23),
  (@res338, @emp18),
  (@res338, @emp8),
  (@res338, @emp19),
  (@res338, @emp11),
  (@res339, @emp21),
  (@res339, @emp10),
  (@res339, @emp4),
  (@res339, @emp22),
  (@res339, @emp9),
  (@res340, @emp16),
  (@res340, @emp15),
  (@res341, @emp1),
  (@res341, @emp6),
  (@res341, @emp14),
  (@res341, @emp19),
  (@res341, @emp11),
  (@res342, @emp1),
  (@res342, @emp6),
  (@res342, @emp8),
  (@res342, @emp18),
  (@res342, @emp11),
  (@res342, @emp15),
  (@res343, @emp21),
  (@res343, @emp6),
  (@res343, @emp4),
  (@res343, @emp11),
  (@res343, @emp19),
  (@res344, @emp7),
  (@res344, @emp10),
  (@res344, @emp14),
  (@res344, @emp5),
  (@res345, @emp7),
  (@res345, @emp10),
  (@res345, @emp4),
  (@res345, @emp19),
  (@res345, @emp22),
  (@res346, @emp13),
  (@res346, @emp6),
  (@res346, @emp8),
  (@res346, @emp5),
  (@res346, @emp15),
  (@res347, @emp16),
  (@res347, @emp17),
  (@res348, @emp7),
  (@res348, @emp6),
  (@res348, @emp14),
  (@res348, @emp5),
  (@res349, @emp23),
  (@res349, @emp8),
  (@res349, @emp11),
  (@res349, @emp9),
  (@res350, @emp13),
  (@res350, @emp10),
  (@res350, @emp8),
  (@res350, @emp18),
  (@res350, @emp22),
  (@res350, @emp9),
  (@res351, @emp12),
  (@res351, @emp16),
  (@res351, @emp18),
  (@res351, @emp8),
  (@res351, @emp17),
  (@res351, @emp9),
  (@res352, @emp13),
  (@res352, @emp16),
  (@res352, @emp14),
  (@res352, @emp17),
  (@res353, @emp21),
  (@res353, @emp16),
  (@res353, @emp18),
  (@res353, @emp17),
  (@res354, @emp7),
  (@res354, @emp10),
  (@res354, @emp14),
  (@res354, @emp17),
  (@res355, @emp6),
  (@res355, @emp9),
  (@res356, @emp1),
  (@res356, @emp23),
  (@res356, @emp14),
  (@res356, @emp9),
  (@res356, @emp19),
  (@res357, @emp21),
  (@res357, @emp16),
  (@res357, @emp4),
  (@res357, @emp11),
  (@res357, @emp22),
  (@res358, @emp7),
  (@res358, @emp6),
  (@res358, @emp14),
  (@res358, @emp15),
  (@res358, @emp9),
  (@res359, @emp21),
  (@res359, @emp23),
  (@res359, @emp4),
  (@res359, @emp9),
  (@res359, @emp5),
  (@res360, @emp16),
  (@res360, @emp11),
  (@res361, @emp13),
  (@res361, @emp16),
  (@res361, @emp18),
  (@res361, @emp22),
  (@res361, @emp17),
  (@res362, @emp7),
  (@res362, @emp6),
  (@res362, @emp18),
  (@res362, @emp11),
  (@res362, @emp5),
  (@res363, @emp13),
  (@res363, @emp10),
  (@res363, @emp18),
  (@res363, @emp9),
  (@res364, @emp7),
  (@res364, @emp10),
  (@res364, @emp8),
  (@res364, @emp22),
  (@res364, @emp19),
  (@res365, @emp12),
  (@res365, @emp16),
  (@res365, @emp4),
  (@res365, @emp18),
  (@res365, @emp17),
  (@res365, @emp5),
  (@res366, @emp23),
  (@res366, @emp19),
  (@res367, @emp21),
  (@res367, @emp23),
  (@res367, @emp4),
  (@res367, @emp19),
  (@res367, @emp11),
  (@res368, @emp7),
  (@res368, @emp16),
  (@res368, @emp4),
  (@res368, @emp15),
  (@res369, @emp16),
  (@res369, @emp4),
  (@res369, @emp11),
  (@res370, @emp3),
  (@res370, @emp10),
  (@res370, @emp14),
  (@res370, @emp17),
  (@res371, @emp1),
  (@res371, @emp16),
  (@res371, @emp8),
  (@res371, @emp9);

-- ======================================================================
-- 20. PAGOS Y SUS METODOS
-- ======================================================================
-- saldo_pendiente = lo que faltaba pagar despues de ese pago (sin contar los anulados).
-- Las anuladas no tienen pagos (una reserva con pagos no se puede anular).
-- Algunas finalizadas quedaron con saldo pendiente: el cliente todavia debe una parte.
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res1, 188000, 282000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res1, 282000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res2, 408000, 407000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res2, 407000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res3, 266000, 399000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res3, 399000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res4, 342000, 513000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res4, 233000, 280000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res4, 280000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res6, 98000, 97000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res6, 52000, 45000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res6, 26000, 19000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res7, 146000, 339000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res7, 147000, 192000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res7, 192000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res8, 310000, 725000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res8, 725000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res9, 52000, 53000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res9, 53000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res10, 123000, 287000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res10, 287000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res11, 232000, 233000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res11, 233000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res12, 438000, 437000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res12, 180000, 257000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res12, 257000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res13, 298000, 297000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res13, 133000, 164000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res13, 164000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res14, 360000, 360000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res14, 154000, 206000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res14, 206000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res16, 108000, 107000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res16, 107000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res17, 64000, 151000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res17, 151000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res18, 38000, 87000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res18, 87000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res19, 65000, 65000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res19, 65000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res20, 328000, 327000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res20, 327000, 0, 0, '2025-01-02 12:00:00', 'La transferencia fue rechazada por el banco.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res20, 327000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res21, 134000, 201000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res21, 116000, 85000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res21, 85000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res22, 348000, 347000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res22, 347000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res23, 52000, 78000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res23, 34000, 44000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res23, 44000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res24, 340000, 795000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res24, 795000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res25, 350000, 350000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res25, 165000, 185000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res25, 185000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res26, 46000, 69000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res26, 69000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res27, 250000, 375000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res27, 375000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res28, 374000, 561000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res28, 561000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res29, 288000, 432000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res29, 213000, 219000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res30, 330000, 495000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res30, 200000, 295000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res30, 295000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res31, 46000, 69000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res31, 69000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res32, 350000, 815000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res32, 815000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res33, 432000, 1008000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res33, 1008000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res34, 225000, 225000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res34, 105000, 120000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res34, 120000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res35, 68000, 67000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res35, 34000, 33000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res35, 33000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res36, 230000, 230000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res36, 230000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res37, 258000, 257000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res37, 257000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res38, 164000, 246000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res38, 246000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res39, 278000, 417000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res39, 203000, 214000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res39, 214000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res40, 260000, 260000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res40, 158000, 102000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res41, 290000, 290000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res41, 290000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res42, 236000, 354000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res42, 354000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res43, 388000, 582000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res43, 299000, 283000, 0, '2025-03-01 12:00:00', 'La transferencia fue rechazada por el banco.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res43, 299000, 283000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res43, 283000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res44, 158000, 367000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res44, 367000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res45, 78000, 77000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res45, 77000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res46, 235000, 235000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res46, 235000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res47, 312000, 313000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res47, 313000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res48, 48000, 72000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res48, 72000, 0, 0, '2025-03-21 12:00:00', 'Se cargó el monto equivocado.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res48, 72000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res49, 164000, 246000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res49, 246000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res50, 48000, 72000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res50, 72000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res51, 408000, 407000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res51, 186000, 221000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res51, 221000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res52, 60000, 60000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res52, 60000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res53, 226000, 529000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res53, 529000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res54, 110000, 110000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res54, 51000, 59000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res55, 520000, 520000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res55, 520000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res56, 286000, 429000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res56, 183000, 246000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res56, 246000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res57, 338000, 337000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res57, 142000, 195000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res57, 195000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res58, 44000, 101000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res58, 56000, 45000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res58, 45000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res59, 44000, 101000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res59, 101000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res60, 160000, 375000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res60, 212000, 163000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res60, 163000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res62, 518000, 777000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res62, 777000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res63, 192000, 288000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res63, 131000, 157000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res63, 157000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res64, 50000, 75000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res64, 46000, 29000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res65, 291000, 679000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res65, 283000, 396000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res65, 396000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res66, 129000, 301000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res66, 301000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res67, 44000, 101000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res67, 101000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res68, 178000, 417000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res68, 234000, 183000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res68, 183000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res69, 240000, 560000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res69, 560000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res70, 38000, 87000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res70, 87000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res71, 62000, 63000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res71, 63000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res72, 245000, 245000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res72, 99000, 146000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res72, 146000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res73, 220000, 220000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res73, 220000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res74, 230000, 230000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res74, 230000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res75, 662000, 663000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res75, 663000, 0, 0, '2025-05-08 12:00:00', 'Pago duplicado por error.', @usr_delafuentec); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res75, 663000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res76, 515000, 515000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res76, 515000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res77, 60000, 90000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res77, 50000, 40000, 0, '2025-05-11 12:00:00', 'Se cargó el monto equivocado.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res77, 50000, 40000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res77, 40000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res78, 326000, 489000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res78, 266000, 223000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res78, 223000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res79, 280000, 280000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res79, 280000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res80, 75000, 75000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res80, 33000, 42000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res80, 42000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res81, 58000, 87000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res81, 87000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res83, 52000, 78000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res83, 40000, 38000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res83, 38000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res84, 44000, 101000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res84, 59000, 42000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res84, 26000, 16000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res85, 208000, 487000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res85, 283000, 204000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res85, 204000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res86, 180000, 270000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res86, 124000, 146000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res87, 154000, 231000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res87, 231000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res88, 336000, 784000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res88, 784000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res89, 39000, 91000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res89, 91000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res90, 320000, 320000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res90, 173000, 147000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res90, 147000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res91, 410000, 955000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res91, 955000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res92, 152000, 353000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res92, 189000, 164000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res92, 164000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res94, 424000, 636000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res94, 636000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res95, 224000, 336000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res95, 336000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res96, 182000, 273000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res96, 273000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res97, 202000, 303000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res97, 303000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res98, 75000, 75000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res98, 75000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res99, 184000, 276000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res99, 276000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res100, 46000, 109000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res100, 71000, 38000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res101, 342000, 343000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res101, 343000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res102, 255000, 255000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res102, 126000, 129000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res102, 129000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res103, 75000, 75000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res103, 75000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res104, 365000, 365000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res104, 365000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res105, 602000, 603000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res105, 247000, 356000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res105, 356000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res107, 536000, 804000, 0, '2025-06-26 12:00:00', 'Pago duplicado por error.', @usr_admin); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res107, 536000, 804000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res107, 457000, 347000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res108, 176000, 409000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res108, 183000, 226000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res108, 226000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res109, 230000, 345000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res109, 345000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res110, 68000, 67000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res110, 67000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res112, 332000, 333000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res112, 189000, 144000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res112, 144000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res113, 64000, 96000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res113, 46000, 50000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res113, 50000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res114, 42000, 98000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res114, 98000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res115, 42000, 98000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res115, 98000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res116, 46000, 109000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res116, 109000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res117, 70000, 70000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res117, 29000, 41000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res117, 41000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res118, 336000, 784000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res118, 784000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res119, 56000, 84000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res119, 44000, 40000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res119, 40000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res120, 270000, 270000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res120, 153000, 117000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res120, 117000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res121, 330000, 330000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res121, 145000, 185000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res121, 185000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res122, 291000, 679000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res122, 679000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res123, 82000, 83000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res123, 47000, 36000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res123, 36000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res124, 584000, 876000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res124, 462000, 414000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res124, 414000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res125, 208000, 487000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res125, 487000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res126, 42000, 98000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res126, 57000, 41000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res126, 41000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res127, 292000, 293000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res127, 196000, 97000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res128, 212000, 493000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res128, 493000, 0, 0, '2025-09-13 12:00:00', 'Pago duplicado por error.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res128, 493000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res129, 192000, 288000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res129, 151000, 137000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res129, 137000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res130, 82000, 193000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res130, 193000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res131, 286000, 669000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res131, 669000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res132, 198000, 297000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res132, 297000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res133, 51000, 119000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res133, 119000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res134, 488000, 732000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res134, 732000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res135, 102000, 238000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res135, 89000, 149000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res136, 250000, 375000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res136, 375000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res138, 278000, 277000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res138, 277000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res139, 188000, 437000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res139, 437000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res140, 318000, 317000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res140, 317000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res141, 58000, 87000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res141, 36000, 51000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res141, 51000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res143, 76000, 179000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res143, 179000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res144, 140000, 140000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res144, 140000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res145, 256000, 599000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res145, 326000, 273000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res145, 273000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res146, 44000, 101000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res146, 50000, 51000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res146, 51000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res147, 78000, 182000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res147, 91000, 91000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res147, 91000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res148, 345000, 805000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res148, 361000, 444000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res148, 444000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res149, 528000, 792000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res149, 426000, 366000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res149, 366000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res150, 544000, 1271000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res150, 651000, 620000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res150, 620000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res151, 374000, 561000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res151, 309000, 252000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res151, 252000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res152, 244000, 366000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res152, 366000, 0, 0, '2025-10-10 12:00:00', 'Se cargó el monto equivocado.', @usr_delafuentec); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res152, 366000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res154, 60000, 90000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res154, 90000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res155, 80000, 185000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res155, 185000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res156, 132000, 133000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res156, 133000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res157, 204000, 306000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res157, 306000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res158, 132000, 133000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res158, 68000, 65000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res158, 65000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res159, 75000, 75000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res159, 44000, 31000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res159, 31000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res160, 322000, 323000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res160, 323000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res161, 432000, 433000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res161, 433000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res162, 108000, 162000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res162, 162000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res163, 354000, 531000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res163, 236000, 295000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res163, 295000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res164, 75000, 75000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res164, 75000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res165, 552000, 553000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res165, 553000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res166, 330000, 495000, 0, '2025-11-28 12:00:00', 'Pago duplicado por error.', @usr_gutierrezm); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res166, 330000, 495000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res166, 495000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res167, 144000, 216000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res167, 123000, 93000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res167, 93000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res168, 148000, 147000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res168, 147000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res169, 418000, 417000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res169, 417000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res170, 62000, 93000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res170, 46000, 47000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res170, 47000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res171, 300000, 450000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res171, 450000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res172, 70000, 105000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res172, 105000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res173, 92000, 213000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res173, 213000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res174, 46000, 109000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res174, 109000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res175, 185000, 185000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res175, 185000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res176, 482000, 483000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res176, 251000, 232000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res177, 206000, 479000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res177, 282000, 197000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res177, 103000, 94000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res178, 72000, 108000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res178, 43000, 65000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res178, 65000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res179, 448000, 672000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res179, 672000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res180, 74000, 111000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res180, 111000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res181, 350000, 525000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res181, 289000, 236000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res181, 109000, 127000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res182, 62000, 143000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res182, 70000, 73000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res183, 80000, 80000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res183, 43000, 37000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res183, 37000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res185, 48000, 112000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res185, 54000, 58000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res185, 58000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res187, 48000, 112000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res187, 54000, 58000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res188, 252000, 378000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res188, 378000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res189, 352000, 353000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res189, 353000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res190, 318000, 477000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res190, 477000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res191, 76000, 114000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res191, 59000, 55000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res191, 55000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res192, 92000, 93000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res192, 93000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res193, 258000, 602000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res193, 602000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res194, 320000, 480000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res194, 480000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res195, 540000, 540000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res195, 313000, 227000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res195, 227000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res196, 518000, 517000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res196, 517000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res199, 306000, 714000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res199, 714000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res200, 228000, 342000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res200, 342000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res201, 318000, 317000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res201, 144000, 173000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res201, 173000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res203, 66000, 99000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res203, 99000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res204, 784000, 1176000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res204, 554000, 622000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res204, 622000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res205, 360000, 360000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res205, 360000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res206, 330000, 770000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res206, 770000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res207, 266000, 399000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res207, 230000, 169000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res207, 169000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res208, 218000, 507000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res208, 290000, 217000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res209, 362000, 363000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res209, 363000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res210, 76000, 114000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res210, 50000, 64000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res210, 64000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res211, 98000, 97000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res211, 57000, 40000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res211, 21000, 19000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res212, 408000, 407000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res212, 175000, 232000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res213, 226000, 339000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res213, 339000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res214, 464000, 696000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res214, 696000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res215, 322000, 323000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res215, 323000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res216, 482000, 1123000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res216, 1123000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res217, 338000, 787000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res217, 787000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res218, 572000, 858000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res218, 858000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res220, 60000, 140000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res220, 140000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res222, 544000, 816000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res222, 816000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res223, 100000, 100000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res223, 100000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res224, 528000, 792000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res225, 262000, 393000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res225, 161000, 232000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res225, 232000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res226, 88000, 132000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res226, 132000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res227, 68000, 102000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res227, 102000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res228, 98000, 97000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res228, 53000, 44000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res228, 44000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res229, 172000, 403000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res229, 183000, 220000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res229, 220000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res230, 352000, 823000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res230, 354000, 469000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res231, 332000, 498000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res231, 498000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res232, 372000, 558000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res232, 558000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res233, 98000, 97000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res233, 97000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res234, 85000, 85000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res234, 85000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res235, 750000, 750000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res236, 404000, 941000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res236, 941000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res237, 88000, 87000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res237, 87000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res238, 238000, 357000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res238, 357000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res239, 332000, 333000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res239, 333000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res240, 422000, 983000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res240, 543000, 440000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res240, 440000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res241, 333000, 777000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res241, 222000, 555000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res242, 266000, 399000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res242, 187000, 212000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res242, 212000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res243, 70000, 105000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res243, 58000, 47000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res243, 47000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res244, 255000, 595000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res244, 216000, 379000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res246, 442000, 663000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res246, 279000, 384000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res246, 384000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res247, 600000, 900000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res247, 900000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res249, 190000, 445000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res249, 445000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res250, 216000, 504000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res250, 504000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res252, 344000, 516000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res252, 516000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res254, 872000, 873000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res254, 413000, 460000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res254, 179000, 281000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res255, 352000, 353000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res256, 102000, 103000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res256, 103000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res257, 52000, 123000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res257, 64000, 59000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res257, 59000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res259, 302000, 303000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res259, 303000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res260, 112000, 113000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res260, 113000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res261, 710000, 710000, 0, '2026-06-11 12:00:00', 'Pago duplicado por error.', @usr_delafuentec); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res261, 710000, 710000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res261, 284000, 426000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res262, 364000, 546000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res262, 227000, 319000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res262, 319000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res263, 102000, 103000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res263, 103000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res264, 230000, 535000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res264, 535000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res265, 308000, 462000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res265, 462000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res266, 105000, 105000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res266, 105000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res268, 72000, 108000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res268, 108000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res269, 246000, 369000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res269, 221000, 148000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res269, 148000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res270, 565000, 565000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res270, 238000, 327000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res270, 327000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res272, 242000, 363000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res272, 157000, 206000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res272, 206000, 0, 0, '2026-06-30 12:00:00', 'Se cargó el monto equivocado.', @usr_admin); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res272, 206000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res273, 276000, 644000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res273, 644000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res275, 160000, 160000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res275, 160000, 0, 0, '2026-07-08 12:00:00', 'Se cargó el monto equivocado.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res275, 160000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res276, 90000, 90000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res276, 90000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res277, 294000, 686000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res277, 686000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res278, 508000, 762000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res278, 762000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res280, 54000, 126000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res280, 55000, 71000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res280, 71000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res281, 381000, 889000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res281, 889000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res282, 684000, 1026000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res282, 501000, 525000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res282, 525000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res283, 178000, 712000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res284, 312000, 468000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res284, 207000, 261000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res284, 261000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res285, 234000, 546000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res285, 288000, 258000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res285, 118000, 140000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res286, 312000, 468000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res286, 468000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res287, 208000, 487000, 0, '2026-08-05 12:00:00', 'Pago duplicado por error.', @usr_gutierrezm); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res287, 208000, 487000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res287, 487000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res288, 515000, 515000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res288, 275000, 240000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res288, 240000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res289, 392000, 588000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res289, 588000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res290, 426000, 1704000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res291, 480000, 720000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res291, 720000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res292, 216000, 504000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res293, 330000, 770000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res293, 770000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res294, 392000, 588000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res294, 251000, 337000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res294, 337000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res295, 600000, 600000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res297, 515000, 515000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res297, 515000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res299, 72000, 108000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res300, 620000, 620000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res300, 620000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res301, 720000, 720000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res301, 720000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res302, 416000, 624000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res303, 234000, 546000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res304, 345000, 345000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res304, 345000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res305, 72000, 108000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res305, 108000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res309, 748000, 1122000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res310, 392000, 588000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res310, 259000, 329000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res310, 329000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res312, 520000, 520000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res312, 208000, 312000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res313, 312000, 468000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res314, 340000, 510000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res314, 240000, 270000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res314, 270000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res315, 186000, 434000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res315, 124000, 310000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res316, 178000, 712000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res318, 390000, 390000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res318, 156000, 234000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res319, 510000, 765000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res320, 404000, 941000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res321, 178000, 712000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res322, 446000, 669000, 0, '2026-09-27 12:00:00', 'Pago duplicado por error.', @usr_herrerav); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res322, 446000, 669000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res323, 296000, 444000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res326, 513000, 1197000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res326, 342000, 855000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res328, 342000, 798000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res328, 428000, 370000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res328, 247000, 123000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res329, 54000, 126000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res329, 126000, 0, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res331, 140000, 210000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res331, 70000, 140000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res332, 390000, 390000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res333, 440000, 440000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res334, 234000, 546000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res334, 156000, 390000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res337, 334000, 781000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res337, 223000, 558000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res338, 884000, 1326000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res339, 312000, 728000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res339, 208000, 520000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res340, 42000, 168000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res341, 390000, 390000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res342, 435000, 1015000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res343, 382000, 893000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res344, 211000, 844000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res345, 360000, 840000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res345, 240000, 600000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res346, 234000, 546000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res347, 160000, 160000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res350, 932000, 933000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res350, 373000, 560000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res353, 140000, 210000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res356, 144000, 576000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res359, 438000, 1022000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res360, 63000, 147000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res362, 638000, 637000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res363, 310000, 310000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res365, 644000, 966000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res365, 322000, 644000, 0, '2026-11-07 12:00:00', 'La transferencia fue rechazada por el banco.', @usr_admin); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res365, 322000, 644000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res366, 96000, 224000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res366, 64000, 160000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res367, 234000, 546000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res368, 105000, 245000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res369, 345000, 345000, 0, '2026-11-07 12:00:00', 'Se cargó el monto equivocado.', @usr_delafuentec); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res369, 345000, 345000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente, activo, fecha_baja, motivo_anulacion, id_usuario_anulacion) VALUES (@res371, 138000, 552000, 1, NULL, '', NULL); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);

COMMIT;

-- Fin. Reservas: 371 - Pagos: 711 (16 anulados)
