# Django + MySQL + phpMyAdmin sobre Docker

Proyecto de ejemplo para el taller: un stack de 3 contenedores con
Django corriendo en el contenedor de Python, que instala todo y migra solo al levantarse.

## Arquitectura

| Contenedor                  | Imagen           | Puerto host | Para que sirve                       |
|-----------------------------|------------------|-------------|--------------------------------------|
| `Infinito_Sonido_db`        | `mysql:8.0`      | 3306        | Base de datos MySQL                  |
| `Infinito_Sonido_phpmyadmin`| `phpmyadmin:5`   | 8080        | Administrador web de MySQL           |
| `Infinito_Sonido_web`       | `python:3.11`    | 8000        | Entorno donde corre Django           |

## Estructura de archivos

```
Django_MySQL_Docker/
├── docker-compose.yml      # Orquesta los 3 contenedores
├── requirements.txt        # Django + PyMySQL
├── .env                    # Credenciales de MySQL
├── manage.py               # Lanzador de Django
├── core/                   # Configuracion del proyecto
│   ├── __init__.py         # Activa PyMySQL como conector
│   ├── settings.py         # Conexion a MySQL via variables de entorno
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
└── infinito_sonido/                # App de ejemplo
    ├── models.py           # Modelo Infinito sonidos
    ├── admin.py
    ├── views.py
    ├── urls.py
    ├── migrations/
    └── templates/infinito_sonidos.html
```

## Puesta en marcha

### 1. Levantar los contenedores
En la carpeta del `docker-compose.yml`:

```bash
docker-compose up -d
```

El contenedor `web` hace todo solo, en este orden:

1. `pip install -r requirements.txt` (instala Django y las librerias)
2. `python manage.py migrate` (crea o actualiza las tablas en MySQL)
3. `python manage.py runserver 0.0.0.0:8000` (arranca el servidor)

Para ver como va (y si algun paso dio error):

```bash
docker-compose logs -f web
```

### 2. Cuando se cambia `models.py`

Las migraciones nuevas se generan a mano, y despues se reinicia el contenedor
para que las aplique:

```bash
docker exec -i -t Infinito_Sonido_web python manage.py makemigrations infinito_sonido
docker-compose restart web
```

### 3. Crear un superusuario para el panel /admin (opcional)

```bash
docker exec -i -t Infinito_Sonido_web python manage.py createsuperuser
```

## Scripts de base de datos (carpeta `scripts_bd/`)

Para crear la base sin Docker ni Django (por ejemplo, para la entrega), cargar en
phpMyAdmin, en este orden y sobre una base vacía:

1. `01_estructura.sql`: crea todas las tablas.
2. `02_datos_iniciales.sql`: permisos, estados de equipo y el control interno de Django.
3. `03_datos_de_prueba.sql`: datos de ejemplo. Usuario `admin` / contraseña `admin123`.

Con Docker no hace falta: las tablas las crean las migraciones y alcanza con cargar
`datos_de_prueba.txt` (es el mismo contenido que el script 3).

## Acceso

- Aplicacion Django:  http://localhost:8000/
- Panel de administracion:  http://localhost:8000/admin/
- phpMyAdmin:  http://localhost:8080/  (usuario y contrasena del archivo `.env`)

## Detener todo

```bash
docker-compose down
```

Para borrar tambien la base de datos:

```bash
docker-compose down -v
```
