# GRÁFICOS DE LOS REPORTES
#
# Los gráficos se dibujan acá, en el backend, con pandas y matplotlib. El resultado es una
# imagen PNG que viaja dentro de la respuesta del reporte como texto (base64), y la pantalla
# la muestra con un <img> (y la puede descargar como archivo .png). Así el gráfico siempre
# coincide con los números de la tabla, porque sale de los mismos datos.
#
# Hay seis tipos de gráfico:
#   barras_por_mes        -> barras simples, una por mes (Uso de equipos, Demanda, Eventos, Carga)
#   barras_agrupadas      -> dos o más barras juntas por categoría (Comparación de períodos)
#   barras_dobles_por_mes -> dos barras juntas por mes (Contratado vs. cobrado)
#   torta                 -> qué parte del total es cada categoría (Demanda por servicio)
#   lineas_con_tendencia  -> línea mes a mes con su recta de tendencia (Evolución de ingresos)
#   heatmap               -> mapa de calor de filas x meses (Carga de trabajo de los empleados)
#
# Además, agregados() calcula con numpy los números de resumen de una serie mensual
# (total, promedio, máximo, mínimo, desvío) que se muestran arriba de cada reporte.

import base64
import io

import matplotlib

# "Agg" dibuja sin abrir ninguna ventana: es lo que hace falta en un servidor
matplotlib.use('Agg')

import matplotlib.pyplot as plt  # noqa: E402  (tiene que ir después de matplotlib.use)
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.ticker import FuncFormatter, MaxNLocator  # noqa: E402

# Colores del sistema (los mismos de frontend/src/index.css)
VERDE = '#4e7246'        # --verde: el de los botones de registrar (btn-primary)
AZUL = '#2d5590'         # azul del sistema, para la segunda serie y la tendencia
TEXTO = '#142042'        # --text-main
TEXTO_SUAVE = '#6b7590'  # --text-muted
GRILLA = '#e4e8f1'       # --border
PISO = '#c3cada'
# Colores de las porciones de la torta, uno por servicio. "Otros" va siempre en gris.
COLORES_TORTA = ['#4e7246', '#2d5590', '#c98a1b', '#8b4f9e', '#d64545', '#3a8f8a', '#a0522d', '#5b8fc9']
COLOR_OTROS = '#9aa3b5'
# Escala del mapa de calor: de casi blanco (0) a verde oscuro (el máximo)
ESCALA_CALOR = 'Greens'

# Tamaño de la imagen en pulgadas (ancho, alto) y su resolución.
# 8.6 x 3.1 a 150 puntos por pulgada da una imagen de 1290 x 465 píxeles: nítida en
# cualquier pantalla y un poco más bajita que el gráfico anterior.
TAMANIO = (8.6, 3.1)
RESOLUCION = 150


# Escribe plata corta, para que entre en el gráfico:
# 2960000 -> "$ 2,96 M", 1500000 -> "$ 1,5 M", 3000000 -> "$ 3 M", 850000 -> "$ 850 mil"
def pesos_corto(valor):
    if valor >= 1_000_000:
        # Hasta 2 decimales, sacando los ceros que sobran al final (y la coma si no queda ninguno)
        millones = f'{valor / 1_000_000:.2f}'.rstrip('0').rstrip('.')
        return f'$ {millones.replace(".", ",")} M'
    if valor >= 1_000:
        return f'$ {valor / 1_000:.0f} mil'
    return f'$ {valor:.0f}'


def barras_por_mes(meses, valores, eje_y, formato=None):
    """
    Dibuja un gráfico de barras con una barra por mes. Devuelve:
      {
        'imagen': 'data:image/png;base64,...',   -> para usar en un <img src="...">
        'barras': [{izquierda, derecha, arriba, piso, casillero_izquierda, casillero_derecha}, ...]
      }
    "barras" dice dónde quedó dibujada cada barra dentro de la imagen, en proporción
    (0 = borde izquierdo/de arriba, 1 = borde derecho/de abajo). La pantalla lo usa para
    poner encima zonas invisibles y mostrar el cartelito al pasar el mouse por cada mes.

      meses   -> la lista de meses del reporte: [{'anio': 2026, 'mes': 3, 'etiqueta': 'mar 2026'}, ...]
      valores -> el número de cada mes, en el mismo orden
      eje_y   -> qué se cuenta (ej: "Unidades"), se escribe de costado a la izquierda
      formato -> (opcional) cómo se escribe cada número, ej: pesos_corto. Si no se manda, va tal cual.
    """
    formato = formato or (lambda v: f'{v:g}')

    # Con pandas armamos la tabla mes -> valor. La etiqueta de cada barra es el mes y,
    # abajo, el año ("mar\n2026"), así se ve dónde termina un año y empieza el otro.
    datos = pd.Series(
        valores,
        index=[m['etiqueta'].replace(' ', '\n') for m in meses],
        dtype='float',
    )

    fig, ax = plt.subplots(figsize=TAMANIO, dpi=RESOLUCION)
    # pandas dibuja las barras usando matplotlib por debajo
    datos.plot.bar(ax=ax, color=VERDE, width=0.6, zorder=3)

    # El número arriba de cada barra, para poder comprobarlo contra la tabla
    ax.bar_label(ax.containers[0], labels=[formato(v) for v in datos], padding=3,
                 fontsize=8, color=TEXTO, fontweight='bold')

    # Eje de la izquierda: números redondos, sin decimales si se cuentan cosas enteras,
    # y con un poco de lugar arriba para que entren los números de las barras
    ax.yaxis.set_major_locator(MaxNLocator(nbins=5, integer=True))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: formato(v)))
    ax.set_ylim(0, max(datos.max(), 1) * 1.18)
    ax.set_ylabel(eje_y, color=TEXTO_SUAVE, fontsize=9)
    ax.set_xlabel('Mes del evento', color=TEXTO_SUAVE, fontsize=9, labelpad=6)

    # Estilo limpio: solo líneas de fondo horizontales clarititas y la línea del piso
    ax.grid(axis='y', color=GRILLA, linewidth=1, zorder=0)
    for lado in ('top', 'right', 'left'):
        ax.spines[lado].set_visible(False)
    ax.spines['bottom'].set_color(PISO)
    ax.tick_params(axis='x', rotation=0, labelsize=8, colors=TEXTO_SUAVE, length=0)
    ax.tick_params(axis='y', labelsize=8, colors=TEXTO_SUAVE, length=0)

    fig.tight_layout()

    # ---- Dónde quedó cada barra dentro de la imagen (para el cartelito del mouse) ----
    # draw() termina de acomodar todo; recién ahí las posiciones son las definitivas.
    fig.canvas.draw()
    ancho_img, alto_img = fig.bbox.width, fig.bbox.height
    zona = ax.get_window_extent()  # la zona donde van las barras
    # Cada mes ocupa un "casillero" del mismo ancho (pandas pone las barras en 0, 1, 2...)
    casillero = zona.width / len(datos)
    barras = []
    for i, barra in enumerate(ax.containers[0]):
        caja = barra.get_window_extent()
        # matplotlib mide desde abajo a la izquierda; la pantalla, desde arriba a la izquierda
        barras.append({
            'izquierda': round(caja.x0 / ancho_img, 4),
            'derecha': round(caja.x1 / ancho_img, 4),
            'arriba': round(1 - caja.y1 / alto_img, 4),
            'piso': round(1 - caja.y0 / alto_img, 4),
            'casillero_izquierda': round((zona.x0 + casillero * i) / ancho_img, 4),
            'casillero_derecha': round((zona.x0 + casillero * (i + 1)) / ancho_img, 4),
            # Lo alto de la zona de barras, para que el mouse funcione en todo el casillero
            'zona_arriba': round(1 - zona.y1 / alto_img, 4),
        })

    # Sin recortar bordes, para que las posiciones de arriba sigan valiendo
    return {'imagen': _a_png(fig), 'barras': barras}


# Guarda el gráfico como imagen PNG en memoria (no en un archivo) y la devuelve como texto
# base64, lista para usar en un <img src="..."> o para descargarla como archivo .png.
def _a_png(fig, recortar=False):
    memoria = io.BytesIO()
    fig.savefig(memoria, format='png', facecolor='white', bbox_inches='tight' if recortar else None)
    # Cerrar la figura es importante: si no, matplotlib las va juntando en memoria
    plt.close(fig)
    return 'data:image/png;base64,' + base64.b64encode(memoria.getvalue()).decode('ascii')


# Estilo limpio que comparten los gráficos con ejes: líneas de fondo clarititas y sin bordes
def _estilo_ejes(ax, eje_y, formato):
    ax.yaxis.set_major_locator(MaxNLocator(nbins=5, integer=True))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: formato(v)))
    ax.set_ylabel(eje_y, color=TEXTO_SUAVE, fontsize=9)
    ax.grid(axis='y', color=GRILLA, linewidth=1, zorder=0)
    for lado in ('top', 'right', 'left'):
        ax.spines[lado].set_visible(False)
    ax.spines['bottom'].set_color(PISO)
    ax.tick_params(axis='x', rotation=0, labelsize=8, colors=TEXTO_SUAVE, length=0)
    ax.tick_params(axis='y', labelsize=8, colors=TEXTO_SUAVE, length=0)


# Corta un texto largo para que entre debajo de una barra: "Sonido para casamientos" -> "Sonido para\ncasamientos"
def _partir(texto, largo=16):
    palabras, lineas, actual = texto.split(), [], ''
    for p in palabras:
        if actual and len(actual) + 1 + len(p) > largo:
            lineas.append(actual)
            actual = p
        else:
            actual = f'{actual} {p}'.strip()
    lineas.append(actual)
    return '\n'.join(lineas)


# ---------------------------------------------------------------------------
# BARRAS AGRUPADAS
# ---------------------------------------------------------------------------

def barras_agrupadas(categorias, series, eje_y, formato=None):
    """
    Dibuja varias barras juntas por cada categoría, una por serie. Por ejemplo, en la
    Comparación de períodos: por cada servicio, una barra del período actual y otra del
    mismo período del año anterior. Devuelve {'imagen': 'data:image/png;base64,...'}.
    Las barras van acostadas (horizontales): así los nombres se leen enteros a la izquierda
    y, si hay muchas categorías, el gráfico crece para abajo en vez de achicarse.

      categorias -> los nombres de abajo (ej: los servicios)
      series     -> {nombre de la serie: [valor de cada categoría]}, ej:
                    {'2º trimestre 2026': [...], '2º trimestre 2025': [...]}
      eje_y      -> qué se mide (ej: "Ingresos")
      formato    -> (opcional) cómo se escribe cada número, ej: pesos_corto
    """
    formato = formato or (lambda v: f'{v:g}')

    # pandas arma la tabla: una fila por categoría y una columna por serie
    datos = pd.DataFrame(series, index=[_partir(c, 34) for c in categorias], dtype='float')

    # Más alto cuantas más categorías haya, para que cada una tenga su lugar
    alto = max(3.2, 0.5 * len(categorias) + 1.4)
    fig, ax = plt.subplots(figsize=(10, alto), dpi=RESOLUCION)
    datos.plot.barh(ax=ax, color=[VERDE, AZUL, '#c98a1b'][:len(series)], width=0.78, zorder=3)
    # La primera categoría arriba (por defecto matplotlib la pone abajo)
    ax.invert_yaxis()

    # El número al final de cada barra (solo si no es cero, para no ensuciar)
    for barras in ax.containers:
        ax.bar_label(barras, labels=[formato(b.get_width()) if b.get_width() else '' for b in barras],
                     padding=3, fontsize=8, color=TEXTO)

    # Eje de abajo con los montos y líneas de fondo verticales clarititas
    ax.xaxis.set_major_locator(MaxNLocator(nbins=5))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: formato(v)))
    ax.set_xlim(0, max(np.nanmax(datos.to_numpy()), 1) * 1.15)
    ax.set_xlabel(eje_y, color=TEXTO_SUAVE, fontsize=9)
    ax.grid(axis='x', color=GRILLA, linewidth=1, zorder=0)
    for lado in ('top', 'right', 'bottom'):
        ax.spines[lado].set_visible(False)
    ax.spines['left'].set_color(PISO)
    ax.tick_params(axis='y', labelsize=9, colors=TEXTO, length=0)
    ax.tick_params(axis='x', labelsize=8, colors=TEXTO_SUAVE, length=0)
    # La leyenda arriba del gráfico, en una fila, para que no tape ninguna barra
    ax.legend(frameon=False, fontsize=9, loc='lower left', bbox_to_anchor=(0, 1.0), ncol=len(series))
    fig.tight_layout()
    return {'imagen': _a_png(fig)}


# ---------------------------------------------------------------------------
# BARRAS DOBLES POR MES
# ---------------------------------------------------------------------------

def barras_dobles_por_mes(meses, series, eje_y, formato=None):
    """
    Dibuja dos (o más) barras paradas, una al lado de la otra, por cada mes. Se usa en el
    reporte Contratado vs. cobrado: por cada mes, lo que se reservó al lado de lo que se pagó.
    Es como barras_agrupadas, pero vertical y con los meses abajo, que es como se lee una
    evolución en el tiempo. Devuelve {'imagen': 'data:image/png;base64,...'}.

      meses   -> la lista de meses del reporte: [{'anio': 2026, 'mes': 3, 'etiqueta': 'mar 2026'}, ...]
      series  -> {nombre de la serie: [valor de cada mes]}, ej: {'Contratado': [...], 'Cobrado': [...]}
      eje_y   -> qué se mide (ej: "Pesos")
      formato -> (opcional) cómo se escribe cada número, ej: pesos_corto
    """
    formato = formato or (lambda v: f'{v:g}')

    # pandas arma la tabla: una fila por mes ("mar\n2026", el año abajo) y una columna por serie
    datos = pd.DataFrame(series, index=[m['etiqueta'].replace(' ', '\n') for m in meses], dtype='float')

    fig, ax = plt.subplots(figsize=(TAMANIO[0], TAMANIO[1] + 0.6), dpi=RESOLUCION)
    datos.plot.bar(ax=ax, color=[VERDE, AZUL, '#c98a1b'][:len(series)], width=0.75, zorder=3)

    # Hasta 12 meses se escribe el número arriba de cada barra, parado (en vertical) para que
    # dos barras de altura parecida no se pisen los números. Con más meses no entran y se
    # leen en la tabla.
    if len(meses) <= 12:
        for barras in ax.containers:
            ax.bar_label(barras, labels=[formato(b.get_height()) if b.get_height() else '' for b in barras],
                         padding=3, fontsize=7, color=TEXTO, rotation=90)

    _estilo_ejes(ax, eje_y, formato)
    # Lugar de sobra arriba para que entren los números parados
    ax.set_ylim(0, max(np.nanmax(datos.to_numpy()), 1) * (1.3 if len(meses) <= 12 else 1.15))
    ax.set_xlabel('Mes del evento', color=TEXTO_SUAVE, fontsize=9, labelpad=6)
    # La leyenda arriba del gráfico, en una fila, para que no tape ninguna barra
    ax.legend(frameon=False, fontsize=9, loc='lower left', bbox_to_anchor=(0, 1.0), ncol=len(series))
    fig.tight_layout()
    return {'imagen': _a_png(fig)}


# ---------------------------------------------------------------------------
# TORTA
# ---------------------------------------------------------------------------

# Como mucho se muestran estas porciones; el resto se junta en "Otros" para que se pueda leer
MAXIMO_PORCIONES = 8


def torta(etiquetas, valores, formato=None, leyenda=True):
    """
    Dibuja un gráfico de torta: qué parte del total representa cada categoría.
    Las categorías en cero no se dibujan, y si hay muchas, las más chicas se juntan
    en "Otros". Devuelve {'imagen': 'data:image/png;base64,...'}, o None si todo es cero
    (no hay nada que repartir).
    Con leyenda=False se dibuja solo la torta, sin la lista de nombres al costado: es la
    versión chica que se usa de vista previa en el tablero de Reportes. En ese caso, además
    de la imagen devuelve 'leyenda': [{'nombre', 'color', 'porcentaje'}] para armarla en la pantalla.
    """
    formato = formato or (lambda v: f'{v:g}')
    datos = pd.Series(valores, index=etiquetas, dtype='float')
    datos = datos[datos > 0].sort_values(ascending=False)
    if datos.empty:
        return None
    if len(datos) > MAXIMO_PORCIONES:
        otros = datos.iloc[MAXIMO_PORCIONES - 1:].sum()
        datos = pd.concat([datos.iloc[:MAXIMO_PORCIONES - 1], pd.Series({'Otros': otros})])

    if leyenda:
        # La torta va en un lugar fijo a la izquierda, ocupando toda la altura, y la leyenda a su
        # derecha. Así los nombres largos de la leyenda no achican la torta.
        fig = plt.figure(figsize=(10, 4.4), dpi=RESOLUCION)
        ax = fig.add_axes([0.02, 0.06, 0.40, 0.88])
    else:
        # Sin leyenda: una figura cuadrada y la torta ocupando casi todo (deja un margen
        # para los porcentajes, que van afuera de cada porción)
        fig = plt.figure(figsize=(5, 5), dpi=RESOLUCION)
        ax = fig.add_axes([0.08, 0.08, 0.84, 0.84])
    colores = [COLOR_OTROS if nombre == 'Otros' else COLORES_TORTA[i % len(COLORES_TORTA)]
               for i, nombre in enumerate(datos.index)]
    porciones, _, textos = ax.pie(
        datos, colors=colores, startangle=90, counterclock=False,
        # El porcentaje adentro de cada porción (las muy chicas no llevan, no entra)
        # El porcentaje va afuera de cada porción, chiquito, al lado de su borde
        autopct=lambda p: f'{p:.0f} %' if p >= 2 else '',
        pctdistance=1.13, wedgeprops={'linewidth': 1.5, 'edgecolor': 'white'},
    )
    for t in textos:
        t.set_color(TEXTO)
        t.set_fontsize(8 if leyenda else 11)
    ax.axis('equal')  # para que sea un círculo y no un óvalo

    if not leyenda:
        # Sin la leyenda dibujada, pero con sus datos aparte (nombre, color y porcentaje de cada
        # porción), para que la pantalla la arme como texto al lado de la torta
        total = datos.sum()
        return {
            'imagen': _a_png(fig),
            'leyenda': [
                {'nombre': nombre, 'color': color, 'porcentaje': round(float(v) * 100 / float(total), 1)}
                for (nombre, v), color in zip(datos.items(), colores)
            ],
        }

    # Leyenda al costado: nombre (partido en dos renglones si es largo), valor y porcentaje
    # (con coma decimal, como se escribe acá)
    total = datos.sum()
    leyenda = fig.legend(
        porciones,
        [f'{_partir(nombre, 38)}: {formato(v)} ({f"{v * 100 / total:.1f}".replace(".", ",")} %)'
         for nombre, v in datos.items()],
        loc='center left', bbox_to_anchor=(0.46, 0.5), frameon=False, fontsize=10,
        labelspacing=0.9, handlelength=1.4,
    )
    for t in leyenda.get_texts():
        t.set_color(TEXTO)
    # Se recorta lo que sobra a la derecha de la leyenda
    return {'imagen': _a_png(fig, recortar=True)}


# ---------------------------------------------------------------------------
# LÍNEAS CON TENDENCIA
# ---------------------------------------------------------------------------

def lineas_con_tendencia(meses, valores, eje_y, formato=None):
    """
    Dibuja una línea con el valor de cada mes y, encima, la recta de tendencia y el promedio.
    La tendencia se calcula con numpy (np.polyfit): es la recta que mejor se acerca a todos
    los puntos, y su pendiente dice cuánto sube (o baja) en promedio de un mes al siguiente.
    Devuelve:
      {
        'imagen': 'data:image/png;base64,...',
        'tendencia': {'pendiente': cuánto cambia por mes, 'direccion': 'sube' | 'baja' | 'estable'}
      }
    """
    formato = formato or (lambda v: f'{v:g}')
    y = np.array(valores, dtype=float)
    x = np.arange(len(y))  # 0, 1, 2... un número por mes
    etiquetas = [m['etiqueta'].replace(' ', '\n') for m in meses]

    fig, ax = plt.subplots(figsize=TAMANIO, dpi=RESOLUCION)
    # pandas dibuja la línea con un punto en cada mes
    pd.Series(y, index=x).plot(ax=ax, color=VERDE, linewidth=2.2, marker='o', markersize=5,
                               label=eje_y, zorder=3)

    # Recta de tendencia: np.polyfit con grado 1 devuelve la pendiente y la ordenada de y = a·x + b
    pendiente = 0.0
    if len(y) >= 2:
        pendiente, ordenada = np.polyfit(x, y, 1)
        ax.plot(x, pendiente * x + ordenada, color=AZUL, linestyle='--', linewidth=1.6,
                label='Tendencia', zorder=2)

    # Promedio mensual (np.mean), como línea horizontal de referencia
    promedio = float(np.mean(y)) if len(y) else 0.0
    ax.axhline(promedio, color='#c98a1b', linestyle=':', linewidth=1.4,
               label=f'Promedio ({formato(promedio)})', zorder=1)

    ax.set_xticks(x, etiquetas)
    _estilo_ejes(ax, eje_y, formato)
    ax.set_ylim(0, max(np.max(y) if len(y) else 0, 1) * 1.18)
    ax.set_xlabel('Mes del evento', color=TEXTO_SUAVE, fontsize=9, labelpad=6)
    ax.legend(frameon=False, fontsize=8, loc='upper left')
    fig.tight_layout()

    # Si la pendiente es muy chica comparada con el promedio (menos del 1 % por mes), se toma como estable
    if promedio and abs(pendiente) < promedio * 0.01:
        direccion = 'estable'
    else:
        direccion = 'sube' if pendiente > 0 else 'baja' if pendiente < 0 else 'estable'
    return {
        'imagen': _a_png(fig),
        'tendencia': {'pendiente': round(float(pendiente), 2), 'direccion': direccion},
    }


# ---------------------------------------------------------------------------
# HEATMAP (MAPA DE CALOR)
# ---------------------------------------------------------------------------

# Como mucho se muestran estas filas en el mapa de calor (las de más valor); con más no se lee
MAXIMO_FILAS_CALOR = 20


def heatmap(filas, meses, matriz, eje='Eventos'):
    """
    Dibuja un mapa de calor: una fila por cada nombre (ej: empleado), una columna por mes, y
    cada casillero pintado más oscuro cuanto más alto es el número. El número va escrito adentro.
    Sirve para ver de un vistazo quién está más cargado y en qué meses.
      filas  -> los nombres de cada fila
      meses  -> la lista de meses del reporte (con 'etiqueta')
      matriz -> una lista por fila con el número de cada mes
    Devuelve {'imagen': 'data:image/png;base64,...'}, o None si no hay filas.
    """
    if not filas:
        return None
    # numpy arma la matriz de números (filas x meses)
    datos = np.array(matriz, dtype=float)
    nombres = list(filas)
    if len(nombres) > MAXIMO_FILAS_CALOR:
        # Se quedan las filas con más total (np.argsort ordena de menor a mayor, por eso se da vuelta)
        mejores = np.argsort(datos.sum(axis=1))[::-1][:MAXIMO_FILAS_CALOR]
        mejores.sort()
        datos = datos[mejores]
        nombres = [nombres[i] for i in mejores]

    alto = max(2.2, 0.38 * len(nombres) + 1.2)
    fig, ax = plt.subplots(figsize=(TAMANIO[0], alto), dpi=RESOLUCION)
    maximo = max(float(np.max(datos)), 1)
    imagen = ax.imshow(datos, cmap=ESCALA_CALOR, aspect='auto', vmin=0, vmax=maximo)

    # El número dentro de cada casillero: blanco sobre los oscuros, oscuro sobre los claros
    for i in range(datos.shape[0]):
        for j in range(datos.shape[1]):
            valor = datos[i, j]
            ax.text(j, i, f'{valor:g}' if valor else '·', ha='center', va='center', fontsize=7,
                    color='white' if valor > maximo * 0.6 else TEXTO)

    ax.set_xticks(np.arange(len(meses)), [m['etiqueta'].replace(' ', '\n') for m in meses])
    ax.set_yticks(np.arange(len(nombres)), nombres)
    ax.tick_params(axis='both', labelsize=8, colors=TEXTO_SUAVE, length=0)
    for lado in ax.spines.values():
        lado.set_visible(False)
    barra = fig.colorbar(imagen, ax=ax, fraction=0.025, pad=0.02)
    barra.set_label(eje, color=TEXTO_SUAVE, fontsize=8)
    barra.ax.tick_params(labelsize=7, colors=TEXTO_SUAVE)
    barra.outline.set_visible(False)
    fig.tight_layout()
    return {'imagen': _a_png(fig)}


# ---------------------------------------------------------------------------
# AGREGADOS CON NUMPY
# ---------------------------------------------------------------------------

def agregados(meses, valores):
    """
    Calcula con numpy los números de resumen de una serie mes a mes:
      total, promedio mensual, máximo y mínimo (con el mes en que se dieron) y desvío estándar
      (cuánto se alejan los meses del promedio: si es alto, hay meses muy cargados y otros flojos).
    Devuelve un diccionario listo para mandar en la respuesta del reporte.
    """
    y = np.array(valores, dtype=float)
    if len(y) == 0:
        return None
    i_max, i_min = int(np.argmax(y)), int(np.argmin(y))
    return {
        'total': round(float(np.sum(y)), 2),
        'promedio': round(float(np.mean(y)), 2),
        'maximo': {'valor': round(float(y[i_max]), 2), 'etiqueta': meses[i_max]['etiqueta']},
        'minimo': {'valor': round(float(y[i_min]), 2), 'etiqueta': meses[i_min]['etiqueta']},
        'desvio': round(float(np.std(y)), 2),
    }
