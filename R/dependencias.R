# Dependencias explícitas para el manifiesto de Posit Connect.
#
# Este archivo no se carga nunca. Sirve para que el detector de dependencias de
# rsconnect::writeManifest() vea los paquetes que la app adjunta con
# library(p, character.only = TRUE) (REF_PAQUETES, R/adapter_names.R) y los de
# PAQUETES_APP (R/config.R). Una prueba verifica que coincide con esas listas.
# Sin los opcionales (REF_PAQUETES_OPCIONALES) ni testthat.

if (FALSE) {
  # App (PAQUETES_APP)
  library(shiny)
  library(bslib)
  library(DT)
  library(plotly)
  library(htmltools)
  library(jsonlite)
  library(rlang)
  library(readxl)
  library(openxlsx)
  library(janitor)
  # Motor de referencia (REF_PAQUETES)
  library(tidyverse)
  library(data.table)
  library(statar)
  library(scales)
  library(collapse)
  library(haven)
}
