# ==== Librerias ====
library(sf)
library(dplyr)
library(stringr)
library(units)

# ==== 1) Rutas y parámetros ====
EQP_PATH   <- "SHP/data/equipamientos.shp"
OUT_DIR    <- "out_entropy"
OUT_SHP    <- file.path(OUT_DIR, "equipamientos_entropy_hex.shp")
CRS_METERS <- 32717     # UTM 17S; cambiar y ajustar para el área de interés
HEX_SIZE   <- 250       # tamaño de celda (m)

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ==== 2) Definición de CRS para todas las capas ====
eqp <- st_read(EQP_PATH, quiet = TRUE) # EQP_PATH es el archivo en .shp que contiene la info. de equimientos
stopifnot(!is.na(st_crs(eqp)))

eqp <- st_transform(eqp, CRS_METERS) # se transforma el shape de equipamientos a 32717 (UTM 17S),
                                      #CRS_METERS se definió en el bloque anterior

# ==== 3) Asegurar columna de categoría ====

CAT_COL <- "tipoequipa" # Corresponde a  la columna categórica que vamos a usar para analizar la diversidad
if (!CAT_COL %in% names(eqp)) stop("No existe la columna 'tipoequipa' en la capa.") #Si no existe la columna la busqueda se detiene

eqp <- eqp |>
  mutate(
    !!CAT_COL := as.character(.data[[CAT_COL]]) |> stringr::str_trim(), # Se limpia el texto y eliminamos espacios e.g. "Comercio " a "Comercio"
    !!CAT_COL := ifelse(is.na(.data[[CAT_COL]]) | .data[[CAT_COL]] == "", 
                        "SIN_CLASE", .data[[CAT_COL]]) # Si la columna no tiene registros,
                                                       #en vez de dejarlos en vacíos los reemplaza con "SIN CLASE"
  )

# Número total de categorías (K) para normalizar
# K es número total de clases e.g. Salud, comercio, educación y cultura K=4, esto sirve para normalizar Shannon.
K_global <- eqp |> st_drop_geometry() |> pull(!!CAT_COL) |> unique() |> length()
if (K_global < 2) stop("Se requiere al menos 2 categorías distintas en 'tipoequipa'.") 


# ==== 4) Función de entropía de Shannon normalizada ====
# Hnorm = [ - sum(p_i * ln p_i) ] / ln(K), con p_i proporciones por categoría
entropy_norm <- function(counts, K) {
  if (length(counts) == 0 || sum(counts, na.rm = TRUE) == 0) return(NA_real_)
  p <- counts / sum(counts)
  p <- p[p > 0]
  H  <- -sum(p * log(p))
  H / log(K)
}

# ==== 5) Área de trabajo y hexagonos ====
# Usamos un buffer suave alrededor del convex hull para no "cortar" bordes
bbox_area <- eqp |> st_union() |> st_convex_hull() |> st_buffer(3 * HEX_SIZE)

hex <- st_make_grid(bbox_area, cellsize = HEX_SIZE, square = FALSE) |>
  st_as_sf() |>
  st_intersection(bbox_area) |>
  mutate(hex_id = dplyr::row_number())

# ==== 6) Asignar equipamientos a hexágonos ====
eqp_hex <- st_join(eqp, hex, join = st_within, left = FALSE) |>
  st_drop_geometry() |>
  select(hex_id, !!CAT_COL)

# ==== 7) Conteos por categoría y entropía por celda ====
hex_stats <- eqp_hex |>
  count(hex_id, !!sym(CAT_COL), name = "n_cat") |>
  group_by(hex_id) |>
  summarise(
    H_norm        = entropy_norm(n_cat, K_global),
    n_equip       = sum(n_cat),
    n_categorias  = dplyr::n_distinct(.data[[CAT_COL]]),
    .groups = "drop"
  )

# Unir métricas a la geometría
hex_out <- hex |>
  left_join(hex_stats, by = "hex_id")

# (opcional) Poner 0 en celdas sin equipamientos: si quieren eso deben quitar el "#" de la línea 82
# hex_out$H_norm[is.na(hex_out$H_norm)] <- 0

# --- limpiar shapefile previo con el mismo nombre ---
base <- tools::file_path_sans_ext(OUT_SHP)
exts <- c(".shp", ".shx", ".dbf", ".prj", ".cpg", ".qpj")
unlink(paste0(base, exts), force = TRUE)

# --- verificar geometría (debería ser POLYGON) ---
print(unique(sf::st_geometry_type(hex_out)))  # debería mostrar POLYGON o MULTIPOLYGON

# --- Diagnóstico rápido ---
table(sf::st_geometry_type(hex_out))

# --- 1) Asegura geometrías válidas y extrae SOLO polígonos ---
hex_out <- sf::st_make_valid(hex_out)
hex_out <- sf::st_collection_extract(hex_out, "POLYGON")  # descarta POINT/LINE
# (si quieres multipolígono homogéneo)
# hex_out <- sf::st_cast(hex_out, "MULTIPOLYGON")

# --- 2) Aqui ordenamos "Si el shapefile previo ya existe con geometría de puntos, bórralo por completo" ---
base <- tools::file_path_sans_ext(OUT_SHP)
exts <- c(".shp", ".shx", ".dbf", ".prj", ".cpg", ".qpj")
unlink(paste0(base, exts), force = TRUE)

# --- 3) Exporta (GeoPackage) ---
OUT_GPKG <- file.path(OUT_DIR, "entropy.gpkg")
sf::st_write(hex_out, OUT_GPKG, layer = "entropy_hex_250m", delete_layer = TRUE, quiet = TRUE)

# Exporta en .shp:
sf::st_write(hex_out, OUT_SHP, delete_layer = TRUE, quiet = TRUE)

# Mensaje para notificar que ya se desacargo el archihvo en .shp
cat("\nOK ✅ Capa exportada.\n")
