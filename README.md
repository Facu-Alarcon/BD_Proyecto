# Django + MySQL + phpMyAdmin sobre Docker

Proyecto de ejemplo para el taller: un stack de 3 contenedores con
**instalacion manual** de Django dentro del contenedor de Python.

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

## Puesta en marcha (instalacion manual)

### 1. Levantar los contenedores
En la carpeta del `docker-compose.yml`:

```bash
docker-compose up -d
```

### 2. Entrar al contenedor de Django

```bash
docker exec -i -t Infinito_Sonido_web bash
```

### 3. Instalar Django y el conector MySQL (dentro del contenedor)

```bash
pip install -r requirements.txt
```
### 4-1. Aplicar makemigrations (carga las tablas)

```bash
python manage.py makemigrations infinito_sonido
```

### 4-2. Aplicar las migraciones (crea las tablas en MySQL)

```bash
python manage.py migrate
```

### 5. Crear un superusuario para el panel /admin

```bash
python manage.py createsuperuser
```

### 6. Iniciar el servidor de desarrollo

```bash
python manage.py runserver 0.0.0.0:8000
```

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
