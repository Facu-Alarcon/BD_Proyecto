# REPORTES DEL SISTEMA

# REPORTE 1 - USO DE EQUIPOS POR MES


import base64
import calendar
import datetime
import io
from collections import defaultdict

import matplotlib
# 'Agg' dibuja directo a una imagen, sin abrir ventanas (en el servidor no hay pantalla)
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Equipos, Equipos_x_Servicios, Reservas, Reservas_x_Servicios, Tipo_Equipos
from .permissions import permiso_modulo

# Nombres cortos de los meses, para las etiquetas del gráfico
MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

# Como mucho se pueden pedir 24 meses juntos: con más, el gráfico no se llega a leer
MAXIMO_MESES = 24


# Convierte un texto como "2026-03" en el par (2026, 3). Si viene mal escrito devuelve None.
def _leer_mes(texto):
    try:
        anio, mes = (texto or '').split('-')
        anio, mes = int(anio), int(mes)
    except ValueError:
        return None
    if 1 <= mes <= 12 and 2000 <= anio <= 2100:
        return anio, mes
    return None


# Arma la lista de todos los meses entre dos fechas, uno atrás del otro:
# de (2026, 11) a (2027, 2) devuelve [(2026, 11), (2026, 12), (2027, 1), (2027, 2)].
# Así en el gráfico aparecen también los meses sin reservas (con 0).
def _meses_entre(desde, hasta):
    meses = []
    anio, mes = desde
    while (anio, mes) <= hasta:
        meses.append((anio, mes))
        mes += 1
        if mes == 13:  # después de diciembre viene enero del año siguiente
            anio, mes = anio + 1, 1
    return meses


# Dibuja el gráfico de barras (una barra por mes) con pandas y matplotlib y lo devuelve
# como imagen PNG en texto base64, para mandarlo dentro de la respuesta JSON. El frontend
# lo muestra con <img src="data:image/png;base64,...">.
def _grafico_uso_por_mes(columnas):
    # pandas: una tabla con una fila por mes. El índice es lo que va debajo de cada barra
    # (ej: "ene\n2026", el \n pone el año en un segundo renglón)
    tabla = pd.DataFrame(columnas)
    tabla.index = [f"{MESES[m - 1]}\n{a}" for a, m in zip(tabla['anio'], tabla['mes'])]

    # matplotlib: figsize es el tamaño en pulgadas (7 x 3 = un gráfico chico y apaisado).
    # dpi = puntos por pulgada: 7 x 150 = 1050px de ancho, así se ve nítido en pantalla
    fig, ax = plt.subplots(figsize=(7, 3), dpi=150)
    tabla['unidades'].plot(kind='bar', ax=ax, color='#4e7246', width=0.6, rot=0)

    # El número arriba de cada barra (en los meses sin uso no se escribe nada)
    ax.bar_label(ax.containers[0], labels=[v if v else '' for v in tabla['unidades']], fontsize=8, padding=2)

    ax.set_title('Unidades de equipos comprometidas en eventos, por mes', fontsize=10, color='#05284c')
    ax.set_xlabel('Mes del evento', fontsize=8, color='#6b7590')
    ax.set_ylabel('Unidades', fontsize=8, color='#6b7590')
    ax.tick_params(labelsize=7, colors='#142042')
    # Sin el borde de arriba y de la derecha, y con líneas guía suaves detrás de las barras
    ax.spines[['top', 'right']].set_visible(False)
    ax.grid(axis='y', color='#e4e8f1')
    ax.set_axisbelow(True)
    # Deja un poco de aire arriba para que entre el número de la barra más alta
    ax.margins(y=0.15)
    fig.tight_layout()

    # Guardamos la imagen en memoria (no en un archivo) y la pasamos a texto
    buffer = io.BytesIO()
    fig.savefig(buffer, format='png')
    plt.close(fig)  # libera la memoria del gráfico
    return base64.b64encode(buffer.getvalue()).decode('ascii')


class ReporteUsoEquiposView(APIView):
    """
    Reporte "Uso de equipos por mes".
    Se pide así: /api/reportes/uso-equipos/?desde=2026-01&hasta=2026-12
    Opcionalmente se le puede agregar &tipo=<id> para ver un solo tipo de equipo
    (por ejemplo solo Sonido) o &equipo=<id> para ver un solo equipo.
    Si no se manda el período, muestra el año actual completo.
    """
    # Solo entran los perfiles que tienen el permiso "Ver Reportes"
    permission_classes = [permiso_modulo('reportes')]

    def get(self, request):
        # ---------- 1) Leemos lo que eligió el usuario en los filtros ----------
        hoy = timezone.localdate()
        desde = _leer_mes(request.query_params.get('desde')) or (hoy.year, 1)
        hasta = _leer_mes(request.query_params.get('hasta')) or (hoy.year, 12)

        if desde > hasta:
            return Response({'detail': 'El mes "Desde" no puede ser posterior al mes "Hasta".'},
                            status=status.HTTP_400_BAD_REQUEST)
        meses = _meses_entre(desde, hasta)
        if len(meses) > MAXIMO_MESES:
            return Response({'detail': f'El período no puede tener más de {MAXIMO_MESES} meses.'},
                            status=status.HTTP_400_BAD_REQUEST)

        tipo = request.query_params.get('tipo')
        equipo = request.query_params.get('equipo')
        tipo = int(tipo) if tipo and tipo.isdigit() else None
        equipo = int(equipo) if equipo and equipo.isdigit() else None

        # ---------- 2) Los equipos que entran en el reporte ----------
        equipos_qs = Equipos.objects.select_related('id_tipoeq').order_by('nombre_equipo')
        if tipo:
            equipos_qs = equipos_qs.filter(id_tipoeq=tipo)
        if equipo:
            equipos_qs = equipos_qs.filter(pk=equipo)
        equipos = {e.pk: e for e in equipos_qs}

        # ---------- 3) Las reservas del período (sin las anuladas) ----------
        primer_dia = datetime.date(desde[0], desde[1], 1)
        # monthrange dice cuántos días tiene el mes (28, 29, 30 o 31)
        ultimo_dia = datetime.date(hasta[0], hasta[1], calendar.monthrange(hasta[0], hasta[1])[1])
        reservas = Reservas.objects.filter(fecha_evento__range=(primer_dia, ultimo_dia)).exclude(estado_reserva='ANULADA')

        # Los servicios de esas reservas: por cada uno, de qué reserva es y qué día es el evento
        servicios_reservados = Reservas_x_Servicios.objects.filter(id_reserva__in=reservas).values_list(
            'id_reserva_id', 'id_reserva__fecha_evento', 'id_servicio_id'
        )

        # Qué equipos usa cada servicio y cuántos: {servicio: [(equipo, cantidad), ...]}
        equipos_del_servicio = defaultdict(list)
        for id_servicio, id_equipo, cantidad in Equipos_x_Servicios.objects.values_list('id_servicio_id', 'id_equipo_id', 'cantidad'):
            equipos_del_servicio[id_servicio].append((id_equipo, cantidad))

        # ---------- 4) Sumamos ----------
        # unidades[equipo][(año, mes)] = unidades comprometidas de ese equipo en ese mes
        unidades = defaultdict(lambda: defaultdict(int))
        # por_dia[equipo][fecha] = unidades de ese equipo en un mismo día (para sacar el día de más uso)
        por_dia = defaultdict(lambda: defaultdict(int))
        # eventos[equipo] = las reservas donde se usó (para contar en cuántos eventos estuvo)
        eventos = defaultdict(set)
        # reservas_del_mes[(año, mes)] = las reservas de ese mes que usan alguno de los equipos elegidos
        reservas_del_mes = defaultdict(set)

        for id_reserva, fecha, id_servicio in servicios_reservados:
            for id_equipo, cantidad in equipos_del_servicio[id_servicio]:
                # Si el equipo quedó afuera por los filtros, no se cuenta
                if id_equipo not in equipos:
                    continue
                mes = (fecha.year, fecha.month)
                unidades[id_equipo][mes] += cantidad
                por_dia[id_equipo][fecha] += cantidad
                eventos[id_equipo].add(id_reserva)
                reservas_del_mes[mes].add(id_reserva)

        # ---------- 5) Armamos la respuesta ----------
        # Una fila por equipo, con sus unidades mes por mes
        filas = []
        for id_equipo, e in equipos.items():
            por_mes = [unidades[id_equipo][m] for m in meses]
            # El día en que más unidades de este equipo se usaron juntas
            dia_pico, maximo_dia = None, 0
            for fecha, cantidad in por_dia[id_equipo].items():
                if cantidad > maximo_dia:
                    dia_pico, maximo_dia = fecha, cantidad
            filas.append({
                'id_equipo': id_equipo,
                'nombre_equipo': e.nombre_equipo,
                'tipo': e.id_tipoeq.nombre_tipoeq,
                # Cuántas unidades tenemos de este equipo (para comparar con lo que se usa)
                'stock': e.cantidad_equipo,
                'por_mes': por_mes,
                'total': sum(por_mes),
                'eventos': len(eventos[id_equipo]),
                'maximo_dia': maximo_dia,
                'fecha_maximo': dia_pico,
            })
        # Primero los más usados; si empatan, por nombre
        filas.sort(key=lambda f: (-f['total'], f['nombre_equipo']))

        # Una columna del gráfico por mes: el total de unidades de todos los equipos elegidos
        columnas = [
            {
                'anio': anio,
                'mes': mes,
                'etiqueta': f'{MESES[mes - 1]} {anio}',
                'unidades': sum(unidades[id_equipo][(anio, mes)] for id_equipo in equipos),
                'reservas': len(reservas_del_mes[(anio, mes)]),
            }
            for anio, mes in meses
        ]

        total_unidades = sum(c['unidades'] for c in columnas)

        return Response({
            'periodo': {'desde': f'{desde[0]}-{desde[1]:02d}', 'hasta': f'{hasta[0]}-{hasta[1]:02d}'},
            'meses': columnas,
            # La imagen del gráfico (si no hubo uso en el período no se dibuja)
            'grafico': _grafico_uso_por_mes(columnas) if total_unidades else None,
            'equipos': filas,
            'total_unidades': total_unidades,
            # Reservas del período (no anuladas) que usan alguno de los equipos elegidos
            'total_reservas': len(set().union(*reservas_del_mes.values())) if reservas_del_mes else 0,
            # Las listas para armar los filtros de la pantalla. Van acá para que quien tiene
            # permiso de ver reportes no necesite además el permiso de Equipos.
            'opciones': {
                'tipos': [{'id': t.pk, 'nombre': t.nombre_tipoeq} for t in Tipo_Equipos.objects.order_by('nombre_tipoeq')],
                'equipos': [
                    {'id': e.pk, 'nombre': e.nombre_equipo, 'tipo': e.id_tipoeq_id}
                    for e in Equipos.objects.order_by('nombre_equipo')
                ],
            },
        })
