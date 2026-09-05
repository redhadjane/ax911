"use strict";
(() => {
  if (!window.webkit?.messageHandlers?.hopNative) return;
  const origin = "https://www.houseofpizzagaffney.com";
  const native = (action, payload = {}) => window.webkit.messageHandlers.hopNative.postMessage({ action, ...payload });
  const realFetch = window.fetch.bind(window);
  const get = Storage.prototype.getItem;
  const set = Storage.prototype.setItem;
  const remove = Storage.prototype.removeItem;
  const session = new Map();
  if (window.__HOP_NATIVE_SESSION__) session.set("hop_manager_token", "native-session");
  const protectedKeys = new Set(["hop_manager_token", "hop_manager_profile"]);
  for (const key of protectedKeys) remove.call(localStorage, key);
  set.call(localStorage, "hop_command_api_base", origin);
  Storage.prototype.getItem = function (key) {
    return this === localStorage && protectedKeys.has(key) ? session.get(key) ?? null : get.call(this, key);
  };
  Storage.prototype.setItem = function (key, value) {
    if (this === localStorage && protectedKeys.has(key)) { session.set(key, String(value)); return; }
    if (this === localStorage && key === "hop_command_api_base") return;
    set.call(this, key, value);
  };
  Storage.prototype.removeItem = function (key) {
    if (this === localStorage && protectedKeys.has(key)) {
      session.delete(key);
      if (key === "hop_manager_token") native("logout").catch(showError);
      return;
    }
    remove.call(this, key);
  };
  Storage.prototype.clear = function () {
    if (this === localStorage) {
      session.clear(); native("logout").catch(showError);
      for (const key of Object.keys(this)) remove.call(this, key);
      set.call(this, "hop_command_api_base", origin);
    }
  };
  function showError(error) {
    const text = String(error?.message || error || "The iPad action could not finish.");
    const region = document.getElementById("toastRegion");
    if (!region) return;
    const toast = document.createElement("div");
    toast.className = "toast error"; toast.textContent = text;
    region.append(toast); setTimeout(() => toast.remove(), 8000);
  }
  window.fetch = async (input, options = {}) => {
    const url = new URL(typeof input === "string" ? input : input.url, location.href);
    if (url.protocol === "blob:" || url.protocol === "data:" || url.protocol === "file:") return realFetch(input, options);
    if (url.origin !== origin || !url.pathname.startsWith("/api/")) throw new Error("Only the connected HOP API is allowed.");
    if (options.signal?.aborted) throw new DOMException("Request cancelled", "AbortError");
    const response = await native("request", {
      url: url.href, method: options.method || (input instanceof Request ? input.method : "GET"),
      body: options.body ?? (input instanceof Request && !["GET", "HEAD"].includes(input.method) ? await input.text() : null)
    });
    if (response.status === 401) { session.clear(); }
    const bytes = Uint8Array.from(atob(response.body), c => c.charCodeAt(0));
    return new Response([204, 205, 304].includes(response.status) ? null : bytes, { status: response.status, headers: { "Content-Type": response.contentType } });
  };
  window.open = (url) => { native("external", { url: new URL(url, origin).href }).catch(showError); return null; };
  document.addEventListener("click", event => {
    const link = event.target.closest("a[download]");
    if (!link) return;
    event.preventDefault();
    realFetch(link.href).then(r => r.blob()).then(blob => new Promise((resolve, reject) => {
      const reader = new FileReader(); reader.onload = () => resolve(String(reader.result).split(",")[1]); reader.onerror = reject; reader.readAsDataURL(blob);
    })).then(base64 => native("share", { filename: link.download, base64 })).catch(showError);
  }, true);

  function documentTarget() {
    const active = document.body.classList;
    if (active.contains("printing-taskboard")) return { selector: ".task-wallboard-export", landscape: true, kind: "Tasks" };
    if (active.contains("printing-application")) return { selector: ".application-paper", landscape: false, kind: "Application" };
    if (active.contains("printing-invoice")) return { selector: ".main-site-invoice", landscape: false, kind: "Invoice" };
    if (active.contains("printing-wallboard") || document.querySelector("dialog[open] .wallboard-export")) return { selector: "dialog[open] .wallboard-export", landscape: true, kind: "Wallboard" };
    if (location.hash === "#invoices") return { selector: ".main-site-invoice", landscape: false, kind: "Invoice" };
    return null;
  }
  window.print = () => {
    const target = documentTarget();
    if (!target) {
      const preview = document.querySelector('[data-action="schedule-export"]');
      if (preview) { preview.click(); return; }
      showError("Open this document's Export / Preview first, then choose Print / Save PDF."); return;
    }
    const source = document.querySelector(target.selector);
    if (!source) { showError("The printable document has not loaded. Reopen its preview first."); return; }
    const clone = source.cloneNode(true);
    clone.querySelectorAll("script,iframe,object,embed,form,input,button").forEach(node => node.remove());
    for (const node of [clone, ...clone.querySelectorAll("*")]) {
      for (const attr of [...node.attributes]) if (/^on/i.test(attr.name)) node.removeAttribute(attr.name);
      if (node.tagName === "IMG" && !String(node.getAttribute("src")).startsWith("./assets/")) node.remove();
    }
    const styles = ["styles.css", "document-print.css", "usability-2026.css", "ipad-print.css"].map(name => `<link rel="stylesheet" href="./${name}">`).join("");
    const bodyClass = target.kind === "Tasks" ? "printing-taskboard" : target.kind === "Application" ? "printing-application" : target.kind === "Invoice" ? "printing-invoice" : "printing-wallboard";
    const html = `<!doctype html><html data-theme="light"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' file: data:; style-src 'self' file: 'unsafe-inline'; script-src 'none'; connect-src 'none'"><meta name="viewport" content="width=device-width,initial-scale=1">${styles}</head><body class="ipad-export ${bodyClass}">${clone.outerHTML}</body></html>`;
    native("document", { html, landscape: target.landscape, filename: `HOP-${target.kind}-${new Date().toISOString().slice(0,10)}.pdf` }).catch(showError).finally(() => window.dispatchEvent(new Event("afterprint")));
  };
  const windowsOnlyActions = new Set(["printer-discover", "bridge-connect", "bridge-start", "print-discover", "print-bridge-start"]);
  document.addEventListener("click", event => {
    const button = event.target.closest("[data-action]");
    if (button && windowsOnlyActions.has(button.dataset.action)) {
      event.preventDefault(); event.stopImmediatePropagation();
      showError("The automatic printer bridge runs on Windows. On iPad, use a document's Export / Preview for AirPrint or Save to Files.");
    }
    if (event.target.closest("#primaryNav [data-route]")) document.body.classList.remove("nav-open");
  }, true);
  document.addEventListener("DOMContentLoaded", () => {
    document.body.classList.add("ipad-runtime");
    const note = document.createElement("div");
    note.className = "ipad-build-label";
    note.textContent = "iPad · 0.1.0 · Live HOP";
    document.querySelector(".sidebar-foot")?.append(note);
    const updateViewport = () => document.documentElement.style.setProperty("--ipad-height", `${window.visualViewport?.height || innerHeight}px`);
    window.visualViewport?.addEventListener("resize", updateViewport); updateViewport();
  });
})();
