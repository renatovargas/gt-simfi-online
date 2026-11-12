# Genera manifest.json para Posit Connect (despliegue desde GitHub).
# Correr desde la raíz: source("data-raw/escribir_manifest.R").
# Volver a correrlo cuando cambien los paquetes o los archivos de la app, y
# hacer commit de manifest.json.
#
# Se incluyen solo los archivos que usa la app: no van tests/, data-raw/,
# observaciones/, app_state/ ni data/dispincome_raw.rds (solo para data-raw/).
# reference/ va completo: base_vigente() compara el md5 de todos sus archivos.

archivos <- c(
  "app.R",
  ".renvignore",   # excluye el script 05 de la detección de paquetes (sf, ragg)
  list.files(".", "^mod_.*\\.R$"),
  list.files("R", "\\.R$", full.names = TRUE),
  list.files("www", recursive = TRUE, full.names = TRUE),
  list.files("reference", recursive = TRUE, full.names = TRUE),
  setdiff(list.files("data", recursive = TRUE, full.names = TRUE), "data/dispincome_raw.rds")
)

local({
  op <- options(repos = c(CRAN = "https://cloud.r-project.org"))
  on.exit(options(op))
  rsconnect::writeManifest(appDir = ".", appFiles = archivos, appPrimaryDoc = "app.R")
})
