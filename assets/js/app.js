import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { CodeEditorHook } from "../../deps/live_monaco_editor/priv/static/live_monaco_editor.esm";
import topbar from "../vendor/topbar";

let Hooks = {};
Hooks.CodeEditorHook = CodeEditorHook;

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

window.addEventListener("phx:copy", (event) => {
  const originalContent = event.target.innerHTML;
  event.target.innerHTML = "<span class='hero-clipboard-document-check'></span>";

  let value = event.detail.url;
  navigator.clipboard.writeText(value);

  setTimeout(() => {
    event.target.innerHTML = originalContent;
  }, 1000);
});

function applyColorSchemePreference() {
  const darkExpected = window.matchMedia('(prefers-color-scheme: dark)').matches;
  if (darkExpected) {
      document.documentElement.classList.add('dark');
      document.documentElement.style.setProperty('color-scheme', 'dark');
  }
  else {
      document.documentElement.classList.remove('dark');
      document.documentElement.style.setProperty('color-scheme', 'light');
  }
}

// set listener to update color scheme preference on change
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', event => {
  const newColorScheme = event.matches ? "dark" : "light";
  console.log(newColorScheme);
  applyColorSchemePreference();
});

// check color scheme preference on page load
applyColorSchemePreference();
