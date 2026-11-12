# Módulo: ejecución de la simulación y contenedor de resultados.
# Con daemons de mirai (modo servidor, R/paralelo.R) los escenarios corren en
# paralelo dentro de un shiny::ExtendedTask, sin bloquear el proceso de R. Sin
# daemons (modo local y pruebas) la corrida es síncrona: ejecutar_escenarios().

mod_simulacion_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Ejecución"),
      layout_columns(
        col_widths = c(4, 8),
        div(input_task_button(ns("run"), "Simular", icon = icon("play"), label_busy = "Simulando\u2026",
                              class = "btn-primary w-100"),
            p(class = "small text-muted mt-1 mb-0", "Corre los escenarios marcados y la situación base.")),
        div(uiOutput(ns("mensaje")),
            div(class = "small text-muted mt-1", tags$strong("En cola: "), uiOutput(ns("cola"), inline = TRUE)))
      )
    ),
    mod_resultados_ui(ns("res"))
  )
}

mod_simulacion_server <- function(id, estado, plantilla) {
  moduleServer(id, function(input, output, session) {
    cache <- new.env()   # corridas ya calculadas (clave: hash de las tablas del motor)

    mostrar_error <- \(mensaje) showModal(modalDialog(
      title = "No se pudo completar la simulación",
      p("Revise los valores del esquema tarifario y de la compensación del escenario indicado."),
      tags$p(class = "small text-muted mb-1", "Detalle:"),
      tags$pre(class = "small", style = "white-space: pre-wrap;", mensaje),
      easyClose = TRUE, footer = modalButton("Cerrar")))

    # Corrida en paralelo (solo si hay daemons). `pendiente` guarda lo necesario para
    # armar los resultados cuando termina la tarea.
    tarea <- NULL
    pendiente <- NULL
    if (paralelo_activo()) {
      tarea <- ExtendedTask$new(\(tablas, nombres) correr_en_paralelo(tablas, nombres)) |>
        bind_task_button("run")
      observeEvent(tarea$status(), {
        st <- tarea$status()
        if (!st %in% c("success", "error")) return()
        ctx <- pendiente
        pendiente <<- NULL
        res <- tryCatch({
          corridas <- tarea$result()
          for (k in seq_along(ctx$nuevas)) {
            for (i in which(ctx$prep$claves == ctx$nuevas[k])) ctx$prep$corridas[[i]] <- corridas[[k]]
            cache[[ctx$nuevas[k]]] <- corridas[[k]]
          }
          armar_resultados(ctx$sel, ctx$libs, ctx$prep$corridas)
        }, error = \(e) { message("Error de simulación: ", conditionMessage(e)); e })
        if (inherits(res, "error")) {
          mostrar_error(conditionMessage(res))
        } else {
          estado$resultados <- res
          estado$firma <- ctx$firma
        }
      }, ignoreInit = TRUE)
    }

    seleccion <- reactive(Filter(\(e) isTRUE(e$comparar), estado$escenarios))
    firma_actual <- reactive({
      sel <- seleccion()
      rlang::hash(list(sel, lapply(sel, \(e) list(estado$libs$sub[[normalizar_ref(e$sub)]],
                                                  estado$libs$comp[[normalizar_ref(e$comp)]]))))
    })

    output$cola <- renderUI({
      nm <- vapply(seleccion(), `[[`, "", "name")
      if (length(nm)) paste(nm, collapse = ", ") else tags$em("ningún escenario marcado")
    })

    output$mensaje <- renderUI({
      if (!is.null(tarea) && tarea$status() == "running") {
        return(tags$span(class = "badge text-bg-info", "Simulando\u2026"))
      }
      if (is.null(estado$resultados)) return(NULL)
      if (!identical(estado$firma, firma_actual())) {
        tags$span(class = "badge text-bg-warning",
                  "Los resultados no corresponden a la configuración actual; vuelva a simular.")
      } else {
        tags$span(class = "badge text-bg-success", "Resultados al día")
      }
    })

    observeEvent(input$run, {
      sel <- seleccion()
      if (!length(sel)) {
        return(showNotification("Marque al menos un escenario en la pestaña «Escenarios».", type = "warning"))
      }
      faltan <- paquetes_faltantes()
      if (length(faltan)) return(showModal(aviso_paquetes(faltan)))
      err <- validar_escenarios(sel, estado$libs)
      if (length(err)) return(showNotification(paste(err, collapse = " "), type = "error", duration = 15))

      # Evita que se vean resultados viejos durante y después de una corrida fallida
      estado$resultados <- NULL
      estado$firma <- NULL
      firma <- firma_actual()

      if (!is.null(tarea)) {
        prep <- tryCatch(preparar_corridas(sel, estado$libs, plantilla, cache), error = \(e) e)
        if (inherits(prep, "error")) return(mostrar_error(conditionMessage(prep)))
        falta <- vapply(prep$corridas, is.null, logical(1))
        nuevas <- unique(prep$claves[falta])          # escenarios repetidos se corren una vez
        idx <- match(nuevas, prep$claves)
        pendiente <<- list(sel = sel, libs = estado$libs, prep = prep, nuevas = nuevas, firma = firma)
        return(tarea$invoke(prep$tablas[idx], prep$nombres[idx]))
      }

      res <- withProgress(message = "Simulando…", value = 0, {
        tryCatch(
          ejecutar_escenarios(sel, estado$libs, plantilla, cache = cache,
            progreso = \(i, n, nombre) setProgress((i - 1) / n, detail = sprintf("%s (%d de %d)", nombre, i, n))),
          error = \(e) { message("Error de simulación: ", conditionMessage(e)); e })
      })
      if (inherits(res, "error")) {
        mostrar_error(conditionMessage(res))
      } else {
        estado$resultados <- res
        estado$firma <- firma
      }
    })

    mod_resultados_server("res", reactive(estado$resultados))
  })
}
