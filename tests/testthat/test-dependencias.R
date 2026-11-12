# R/dependencias.R declara los paquetes para el manifiesto de Connect: debe
# coincidir con PAQUETES_APP y REF_PAQUETES (sin opcionales ni testthat).

test_that("R/dependencias.R coincide con PAQUETES_APP, REF_PAQUETES y PAQUETES_SERVIDOR", {
  ex <- parse(file.path(raiz, "R", "dependencias.R"), keep.source = FALSE)
  declarados <- character()
  buscar <- function(e) {
    if (is.call(e)) {
      if (identical(e[[1]], as.name("library"))) declarados <<- c(declarados, as.character(e[[2]]))
      for (a in as.list(e)[-1]) buscar(a)
    }
  }
  for (e in ex) buscar(e)
  esperados <- setdiff(unique(c(PAQUETES_APP, REF_PAQUETES, PAQUETES_SERVIDOR)),
                       c("testthat", REF_PAQUETES_OPCIONALES))
  expect_setequal(declarados, esperados)
  expect_false(anyDuplicated(declarados) > 0)
})

test_that("los opcionales no se exigen y se omiten si no están instalados", {
  expect_true(all(REF_PAQUETES_OPCIONALES %in% REF_PAQUETES))
  expect_false(any(REF_PAQUETES_OPCIONALES %in% paquetes_faltantes()))
  # Un opcional que no está instalado se salta; uno obligatorio falla
  viejo <- REF_PAQUETES_OPCIONALES
  assign("REF_PAQUETES_OPCIONALES", c(viejo, "paquete.inexistente"), envir = globalenv())
  on.exit(assign("REF_PAQUETES_OPCIONALES", viejo, envir = globalenv()), add = TRUE)
  expect_no_error(adjuntar_paquetes_ref(c("readxl", "paquete.inexistente")))
  expect_error(adjuntar_paquetes_ref("otro.paquete.inexistente"))
})
