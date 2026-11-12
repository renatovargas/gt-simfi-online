# Corridas en paralelo con mirai (modo servidor).
#
# Cada daemon es un proceso de R que carga una sola vez el código del motor y
# adjunta sus paquetes; luego cada escenario se corre con correr_tabla() en un
# daemon. En modo local (o sin mirai) la app usa la ruta síncrona,
# ejecutar_escenarios().

# Archivos de R/ que necesita un daemon para correr run_scenario().
ARCHIVOS_MOTOR <- c("config.R", "adapter_names.R", "adapter_params.R", "adapter_env.R",
                    "adapter_engine.R")

#' ¿Correr los escenarios en paralelo? Por defecto, en modo servidor si mirai y
#' promises están instalados. `GTSIMFI_MIRAI` = "1" o "0" lo fuerza.
usar_mirai <- function() {
  v <- Sys.getenv("GTSIMFI_MIRAI")
  quiere <- if (v %in% c("0", "1")) v == "1" else modo_app() == "servidor"
  quiere && requireNamespace("mirai", quietly = TRUE) && requireNamespace("promises", quietly = TRUE)
}

#' Número de daemons por proceso de la app (`GTSIMFI_DAEMONS`, por defecto 1:
#' en Connect Cloud gratuito hay 1 CPU y 4 GB, así que más daemons no aceleran y
#' gastan memoria; con 1 la interfaz igual no se bloquea mientras se simula).
#' En Connect cada proceso levanta los suyos: memoria ~ procesos x (1 + daemons).
n_daemons <- function() {
  n <- suppressWarnings(as.integer(Sys.getenv("GTSIMFI_DAEMONS", "1")))
  if (is.na(n) || n < 1L) 1L else n
}

#' Levanta los daemons y carga en cada uno el código del motor y sus paquetes.
iniciar_daemons <- function(n = n_daemons(), raiz = normalizePath(ruta_app())) {
  mirai::daemons(n)
  mirai::everywhere({
    asegurar_utf8()   # el daemon es otro proceso de R: mismo problema de locale que app.R
    options(gtsimfi.raiz = raiz)
    for (f in archivos) source(file.path(raiz, "R", f), encoding = "UTF-8", local = globalenv())
    adjuntar_paquetes_ref()
  }, raiz = raiz, archivos = ARCHIVOS_MOTOR, asegurar_utf8 = asegurar_utf8)
  invisible(n)
}

#' ¿Hay daemons listos para recibir corridas?
paralelo_activo <- function() {
  requireNamespace("mirai", quietly = TRUE) && mirai::daemons_set()
}

#' Corre en los daemons las tablas indicadas. Devuelve una promesa que se resuelve
#' con una lista de corridas, en el mismo orden. Un error del motor se devuelve
#' como valor (con el mismo mensaje que la ruta síncrona) y se lanza aquí, en el
#' proceso principal, para que el mensaje no cambie.
correr_en_paralelo <- function(tablas, nombres) {
  tareas <- lapply(seq_along(tablas), \(i) mirai::mirai(
    tryCatch(correr_tabla(tablas, nombre), error = \(e) structure(list(mensaje = conditionMessage(e)),
                                                                     class = "gtsimfi_error")),
    tablas = tablas[[i]], nombre = nombres[i], correr_tabla = correr_tabla))
  promises::promise_all(.list = lapply(tareas, promises::as.promise)) |>
    promises::then(\(corridas) {
      err <- Filter(\(x) inherits(x, "gtsimfi_error"), corridas)
      if (length(err)) stop(err[[1]]$mensaje, call. = FALSE)
      corridas
    })
}
