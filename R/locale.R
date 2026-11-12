# The R/ files and UI texts are UTF-8. Some servers (Posit Connect Cloud) start R
# with a non-UTF-8 locale, and then source(..., encoding = "UTF-8") cannot read
# accented characters. asegurar_utf8() switches LC_CTYPE to a UTF-8 locale. It is
# called in app.R before sourcing anything else, and in each mirai daemon
# (iniciar_daemons(), R/paralelo.R).
#
# This file must stay ASCII-only: it is read before the locale is fixed.

asegurar_utf8 <- function() {
  if (isTRUE(l10n_info()[["UTF-8"]])) return(invisible(TRUE))
  for (loc in c("C.UTF-8", "C.utf8", "en_US.UTF-8", "en_US.utf8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", loc)))) return(invisible(TRUE))
  }
  warning("No UTF-8 locale found; accented texts may fail to load.", call. = FALSE)
  invisible(FALSE)
}
