# Ruta en paralelo (mirai): los resultados deben ser idénticos a la ruta síncrona,
# tanto a nivel de funciones como en el módulo de simulación (ExtendedTask).

skip_if_not_installed("mirai")
skip_if_not_installed("promises")
skip_on_cran()

library(shiny)
library(bslib)
for (f in c("adapter_compose.R", "scenario_store.R", "results_views.R", "map_views.R", "ui_helpers.R",
            "paralelo.R")) {
  source(file.path(raiz, "R", f), encoding = "UTF-8")
}
for (f in c("mod_resultados.R", "mod_simulacion.R")) source(file.path(raiz, f), encoding = "UTF-8")

plantilla <- tablas_escenario_plantilla()
libs <- biblioteca_ejemplo(plantilla)
escenarios <- lapply(1:3, \(i) list(
  name = paste("Escenario de prueba", i), sub = names(libs$sub)[(i - 1) %% length(libs$sub) + 1],
  comp = if (i %% 2) names(libs$comp)[1] else "", comparar = TRUE))

# Espera a que se resuelva una promesa (o a que termine una ExtendedTask).
esperar <- function(listo, segundos = 120) {
  limite <- Sys.time() + segundos
  while (!listo() && Sys.time() < limite) later::run_now(0.05)
  expect_true(listo())
}

iniciar_daemons(2)
withr::defer(mirai::daemons(0), teardown_env())
sincrono <- ejecutar_escenarios(escenarios, libs, plantilla)

test_that("correr_en_paralelo() da resultados idénticos a ejecutar_escenarios()", {
  expect_true(paralelo_activo())
  prep <- preparar_corridas(escenarios, libs, plantilla)
  corridas <- NULL
  promises::then(correr_en_paralelo(prep$tablas, prep$nombres), \(v) corridas <<- v)
  esperar(\() !is.null(corridas))
  expect_identical(armar_resultados(escenarios, libs, corridas), sincrono)
})

test_that("un error del motor tiene el mismo mensaje en paralelo que en síncrono", {
  prep <- preparar_corridas(escenarios[1], libs, plantilla)
  mala <- prep$tablas
  mala[[1]]$sim_sub <- mala[[1]]$sim_sub[0, ]
  msg_sinc <- tryCatch(correr_tabla(mala[[1]], "Malo"), error = conditionMessage)
  msg_par <- NULL
  promises::then(correr_en_paralelo(mala, "Malo"), \(v) msg_par <<- "sin error",
                 \(e) msg_par <<- conditionMessage(e))
  esperar(\() !is.null(msg_par))
  expect_match(msg_sinc, "^Escenario «Malo»: ")
  expect_identical(msg_par, msg_sinc)
})

test_that("el módulo corre en una ExtendedTask y llena los mismos resultados", {
  estado <- reactiveValues(libs = libs, escenarios = escenarios, resultados = NULL, firma = NULL)
  testServer(mod_simulacion_server, args = list(estado = estado, plantilla = plantilla), {
    expect_false(is.null(tarea))
    session$setInputs(run = 1)
    expect_null(estado$resultados)
    esperar(\() { session$flushReact(); !is.null(estado$resultados) })
    expect_identical(estado$resultados, sincrono)
    expect_identical(estado$firma, firma_actual())

    # Segunda corrida: todo sale de la caché
    session$setInputs(run = 2)
    esperar(\() { session$flushReact(); !is.null(estado$resultados) })
    expect_identical(estado$resultados, sincrono)
  })
})
