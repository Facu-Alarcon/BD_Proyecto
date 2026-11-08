# MÓDULO DE ANALÍTICA (M1)
#
# Script aparte del sistema: se conecta directo a la base MySQL con PyMySQL (conector nativo,
# sin pasar por Django), lee las reservas y sus servicios, los transforma con pandas, calcula
# con numpy y dibuja con matplotlib cuatro gráficos que responden preguntas del negocio:
#
#   01_barras_agrupadas.png  -> ¿Qué servicios se piden en cada mes?
#   02_donut_servicios.png   -> ¿Qué servicios concentran la facturación?
#   03_lineas_ingresos.png   -> ¿Los ingresos crecen? ¿Llegamos al objetivo mensual?
#   04_heatmap_eventos.png   -> ¿Qué días y a qué hora se concentran los eventos?
#   05_tablero.png           -> los cuatro juntos, como tablero para el dueño
#
# Las reservas anuladas no se cuentan: no son demanda ni ingresos reales.
#
# Cómo se corre (lo más fácil es dentro del contenedor, que ya tiene las variables de la base):
#   docker exec -it Infinito_Sonido_web python analitica/analitica.py --desde 2026-06-01 --hasta 2027-02-28
# Opciones:
#   --desde / --hasta  rango de fechas del evento (si no se mandan, el año actual completo)
#   --objetivo         ingreso mensual que se quiere alcanzar (si no se manda, el promedio del período)
#   --top              cuántos servicios se muestran por nombre; el resto va como "Otros" (5 por defecto)
#   --salida           carpeta donde se guardan los PNG (analitica/salida por defecto)

import argparse
import datetime
import os
import sys
import warnings

import matplotlib

# "Agg" dibuja sin abrir ventanas: así el script anda igual dentro del contenedor
matplotlib.use('Agg')

import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import pymysql  # noqa: E402
from matplotlib.gridspec import GridSpec  # noqa: E402
from matplotlib.ticker import FuncFormatter, MaxNLocator  # noqa: E402

# Usamos los mismos colores y el mismo formato de plata que los gráficos del sistema
# (infinito_sonido/graficos.py no usa nada de Django, así que se puede importar tal cual)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from infinito_sonido.graficos import (  # noqa: E402
    AZUL, COLOR_OTROS, COLORES_TORTA, GRILLA, PISO, TEXTO, TEXTO_SUAVE, VERDE, pesos_corto,
)

# pandas avisa que prefiere SQLAlchemy, pero con la conexión de PyMySQL funciona bien.
# Lo silenciamos para que no ensucie la salida en la demo.
warnings.filterwarnings('ignore', message='pandas only supports SQLAlchemy')

# matplotlib toma lo que está entre dos signos $ como fórmula matemática; acá el $ es de pesos
plt.rcParams['text.parse_math'] = False

MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
DIAS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']
ROJO = '#d64545'
RESOLUCION = 150


# Lee lo que se escribió al correr el script. Si no se manda el período, es el año actual.
def leer_parametros():
    hoy = datetime.date.today()
    parser = argparse.ArgumentParser(description='Gráficos de analítica de Infinito Sonido e Iluminación')
    parser.add_argument('--desde', type=datetime.date.fromisoformat, default=datetime.date(hoy.year, 1, 1),
                        help='Primer día del período (AAAA-MM-DD)')
    parser.add_argument('--hasta', type=datetime.date.fromisoformat, default=datetime.date(hoy.year, 12, 31),
                        help='Último día del período (AAAA-MM-DD)')
    parser.add_argument('--objetivo', type=float, default=None,
                        help='Ingreso mensual objetivo en pesos (por defecto, el promedio del período)')
    parser.add_argument('--top', type=int, default=5,
                        help='Cuántos servicios se muestran por nombre (el resto va como "Otros")')
    parser.add_argument('--salida', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'salida'),
                        help='Carpeta donde se guardan los PNG')
    parametros = parser.parse_args()
    if parametros.desde > parametros.hasta:
        parser.error('La fecha "desde" no puede ser posterior a "hasta".')
    return parametros


# Abre la conexión a MySQL con las mismas variables de entorno que usa Django (settings.py).
# Dentro del contenedor ya están cargadas; desde afuera se entra por el puerto 3307.
def conectar():
    return pymysql.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        port=int(os.environ.get('DB_PORT', '3307')),
        user=os.environ.get('DB_USER') or os.environ.get('MYSQL_USER'),
        password=os.environ.get('DB_PASSWORD') or os.environ.get('MYSQL_PASSWORD'),
        database=os.environ.get('DB_NAME') or os.environ.get('MYSQL_DATABASE'),
        charset='utf8mb4',
    )


# Trae las tablas que hacen falta. Se leen por separado y se unen con pandas (merge),
# así el filtro de fechas y de anuladas queda en SQL y las cuentas quedan en pandas.
def leer_datos(conexion, desde, hasta):
    reservas = pd.read_sql(
        """
        SELECT id_reserva, fecha_evento, hora_evento, monto_total
        FROM infinito_sonido_reservas
        WHERE fecha_evento BETWEEN %s AND %s
        AND estado_reserva <> 'ANULADA'
        """,
        conexion, params=(desde, hasta), parse_dates=['fecha_evento'],
    )
    servicios_reservados = pd.read_sql(
        'SELECT id_reserva, id_servicio, precio_servicio FROM infinito_sonido_reservas_x_servicios',
        conexion,
    )
    servicios = pd.read_sql('SELECT id_servicio, tipo_servicio FROM infinito_sonido_servicios', conexion)

    # Cada servicio contratado con la fecha de su reserva y el nombre del servicio.
    # El merge con "inner" deja afuera los servicios de reservas anuladas o de otro período.
    detalle = (servicios_reservados
            .merge(reservas[['id_reserva', 'fecha_evento']], on='id_reserva', how='inner')
            .merge(servicios, on='id_servicio', how='left'))
    return reservas, detalle


# Todos los meses del período, uno atrás del otro, para que los meses sin reservas aparezcan con 0
def meses_del_periodo(desde, hasta):
    return pd.period_range(desde, hasta, freq='M')


def etiqueta_mes(periodo):
    return f'{MESES[periodo.month - 1]}\n{periodo.year}'


# Deja los servicios con más valor por nombre y junta el resto en "Otros"
# (con 17 servicios, un gráfico con todos no se puede leer)
def agrupar_otros(detalle, valores, top):
    ranking = detalle.groupby('tipo_servicio')[valores].sum().sort_values(ascending=False)
    principales = ranking.index[:top]
    return detalle['tipo_servicio'].where(detalle['tipo_servicio'].isin(principales), 'Otros')


# Achica los nombres largos de los servicios para las referencias de color: corta lo que va
# entre paréntesis y, si sigue largo, lo deja en 30 letras con "..."
def nombre_corto(nombre, largo=30):
    nombre = nombre.split(' (')[0]
    return nombre if len(nombre) <= largo else nombre[:largo - 1].rstrip() + '…'


# Estilo común de los ejes: solo las líneas de fondo horizontales y la línea del piso
def estilo_ejes(ax, titulo, eje_y, formato=None):
    ax.set_title(titulo, loc='left', fontsize=11, fontweight='bold', color=TEXTO, pad=10)
    ax.set_ylabel(eje_y, color=TEXTO_SUAVE, fontsize=9)
    ax.grid(axis='y', color=GRILLA, linewidth=1, zorder=0)
    for lado in ('top', 'right', 'left'):
        ax.spines[lado].set_visible(False)
    ax.spines['bottom'].set_color(PISO)
    ax.tick_params(axis='x', rotation=0, labelsize=8, colors=TEXTO_SUAVE, length=0)
    ax.tick_params(axis='y', labelsize=8, colors=TEXTO_SUAVE, length=0)
    if formato:
        ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: formato(v)))


# ---------------------------------------------------------------------------
# GRÁFICO 1 - BARRAS AGRUPADAS: contrataciones de cada servicio, mes por mes
# ---------------------------------------------------------------------------

def barras_agrupadas(ax, detalle, meses, top):
    datos = detalle.assign(
        mes=detalle['fecha_evento'].dt.to_period('M'),
        # Los mismos servicios principales que en el donut (los de más facturación), así cada
        # servicio tiene el mismo color en los dos gráficos
        servicio=agrupar_otros(detalle, 'precio_servicio', top),
    )
    # pivot_table: una fila por mes y una columna por servicio, contando las contrataciones
    tabla = (datos.pivot_table(index='mes', columns='servicio', values='id_reserva', aggfunc='count')
            .reindex(meses).fillna(0))
    # Las columnas en el mismo orden que el donut (de mayor a menor facturación) y "Otros" al final, en gris
    orden = detalle.groupby('tipo_servicio')['precio_servicio'].sum().sort_values(ascending=False).index
    columnas = [c for c in orden if c in tabla.columns] + (['Otros'] if 'Otros' in tabla.columns else [])
    tabla = tabla[columnas]
    colores = [COLOR_OTROS if c == 'Otros' else COLORES_TORTA[i % len(COLORES_TORTA)] for i, c in enumerate(columnas)]
    # Las filas pasan a ser el texto del mes ("jun\n2026"): con los meses como Period, pandas
    # no ubica bien las barras en el eje
    tabla.index = [etiqueta_mes(m) for m in tabla.index]
    tabla.columns = [nombre_corto(c) for c in tabla.columns]

    tabla.plot(kind='bar', ax=ax, color=colores, width=0.8, zorder=3)
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))
    estilo_ejes(ax, '¿Qué servicios se piden en cada mes?', 'Contrataciones')
    ax.set_xlabel('')
    # La referencia de colores va abajo del gráfico para no tapar las barras
    ax.legend(frameon=False, fontsize=7, ncol=3, loc='upper center', bbox_to_anchor=(0.5, -0.18))


# ---------------------------------------------------------------------------
# GRÁFICO 2 - DONUT: qué parte de la facturación aporta cada servicio
# ---------------------------------------------------------------------------

def donut(ax, detalle, top):
    servicio = agrupar_otros(detalle, 'precio_servicio', top)
    ingresos = detalle.groupby(servicio)['precio_servicio'].sum().sort_values(ascending=False)
    # "Otros" al final para que quede en gris
    if 'Otros' in ingresos.index:
        ingresos = pd.concat([ingresos.drop('Otros'), ingresos[['Otros']]])
    colores = [COLOR_OTROS if s == 'Otros' else COLORES_TORTA[i % len(COLORES_TORTA)] for i, s in enumerate(ingresos.index)]

    # numpy calcula el porcentaje de cada servicio sobre el total
    porcentajes = np.round(ingresos.values / np.sum(ingresos.values) * 100, 1)
    ax.pie(ingresos.values, colors=colores, startangle=90, counterclock=False,
        wedgeprops={'width': 0.38, 'edgecolor': 'white', 'linewidth': 1.5})
    # En el centro, el total facturado
    ax.text(0, 0.08, pesos_corto(ingresos.sum()), ha='center', va='center', fontsize=13,
            fontweight='bold', color=TEXTO)
    ax.text(0, -0.16, 'facturado', ha='center', va='center', fontsize=8, color=TEXTO_SUAVE)
    ax.legend([f'{nombre_corto(nombre)} · {p:g} %' for nombre, p in zip(ingresos.index, porcentajes)],
            frameon=False, fontsize=7, loc='center left', bbox_to_anchor=(1, 0.5))
    ax.set_title('¿Qué servicios concentran la facturación?', loc='left', fontsize=11,
                fontweight='bold', color=TEXTO, pad=10)
    ax.set_aspect('equal')


# ---------------------------------------------------------------------------
# GRÁFICO 3 - LÍNEAS CON TENDENCIA: ingresos de cada mes contra el objetivo
# ---------------------------------------------------------------------------

def lineas_ingresos(ax, reservas, meses, objetivo):
    # resample junta las reservas por mes ('MS' = desde el primer día de cada mes)
    por_mes = (reservas.set_index('fecha_evento')['monto_total'].resample('MS').sum()
            .to_period('M').reindex(meses, fill_value=0))
    y = por_mes.values.astype(float)
    x = np.arange(len(y))
    if objetivo is None:
        objetivo = float(np.mean(y))

    # Sombreado: verde donde se superó el objetivo, rojo donde faltó
    ax.fill_between(x, y, objetivo, where=y >= objetivo, interpolate=True, color=VERDE, alpha=0.15, zorder=1)
    ax.fill_between(x, y, objetivo, where=y < objetivo, interpolate=True, color=ROJO, alpha=0.12, zorder=1)
    ax.plot(x, y, color=VERDE, linewidth=2.2, marker='o', markersize=5, label='Ingresos del mes', zorder=3)
    ax.axhline(objetivo, color='#c98a1b', linestyle=':', linewidth=1.4,
            label=f'Objetivo ({pesos_corto(objetivo)})', zorder=2)

    # Recta de tendencia con numpy: polyfit de grado 1 da la pendiente (cuánto cambia por mes)
    pendiente = 0.0
    if len(y) >= 2:
        pendiente, ordenada = np.polyfit(x, y, 1)
        ax.plot(x, pendiente * x + ordenada, color=AZUL, linestyle='--', linewidth=1.6,
                label='Tendencia', zorder=2)

    ax.set_xticks(x, [etiqueta_mes(m) for m in por_mes.index])
    ax.set_ylim(0, max(np.max(y), objetivo, 1) * 1.2)
    estilo_ejes(ax, '¿Los ingresos crecen y llegan al objetivo?', 'Ingresos', pesos_corto)
    ax.legend(frameon=False, fontsize=7, loc='upper left')
    meses_cumplidos = int(np.sum(y >= objetivo))
    return pendiente, objetivo, meses_cumplidos


# ---------------------------------------------------------------------------
# GRÁFICO 4 - HEATMAP: cuántos eventos hay por día de la semana y hora de inicio
# ---------------------------------------------------------------------------

def heatmap_eventos(ax, reservas):
    # La hora de inicio viene como "tiempo" (timedelta): nos quedamos con la hora entera
    datos = reservas.assign(
        dia=reservas['fecha_evento'].dt.day_of_week,  # 0 = lunes ... 6 = domingo
        hora=pd.to_timedelta(reservas['hora_evento']).dt.components.hours,
    )
    horas = range(int(datos['hora'].min()), int(datos['hora'].max()) + 1)
    matriz = (datos.pivot_table(index='dia', columns='hora', values='id_reserva', aggfunc='count')
            .reindex(index=range(7), columns=horas).fillna(0))
    valores = matriz.values
    maximo = max(float(np.max(valores)), 1)

    imagen = ax.imshow(valores, cmap='Greens', aspect='auto', vmin=0, vmax=maximo)
    # El número dentro de cada casillero (blanco sobre los oscuros)
    for i in range(valores.shape[0]):
        for j in range(valores.shape[1]):
            valor = valores[i, j]
            ax.text(j, i, f'{valor:g}' if valor else '·', ha='center', va='center', fontsize=8,
                    color='white' if valor > maximo * 0.6 else TEXTO)
    ax.set_xticks(np.arange(len(horas)), [f'{h} h' for h in horas])
    ax.set_yticks(np.arange(7), DIAS)
    ax.tick_params(axis='both', labelsize=8, colors=TEXTO_SUAVE, length=0)
    for lado in ax.spines.values():
        lado.set_visible(False)
    ax.set_xlabel('Hora de inicio', color=TEXTO_SUAVE, fontsize=9)
    ax.set_title('¿Qué días y a qué hora se concentran los eventos?', loc='left', fontsize=11,
                fontweight='bold', color=TEXTO, pad=10)
    barra = ax.figure.colorbar(imagen, ax=ax, fraction=0.03, pad=0.02)
    barra.set_label('Eventos', color=TEXTO_SUAVE, fontsize=8)
    # Los eventos se cuentan enteros: la escala de colores no lleva decimales
    barra.locator = MaxNLocator(integer=True)
    barra.update_ticks()
    barra.ax.tick_params(labelsize=7, colors=TEXTO_SUAVE)
    barra.outline.set_visible(False)

    # Devolvemos el casillero con más eventos para mostrarlo en el resumen
    fila, columna = np.unravel_index(np.argmax(valores), valores.shape)
    return DIAS[fila], list(horas)[columna], int(valores[fila, columna])


# Guarda la figura como PNG en la carpeta de salida y la cierra (si no, matplotlib las acumula)
def guardar(fig, carpeta, nombre):
    ruta = os.path.join(carpeta, nombre)
    fig.savefig(ruta, dpi=RESOLUCION, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return ruta


# Los números de resumen calculados con numpy, que se muestran en la consola y en el tablero
def resumen(reservas):
    montos = reservas['monto_total'].values.astype(float)
    return {
        'eventos': len(montos),
        'total': float(np.sum(montos)),
        'promedio': float(np.mean(montos)),
        'desvio': float(np.std(montos)),
        'p25': float(np.percentile(montos, 25)),
        'mediana': float(np.percentile(montos, 50)),
        'p90': float(np.percentile(montos, 90)),
    }


def main():
    parametros = leer_parametros()
    os.makedirs(parametros.salida, exist_ok=True)

    conexion = conectar()
    try:
        reservas, detalle = leer_datos(conexion, parametros.desde, parametros.hasta)
    finally:
        conexion.close()

    if reservas.empty:
        print(f'No hay reservas (sin contar anuladas) entre {parametros.desde} y {parametros.hasta}.')
        sys.exit(1)

    meses = meses_del_periodo(parametros.desde, parametros.hasta)
    numeros = resumen(reservas)
    archivos = []

    # Cada gráfico se dibuja en su propia figura y se guarda como PNG
    fig, ax = plt.subplots(figsize=(10, 4.2))
    barras_agrupadas(ax, detalle, meses, parametros.top)
    archivos.append(guardar(fig, parametros.salida, '01_barras_agrupadas.png'))

    fig, ax = plt.subplots(figsize=(8, 4.2))
    donut(ax, detalle, parametros.top)
    archivos.append(guardar(fig, parametros.salida, '02_donut_servicios.png'))

    fig, ax = plt.subplots(figsize=(10, 4.2))
    pendiente, objetivo, cumplidos = lineas_ingresos(ax, reservas, meses, parametros.objetivo)
    archivos.append(guardar(fig, parametros.salida, '03_lineas_ingresos.png'))

    fig, ax = plt.subplots(figsize=(8, 4.2))
    dia_pico, hora_pico, eventos_pico = heatmap_eventos(ax, reservas)
    archivos.append(guardar(fig, parametros.salida, '04_heatmap_eventos.png'))

    # Tablero: los cuatro gráficos en una sola figura con GridSpec, y los números arriba
    fig = plt.figure(figsize=(16, 10))
    grilla = GridSpec(2, 2, figure=fig, hspace=0.45, wspace=0.3)
    barras_agrupadas(fig.add_subplot(grilla[0, 0]), detalle, meses, parametros.top)
    donut(fig.add_subplot(grilla[0, 1]), detalle, parametros.top)
    lineas_ingresos(fig.add_subplot(grilla[1, 0]), reservas, meses, parametros.objetivo)
    heatmap_eventos(fig.add_subplot(grilla[1, 1]), reservas)
    fig.suptitle(
        f'Infinito Sonido e Iluminación · del {parametros.desde:%d/%m/%Y} al {parametros.hasta:%d/%m/%Y}\n'
        f'{numeros["eventos"]} eventos · {pesos_corto(numeros["total"])} facturados · '
        f'reserva promedio {pesos_corto(numeros["promedio"])}',
        fontsize=14, fontweight='bold', color=TEXTO,
    )
    archivos.append(guardar(fig, parametros.salida, '05_tablero.png'))

    # Resumen en la consola
    tendencia = 'sube' if pendiente > 0 else 'baja' if pendiente < 0 else 'se mantiene'
    print(f'Período: {parametros.desde} a {parametros.hasta} ({len(meses)} meses, sin reservas anuladas)')
    print(f'Eventos: {numeros["eventos"]} · Facturado: $ {numeros["total"]:,.0f}')
    print(f'Monto por reserva: promedio $ {numeros["promedio"]:,.0f} · desvío $ {numeros["desvio"]:,.0f} · '
        f'mediana $ {numeros["mediana"]:,.0f} · percentil 90 $ {numeros["p90"]:,.0f}')
    print(f'Tendencia de ingresos: {tendencia} unos $ {abs(pendiente):,.0f} por mes · '
        f'{cumplidos} de {len(meses)} meses llegaron al objetivo de $ {objetivo:,.0f}')
    print(f'Momento con más eventos: {dia_pico} a las {hora_pico} h ({eventos_pico} eventos)')
    print('Gráficos guardados:')
    for ruta in archivos:
        print(f'  {ruta}')


if __name__ == '__main__':
    main()
