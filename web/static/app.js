const $ = id => document.getElementById(id);
let fallbackTimer;

function setConnection(connected) {
  $("connection-state").textContent = connected ? "LIVE" : "RECONNECTING";
  document.querySelector(".connection").style.color = connected ? "var(--green)" : "var(--orange)";
}

function update(stats) {
  $("hostname").textContent = stats.hostname || "Unknown host";
  $("cpu").textContent = `${stats.cpu.load.toFixed(1)} / ${stats.cpu.cores}`;
  $("cpu-detail").textContent = `${stats.cpu.percent.toFixed(1)}% load`;
  $("memory").textContent = `${stats.memory.used_gb.toFixed(1)} GB`;
  $("memory-detail").textContent = `of ${stats.memory.total_gb.toFixed(0)} GB · ${stats.memory.percent.toFixed(1)}%`;
  $("disk").textContent = `${stats.disk.used_gb.toFixed(1)} GB`;
  $("disk-detail").textContent = `of ${stats.disk.total_gb.toFixed(0)} GB · ${stats.disk.percent.toFixed(1)}%`;
  $("model").textContent = stats.model || "Unknown";
  $("model-detail").textContent = (stats.os || "").split("-")[0];
  $("uptime").textContent = stats.uptime;
  $("tailnet").textContent = `${stats.tailscale_nodes} nodes`;
  $("updated").textContent = new Date(stats.timestamp * 1000).toLocaleTimeString([], {hour:"2-digit", minute:"2-digit", second:"2-digit"});
}

async function poll() {
  try { update(await (await fetch("/api/stats", {cache:"no-store"})).json()); setConnection(true); }
  catch (_) { setConnection(false); }
}

const events = new EventSource("/api/events");
events.onmessage = event => { try { update(JSON.parse(event.data)); setConnection(true); } catch (_) {} };
events.onerror = () => {
  setConnection(false); events.close();
  if (!fallbackTimer) { poll(); fallbackTimer = setInterval(poll, 3000); }
};
if ("serviceWorker" in navigator) window.addEventListener("load", () => navigator.serviceWorker.register("/service-worker.js"));
