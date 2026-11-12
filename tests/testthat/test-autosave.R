# Autosave: modo de la app, ida y vuelta del texto que se guarda en el navegador
# y restauración al conectarse una sesión en modo servidor.

library(shiny)
for (f in c("adapter_compose.R", "scenario_store.R")) {
  source(file.path(raiz, "R", f), encoding = "UTF-8")
}

test_that("modo_app() usa GTSIMFI_MODO y, si no, detecta Connect", {
  withr::with_envvar(c(GTSIMFI_MODO = "", R_CONFIG_ACTIVE = ""), expect_equal(modo_app(), "local"))
  withr::with_envvar(c(GTSIMFI_MODO = "", R_CONFIG_ACTIVE = "rsconnect"), expect_equal(modo_app(), "servidor"))
  withr::with_envvar(c(GTSIMFI_MODO = "local", R_CONFIG_ACTIVE = "rsconnect"), expect_equal(modo_app(), "local"))
  withr::with_envvar(c(GTSIMFI_MODO = "Servidor"), expect_equal(modo_app(), "servidor"))
})

test_that("el estado sobrevive la ida y vuelta por texto (incluidos NA y listas vacías)", {
  libs <- biblioteca_ejemplo()
  esc <- list(list(name = "Reforma", sub = names(libs$sub)[1], comp = "__ref__", comparar = TRUE))
  expect_true(anyNA(unlist(libs)))
  txt <- estado_a_texto(libs, esc)
  # Texto plano: Shiny envía la clase "json" como objeto, no como cadena
  expect_identical(class(txt), "character")
  expect_true(is.character(jsonlite::fromJSON(shiny:::toJSON(txt))))
  r <- texto_a_estado(txt)
  expect_identical(r$libs, libs)
  expect_identical(r$escenarios, esc)

  vacio <- texto_a_estado(estado_a_texto(list(sub = list(), comp = list()), list()))
  expect_identical(vacio$libs, list(sub = list(), comp = list()))
  expect_identical(vacio$escenarios, list())
})

test_that("texto vacío, inválido o de otra versión no se restaura", {
  expect_null(texto_a_estado(""))
  expect_null(texto_a_estado(NULL))
  expect_null(texto_a_estado(NA_character_))
  expect_null(texto_a_estado("{no es json"))
  expect_null(texto_a_estado(jsonlite::serializeJSON(list(version = 99L, libs = list(), escenarios = list()))))
  # Tipos inesperados (por ejemplo, una función) no pasan
  malo <- jsonlite::serializeJSON(list(version = AUTOSAVE_VERSION, escenarios = list(),
                                       libs = list(sub = list(a = setNames(list(function() 1), SUB_CAMPOS[1])), comp = list())))
  expect_null(texto_a_estado(malo))
})

test_that("en modo servidor la sesión se restaura desde el navegador y no lee app_state/", {
  libs <- biblioteca_ejemplo()
  esc <- list(list(name = "Desde el navegador", sub = names(libs$sub)[1], comp = "", comparar = FALSE))
  withr::local_envvar(GTSIMFI_MODO = "servidor", GTSIMFI_MIRAI = "0")  # sin daemons: aquí solo se prueba el autosave
  testServer(shiny::shinyAppDir(raiz), {
    expect_false(restaurado())
    expect_equal(length(estado$escenarios), 0)
    session$setInputs(autosave_navegador = estado_a_texto(libs, esc))
    expect_true(restaurado())
    expect_identical(estado$libs, libs)
    expect_identical(estado$escenarios, esc)
  })
})

test_that("en modo servidor un navegador sin datos deja la sesión vacía", {
  withr::local_envvar(GTSIMFI_MODO = "servidor", GTSIMFI_MIRAI = "0")  # sin daemons: aquí solo se prueba el autosave
  testServer(shiny::shinyAppDir(raiz), {
    session$setInputs(autosave_navegador = "")
    expect_true(restaurado())
    expect_equal(length(estado$libs$sub), 0)
    expect_equal(length(estado$escenarios), 0)
  })
})
