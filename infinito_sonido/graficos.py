# GRÁFICOS DE LOS REPORTES
#
# Los gráficos se dibujan acá, en el backend, con pandas y matplotlib. El resultado es una
# imagen PNG que viaja dentro de la respuesta del reporte como texto (base64), y la pantalla
# la muestra con un <img>. Así el gráfico siempre coincide con los números de la tabla,
# porque sale de los mismos datos.

import base64
import io

import matplotlib

# "Agg" dibuja sin abrir ninguna ventana: es lo que hace falta en un servidor
matplotlib.use('Agg')

import matplotlib.pyplot as plt  # noqa: E402  (tiene que ir después de matplotlib.use)
import pandas as pd  # noqa: E402
from matplotlib.ticker import FuncFormatter, MaxNLocator  # noqa: E402

# Colores del sistema (los mismos de frontend/src/index.css)
VERDE = '#4e7246'        # --verde: el de los botones de registrar (btn-primary)
TEXTO = '#142042'        # --text-main
TEXTO_SUAVE = '#6b7590'  # --text-muted
GRILLA = '#e4e8f1'       # --border
PISO = '#c3cada'

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

    # Guardamos la imagen en memoria (no en un archivo) y la pasamos a texto base64.
    # Sin recortar bordes, para que las posiciones de arriba sigan valiendo.
    memoria = io.BytesIO()
    fig.savefig(memoria, format='png', facecolor='white')
    # Cerrar la figura es importante: si no, matplotlib las va juntando en memoria
    plt.close(fig)
    return {
        'imagen': 'data:image/png;base64,' + base64.b64encode(memoria.getvalue()).decode('ascii'),
        'barras': barras,
    }
