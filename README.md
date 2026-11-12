# gt-simfi-online

Microsimulación del subsidio eléctrico de Guatemala (impacto fiscal y distributivo), en su versión
para **Posit Connect**. La versión local, que cada persona descarga y corre en su equipo, está en
[`gt-simfi`](https://github.com/renatovargas/gt-simfi).

## Paquetes

No se usa `renv`. Paquetes de la app: `PAQUETES_APP` en `R/config.R`. Paquetes del motor de
referencia: `REF_PAQUETES` en `R/adapter_names.R`; `sf` y `ragg` (`REF_PAQUETES_OPCIONALES`) no los
usa el motor y se adjuntan solo si están instalados. Para Connect, los paquetes se declaran en
`R/dependencias.R` (una prueba verifica que coincide con esas listas).

## Correr localmente

Desde la raíz del repo:

```r
shiny::runApp()
```

Pruebas: `NOT_CRAN=true Rscript -e 'testthat::test_dir("tests/testthat")'`.

## Desplegar en Posit Connect

El despliegue es desde GitHub (*git-backed*): Connect lee `manifest.json` de la rama elegida.
Cuando cambien los paquetes o los archivos de la app, regenerar el manifiesto y hacer commit:

```r
source("data-raw/escribir_manifest.R")   # necesita rsconnect
```

- El manifiesto incluye solo lo que usa la app (sin `tests/`, `data-raw/` ni
  `data/dispincome_raw.rds`). `.renvignore` saca el script `05` (que no se ejecuta) de la detección
  de paquetes, para que no pida `sf`.
- Fija la versión de R con la que se generó; Connect debe tener una compatible.
- En Connect: una conexión por proceso (*Runtime → Max connections per process = 1*).
- En Connect la app corre en modo servidor (`modo_app()`, `R/config.R`): el trabajo se guarda en
  el navegador de cada persona. Se puede forzar el modo con la variable de entorno `GTSIMFI_MODO`
  (`local` o `servidor`).
- Los escenarios corren en paralelo con `mirai` en modo servidor. `GTSIMFI_DAEMONS` fija los
  daemons por proceso (por defecto 2; cada uno ocupa ~0.7 GB tras una corrida) y
  `GTSIMFI_MIRAI` = `0` apaga el paralelo (`1` lo fuerza, por ejemplo para probar localmente).
