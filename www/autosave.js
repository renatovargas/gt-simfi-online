// Autosave en el navegador (modo servidor): guarda el estado de la sesión en
// localStorage. Al conectar, envía lo guardado a input$autosave_navegador
// ("" si no hay nada o el navegador no permite guardar).
(function () {
  var CLAVE = "gtsimfi_autosave";

  function leer() {
    try { return window.localStorage.getItem(CLAVE) || ""; } catch (e) { return ""; }
  }

  $(document).on("shiny:connected", function () {
    Shiny.setInputValue("autosave_navegador", leer(), { priority: "event" });
  });

  Shiny.addCustomMessageHandler("gtsimfi_guardar", function (texto) {
    try { window.localStorage.setItem(CLAVE, texto); } catch (e) { /* sin espacio o bloqueado */ }
  });

  Shiny.addCustomMessageHandler("gtsimfi_borrar", function (x) {
    try { window.localStorage.removeItem(CLAVE); } catch (e) { /* bloqueado */ }
  });
})();
