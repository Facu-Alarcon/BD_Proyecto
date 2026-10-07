-- =====================================================================
-- INFINITO SONIDO E ILUMINACION - Script 1 de 3: ESTRUCTURA DE LA BASE
-- =====================================================================
-- Crea todas las tablas (vacías) con sus claves primarias, claves
-- foráneas, índices y restricciones de unicidad.
-- Generado desde la base después de aplicar todas las migraciones de
-- Django (hasta la 0023). Motor: MySQL 8.0, codificación utf8mb4.
--
-- Orden de carga (sobre una base vacía):
--   1. 01_estructura.sql        -> tablas
--   2. 02_datos_iniciales.sql   -> permisos, estados de equipo y control de Django
--   3. 03_datos_de_prueba.sql   -> datos de ejemplo (perfiles, usuarios, clientes, reservas...)
--
-- Si se usa Docker no hace falta este script: el contenedor web crea
-- las tablas solo con las migraciones (python manage.py migrate).
--
-- Tablas del sistema (prefijo infinito_sonido_):
--   Proceso de Reserva (Hito 3):
--     reservas (cabecera), reservas_x_servicios y detalles_reservas (detalles),
--     clientes, servicios, empleados, equipos_x_servicios, pagos, detalles_de_pago
--   Seguridad: usuarios, perfiles, permisos, permisos_x_perfiles, sesiontoken,
--     token_recuperacion, registro_actividad
--   Resto: equipos, tipo_equipos, estado_equipos, puestos, puestos_x_empleados,
--     sueldos, horarios, horarios_x_empleados, metodo_pagos
-- Las tablas auth_*, django_* son internas de Django.
-- =====================================================================


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_group` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_group_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `group_id` int NOT NULL,
  `permission_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_group_permissions_group_id_permission_id_0cd325b0_uniq` (`group_id`,`permission_id`),
  KEY `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` (`permission_id`),
  CONSTRAINT `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`),
  CONSTRAINT `auth_group_permissions_group_id_b120cbf9_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_permission` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `content_type_id` int NOT NULL,
  `codename` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_permission_content_type_id_codename_01ab375a_uniq` (`content_type_id`,`codename`),
  CONSTRAINT `auth_permission_content_type_id_2f476e4b_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_user` (
  `id` int NOT NULL AUTO_INCREMENT,
  `password` varchar(128) NOT NULL,
  `last_login` datetime(6) DEFAULT NULL,
  `is_superuser` tinyint(1) NOT NULL,
  `username` varchar(150) NOT NULL,
  `first_name` varchar(150) NOT NULL,
  `last_name` varchar(150) NOT NULL,
  `email` varchar(254) NOT NULL,
  `is_staff` tinyint(1) NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  `date_joined` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_user_groups` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `group_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_user_groups_user_id_group_id_94350c0c_uniq` (`user_id`,`group_id`),
  KEY `auth_user_groups_group_id_97559544_fk_auth_group_id` (`group_id`),
  CONSTRAINT `auth_user_groups_group_id_97559544_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`),
  CONSTRAINT `auth_user_groups_user_id_6a12ed8b_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_user_user_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `permission_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_user_user_permissions_user_id_permission_id_14a6b632_uniq` (`user_id`,`permission_id`),
  KEY `auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm` (`permission_id`),
  CONSTRAINT `auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`),
  CONSTRAINT `auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_admin_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `action_time` datetime(6) NOT NULL,
  `object_id` longtext,
  `object_repr` varchar(200) NOT NULL,
  `action_flag` smallint unsigned NOT NULL,
  `change_message` longtext NOT NULL,
  `content_type_id` int DEFAULT NULL,
  `user_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `django_admin_log_content_type_id_c4bce8eb_fk_django_co` (`content_type_id`),
  KEY `django_admin_log_user_id_c564eba6_fk_auth_user_id` (`user_id`),
  CONSTRAINT `django_admin_log_content_type_id_c4bce8eb_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`),
  CONSTRAINT `django_admin_log_user_id_c564eba6_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`),
  CONSTRAINT `django_admin_log_chk_1` CHECK ((`action_flag` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_content_type` (
  `id` int NOT NULL AUTO_INCREMENT,
  `app_label` varchar(100) NOT NULL,
  `model` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `django_content_type_app_label_model_76bd3d3b_uniq` (`app_label`,`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_migrations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `app` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `applied` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_session` (
  `session_key` varchar(40) NOT NULL,
  `session_data` longtext NOT NULL,
  `expire_date` datetime(6) NOT NULL,
  PRIMARY KEY (`session_key`),
  KEY `django_session_expire_date_a5c62663` (`expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_clientes` (
  `id_cliente` int NOT NULL AUTO_INCREMENT,
  `nombre_cliente` varchar(30) NOT NULL,
  `apellido_cliente` varchar(30) NOT NULL,
  `domicilio_cliente` varchar(60) NOT NULL,
  `telefono_cliente` varchar(12) NOT NULL,
  `email_cliente` varchar(100) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_cliente`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_detalles_de_pago` (
  `id_detalle_pago` int NOT NULL AUTO_INCREMENT,
  `id_metodo_pago` int NOT NULL,
  `id_pago` int NOT NULL,
  PRIMARY KEY (`id_detalle_pago`),
  KEY `infinito_sonido_deta_id_metodo_pago_887fdcfe_fk_infinito_` (`id_metodo_pago`),
  KEY `infinito_sonido_deta_id_pago_3a73fe82_fk_infinito_` (`id_pago`),
  CONSTRAINT `infinito_sonido_deta_id_metodo_pago_887fdcfe_fk_infinito_` FOREIGN KEY (`id_metodo_pago`) REFERENCES `infinito_sonido_metodo_pagos` (`id_metodo_pago`),
  CONSTRAINT `infinito_sonido_deta_id_pago_3a73fe82_fk_infinito_` FOREIGN KEY (`id_pago`) REFERENCES `infinito_sonido_pagos` (`id_pago`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_detalles_reservas` (
  `id_detalle_reserva` int NOT NULL AUTO_INCREMENT,
  `id_empleado` int NOT NULL,
  `id_reserva` int NOT NULL,
  PRIMARY KEY (`id_detalle_reserva`),
  KEY `infinito_sonido_deta_id_empleado_8bbd6eba_fk_infinito_` (`id_empleado`),
  KEY `infinito_sonido_deta_id_reserva_4c17aa2a_fk_infinito_` (`id_reserva`),
  CONSTRAINT `infinito_sonido_deta_id_empleado_8bbd6eba_fk_infinito_` FOREIGN KEY (`id_empleado`) REFERENCES `infinito_sonido_empleados` (`id_empleado`),
  CONSTRAINT `infinito_sonido_deta_id_reserva_4c17aa2a_fk_infinito_` FOREIGN KEY (`id_reserva`) REFERENCES `infinito_sonido_reservas` (`id_reserva`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_empleados` (
  `id_empleado` int NOT NULL AUTO_INCREMENT,
  `nombre_emp` varchar(30) NOT NULL,
  `apellido_emp` varchar(30) NOT NULL,
  `telefono_emp` varchar(12) NOT NULL,
  `email_emp` varchar(254) NOT NULL,
  `dni` varchar(8) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_empleado`),
  UNIQUE KEY `dni` (`dni`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_equipos` (
  `id_equipo` int NOT NULL AUTO_INCREMENT,
  `nombre_equipo` varchar(50) NOT NULL,
  `cantidad_equipo` int unsigned NOT NULL,
  `id_tipoeq` int NOT NULL,
  `id_estadoeq` int NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_equipo`),
  KEY `infinito_sonido_equi_id_tipoeq_f5e0a991_fk_infinito_` (`id_tipoeq`),
  KEY `infinito_sonido_equi_id_estadoeq_0374702a_fk_infinito_` (`id_estadoeq`),
  CONSTRAINT `infinito_sonido_equi_id_estadoeq_0374702a_fk_infinito_` FOREIGN KEY (`id_estadoeq`) REFERENCES `infinito_sonido_estado_equipos` (`id_estadoeq`),
  CONSTRAINT `infinito_sonido_equi_id_tipoeq_f5e0a991_fk_infinito_` FOREIGN KEY (`id_tipoeq`) REFERENCES `infinito_sonido_tipo_equipos` (`id_tipoeq`),
  CONSTRAINT `infinito_sonido_equipos_chk_1` CHECK ((`cantidad_equipo` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_equipos_x_servicios` (
  `id_equipo_servicio` int NOT NULL AUTO_INCREMENT,
  `id_equipo` int NOT NULL,
  `id_servicio` int NOT NULL,
  `cantidad` int unsigned NOT NULL,
  PRIMARY KEY (`id_equipo_servicio`),
  UNIQUE KEY `infinito_sonido_equipos__id_equipo_id_servicio_8d9ada94_uniq` (`id_equipo`,`id_servicio`),
  KEY `infinito_sonido_equi_id_servicio_f7e6a7da_fk_infinito_` (`id_servicio`),
  CONSTRAINT `infinito_sonido_equi_id_equipo_a74fd7ae_fk_infinito_` FOREIGN KEY (`id_equipo`) REFERENCES `infinito_sonido_equipos` (`id_equipo`),
  CONSTRAINT `infinito_sonido_equi_id_servicio_f7e6a7da_fk_infinito_` FOREIGN KEY (`id_servicio`) REFERENCES `infinito_sonido_servicios` (`id_servicio`),
  CONSTRAINT `infinito_sonido_equipos_x_servicios_chk_1` CHECK ((`cantidad` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_estado_equipos` (
  `id_estadoeq` int NOT NULL AUTO_INCREMENT,
  `nombre_estadoeq` varchar(50) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_estadoeq`),
  UNIQUE KEY `nombre_estadoeq` (`nombre_estadoeq`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_horarios` (
  `id_horario` int NOT NULL AUTO_INCREMENT,
  `cantidad_horas` double NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_horario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_horarios_x_empleados` (
  `id_horario_empleado` int NOT NULL AUTO_INCREMENT,
  `id_empleado` int NOT NULL,
  `id_horario` int NOT NULL,
  PRIMARY KEY (`id_horario_empleado`),
  UNIQUE KEY `infinito_sonido_horarios_id_empleado_id_horario_9c62d860_uniq` (`id_empleado`,`id_horario`),
  KEY `infinito_sonido_hora_id_horario_31467a95_fk_infinito_` (`id_horario`),
  CONSTRAINT `infinito_sonido_hora_id_empleado_2f1b2782_fk_infinito_` FOREIGN KEY (`id_empleado`) REFERENCES `infinito_sonido_empleados` (`id_empleado`),
  CONSTRAINT `infinito_sonido_hora_id_horario_31467a95_fk_infinito_` FOREIGN KEY (`id_horario`) REFERENCES `infinito_sonido_horarios` (`id_horario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_metodo_pagos` (
  `id_metodo_pago` int NOT NULL AUTO_INCREMENT,
  `metodo_pago` varchar(50) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_metodo_pago`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_pagos` (
  `id_pago` int NOT NULL AUTO_INCREMENT,
  `monto` double NOT NULL,
  `saldo_pendiente` double NOT NULL,
  `id_reserva` int NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_pago`),
  KEY `infinito_sonido_pago_id_reserva_d67b2ef5_fk_infinito_` (`id_reserva`),
  CONSTRAINT `infinito_sonido_pago_id_reserva_d67b2ef5_fk_infinito_` FOREIGN KEY (`id_reserva`) REFERENCES `infinito_sonido_reservas` (`id_reserva`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_perfiles` (
  `id_perfil` int NOT NULL AUTO_INCREMENT,
  `tipo_perfil` varchar(50) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_perfil`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_permisos` (
  `id_permiso` int NOT NULL AUTO_INCREMENT,
  `nombre_permiso` varchar(50) NOT NULL,
  `descripcion_permiso` varchar(150) NOT NULL,
  `estado_permiso` tinyint(1) NOT NULL,
  `codigo` varchar(60) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_permiso`),
  UNIQUE KEY `nombre_permiso` (`nombre_permiso`),
  UNIQUE KEY `infinito_sonido_permisos_codigo_05c0dfed_uniq` (`codigo`),
  KEY `infinito_sonido_permisos_codigo_05c0dfed` (`codigo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_permisos_x_perfiles` (
  `id_permiso_perfil` int NOT NULL AUTO_INCREMENT,
  `id_perfil` int NOT NULL,
  `id_permiso` int NOT NULL,
  PRIMARY KEY (`id_permiso_perfil`),
  UNIQUE KEY `infinito_sonido_permisos_id_perfil_id_permiso_25150925_uniq` (`id_perfil`,`id_permiso`),
  KEY `infinito_sonido_perm_id_permiso_d3cfabef_fk_infinito_` (`id_permiso`),
  CONSTRAINT `infinito_sonido_perm_id_perfil_7a8557ec_fk_infinito_` FOREIGN KEY (`id_perfil`) REFERENCES `infinito_sonido_perfiles` (`id_perfil`),
  CONSTRAINT `infinito_sonido_perm_id_permiso_d3cfabef_fk_infinito_` FOREIGN KEY (`id_permiso`) REFERENCES `infinito_sonido_permisos` (`id_permiso`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_puestos` (
  `id_puesto` int NOT NULL AUTO_INCREMENT,
  `nombre_puesto` varchar(50) NOT NULL,
  `id_sueldo` int NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_puesto`),
  KEY `infinito_sonido_pues_id_sueldo_70a39883_fk_infinito_` (`id_sueldo`),
  CONSTRAINT `infinito_sonido_pues_id_sueldo_70a39883_fk_infinito_` FOREIGN KEY (`id_sueldo`) REFERENCES `infinito_sonido_sueldos` (`id_sueldo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_puestos_x_empleados` (
  `id_puesto_empleado` int NOT NULL AUTO_INCREMENT,
  `id_empleado` int NOT NULL,
  `id_puesto` int NOT NULL,
  PRIMARY KEY (`id_puesto_empleado`),
  UNIQUE KEY `infinito_sonido_puestos__id_empleado_id_puesto_bc7cf03b_uniq` (`id_empleado`,`id_puesto`),
  KEY `infinito_sonido_pues_id_puesto_a1edccd7_fk_infinito_` (`id_puesto`),
  CONSTRAINT `infinito_sonido_pues_id_empleado_c5591e7e_fk_infinito_` FOREIGN KEY (`id_empleado`) REFERENCES `infinito_sonido_empleados` (`id_empleado`),
  CONSTRAINT `infinito_sonido_pues_id_puesto_a1edccd7_fk_infinito_` FOREIGN KEY (`id_puesto`) REFERENCES `infinito_sonido_puestos` (`id_puesto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_registro_actividad` (
  `id_registro` int NOT NULL AUTO_INCREMENT,
  `fecha` datetime(6) NOT NULL,
  `usuario_texto` varchar(50) NOT NULL,
  `accion` varchar(20) NOT NULL,
  `modulo` varchar(50) NOT NULL,
  `id_objeto` varchar(20) NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `detalle` longtext NOT NULL,
  `ip` char(39) DEFAULT NULL,
  `id_usuario` int DEFAULT NULL,
  PRIMARY KEY (`id_registro`),
  KEY `infinito_sonido_regi_id_usuario_830c79df_fk_infinito_` (`id_usuario`),
  KEY `infinito_sonido_registro_actividad_fecha_e8608b1e` (`fecha`),
  KEY `infinito_sonido_registro_actividad_accion_f1909102` (`accion`),
  CONSTRAINT `infinito_sonido_regi_id_usuario_830c79df_fk_infinito_` FOREIGN KEY (`id_usuario`) REFERENCES `infinito_sonido_usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_reservas` (
  `id_reserva` int NOT NULL AUTO_INCREMENT,
  `fecha_evento` date NOT NULL,
  `direccion_evento` varchar(100) NOT NULL,
  `duracion_evento` time(6) DEFAULT NULL,
  `monto_total` double NOT NULL,
  `estado_reserva` varchar(20) NOT NULL,
  `id_cliente` int NOT NULL,
  `nombre_evento` varchar(100) NOT NULL,
  `hora_evento` time(6) NOT NULL,
  `fecha_registro` datetime(6) DEFAULT NULL,
  `id_usuario_registro` int DEFAULT NULL,
  `fecha_anulacion` datetime(6) DEFAULT NULL,
  `motivo_anulacion` varchar(255) NOT NULL,
  `id_usuario_anulacion` int DEFAULT NULL,
  PRIMARY KEY (`id_reserva`),
  KEY `infinito_sonido_rese_id_cliente_6134e108_fk_infinito_` (`id_cliente`),
  KEY `infinito_sonido_rese_id_usuario_registro_cbdf571f_fk_infinito_` (`id_usuario_registro`),
  KEY `infinito_sonido_rese_id_usuario_anulacion_b4df6828_fk_infinito_` (`id_usuario_anulacion`),
  CONSTRAINT `infinito_sonido_rese_id_cliente_6134e108_fk_infinito_` FOREIGN KEY (`id_cliente`) REFERENCES `infinito_sonido_clientes` (`id_cliente`),
  CONSTRAINT `infinito_sonido_rese_id_usuario_anulacion_b4df6828_fk_infinito_` FOREIGN KEY (`id_usuario_anulacion`) REFERENCES `infinito_sonido_usuarios` (`id_usuario`),
  CONSTRAINT `infinito_sonido_rese_id_usuario_registro_cbdf571f_fk_infinito_` FOREIGN KEY (`id_usuario_registro`) REFERENCES `infinito_sonido_usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_reservas_x_servicios` (
  `id_reserva_servicio` int NOT NULL AUTO_INCREMENT,
  `id_reserva` int NOT NULL,
  `id_servicio` int NOT NULL,
  `precio_servicio` double NOT NULL,
  PRIMARY KEY (`id_reserva_servicio`),
  UNIQUE KEY `infinito_sonido_reservas_id_reserva_id_servicio_3c179598_uniq` (`id_reserva`,`id_servicio`),
  KEY `infinito_sonido_rese_id_servicio_c501fda2_fk_infinito_` (`id_servicio`),
  CONSTRAINT `infinito_sonido_rese_id_reserva_f60650dc_fk_infinito_` FOREIGN KEY (`id_reserva`) REFERENCES `infinito_sonido_reservas` (`id_reserva`),
  CONSTRAINT `infinito_sonido_rese_id_servicio_c501fda2_fk_infinito_` FOREIGN KEY (`id_servicio`) REFERENCES `infinito_sonido_servicios` (`id_servicio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_servicios` (
  `id_servicio` int NOT NULL AUTO_INCREMENT,
  `tipo_servicio` varchar(100) NOT NULL,
  `precio_servicio` double NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_servicio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_sesiontoken` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `token` varchar(64) NOT NULL,
  `creado` datetime(6) NOT NULL,
  `id_usuario` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `infinito_sonido_sesi_id_usuario_95b2b90c_fk_infinito_` (`id_usuario`),
  CONSTRAINT `infinito_sonido_sesi_id_usuario_95b2b90c_fk_infinito_` FOREIGN KEY (`id_usuario`) REFERENCES `infinito_sonido_usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_sueldos` (
  `id_sueldo` int NOT NULL AUTO_INCREMENT,
  `monto_sueldo` double NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_sueldo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_tipo_equipos` (
  `id_tipoeq` int NOT NULL AUTO_INCREMENT,
  `nombre_tipoeq` varchar(50) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `fecha_baja` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id_tipoeq`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_token_recuperacion` (
  `id_token` int NOT NULL AUTO_INCREMENT,
  `token_hash` varchar(64) NOT NULL,
  `creado` datetime(6) NOT NULL,
  `expira` datetime(6) NOT NULL,
  `usado` tinyint(1) NOT NULL,
  `id_usuario` int NOT NULL,
  PRIMARY KEY (`id_token`),
  UNIQUE KEY `token_hash` (`token_hash`),
  KEY `infinito_sonido_toke_id_usuario_1dac3a96_fk_infinito_` (`id_usuario`),
  CONSTRAINT `infinito_sonido_toke_id_usuario_1dac3a96_fk_infinito_` FOREIGN KEY (`id_usuario`) REFERENCES `infinito_sonido_usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `infinito_sonido_usuarios` (
  `id_usuario` int NOT NULL AUTO_INCREMENT,
  `usuario` varchar(50) NOT NULL,
  `contraseña` varchar(128) NOT NULL,
  `id_perfil` int NOT NULL,
  `activo` tinyint(1) NOT NULL,
  `debe_cambiar_clave` tinyint(1) NOT NULL,
  `fecha_ultima_modificacion` date NOT NULL,
  `fecha_baja` date DEFAULT NULL,
  `id_empleado` int NOT NULL,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `infinito_sonido_usuarios_usuario_dde399c9_uniq` (`usuario`),
  UNIQUE KEY `id_empleado` (`id_empleado`),
  KEY `infinito_sonido_usua_id_perfil_dd107a48_fk_infinito_` (`id_perfil`),
  CONSTRAINT `infinito_sonido_usua_id_empleado_c6db7a7d_fk_infinito_` FOREIGN KEY (`id_empleado`) REFERENCES `infinito_sonido_empleados` (`id_empleado`),
  CONSTRAINT `infinito_sonido_usua_id_perfil_dd107a48_fk_infinito_` FOREIGN KEY (`id_perfil`) REFERENCES `infinito_sonido_perfiles` (`id_perfil`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

