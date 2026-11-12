# gt-simfi-online

Microsimulación del subsidio eléctrico de Guatemala (impacto fiscal y distributivo), en su versión
para **Posit Connect**. La versión local, que cada persona descarga y corre en su equipo, está en
[`gt-simfi`](https://github.com/renatovargas/gt-simfi).

## Paquetes

No se usa `renv`. Paquetes de la app: `PAQUETES_APP` en `R/config.R`. Paquetes del motor de
referencia: `REF_PAQUETES` en `R/adapter_names.R`.

## Correr localmente

Desde la raíz del repo:

```r
shiny::runApp()
```

Pruebas: `NOT_CRAN=true Rscript -e 'testthat::test_dir("tests/testthat")'`.

## Desplegar en Posit Connect

Desde GitHub (*git-backed*), con `manifest.json`. Pendiente.
