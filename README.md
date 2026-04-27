# entropy-hex-urban-accessibility-cuenca
R script for normalized Shannon entropy using 250 m hexagonal grid to assess functional urban diversity and accessibility in Cuenca, Ecuador.
# Cálculo de entropía funcional mediante malla hexagonal

Este repositorio contiene un script en R para calcular la diversidad funcional urbana mediante el índice de entropía de Shannon normalizado, aplicado a equipamientos urbanos agregados en una malla hexagonal regular de 250 metros.

El procedimiento fue desarrollado como parte del análisis espacial del proyecto MOVER-U, orientado a evaluar caminabilidad, accesibilidad urbana y relación campus-ciudad en el entorno del Campus Yanuncay de la Universidad de Cuenca, Ecuador.

## Objetivo
Calcular un indicador espacial de diversidad funcional urbana a partir de la distribución de equipamientos clasificados por tipo.

## Metodología
El análisis utiliza una malla hexagonal de 250 m en el sistema de coordenadas UTM WGS84 Zona 17S (EPSG:32717). Para cada hexágono se contabilizan los equipamientos según su categoría funcional y se calcula el índice de entropía de Shannon normalizado:
H = -Σ pi ln(pi) / ln(K)

donde:

- pi representa la proporción de equipamientos de cada categoría dentro del hexágono.
- K corresponde al número total de categorías funcionales presentes en la base.
- H varía entre 0 y 1.

Valores cercanos a 0 indican baja diversidad funcional, mientras que valores próximos a 1 reflejan mayor mezcla de usos urbanos.

## Insumos requeridos

El script requiere una capa espacial de equipamientos urbanos en formato shapefile con una columna categórica llamada: tipoequipa
