# Handover: gt-simfi-online (versión para Posit Connect)

Para el agente que trabaje en este repo. Escrito desde la sesión de `../gt-simfi` el 2026-11-12.
Responder y comentar en español, de forma concisa.

## Objetivo

Adaptar la app Shiny de microsimulación del subsidio eléctrico de Guatemala (`../gt-simfi`)
para que corra en **Posit Connect** con varios usuarios a la vez. `../gt-simfi` sigue siendo
la versión local que los colegas descargan: **no se modifica desde aquí** (solo lectura).
Este repo no necesita sitio Quarto.

## Punto de partida

1. Clonar `../gt-simfi` en esta carpeta conservando la historia, en el commit
   `f4765f8ddfdc1765644454d0384e533fe384f663` («Merge tarifas-instructivo»).
   La carpeta tiene por ahora solo este archivo: moverlo aparte antes de clonar y regresarlo después.
2. Apuntar `origin` al repo de GitHub `renatovargas/gt-simfi-online` (ya creado, vacío).
   Opcional: conservar `../gt-simfi` como remoto `local` para traer luego cambios del motor.
3. Quitar el sitio Quarto: `_quarto.yml`, `index.qmd`, `instructivo.qmd`, `docs/`, `styles.css`,
   y ajustar `AGENTS.md`:
   - quitar la sección «Sitio Quarto»;
   - reescribir «Despliegue» para Connect;
   - las referencias a `index.qmd` como documentación de paquetes pasan a un `README.md` corto.
   **La pestaña «Instructivo» de la app se queda** (`R/instructivo.R`, `www/img/`). Su enlace al
   sitio de gt-simfi puede quedarse o quitarse; preguntar a la persona usuaria.
4. Leer `AGENTS.md` y `handover.md` del repo clonado: sus reglas siguen vigentes, sobre todo las
   tres siguientes.
   - `reference/` es la copia literal del motor del colega. **Nunca se edita.**
   - Todo el acoplamiento con ese motor vive en `R/adapter_*.R`.
   - Lo no solicitado no se hace.

## Reglas de commits

- Commits y push con el usuario de gh de la persona usuaria, **sin líneas Co-Authored-By**.
- Trabajar en ramas. Hacer merge solo cuando se haya probado y la persona lo pida.
- `observaciones/` debe estar en `.gitignore`.

## Lo que hay que cambiar, en orden

### 1. Autosave por usuario (obligatorio)

Hoy `R/scenario_store.R` guarda el estado de la sesión en `app_state/autosave.rds`, dentro de la
carpeta de la app. Lo usan `autosave_leer()`, `autosave_escribir()` y `autosave_borrar()`, llamados
desde `app.R` y `mod_sesion.R`. En Connect esa carpeta es **compartida por todos los usuarios** y
se borra en cada redespliegue: un usuario pisaría la biblioteca de otro.

Opciones, para decidir con la persona usuaria:
- (a) un archivo por usuario con `session$user` (requiere que la app en Connect exija inicio de
  sesión), en un directorio persistente configurable fuera del bundle;
- (b) guardar en el navegador de cada persona;
- (c) desactivar el autosave en el servidor y dejar solo exportar/importar Excel, que ya existe
  en `mod_sesion.R`.

Recomendación: (a) si hay inicio de sesión; si no, (c). Conviene un interruptor en `R/config.R`
(por ejemplo, el modo local o servidor) para no bifurcar el código.

### 2. Dependencias explícitas

- Connect instala paquetes desde el manifiesto (`rsconnect::writeManifest()`). Su detector no ve
  los `library(p, character.only = TRUE)` de `adjuntar_paquetes_ref()` (`R/adapter_env.R`), que
  carga `REF_PAQUETES` (`R/adapter_names.R`). Declararlos explícitamente en la app, por ejemplo en
  un archivo con llamadas `library()` o `requireNamespace()` que el detector sí vea. No tocar
  `reference/`.
- `sf` está en `REF_PAQUETES` (viene del Master del colega) y necesita GDAL, GEOS y PROJ en el
  servidor. Un `grep` rápido no encontró `st_`/`sf::` en `02`-`04` ni en `x_GTM26SUB_funciones.R`.
  `03`/`04` usan `statar::xtile` y las funciones usan `haven::`. **Verificar** con una corrida
  sin `sf` adjunto antes de decidir. Si no se usa, adjuntarlo solo si está instalado o quitarlo de
  la lista del servidor. Es un cambio del adaptador, no de `reference/`.
- `paquetes_faltantes()` (`R/config.R`) ya avisa en la UI si falta algún paquete.
- No se usa `renv` como decisión del proyecto, aunque `rsconnect` lo usa internamente para el
  manifiesto: está bien.

### 3. Desplegar y configurar Connect

- Primera versión: síncrona como hoy, con **una conexión por proceso** en la configuración de la
  app en Connect. Así cada usuario tiene su propio proceso y nadie bloquea a otro.
- Probar con dos o más sesiones simultáneas con escenarios distintos. Es la prueba de aislamiento
  entre sesiones del `handover.md`, sección 8.
- La raíz de la app es el directorio de trabajo en Connect. Las rutas ya son relativas (`ruta_app()`).

### 4. `ExtendedTask` + `mirai`, con escenarios en paralelo

- Hoy `mod_simulacion.R` llama de forma síncrona a `ejecutar_escenarios()` (`R/adapter_results.R`),
  que corre cada escenario con `run_scenario(tablas)` (`R/adapter_engine.R`), uno tras otro. Cada
  escenario tarda unos 1.6 s, así que 4 escenarios toman unos 6-7 s y bloquean el proceso de R.
- `run_scenario()` es el único punto de entrada al motor. No usa `.GlobalEnv`, `setwd` ni rutas
  fijas, y escribe solo en un `tempfile()` propio. Es lo que se envía a cada proceso de `mirai`.
- Diseño propuesto:
  - `mirai::daemons(n)`, con `n` según la memoria del servidor (medirla: cada proceso carga
    tidyverse, data.table, etc.);
  - `mirai::everywhere()` para cargar una vez por proceso los `R/*.R` necesarios y adjuntar los
    paquetes;
  - un `mirai_map()` o un `mirai` por escenario, y armar los resultados con `combinar_resultados()`
    en el proceso principal;
  - `shiny::ExtendedTask` en `mod_simulacion.R`, con el botón deshabilitado mientras corre.
- Conservar los resultados en `NULL` al iniciar cada corrida y la caché por hash de las tablas
  (`cache` en `mod_simulacion.R`). En el servidor, esa caché podría compartirse entre sesiones.
- Se pierde la barra «escenario N de M» de `withProgress`: mostrar un estado «Simulando…» o
  avisar al terminar cada escenario.
- Mantener un modo síncrono de respaldo (sin daemons) para desarrollo local y para las pruebas.

## Pruebas

- `NOT_CRAN=true Rscript -e 'testthat::test_dir("tests/testthat")'`. Hoy pasan todas. Incluyen la
  paridad con los fixtures de oro del colega y el límite de 25 MB por archivo.
- Para probar la app de verdad: `shinytest2::AppDriver` (necesita `NOT_CRAN=true`). Antes de
  manejarla con datos de prueba, respaldar `app_state/autosave.rds` y restaurarlo al final.
- Agregar pruebas del autosave por usuario y de la ruta `mirai`: resultados idénticos al modo
  síncrono.
