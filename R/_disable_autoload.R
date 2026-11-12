# Disables Shiny autoloading of R/ (shiny.autoload.r). app.R sources these files
# itself, after setting a UTF-8 locale (R/locale.R); autoloading would read them
# first, before the locale is fixed, and load everything twice.
