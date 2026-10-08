-- ======================================================================
-- DATOS DE PRUEBA - INFINITO SONIDO E ILUMINACION
-- ======================================================================
-- Como usarlo:
--   1. Levantar los contenedores (docker compose up -d). El contenedor web
--      corre las migraciones solo, asi que las tablas ya estan creadas y
--      ya tienen cargados los 30 permisos y los 3 estados de equipo.
--   2. Entrar a phpMyAdmin (http://localhost:8080), elegir la base del
--      proyecto, ir a la pestana SQL, pegar TODO este archivo y Continuar.
--      Tiene que ejecutarse todo junto de una sola vez: los ids se van
--      guardando en variables (@...) que se usan en los insert siguientes.
--   3. Usuario: admin / Contrasena: admin123
--      El resto de los usuarios entran con su usuario (primer apellido + inicial,
--      ej: alarconf) y la contrasena: Clave#2026
--      (los usuarios se crean a partir de los empleados)
--
-- Pensado para una base recien migrada (sin datos cargados a mano).
-- Si ya existe un usuario "admin" o algun DNI repetido, ese insert falla.
-- Las contrasenas van hasheadas porque el login usa check_password de Django.
-- ======================================================================

START TRANSACTION;

-- ======================================================================
-- 1. PERFIL ADMINISTRADOR (con todos los permisos, incluido Ver Registro de actividad)
-- ======================================================================
INSERT INTO infinito_sonido_perfiles (tipo_perfil) VALUES ('Administrador');
SET @perfil_admin = LAST_INSERT_ID();
INSERT INTO infinito_sonido_permisos_x_perfiles (id_perfil, id_permiso)
  SELECT @perfil_admin, id_permiso FROM infinito_sonido_permisos;

-- ======================================================================
-- 2. USUARIO ADMINISTRADOR  (usuario: admin / contrasena: admin123)
-- ======================================================================
-- Cada usuario es la cuenta de un empleado, asi que primero va el empleado del admin
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('12345678', 'Admin', 'Sistema', '3870000000', 'admin@infinito.com');
SET @emp_admin = LAST_INSERT_ID();
INSERT INTO infinito_sonido_usuarios (id_empleado, id_perfil, usuario, `contraseña`, activo, debe_cambiar_clave, fecha_ultima_modificacion, fecha_baja)
  VALUES (@emp_admin, @perfil_admin, 'admin', 'pbkdf2_sha256$600000$ImHryuoGzb4nbbVctCV6KQ$j4xSCKv3Y1k6frCDc2wiT1aWWoAQRHJQlkcsVmkiTb0=', 1, 0, CURDATE(), NULL);
SET @usr_admin = LAST_INSERT_ID();

-- ======================================================================
-- 3. PERFIL EMPLEADO (solo consulta: ve reservas, clientes, equipos, servicios y horarios)
-- ======================================================================
INSERT INTO infinito_sonido_perfiles (tipo_perfil) VALUES ('Empleado');
SET @perfil_empleado = LAST_INSERT_ID();
INSERT INTO infinito_sonido_permisos_x_perfiles (id_perfil, id_permiso)
  SELECT @perfil_empleado, id_permiso FROM infinito_sonido_permisos WHERE codigo IN ('ver_reservas','ver_clientes','ver_equipos','ver_servicios','ver_tipos_equipo','ver_horarios');

-- ======================================================================
-- 5. SUELDOS
-- ======================================================================
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (520000); SET @sueldo1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (650000); SET @sueldo2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (720000); SET @sueldo3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_sueldos (monto_sueldo) VALUES (800000); SET @sueldo4 = LAST_INSERT_ID();

-- ======================================================================
-- 6. PUESTOS
-- ======================================================================
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo4, 'DJ'); SET @puesto1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo3, 'Iluminación'); SET @puesto2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo2, 'Operario'); SET @puesto3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_puestos (id_sueldo, nombre_puesto) VALUES (@sueldo1, 'General'); SET @puesto4 = LAST_INSERT_ID();

-- ======================================================================
-- 7. EMPLEADOS (con DNI: es el usuario con el que entran al sistema)
-- ======================================================================
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('30731178', 'Facundo', 'Alarcón', '3874104729', 'facundo.alarcon@gmail.com'); SET @emp1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('31462356', 'Guillermina', 'Paz', '3874209458', 'guillermina.paz@gmail.com'); SET @emp2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('32193534', 'Ezequiel', 'Cruz', '3874314187', 'ezequiel.cruz@gmail.com'); SET @emp3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('32924712', 'Brenda', 'Quiroga', '3874418916', 'brenda.quiroga@gmail.com'); SET @emp4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('33655890', 'Ramiro', 'Ledesma', '3874523645', 'ramiro.ledesma@gmail.com'); SET @emp5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('34387068', 'Paula', 'Guzmán', '3874628374', 'paula.guzman@gmail.com'); SET @emp6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('35118246', 'Leandro', 'Aguirre', '3874733103', 'leandro.aguirre@gmail.com'); SET @emp7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('35849424', 'Milagros', 'Cardozo', '3874837832', 'milagros.cardozo@gmail.com'); SET @emp8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('36580602', 'Hernán', 'Vega', '3874942561', 'hernan.vega@gmail.com'); SET @emp9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('37311780', 'Daniela', 'Figueroa', '3875047290', 'daniela.figueroa@gmail.com'); SET @emp10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('38042958', 'Iván', 'Correa', '3875152019', 'ivan.correa@gmail.com'); SET @emp11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('38774136', 'Natalia', 'Maldonado', '3875256748', 'natalia.maldonado@gmail.com'); SET @emp12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('30505314', 'Sebastián', 'Cáceres', '3875361477', 'sebastian.caceres@gmail.com'); SET @emp13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('31236492', 'Antonella', 'Peralta', '3875466206', 'antonella.peralta@gmail.com'); SET @emp14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('31967670', 'Cristian', 'Ibáñez', '3875570935', 'cristian.ibanez@gmail.com'); SET @emp15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('32698848', 'Victoria', 'Ramos', '3875675664', 'victoria.ramos@gmail.com'); SET @emp16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('33430026', 'Emanuel', 'Toledo', '3875780393', 'emanuel.toledo@gmail.com'); SET @emp17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('34161204', 'Abril', 'Sánchez', '3875885122', 'abril.sanchez@gmail.com'); SET @emp18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('34892382', 'Franco', 'Domínguez', '3875989851', 'franco.dominguez@gmail.com'); SET @emp19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('35623560', 'Melina', 'Ponce', '3876094580', 'melina.ponce@gmail.com'); SET @emp20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('36354738', 'Bruno', 'Arias', '3876199309', 'bruno.arias@gmail.com'); SET @emp21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('37085916', 'Celeste', 'Godoy', '3876304038', 'celeste.godoy@gmail.com'); SET @emp22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('37817094', 'Lisandro', 'Mansilla', '3876408767', 'lisandro.mansilla@gmail.com'); SET @emp23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('38548272', 'Pilar', 'Villalba', '3876513496', 'pilar.villalba@gmail.com'); SET @emp24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_empleados (dni, nombre_emp, apellido_emp, telefono_emp, email_emp) VALUES ('30279450', 'Kevin', 'Juárez', '3876618225', 'kevin.juarez@gmail.com'); SET @emp25 = LAST_INSERT_ID();

-- ======================================================================
-- 7b. USUARIOS DE LOS EMPLEADOS (usuario = primer apellido + inicial, contrasena: Clave#2026)
-- ======================================================================
INSERT INTO infinito_sonido_usuarios (id_empleado, id_perfil, usuario, `contraseña`, activo, debe_cambiar_clave, fecha_ultima_modificacion, fecha_baja) VALUES
  (@emp1, @perfil_admin, 'alarconf', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp2, @perfil_empleado, 'pazg', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp3, @perfil_empleado, 'cruze', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp4, @perfil_empleado, 'quirogab', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp5, @perfil_empleado, 'ledesmar', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp6, @perfil_empleado, 'guzmanp', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp7, @perfil_empleado, 'aguirrel', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp8, @perfil_empleado, 'cardozom', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp9, @perfil_empleado, 'vegah', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp10, @perfil_empleado, 'figueroad', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp11, @perfil_empleado, 'correai', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp12, @perfil_empleado, 'maldonadon', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp13, @perfil_empleado, 'caceress', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp14, @perfil_empleado, 'peraltaa', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 0, 0, CURDATE(), '2026-09-15'),
  (@emp15, @perfil_empleado, 'ibanezc', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp16, @perfil_empleado, 'ramosv', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp17, @perfil_empleado, 'toledoe', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp18, @perfil_empleado, 'sancheza', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL),
  (@emp19, @perfil_empleado, 'dominguezf', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 0, 0, CURDATE(), '2026-09-15'),
  (@emp20, @perfil_empleado, 'poncem', 'pbkdf2_sha256$600000$VBnHGik78ngodPcY3xJWsc$8XkLjK8iHtFfqB4M4w4pUmsF54zGr99zNJgWm9OVibQ=', 1, 0, CURDATE(), NULL);

-- ======================================================================
-- 8. PUESTO DE CADA EMPLEADO (uno solo: 6 DJ, 6 Iluminacion, 9 Operario, 4 General)
-- ======================================================================
INSERT INTO infinito_sonido_puestos_x_empleados (id_empleado, id_puesto) VALUES
  (@emp1, @puesto2),
  (@emp2, @puesto3),
  (@emp3, @puesto4),
  (@emp4, @puesto1),
  (@emp5, @puesto2),
  (@emp6, @puesto3),
  (@emp7, @puesto4),
  (@emp8, @puesto2),
  (@emp9, @puesto3),
  (@emp10, @puesto3),
  (@emp11, @puesto1),
  (@emp12, @puesto2),
  (@emp13, @puesto3),
  (@emp14, @puesto4),
  (@emp15, @puesto1),
  (@emp16, @puesto3),
  (@emp17, @puesto3),
  (@emp18, @puesto1),
  (@emp19, @puesto2),
  (@emp20, @puesto3),
  (@emp21, @puesto4),
  (@emp22, @puesto1),
  (@emp23, @puesto2),
  (@emp24, @puesto3),
  (@emp25, @puesto1);

-- ======================================================================
-- 9. HORARIOS
-- ======================================================================
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (4); SET @horario1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (5); SET @horario2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (6); SET @horario3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (7); SET @horario4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (8); SET @horario5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (9); SET @horario6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (10); SET @horario7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_horarios (cantidad_horas) VALUES (12); SET @horario8 = LAST_INSERT_ID();

-- ======================================================================
-- 10. HORARIO DE CADA EMPLEADO
-- ======================================================================
INSERT INTO infinito_sonido_horarios_x_empleados (id_empleado, id_horario) VALUES
  (@emp1, @horario2),
  (@emp2, @horario6),
  (@emp3, @horario2),
  (@emp4, @horario4),
  (@emp5, @horario7),
  (@emp6, @horario8),
  (@emp7, @horario8),
  (@emp8, @horario4),
  (@emp9, @horario1),
  (@emp10, @horario2),
  (@emp11, @horario2),
  (@emp12, @horario5),
  (@emp13, @horario2),
  (@emp14, @horario8),
  (@emp15, @horario1),
  (@emp16, @horario8),
  (@emp17, @horario6),
  (@emp18, @horario4),
  (@emp19, @horario7),
  (@emp20, @horario5),
  (@emp21, @horario6),
  (@emp22, @horario6),
  (@emp23, @horario7),
  (@emp24, @horario2),
  (@emp25, @horario6);

-- ======================================================================
-- 11. TIPOS DE EQUIPO
-- ======================================================================
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Sonido'); SET @tipo1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Iluminación'); SET @tipo2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Estructuras y Soportes'); SET @tipo3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Efectos Especiales'); SET @tipo4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Cables y Accesorios'); SET @tipo5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_tipo_equipos (nombre_tipoeq) VALUES ('Video y Pantallas'); SET @tipo6 = LAST_INSERT_ID();

-- ======================================================================
-- 12. ESTADOS DE EQUIPO (ya los cargan las migraciones, solo se toman sus ids)
-- ======================================================================
SET @disponible = (SELECT id_estadoeq FROM infinito_sonido_estado_equipos WHERE nombre_estadoeq = 'Disponible');
SET @en_uso = (SELECT id_estadoeq FROM infinito_sonido_estado_equipos WHERE nombre_estadoeq = 'En uso');
SET @reparacion = (SELECT id_estadoeq FROM infinito_sonido_estado_equipos WHERE nombre_estadoeq = 'En reparación');

-- ======================================================================
-- 13. EQUIPOS
-- ======================================================================
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Consola Behringer X32 Digital 32 Canales', @disponible, 1); SET @eq1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Bafle Activo RCF ART 715-A MK4 15"', @disponible, 6); SET @eq2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Subwoofer Activo Electro-Voice ELX200 18"', @en_uso, 4); SET @eq3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Micrófono Inalámbrico Shure SM58 (Par)', @disponible, 5); SET @eq4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Micrófono de Condensador AKG P120', @disponible, 3); SET @eq5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Monitor de Piso Wharfedale Pro EVP-X15', @reparacion, 2); SET @eq6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Potencia Crown XLi 2500', @disponible, 3); SET @eq7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Controladora DJ Pioneer DDJ-FLX10', @en_uso, 2); SET @eq8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Bafle JBL EON715 15"', @disponible, 4); SET @eq9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo1, 'Consola Yamaha MG16XU 16 Canales', @disponible, 1); SET @eq10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Cabezal Móvil Beam 7R 230W', @en_uso, 8); SET @eq11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Tacho Par LED 18x10W RGBW', @disponible, 16); SET @eq12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Barra LED Móvil Sweep 8x10W', @disponible, 6); SET @eq13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Efecto LED Derby Doble RGB', @reparacion, 2); SET @eq14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Consola DMX 512 Canales DMX-Operator', @disponible, 2); SET @eq15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo2, 'Trompa Seguidora 575W con Trípode', @disponible, 1); SET @eq16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Tramo Truss Cuadrada Q30 Aluminio 2m', @disponible, 12); SET @eq17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Torre Elevadora Telescópica 5.3m 150kg', @disponible, 4); SET @eq18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Trípode Reforzado para Bafles de Metal', @en_uso, 10); SET @eq19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo3, 'Base Pesada Cuadrada de Acero 50x50', @disponible, 8); SET @eq20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Máquina de Humo 1500W DMX con Control', @disponible, 3); SET @eq21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Máquina de Fuego Frío Sparkular (Chispas)', @en_uso, 4); SET @eq22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Lanza Papelitos Eléctrico Confetti Fan', @disponible, 2); SET @eq23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo4, 'Máquina de Burbujas Doble Rotor', @reparacion, 2); SET @eq24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo5, 'Medusa Snake 16 Canales XLR 30m', @disponible, 2); SET @eq25 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo5, 'Pack Cables DMX Balanceados 10m (10u)', @disponible, 5); SET @eq26 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo5, 'Cables Speakon de Audio Profesional 15m', @disponible, 12); SET @eq27 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo6, 'Pantalla LED Modular P3.9 3x2m', @disponible, 1); SET @eq28 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo6, 'Proyector Epson 5000 Lúmenes', @en_uso, 2); SET @eq29 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_equipos (id_tipoeq, nombre_equipo, id_estadoeq, cantidad_equipo) VALUES (@tipo6, 'TV LED 65" con Pie', @disponible, 3); SET @eq30 = LAST_INSERT_ID();

-- ======================================================================
-- 14. SERVICIOS
-- ======================================================================
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Combo Fiesta de 15 (Sonido + Iluminación)', 450000); SET @serv1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Combo Boda Estándar (Sonido + Iluminación + DJ)', 650000); SET @serv2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido e Iluminación Egresados', 520000); SET @serv3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido Básico Bautismos y Almuerzos', 180000); SET @serv4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido e Iluminación para Festivales y Peñas', 800000); SET @serv5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Servicio Integral Aniversarios y Fiestas Privadas', 480000); SET @serv6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido y Luces para Cumpleaños Infantiles', 150000); SET @serv7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Servicio Premium Eventos Empresariales', 900000); SET @serv8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido y Microfonía Actos de Graduación', 260000); SET @serv9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido e Iluminación Gran Fiesta de Fin de Año', 750000); SET @serv10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Combo Cumpleaños de 18 (DJ + Pista LED)', 550000); SET @serv11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Servicio Boda Exclusiva Premium', 1200000); SET @serv12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido e Iluminación Brindis y Cenas', 220000); SET @serv13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Servicio de Audio Pool Party / Aire Libre', 300000); SET @serv14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Combo Fiesta de 15 Premium', 780000); SET @serv15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Pantalla LED y Proyección para Eventos', 350000); SET @serv16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Efectos Especiales: Humo, Chispas y Confetti', 200000); SET @serv17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Servicio DJ por Hora Extra', 60000); SET @serv18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Iluminación Arquitectónica de Salón', 280000); SET @serv19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_servicios (tipo_servicio, precio_servicio) VALUES ('Sonido para Conferencias y Charlas', 190000); SET @serv20 = LAST_INSERT_ID();

-- ======================================================================
-- 15. EQUIPOS QUE USA CADA SERVICIO (con cuantas unidades de cada uno)
-- ======================================================================
INSERT INTO infinito_sonido_equipos_x_servicios (id_equipo, id_servicio, cantidad) VALUES
  (@eq11, @serv1, 2),
  (@eq17, @serv1, 6),
  (@eq20, @serv1, 3),
  (@eq13, @serv2, 2),
  (@eq17, @serv2, 1),
  (@eq26, @serv2, 2),
  (@eq4, @serv3, 2),
  (@eq16, @serv3, 1),
  (@eq18, @serv3, 2),
  (@eq19, @serv3, 4),
  (@eq20, @serv3, 4),
  (@eq1, @serv4, 1),
  (@eq9, @serv4, 1),
  (@eq19, @serv4, 5),
  (@eq21, @serv4, 1),
  (@eq29, @serv4, 1),
  (@eq4, @serv5, 2),
  (@eq5, @serv5, 1),
  (@eq9, @serv5, 2),
  (@eq18, @serv5, 2),
  (@eq11, @serv6, 4),
  (@eq19, @serv6, 4),
  (@eq20, @serv6, 4),
  (@eq23, @serv6, 1),
  (@eq29, @serv6, 1),
  (@eq1, @serv7, 1),
  (@eq2, @serv7, 3),
  (@eq5, @serv7, 1),
  (@eq23, @serv7, 1),
  (@eq10, @serv8, 1),
  (@eq18, @serv8, 2),
  (@eq26, @serv8, 2),
  (@eq2, @serv9, 2),
  (@eq11, @serv9, 1),
  (@eq12, @serv9, 8),
  (@eq25, @serv9, 1),
  (@eq30, @serv9, 1),
  (@eq16, @serv10, 1),
  (@eq27, @serv10, 1),
  (@eq30, @serv10, 1),
  (@eq4, @serv11, 2),
  (@eq8, @serv11, 1),
  (@eq13, @serv11, 2),
  (@eq27, @serv11, 1),
  (@eq1, @serv12, 1),
  (@eq17, @serv12, 5),
  (@eq21, @serv12, 1),
  (@eq2, @serv13, 3),
  (@eq4, @serv13, 2),
  (@eq22, @serv13, 2),
  (@eq1, @serv14, 1),
  (@eq12, @serv14, 3),
  (@eq25, @serv14, 1),
  (@eq5, @serv15, 1),
  (@eq21, @serv15, 1),
  (@eq22, @serv15, 2),
  (@eq26, @serv15, 1),
  (@eq11, @serv16, 4),
  (@eq21, @serv16, 1),
  (@eq29, @serv16, 1),
  (@eq1, @serv17, 1),
  (@eq4, @serv17, 1),
  (@eq8, @serv17, 1),
  (@eq15, @serv17, 1),
  (@eq29, @serv17, 1),
  (@eq1, @serv18, 1),
  (@eq18, @serv18, 2),
  (@eq19, @serv18, 4),
  (@eq4, @serv19, 1),
  (@eq17, @serv19, 2),
  (@eq18, @serv19, 1),
  (@eq21, @serv19, 1),
  (@eq9, @serv20, 1),
  (@eq12, @serv20, 7),
  (@eq17, @serv20, 1),
  (@eq22, @serv20, 1),
  (@eq25, @serv20, 1);

-- ======================================================================
-- 16. CLIENTES
-- ======================================================================
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ayelén', 'Saez', 'Av. Belgrano 240, Salta', '3875271828', 'ayelensaez@gmail.com'); SET @cli1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Juan', 'Pérez', 'Mitre 1250, Salta', '3875543656', 'juanperez@gmail.com'); SET @cli2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Laura', 'Alarcón', 'España 455, Salta', '3875815484', 'lauraalarcon@gmail.com'); SET @cli3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Jesús', 'González', 'Caseros 980, Salta', '3876087312', 'jesusgonzalez@gmail.com'); SET @cli4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Mariana', 'López', 'Av. Bolivia 3300, Salta', '3876359140', 'marianalopez@gmail.com'); SET @cli5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Pablo', 'Martínez', 'Alvarado 712, Salta', '3876630968', 'pablomartinez@gmail.com'); SET @cli6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Gabriela', 'Díaz', 'Pueyrredón 150, Salta', '3876902796', 'gabrieladiaz@gmail.com'); SET @cli7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Ricardo', 'Morales', 'Av. Tavella 2100, Salta', '3877174624', 'ricardomorales@gmail.com'); SET @cli8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Silvina', 'Ríos', 'Zuviría 333, Salta', '3877446452', 'silvinarios@gmail.com'); SET @cli9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Esteban', 'Vera', 'Rivadavia 60, Cerrillos', '3877718280', 'estebanvera@gmail.com'); SET @cli10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Andrea', 'Cabrera', 'Güemes 845, Salta', '3877990108', 'andreacabrera@gmail.com'); SET @cli11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Marcelo', 'Ojeda', 'Av. Entre Ríos 1500, Salta', '3878261936', 'marceloojeda@gmail.com'); SET @cli12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Verónica', 'Soria', 'Santiago del Estero 400, Salta', '3878533764', 'veronicasoria@gmail.com'); SET @cli13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Claudio', 'Navarro', 'Lerma 77, Vaqueros', '3878805592', 'claudionavarro@gmail.com'); SET @cli14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Romina', 'Paz', 'Urquiza 1020, Salta', '3879077420', 'rominapaz@gmail.com'); SET @cli15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Fernando', 'Ibarra', 'San Martín 2200, Salta', '3879349248', 'fernandoibarra@gmail.com'); SET @cli16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Lorena', 'Méndez', 'Av. Virrey Toledo 690, Salta', '3879621076', 'lorenamendez@gmail.com'); SET @cli17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Damián', 'Coronel', 'Buenos Aires 15, San Lorenzo', '3879892904', 'damiancoronel@gmail.com'); SET @cli18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Cecilia', 'Bravo', 'Córdoba 530, Salta', '3875164733', 'ceciliabravo@gmail.com'); SET @cli19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Alejandro', 'Funes', 'Ituzaingó 870, Salta', '3875436561', 'alejandrofunes@gmail.com'); SET @cli20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Noelia', 'Rivero', 'Av. Paraguay 2500, Salta', '3875708389', 'noeliarivero@gmail.com'); SET @cli21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Gustavo', 'Aráoz', 'Leguizamón 1400, Salta', '3875980217', 'gustavoaraoz@gmail.com'); SET @cli22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Mónica', 'Chávez', 'Balcarce 950, Salta', '3876252045', 'monicachavez@gmail.com'); SET @cli23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Hugo', 'Saravia', 'Deán Funes 300, Salta', '3876523873', 'hugosaravia@gmail.com'); SET @cli24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Patricia', 'Cornejo', 'Av. Sarmiento 610, Salta', '3876795701', 'patriciacornejo@gmail.com'); SET @cli25 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Walter', 'Burgos', 'Tucumán 180, Salta', '3877067529', 'walterburgos@gmail.com'); SET @cli26 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Yanina', 'Sulca', 'Av. Independencia 1780, Salta', '3877339357', 'yaninasulca@gmail.com'); SET @cli27 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Oscar', 'Mamaní', 'Jujuy 420, Salta', '3877611185', 'oscarmamani@gmail.com'); SET @cli28 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Elena', 'Gareca', 'La Rioja 1100, Salta', '3877883013', 'elenagareca@gmail.com'); SET @cli29 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_clientes (nombre_cliente, apellido_cliente, domicilio_cliente, telefono_cliente, email_cliente) VALUES ('Iara', 'Tapia', 'Catamarca 260, Salta', '3878154841', 'iaratapia@gmail.com'); SET @cli30 = LAST_INSERT_ID();

-- ======================================================================
-- 17. METODOS DE PAGO
-- ======================================================================
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago) VALUES ('Efectivo'); SET @mp1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago) VALUES ('Transferencia Bancaria'); SET @mp2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago) VALUES ('Tarjeta de Débito'); SET @mp3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago) VALUES ('Tarjeta de Crédito'); SET @mp4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago) VALUES ('Mercado Pago'); SET @mp5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_metodo_pagos (metodo_pago) VALUES ('Cheque'); SET @mp6 = LAST_INSERT_ID();

-- ======================================================================
-- 18. RESERVAS (el monto_total es la suma de los precios de sus servicios)
-- ======================================================================
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli1, 'Cumpleaños de 15 Saez', '2026-09-22', '13:00:00', 'Salón Los Álamos', '06:00:00', 60000, 'FINALIZADA', '2026-08-13 10:30:00', @usr_admin, NULL, '', NULL); SET @res1 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli2, 'Casamiento Pérez', '2026-09-13', '20:00:00', 'Club 20 de Febrero', '04:30:00', 200000, 'FINALIZADA', '2026-08-04 10:30:00', @usr_admin, NULL, '', NULL); SET @res2 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli3, 'Fiesta de Egresados Alarcón', '2026-09-04', '21:30:00', 'Club 20 de Febrero', '04:30:00', 260000, 'FINALIZADA', '2026-07-26 10:30:00', @usr_admin, NULL, '', NULL); SET @res3 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli4, 'Bautismo González', '2026-08-26', '21:00:00', 'Quinta San Lorenzo', '06:00:00', 480000, 'ANULADA', '2026-07-17 10:30:00', @usr_admin, '2026-07-22 11:00:00', 'El cliente cambió la fecha del evento y va a reservar de nuevo.', @usr_admin); SET @res4 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli5, 'Peña Folclórica López', '2026-08-17', '22:00:00', 'Salón Del Valle', '06:00:00', 550000, 'FINALIZADA', '2026-07-08 10:30:00', @usr_admin, NULL, '', NULL); SET @res5 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli6, 'Aniversario Martínez', '2026-08-08', '13:00:00', 'Salón Il Divo', '03:00:00', 900000, 'FINALIZADA', '2026-06-29 10:30:00', @usr_admin, NULL, '', NULL); SET @res6 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli7, 'Cumpleaños Infantil Díaz', '2026-07-30', '21:00:00', 'Salón Il Divo', '04:00:00', 930000, 'FINALIZADA', '2026-06-20 10:30:00', @usr_admin, NULL, '', NULL); SET @res7 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli8, 'Evento Empresarial Morales', '2026-07-21', '22:00:00', 'Club Gimnasia y Tiro', '05:00:00', 180000, 'FINALIZADA', '2026-06-11 10:30:00', @usr_admin, NULL, '', NULL); SET @res8 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli9, 'Acto de Graduación Ríos', '2026-07-12', '20:00:00', 'Salón Del Valle', '03:00:00', 60000, 'ANULADA', '2026-06-02 10:30:00', @usr_admin, '2026-06-07 11:00:00', 'El cliente canceló el evento.', @usr_admin); SET @res9 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli10, 'Fiesta de Fin de Año Vera', '2026-07-03', '20:00:00', 'Hotel Sheraton Salta', '03:00:00', 1850000, 'FINALIZADA', '2026-05-24 10:30:00', @usr_admin, NULL, '', NULL); SET @res10 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli11, 'Cumpleaños de 18 Cabrera', '2026-06-24', '21:00:00', 'Hotel Sheraton Salta', '05:00:00', 480000, 'FINALIZADA', '2026-05-15 10:30:00', @usr_admin, NULL, '', NULL); SET @res11 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli12, 'Boda Premium Ojeda', '2026-06-15', '13:00:00', 'Salón Del Valle', '03:00:00', 450000, 'FINALIZADA', '2026-05-06 10:30:00', @usr_admin, NULL, '', NULL); SET @res12 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli13, 'Cena de Gala Soria', '2026-10-07', '21:00:00', 'Club Gimnasia y Tiro', '05:00:00', 340000, 'PENDIENTE', '2026-08-28 10:30:00', @usr_admin, NULL, '', NULL); SET @res13 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli14, 'Pool Party Navarro', '2026-10-15', '22:00:00', 'Salón Golden', '04:00:00', 550000, 'PENDIENTE', '2026-09-05 10:30:00', @usr_admin, NULL, '', NULL); SET @res14 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli15, 'Conferencia Paz', '2026-10-23', '21:00:00', 'Centro de Convenciones Salta', '05:00:00', 480000, 'CONFIRMADA', '2026-09-13 10:30:00', @usr_admin, NULL, '', NULL); SET @res15 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli16, 'Cumpleaños de 15 Ibarra', '2026-10-31', '21:00:00', 'Club Gimnasia y Tiro', '03:00:00', 550000, 'PENDIENTE', '2026-09-21 10:30:00', @usr_admin, NULL, '', NULL); SET @res16 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli17, 'Casamiento Méndez', '2026-11-08', '22:00:00', 'Salón Del Valle', '03:00:00', 700000, 'PENDIENTE', '2026-09-29 10:30:00', @usr_admin, NULL, '', NULL); SET @res17 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli18, 'Fiesta de Egresados Coronel', '2026-11-16', '22:00:00', 'Club 20 de Febrero', '05:00:00', 800000, 'PENDIENTE', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res18 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli19, 'Bautismo Bravo', '2026-11-24', '21:30:00', 'Club 20 de Febrero', '04:00:00', 220000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res19 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli20, 'Peña Folclórica Funes', '2026-12-02', '22:00:00', 'Salón Los Álamos', '06:00:00', 510000, 'PENDIENTE', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res20 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli21, 'Aniversario Rivero', '2026-12-10', '21:00:00', 'Salón Del Valle', '05:00:00', 650000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res21 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli22, 'Cumpleaños Infantil Aráoz', '2026-12-18', '21:00:00', 'Finca La Encantada', '05:00:00', 850000, 'ANULADA', '2026-10-03 10:30:00', @usr_admin, '2026-10-04 11:00:00', 'Se suspendió el evento por falta de salón.', @usr_admin); SET @res22 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli23, 'Evento Empresarial Chávez', '2026-12-26', '22:00:00', 'Salón Il Divo', '04:00:00', 900000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res23 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli24, 'Acto de Graduación Saravia', '2027-01-03', '21:00:00', 'Quinta San Lorenzo', '05:00:00', 150000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res24 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli25, 'Fiesta de Fin de Año Cornejo', '2027-01-11', '20:00:00', 'Salón Golden', '06:00:00', 900000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res25 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli26, 'Cumpleaños de 18 Burgos', '2027-01-19', '20:00:00', 'Hotel Sheraton Salta', '03:00:00', 950000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res26 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli27, 'Boda Premium Sulca', '2027-01-27', '22:00:00', 'Centro de Convenciones Salta', '04:00:00', 630000, 'PENDIENTE', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res27 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli28, 'Cena de Gala Mamaní', '2027-02-04', '13:00:00', 'Salón Golden', '03:00:00', 680000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res28 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli29, 'Pool Party Gareca', '2027-02-12', '13:00:00', 'Hotel Sheraton Salta', '04:30:00', 750000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res29 = LAST_INSERT_ID();
INSERT INTO infinito_sonido_reservas (id_cliente, nombre_evento, fecha_evento, hora_evento, direccion_evento, duracion_evento, monto_total, estado_reserva, fecha_registro, id_usuario_registro, fecha_anulacion, motivo_anulacion, id_usuario_anulacion) VALUES (@cli30, 'Conferencia Tapia', '2027-02-20', '20:00:00', 'Salón Los Álamos', '06:00:00', 1200000, 'CONFIRMADA', '2026-10-03 10:30:00', @usr_admin, NULL, '', NULL); SET @res30 = LAST_INSERT_ID();

-- ======================================================================
-- 19. SERVICIOS DE CADA RESERVA (con el precio del servicio al momento de reservar)
-- ======================================================================
INSERT INTO infinito_sonido_reservas_x_servicios (id_reserva, id_servicio, precio_servicio) VALUES
  (@res1, @serv18, 60000),
  (@res2, @serv17, 200000),
  (@res3, @serv9, 260000),
  (@res4, @serv6, 480000),
  (@res5, @serv11, 550000),
  (@res6, @serv8, 900000),
  (@res7, @serv1, 450000),
  (@res7, @serv6, 480000),
  (@res8, @serv4, 180000),
  (@res9, @serv18, 60000),
  (@res10, @serv2, 650000),
  (@res10, @serv12, 1200000),
  (@res11, @serv6, 480000),
  (@res12, @serv1, 450000),
  (@res13, @serv18, 60000),
  (@res13, @serv19, 280000),
  (@res14, @serv11, 550000),
  (@res15, @serv9, 260000),
  (@res15, @serv13, 220000),
  (@res16, @serv11, 550000),
  (@res17, @serv7, 150000),
  (@res17, @serv11, 550000),
  (@res18, @serv5, 800000),
  (@res19, @serv13, 220000),
  (@res20, @serv1, 450000),
  (@res20, @serv18, 60000),
  (@res21, @serv14, 300000),
  (@res21, @serv16, 350000),
  (@res22, @serv2, 650000),
  (@res22, @serv17, 200000),
  (@res23, @serv8, 900000),
  (@res24, @serv7, 150000),
  (@res25, @serv7, 150000),
  (@res25, @serv10, 750000),
  (@res26, @serv2, 650000),
  (@res26, @serv14, 300000),
  (@res27, @serv1, 450000),
  (@res27, @serv4, 180000),
  (@res28, @serv6, 480000),
  (@res28, @serv17, 200000),
  (@res29, @serv10, 750000),
  (@res30, @serv12, 1200000);

-- ======================================================================
-- 20. EMPLEADOS ASIGNADOS A CADA RESERVA (ningun empleado tiene dos eventos el mismo dia)
-- ======================================================================
INSERT INTO infinito_sonido_detalles_reservas (id_reserva, id_empleado) VALUES
  (@res1, @emp16),
  (@res1, @emp23),
  (@res2, @emp6),
  (@res2, @emp22),
  (@res3, @emp3),
  (@res3, @emp13),
  (@res3, @emp10),
  (@res4, @emp25),
  (@res4, @emp14),
  (@res4, @emp10),
  (@res5, @emp4),
  (@res5, @emp17),
  (@res5, @emp9),
  (@res6, @emp21),
  (@res6, @emp11),
  (@res6, @emp14),
  (@res7, @emp18),
  (@res7, @emp22),
  (@res7, @emp19),
  (@res8, @emp19),
  (@res8, @emp10),
  (@res9, @emp4),
  (@res9, @emp14),
  (@res9, @emp6),
  (@res10, @emp9),
  (@res10, @emp19),
  (@res10, @emp3),
  (@res11, @emp1),
  (@res11, @emp14),
  (@res12, @emp1),
  (@res12, @emp10),
  (@res13, @emp20),
  (@res13, @emp21),
  (@res13, @emp23),
  (@res14, @emp14),
  (@res14, @emp22),
  (@res14, @emp4),
  (@res15, @emp24),
  (@res15, @emp23),
  (@res16, @emp25),
  (@res16, @emp14),
  (@res16, @emp11),
  (@res17, @emp6),
  (@res17, @emp20),
  (@res18, @emp1),
  (@res18, @emp14),
  (@res18, @emp19),
  (@res19, @emp22),
  (@res19, @emp8),
  (@res19, @emp25),
  (@res20, @emp5),
  (@res20, @emp8),
  (@res20, @emp1),
  (@res21, @emp21),
  (@res21, @emp19),
  (@res22, @emp2),
  (@res22, @emp22),
  (@res22, @emp1),
  (@res23, @emp23),
  (@res23, @emp12),
  (@res23, @emp8),
  (@res24, @emp21),
  (@res24, @emp15),
  (@res24, @emp18),
  (@res25, @emp16),
  (@res25, @emp1),
  (@res26, @emp12),
  (@res26, @emp18),
  (@res26, @emp24),
  (@res27, @emp19),
  (@res27, @emp2),
  (@res27, @emp13),
  (@res28, @emp24),
  (@res28, @emp13),
  (@res29, @emp6),
  (@res29, @emp10),
  (@res30, @emp24),
  (@res30, @emp21);

-- ======================================================================
-- 21. PAGOS Y SUS METODOS (saldo_pendiente = total de la reserva - lo pagado hasta ese pago)
-- ======================================================================
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res1, 30000, 30000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res1, 30000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res2, 100000, 100000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res2, 100000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res3, 130000, 130000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res3, 130000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res5, 275000, 275000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res5, 275000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6), (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res6, 450000, 450000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res6, 450000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res7, 465000, 465000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res7, 465000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res8, 90000, 90000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res8, 90000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res10, 925000, 925000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res10, 925000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1), (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res11, 240000, 240000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res11, 240000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res12, 225000, 225000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res12, 225000, 0); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res14, 110000, 440000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res15, 144000, 336000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res16, 110000, 440000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp5);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res18, 160000, 640000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res19, 66000, 154000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp1);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res20, 102000, 408000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res21, 195000, 455000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res23, 270000, 630000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res24, 45000, 105000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res25, 270000, 630000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp5), (@pago, @mp3);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res26, 285000, 665000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res28, 204000, 476000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4), (@pago, @mp6);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res29, 225000, 525000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp2);
INSERT INTO infinito_sonido_pagos (id_reserva, monto, saldo_pendiente) VALUES (@res30, 360000, 840000); SET @pago = LAST_INSERT_ID();
INSERT INTO infinito_sonido_detalles_de_pago (id_pago, id_metodo_pago) VALUES (@pago, @mp4);

COMMIT;

-- Fin. Pagos cargados: 34
