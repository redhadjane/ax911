"use strict";

(function commandCenterApp() {
  const dates = window.HopDateContract;
  const QUERY = new URLSearchParams(location.search);
  const DESKTOP_HOSTS = new Set(["tauri.localhost", "localhost.tauri"]);
  const IS_DESKTOP = location.protocol === "file:" || location.protocol === "tauri:" || DESKTOP_HOSTS.has(location.hostname);
  const LOCAL_PREVIEW = QUERY.has("preview") && ["localhost", "127.0.0.1"].includes(location.hostname);
  const PREVIEW_API = LOCAL_PREVIEW ? String(QUERY.get("api") || "").replace(/\/$/, "") : "";
  const API_BASE = localStorage.getItem("hop_command_api_base") || PREVIEW_API || (IS_DESKTOP ? "https://www.houseofpizzagaffney.com" : "");
  const TAURI_INVOKE = window.__TAURI__?.core?.invoke || null;
  const TOKEN_KEY = "hop_manager_token";
  const MANAGER_KEY = "hop_manager_profile";
  const modules = [
    ["home", "Command Center", "home"], ["schedule", "Schedule", "schedule"], ["employees", "Employees", "employees"],
    ["inbox", "Inbox", "inbox"], ["applications", "Applications", "applications"], ["website", "Website", "website"],
    ["menu", "Menu", "menu"], ["hopclub", "HOP Club", "employees"], ["availability", "Availability", "availability"], ["tasks", "Tasks", "tasks"],
    ["parties", "Parties", "parties"], ["invoices", "Invoices", "invoices"],
    ["reports", "Reports", "reports"], ["notifications", "Notifications", "notifications"], ["settings", "Settings", "settings"],
    ["watchdog", "HOP Watchdog", "watchdog"],
  ].map(([id, label, icon]) => ({ id, label, icon }));
  const descriptions = {
    home: "Daily operations and planning ahead", schedule: "Build the Tuesday–Sunday wall-board schedule",
    employees: "Staff directory, roles, availability, and account status", inbox: "Requests, approvals, announcements, and history",
    applications: "Review and organize job applications", website: "Manage connected public website content",
    menu: "Connected items, prices, modifiers, images, and kitchen routing", hopclub: "Members, points, rewards, campaigns, and loyalty activity", availability: "Submitted employee availability by schedule week",
    tasks: "Assign, review, and verify operational tasks", parties: "Reservations and party staffing",
    invoices: "Create connected quotes and invoices from regular or catering menu items",
    reports: "Operational records and manager audit activity", notifications: "Manager alerts and staff announcements",
    settings: "Restaurant, scheduling, tax, printer, and access settings", watchdog: "Read-only diagnostics with controlled repair approvals",
  };
  const state = {
    route: location.hash.slice(1) || "home", loading: false, data: {}, selected: null,
    weekStart: dates.startOfTuesdayWeek(dates.today()), scheduleType: "main", scheduleView: "published",
    inboxTab: "pending", documentsTab: "documents", search: "", action: null, cateringDetail: null, invoiceDetail: null,
    applicationsTab: "all", notificationsTab: "all", reportsTab: "staffing", settingsTab: "connections",
    websiteTab: "content", websitePage: "home", invoiceSource: "all",
    partiesView: "week", partiesFilter: "all", partyMonth: dates.today().slice(0,7), tasksTab: "week", taskTeam: "main", availabilityFilter: "all", availabilityScope: "all", menuCategory: "all", applicationDetail: null,
    hopclubTab: "overview", hopclubDetail: null, scheduleConflict: null, notificationsCategory: "all", notificationsUnread: false,
    employeeView: "table", employeeMobileScreen: "home", employeeMobileStudio: false, homeTeamType: "main", autoRefreshTimer: null,
    alertTimer: null, alertUnreadIds: new Set(), alertInitialized: false,
    bridge: { key: "", id: `hop-command-${crypto.randomUUID?.() || Date.now()}`, running: false, busy: false, printer: "", lastError: "", timer: null, heartbeatAt: 0 },
  };

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const esc = (value) => String(value ?? "").replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);
  const arr = (value) => Array.isArray(value) ? value : [];
  const firstArray = (payload, keys) => keys.map((key) => payload?.[key]).find(Array.isArray) || (Array.isArray(payload) ? payload : []);
  const titleCase = (value) => String(value || "").replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
  const initials = (value) => String(value || "?").trim().split(/\s+/).slice(0, 2).map((part) => part[0]).join("").toUpperCase();
  const dateLabel = (value, options = {}) => {
    if (!value) return "Not set";
    const includesTime = options.hour !== undefined || options.minute !== undefined;
    const date = includesTime ? new Date(value) : new Date(`${String(value).slice(0, 10)}T12:00:00Z`);
    return new Intl.DateTimeFormat("en-US", { timeZone: includesTime ? "America/New_York" : "UTC", month: "short", day: "numeric", ...options }).format(date);
  };
  const money = (cents) => new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(Number(cents || 0) / 100);
  const mediaUrl = (value) => {
    const path = String(value || "").trim();
    if (!path) return "";
    if (/^(https?:|data:|blob:)/i.test(path)) return path;
    return `${API_BASE}${path.startsWith("/") ? path : `/${path}`}`;
  };
  const fileToDataUrl = (file) => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(new Error("The selected image could not be read."));
    reader.readAsDataURL(file);
  });
  const formatTime = (value) => {
    const match = String(value || "").match(/^(\d{1,2}):(\d{2})/);
    if (!match) return String(value || "");
    const hour = Number(match[1]);
    return `${hour % 12 || 12}:${match[2]} ${hour >= 12 ? "PM" : "AM"}`;
  };
  const statusClass = (value) => /active|approved|published|paid|healthy|ready|complete/i.test(value) ? "green" : /pending|draft|warning|attention|inquiry|partial|open|degraded|not configured/i.test(value) ? "amber" : /denied|critical|failed|terminated|void|issue|offline/i.test(value) ? "red" : "";
  const pill = (value, fallback = "Not set") => `<span class="pill ${statusClass(String(value || fallback))}">${esc(titleCase(value || fallback))}</span>`;
  const icon = (name, filled = false) => `<img src="./assets/${name}${filled ? "-filled" : ""}.svg" alt="">`;
  const empty = (title, detail, iconName = "inbox") => `<div class="empty-state"><div>${icon(iconName)}<b>${esc(title)}</b><small>${esc(detail)}</small></div></div>`;
  const manager = () => { try { return JSON.parse(localStorage.getItem(MANAGER_KEY) || "null"); } catch (_error) { return null; } };
  const appearancePreferences = () => ({
    theme: localStorage.getItem("hop_command_theme") || "system",
    density: localStorage.getItem("hop_command_density") || "comfortable",
    font: localStorage.getItem("hop_command_font") || "large",
    rememberRoute: localStorage.getItem("hop_command_remember_route") !== "false",
    autoRefresh: localStorage.getItem("hop_command_auto_refresh") || "5",
    showConflicts: localStorage.getItem("hop_command_show_conflicts") !== "false",
  });
  function applyAppearancePreferences() {
    const prefs = appearancePreferences();
    const dark = prefs.theme === "dark" || (prefs.theme === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
    document.documentElement.dataset.theme = dark ? "dark" : "light";
    document.documentElement.dataset.density = prefs.density;
    document.documentElement.dataset.font = prefs.font;
  }
  function configureAutoRefresh() {
    if (state.autoRefreshTimer) clearInterval(state.autoRefreshTimer);
    const minutes = Number(appearancePreferences().autoRefresh || 0);
    if (!minutes) return;
    state.autoRefreshTimer = setInterval(() => {
      if (!document.hidden && !$("#actionDialog")?.open && !state.loading) navigate(state.route, { keepSelection: true });
    }, minutes * 60000);
  }
  applyAppearancePreferences();
  configureAutoRefresh();
  const employeeName = (item, employees = []) => item?.employee_name || item?.display_name || item?.full_name || employees.find((employee) => String(employee.id) === String(item?.employee_id))?.display_name || employees.find((employee) => String(employee.id) === String(item?.employee_id))?.name || "Unknown employee";

  function formValues(form) {
    const result = {};
    for (const [key, value] of new FormData(form).entries()) result[key] = typeof value === "string" ? value.trim() : value;
    return result;
  }

  function openActionDialog({ eyebrow = "CONNECTED RECORD", title, description = "", body = "", buttons = [], onSubmit = null }) {
    $("#actionDialog").classList.remove("wallboard-dialog", "invoice-workspace-dialog", "employee-workspace-dialog");
    state.action = { onSubmit };
    $("#actionEyebrow").textContent = eyebrow;
    $("#actionTitle").textContent = title;
    $("#actionDescription").textContent = description;
    $("#actionBody").innerHTML = body;
    $("#actionError").textContent = "";
    $("#actionButtons").innerHTML = buttons.map((button) => `<button type="${button.submit ? "submit" : "button"}" class="${button.className || "button"}" data-dialog-action="${esc(button.action || "close")}">${esc(button.label)}</button>`).join("");
    const dialog = $("#actionDialog");
    if (!dialog.open) dialog.showModal();
  }

  function closeActionDialog() {
    state.action = null;
    $("#actionDialog").classList.remove("wallboard-dialog", "invoice-workspace-dialog", "employee-workspace-dialog");
    if ($("#actionDialog").open) $("#actionDialog").close();
  }

  async function runConnectedAction(work, successMessage, route = state.route) {
    $("#actionError").textContent = "Working…";
    try {
      await work();
      closeActionDialog();
      notify(successMessage);
      await navigate(route, { keepSelection: true });
    } catch (error) {
      $("#actionError").textContent = error.message;
      notify(error.message, true);
    }
  }

  function notify(message, error = false) {
    const region = $("#toastRegion");
    const duplicate = [...region.children].find((toast) => toast.textContent === message);
    if (duplicate) {
      duplicate.classList.add("toast-pulse");
      setTimeout(() => duplicate.classList.remove("toast-pulse"), 220);
      return;
    }
    while (region.children.length >= 3) region.firstElementChild.remove();
    const item = document.createElement("div");
    item.className = `toast${error ? " error" : ""}`;
    item.textContent = message;
    region.append(item);
    setTimeout(() => item.remove(), 3800);
  }

  function notificationSound() {
    if (localStorage.getItem("hop_notification_sound") === "false") return;
    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      const context = new AudioContext();
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = "sine"; oscillator.frequency.value = 720;
      gain.gain.setValueAtTime(0.0001, context.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.12, context.currentTime + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.32);
      oscillator.connect(gain); gain.connect(context.destination); oscillator.start(); oscillator.stop(context.currentTime + 0.34);
      oscillator.addEventListener("ended",()=>context.close());
    } catch (_error) { /* Browser sound permission may require the next manager click. */ }
  }

  function showManagerAlert(item) {
    const region = $("#toastRegion");
    const alert = document.createElement("button");
    alert.type = "button";
    alert.className = "toast manager-alert-toast";
    alert.innerHTML = `<span class="manager-alert-icon">!</span><span><b>${esc(item.title || "New manager notification")}</b><small>${esc(item.message || titleCase(item.category || "Open details"))}</small></span><i>Open</i>`;
    alert.addEventListener("click",()=>{state.notificationsTab="all";state.selected={id:item.id};navigate("notifications",{keepSelection:true});alert.remove();});
    while (region.children.length >= 4) region.firstElementChild.remove();
    region.append(alert);
    setTimeout(()=>alert.remove(),9000);
  }

  async function pollManagerAlerts({ announce = true } = {}) {
    if (!localStorage.getItem(TOKEN_KEY) && !LOCAL_PREVIEW) return;
    try {
      const payload = await api("/api/notifications/manager");
      const notifications = firstArray(payload,["notifications"]);
      const unread = notifications.filter((item)=>!(item.read_at||item.read));
      $(".notification-ping").hidden = unread.length === 0;
      $(".notification-ping").dataset.count = String(unread.length);
      const newItems = unread.filter((item)=>!state.alertUnreadIds.has(String(item.id)));
      state.alertUnreadIds = new Set(unread.map((item)=>String(item.id)));
      renderNav();
      if (state.alertInitialized && announce && newItems.length) {
        newItems.slice(0,2).reverse().forEach(showManagerAlert);
        notificationSound();
      }
      state.alertInitialized = true;
    } catch (_error) { /* Main module continues even if alert polling is temporarily unavailable. */ }
  }

  function startManagerAlerts() {
    if (state.alertTimer) clearInterval(state.alertTimer);
    pollManagerAlerts({announce:false});
    state.alertTimer = setInterval(()=>pollManagerAlerts(),30000);
  }

  async function api(path, options = {}) {
    const response = await fetch(`${API_BASE}${path}`, {
      cache: "no-store",
      ...options,
      headers: {
        Accept: "application/json",
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...(localStorage.getItem(TOKEN_KEY) ? { Authorization: `Bearer ${localStorage.getItem(TOKEN_KEY)}` } : {}),
        ...(options.headers || {}),
      },
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(payload.user_message || payload.error || `${response.status} ${response.statusText}`);
      error.status = response.status;
      error.payload = payload;
      if (response.status === 401 && !LOCAL_PREVIEW) openLogin();
      throw error;
    }
    return payload;
  }

  async function safe(path) {
    try { return { ok: true, value: await api(path) }; }
    catch (error) { return { ok: false, error: error.message, value: {} }; }
  }

  function printJobText(job = {}) {
    const payload = job.payload || {};
    return [payload.title || "HOUSE OF PIZZA & PASTA", payload.subtitle, ...(arr(payload.lines).map(String)), payload.footer]
      .filter(Boolean).join("\r\n");
  }

  async function bridgeHeartbeat(ok, message) {
    if (!state.bridge.key) return;
    await api("/api/print-bridge/heartbeat", { method: "POST", body: JSON.stringify({ bridge_key: state.bridge.key, bridge_id: state.bridge.id, printer_ok: ok, message }) });
    state.bridge.heartbeatAt = Date.now();
  }

  async function pollPrintBridge() {
    if (!state.bridge.running || state.bridge.busy || !TAURI_INVOKE || !state.bridge.key) return;
    state.bridge.busy = true;
    try {
      const payload = await api("/api/print-bridge/claim", { method: "POST", body: JSON.stringify({ bridge_key: state.bridge.key, bridge_id: state.bridge.id, printer_keys: ["front_counter", "drawer", "kitchen", "manager", "customer"] }) });
      if (payload.job) {
        let ok = false; let error = "";
        try {
          await TAURI_INVOKE("print_ticket", { printerName: state.bridge.printer || payload.config?.printer_name || "", text: printJobText(payload.job) });
          ok = true;
        } catch (printError) { error = String(printError?.message || printError); }
        await api("/api/print-bridge/result", { method: "POST", body: JSON.stringify({ bridge_key: state.bridge.key, bridge_id: state.bridge.id, job_id: payload.job.id, ok, error }) });
        if (!ok) throw new Error(error || "Windows printer rejected the job.");
      }
      if (Date.now() - state.bridge.heartbeatAt > 25000) await bridgeHeartbeat(true, `Automatic Windows bridge ready · ${state.bridge.printer}`);
      state.bridge.lastError = "";
    } catch (error) {
      state.bridge.lastError = error.message || String(error);
      if (Date.now() - state.bridge.heartbeatAt > 25000) await bridgeHeartbeat(false, state.bridge.lastError).catch(() => undefined);
    } finally { state.bridge.busy = false; }
  }

  async function startPrintBridge(printerName = "") {
    if (!IS_DESKTOP || !TAURI_INVOKE) throw new Error("Automatic Print Bridge is available in the installed Command Center.");
    const pairing = await api("/api/print-center/pair", { method: "POST", body: "{}" });
    if (!pairing.bridge_key) throw new Error("The server did not return a printer pairing key.");
    state.bridge.key = pairing.bridge_key;
    state.bridge.printer = printerName || pairing.printer_name || state.bridge.printer;
    if (!state.bridge.printer) throw new Error("Choose an installed printer first.");
    state.bridge.running = pairing.enabled !== false;
    if (state.bridge.timer) clearInterval(state.bridge.timer);
    state.bridge.timer = setInterval(pollPrintBridge, 4000);
    await bridgeHeartbeat(true, `Automatic Windows bridge connected · ${state.bridge.printer}`);
    await pollPrintBridge();
  }

  async function discoverWindowsPrinters() {
    if (!IS_DESKTOP || !TAURI_INVOKE) throw new Error("Printer discovery is available in the installed Command Center.");
    return arr(await TAURI_INVOKE("discover_printers"));
  }

  function renderNav() {
    $("#primaryNav").innerHTML = modules.map((module) => `
      <button class="nav-item ${module.id === state.route ? "active" : ""}" data-route="${module.id}" title="${esc(module.label)}">
        ${icon(module.icon, module.id === state.route)}<span>${esc(module.label)}</span>${module.id === "notifications" && state.alertUnreadIds.size ? `<i class="nav-unread">${state.alertUnreadIds.size > 99 ? "99+" : state.alertUnreadIds.size}</i>` : ""}
      </button>`).join("");
  }

  function pageHead(route, actions = "") {
    const module = modules.find((item) => item.id === route);
    return `<div class="page-head"><div><h2>${esc(module.label)}</h2><p>${esc(descriptions[route])}</p></div><div class="page-actions">${actions}</div></div>`;
  }

  function loading() { return `<div class="loading"><div class="spinner"></div>Loading connected HOP data…</div>`; }
  function card(title, body, subtitle = "", action = "") {
    return `<section class="card"><div class="card-head"><div><h3>${esc(title)}</h3>${subtitle ? `<p>${esc(subtitle)}</p>` : ""}</div>${action ? `<div class="card-action">${action}</div>` : ""}</div><div class="card-body">${body}</div></section>`;
  }

  async function loadRouteData(route) {
    const week = state.weekStart;
    const today = dates.today();
    const monthAnchor = new Date(`${state.partyMonth || week.slice(0,7)}-01T12:00:00Z`); const monthStart = new Date(Date.UTC(monthAnchor.getUTCFullYear(),monthAnchor.getUTCMonth(),1)); const monthGridStart = new Date(monthStart); monthGridStart.setUTCDate(1-monthStart.getUTCDay()); const monthGridEnd = new Date(monthGridStart); monthGridEnd.setUTCDate(monthGridEnd.getUTCDate()+41); const iso=(value)=>value.toISOString().slice(0,10);
    const endpoints = {
      schedule: [`/api/schedules?week_start_date=${week}`, "/api/employees?active=true", `/api/schedules/versions/${week}`, `/api/availability?week_start=${week}`, `/api/parties?week_start=${week}`],
      employees: ["/api/employees", `/api/schedules/published/${week}`, `/api/availability?week_start=${week}`],
      inbox: ["/api/inbox/pending", "/api/notifications/manager", "/api/inbox/history", "/api/employees"],
      applications: ["/api/job-applications"], website: ["/api/website-content", "/api/media/library?target=homepage_hero"], menu: ["/api/menu/items", "/api/media/library?target=menu_item_image"],
      hopclub: ["/api/hopclub/admin/dashboard", "/api/hopclub/admin/customers", "/api/hopclub/admin/reward-rules", "/api/hopclub/campaigns", "/api/hopclub/admin/audit?limit=40", "/api/media/library?target=reward_image"],
      availability: [`/api/availability?week_start=${week}`, "/api/employees?active=true", `/api/schedules?week_start_date=${week}`],
      tasks: [`/api/tasks?date=${today}`, `/api/schedules?week_start_date=${week}`, "/api/employees?active=true"], parties: [`/api/parties?from=${iso(monthGridStart)}&to=${iso(monthGridEnd)}`, `/api/parties/history?week_start=${week}`, `/api/parties/contacts?week_start=${week}`, "/api/employees?active=true"],
      invoices: ["/api/command/v2/catering", "/api/invoices", "/api/invoices?archived=true", "/api/menu/items?active=true", "/api/menu/categories?active=true"],
      reports: ["/api/invoices", "/api/inbox/history", "/api/employees", `/api/schedules?week_start_date=${week}`, `/api/parties?week_start=${week}`], notifications: ["/api/notifications/manager", "/api/employees", "/api/push/status-summary", "/api/push/subscriptions?active=true", "/api/inbox/pending"],
      settings: ["/api/settings", "/api/print-center/status"], watchdog: ["/api/command/v2/watchdog"],
    };
    if (route === "home") {
      const results = await Promise.all([
        safe("/api/command/summary"), safe(`/api/schedules/published/${week}`), safe(`/api/parties?from=${week}&to=${dates.addDays(week, 20)}`),
        safe("/api/command/v2/catering"), safe(`/api/command/v2/calendar?from=${today}&to=${dates.addDays(today, 90)}`),
        safe("/api/invoices"), safe("/api/command/v2/watchdog"), safe("/api/employees?active=true"),
        safe(`/api/availability?week_start=${week}`), safe(`/api/availability?week_start=${dates.addDays(week,7)}`), safe(`/api/availability?week_start=${dates.addDays(week,14)}`),
      ]);
      return { results, offline: results.every((result) => !result.ok) };
    }
    const results = await Promise.all((endpoints[route] || []).map(safe));
    return { results, offline: results.length > 0 && results.every((result) => !result.ok) };
  }

  function metric(label, value, detail = "") {
    return `<div class="card metric"><span>${esc(label)}</span><b>${esc(value)}</b>${detail ? `<small>${esc(detail)}</small>` : ""}</div>`;
  }

  function savedState(label = "All changes saved") {
    return `<span class="save-state"><span class="status-dot"></span>${esc(label)}</span>`;
  }

  function tabBar(items, active, attribute, extraClass = "") {
    return `<div class="tabs underline-tabs ${extraClass}">${items.map((item) => {
      const [id, label, count] = item;
      return `<button class="${active === id ? "active" : ""}" data-${attribute}="${esc(id)}">${esc(label)}${count === undefined ? "" : `<span>${esc(count)}</span>`}</button>`;
    }).join("")}</div>`;
  }

  function filterToolbar({ search = "Search connected records", filters = [], meta = "", actions = "" } = {}) {
    return `<div class="filter-toolbar"><label class="module-search"><span>⌕</span><input class="table-search" placeholder="${esc(search)}"></label>${filters.map((filter) => filter.attr ? `<button class="filter-chip${filter.active ? " active" : ""}" ${filter.attr}>${esc(filter.label)}</button>` : `<span class="filter-chip filter-label${filter.active ? " active" : ""}">${esc(filter.label)}</span>`).join("")}<span class="filter-spacer"></span>${meta ? `<span class="table-meta">${esc(meta)}</span>` : ""}${actions}</div>`;
  }

  function inspectorTitle(eyebrow, title, subtitle = "", status = "") {
    return `<div class="inspector-title"><div><span class="eyebrow">${esc(eyebrow)}</span><h3>${esc(title)}</h3>${subtitle ? `<p>${esc(subtitle)}</p>` : ""}</div>${status ? pill(status) : ""}</div>`;
  }

  function miniLegend() {
    return `<div class="mini-legend"><span><i class="available"></i>Available</span><span><i class="off"></i>Requested off</span><span><i class="locked"></i>Approved / locked</span></div>`;
  }

  function personRows(entries) {
    if (!entries.length) return empty("No published assignments", "When a schedule is published, the team appears here.", "employees");
    return `<div class="people-stack">${entries.slice(0, 8).map((entry) => {
      const name = entry.employee_name || entry.display_name || entry.name || "Assigned employee";
      return `<div class="person-row"><span class="initial">${esc(initials(name))}</span><span><b>${esc(name)}</b><small>${esc(entry.slot_name || entry.row_key || entry.role || "Scheduled")}</small></span>${pill(entry.shift || entry.period || "Scheduled")}</div>`;
    }).join("")}</div>`;
  }

  function renderHome(data) {
    const [summaryResult, scheduleResult, partiesResult, cateringResult, calendarResult, invoiceResult, watchdogResult, employeesResult, ...availabilityResults] = data.results;
    const summary = summaryResult.value || {};
    const schedulePayload = scheduleResult.value || {};
    const schedule = schedulePayload.schedule || firstArray(schedulePayload, ["schedules"])[0] || {};
    const employees = firstArray(employeesResult.value, ["employees"]);
    const rowsById = new Map(arr(schedule.rows).map((row) => [String(row.id), row]));
    const entries = arr(schedule.entries || schedulePayload.entries).map((entry) => {
      const row = rowsById.get(String(entry.row_id)) || {};
      return { ...entry, row_key: row.row_key, slot_name: row.label, role_group: row.role_group || entry.role, employee_name: employeeName(entry, employees), shift: row.label };
    });
    const todayDay = new Date(`${dates.today()}T12:00:00Z`).getUTCDay();
    const teamEntries = entries.filter((item) => state.homeTeamType === "host" ? /host/i.test(String(item.role_group || item.role || item.slot_name)) : !/host/i.test(String(item.role_group || item.role || item.slot_name)));
    const todayEntries = teamEntries.filter((item) => Number(item.day_of_week) === todayDay);
    const lunch = todayEntries.filter((item) => /am|lunch/i.test(`${item.shift || ""} ${item.slot_name || item.row_key || ""}`));
    const dinner = todayEntries.filter((item) => /pm|dinner|fh/i.test(`${item.shift || ""} ${item.slot_name || item.row_key || ""}`));
    const parties = firstArray(partiesResult.value, ["parties"]);
    const catering = firstArray(cateringResult.value, ["orders"]);
    const events = firstArray(calendarResult.value, ["events"]);
    const invoices = firstArray(invoiceResult.value, ["invoices"]);
    const warnings = [];
    if (summary.open_shifts?.connected && Number(summary.open_shifts.value) > 0) warnings.push(`${summary.open_shifts.value} open shifts for week ${dateLabel(summary.open_shifts.week_start_date || state.weekStart)}`);
    if (summary.pending_inbox?.connected && Number(summary.pending_inbox.value) > 0) warnings.push(`${summary.pending_inbox.value} manager requests await a decision`);
    const due = invoices.filter((item) => Number(item.balance_due_cents) > 0 && item.due_date).slice(0, 1);
    if (due.length) warnings.push(`Invoice ${due[0].invoice_number || ""} has a remaining balance`);
    const attention = `<div class="attention-strip"><span class="attention-icon">!</span><strong>Needs Attention</strong><div class="attention-items">${warnings.length ? warnings.slice(0, 3).map((item) => `<span class="attention-item">${esc(item)}</span>`).join("") : `<span class="attention-item">No unresolved high-priority items returned.</span>`}</div><button data-route="inbox">Review all →</button></div>`;
    const team = `<div class="team-columns"><div class="shift-panel"><div class="shift-title"><strong>${state.homeTeamType === "host" ? "Lunch hosts" : "Lunch team"}</strong>${pill(lunch.length ? `${lunch.length} assigned` : "No assignments", lunch.length ? "" : "No assignments")}</div>${personRows(lunch)}</div><div class="shift-panel"><div class="shift-title"><strong>${state.homeTeamType === "host" ? "Dinner hosts" : "Dinner team"}</strong>${pill(dinner.length ? `${dinner.length} assigned` : "No assignments")}</div>${personRows(dinner)}</div></div>`;
    const planningItems = [0, 7, 14].map((offset) => {
      const week = dates.addDays(state.weekStart, offset);
      const thisWeek = offset === 0 ? schedule : {};
      const stateLabel = thisWeek.status || (offset === 0 ? "Not started" : "Open planning week");
      const weekEnd = dates.addDays(week, 5);
      const weekParties = parties.filter((party) => String(party.date || party.party_date || "").slice(0, 10) >= week && String(party.date || party.party_date || "").slice(0, 10) <= weekEnd);
      const weekEvents = events.filter((event) => String(event.event_date || "").slice(0, 10) >= week && String(event.event_date || "").slice(0, 10) <= weekEnd);
      const weekAvailability = firstArray(availabilityResults[offset / 7]?.value, ["availability", "employees", "rows"]);
      const unavailableIds = new Set(weekAvailability.filter((item) => item.status === "off" || item.available === false).map((item) => String(item.employee_id || item.id)));
      const unavailableByRole = ["host", "waitress", "floor"].map((role) => `${role === "waitress" ? "servers" : role}: ${employees.filter((employee) => (employee.role === role || arr(employee.secondary_roles).includes(role)) && unavailableIds.has(String(employee.id))).length}`).join(" · ");
      return `<button class="timeline-row planning-row" data-week="${week}" data-route="schedule"><span class="date-tile"><b>${esc(dateLabel(week, { day: "numeric" }))}</b><span>${esc(dateLabel(week, { month: "short", day: undefined }))}</span></span><span class="row-copy"><b>Week of ${esc(dateLabel(week, { month: "short", day: "numeric" }))}</b><small>${weekParties.length} parties · ${weekEvents.length} calendar items</small><small class="planning-staff">Unavailable — ${esc(unavailableByRole)}</small></span>${pill(stateLabel)}</button>`;
    }).join("");
    const eventBody = events.length ? `<div class="compact-list">${events.slice(0, 5).map((event) => `<div class="compact-row"><span class="date-tile"><b>${esc(dateLabel(event.event_date, { day: "numeric" }))}</b><span>${esc(dateLabel(event.event_date, { month: "short", day: undefined }))}</span></span><span class="row-copy"><b>${esc(event.title)}</b><small>${esc(event.metadata?.impact || event.event_type || "Operational calendar")}</small></span>${pill(event.event_type)}</div>`).join("")}</div>` : empty("No upcoming calendar events", "Add holidays, school dates, and local events to the shared calendar.", "schedule");
    const futureWork = [...catering.map((item) => ({ ...item, kind: "Catering", date: item.event_date, label: item.customer_name })), ...invoices.filter((item) => item.due_date || item.event_date).map((item) => ({ ...item, kind: titleCase(item.document_type || "Invoice"), date: item.event_date || item.due_date, label: item.customer_name }))].sort((a, b) => String(a.date).localeCompare(String(b.date)));
    const workBody = futureWork.length ? `<div class="compact-list">${futureWork.slice(0, 5).map((item) => `<div class="compact-row"><span class="date-tile"><b>${esc(dateLabel(item.date, { day: "numeric" }))}</b><span>${esc(dateLabel(item.date, { month: "short", day: undefined }))}</span></span><span class="row-copy"><b>${esc(item.label || item.order_number || "Connected record")}</b><small>${esc(item.kind)} · ${esc(titleCase(item.service_type || ""))}</small></span>${pill(item.status)}</div>`).join("")}</div>` : empty("No future catering or invoice actions", "Connected unresolved records will appear here.", "catering");
    const checks = arr(watchdogResult.value?.checks);
    const watchdogBody = checks.length ? `<div class="compact-list">${checks.map((check) => `<div class="compact-row"><span class="status-dot"></span><span class="row-copy"><b>${esc(check.name)}</b><small>${esc(`${check.latency_ms || 0} ms`)}</small></span>${pill(check.status)}</div>`).join("")}</div>` : empty("Diagnostics unavailable", "Open HOP Watchdog for the current connection state.", "watchdog");
    const importantBody = `<div class="important-grid">${[
      [summary.pending_inbox?.value || 0,"Requests awaiting review","inbox"],
      [warnings.length,"Operational warnings","home"],
      [events.filter((event)=>String(event.event_date||"").slice(0,10)===dates.today()).length,"Important dates today","schedule"],
      [parties.filter((party)=>String(party.date||party.party_date||"").slice(0,10)===dates.today()).length,"Parties today","parties"],
    ].map(([count,label,route],index)=>`<button class="important-tile tone-${index}" data-route="${route}"><span class="count-badge">${esc(count)}</span><span class="row-copy"><b>${esc(label)}</b><small>${count ? "Needs review" : "Clear"}</small></span><span>›</span></button>`).join("")}</div>`;
    const upcomingPartyBody = parties.length ? `<div class="compact-list">${parties.slice(0,4).map((party)=>`<button class="timeline-row" data-route="parties" data-week="${esc(party.date||party.party_date)}"><span class="date-tile"><b>${esc(dateLabel(party.date||party.party_date,{day:"numeric"}))}</b><span>${esc(dateLabel(party.date||party.party_date,{month:"short",day:undefined}))}</span></span><span class="row-copy"><b>${esc(party.name||"Party")}</b><small>${esc(party.time?formatTime(party.time):"Time TBD")} · ${esc(party.count||"?")} guests</small></span><span>›</span></button>`).join("")}</div>` : empty("No upcoming parties","Connected reservations will appear here.","parties");
    return `<div class="page">${pageHead("home", `<button class="button" data-refresh>Refresh</button><button class="primary-button" data-route="schedule">Open Schedule</button>`)}${attention}<div class="home-primary">${card("Today's Team", team, dateLabel(dates.today(), { weekday: "long", month: "long", day: "numeric" }), `<div class="segmented"><button class="${state.homeTeamType === "main" ? "active" : ""}" data-home-team="main">Main</button><button class="${state.homeTeamType === "host" ? "active" : ""}" data-home-team="host">Host</button></div>`)}${card("Planning Ahead", `<div class="timeline-list">${planningItems}</div><button class="card-footer-link" data-route="schedule">Open Schedule Planner <span>›</span></button>`, "Parties, calendar impact, and staff availability")}</div><div class="home-secondary">${card("Important Today", importantBody, "Requests, tasks, and operational exceptions", `<button class="button" data-route="inbox">Open all</button>`)}${card("Upcoming Parties", upcomingPartyBody, "Confirmed customer bookings", `<button class="button" data-route="parties">View all</button>`)}${card("HOP Watchdog", watchdogBody, "Technical health is separate from operations", `<button class="button" data-route="watchdog">Diagnostics</button>`)}</div></div>`;
  }

  const scheduleRows = [
    ["AM1", "10:00 AM–3:00 PM", "am"], ["AM2", "11:00 AM–4:00 PM", "am"], ["AM3", "11:30 AM–4:30 PM", "am"], ["AM4", "12:00 PM–5:00 PM", "am"],
    ["PM1", "3:00 PM–7:30 PM", "pm"], ["PM2", "4:00 PM–8:30 PM", "pm"], ["PM3", "5:00 PM–9:00 PM", "pm"],
    ["FH1", "4:00 PM–8:30 PM", "floor"], ["FH2", "5:00 PM–9:00 PM", "floor"], ["FH3", "5:30 PM–9:30 PM", "floor"], ["FH4", "6:00 PM–10:00 PM", "floor"],
  ];

  function scheduleEntries(payload) {
    const schedule = payload.schedule || firstArray(payload, ["schedules"])[0] || {};
    return { schedule, entries: arr(schedule.entries || payload.entries) };
  }

  function renderSchedule(data) {
    const schedules = firstArray(data.results[0]?.value, ["schedules"]);
    const draft = schedules.find((item) => item.status === "draft") || null;
    const published = schedules.filter((item) => item.status === "published").sort((a, b) => Number(b.version_number || 0) - Number(a.version_number || 0))[0] || null;
    if (state.scheduleView === "published" && !published && draft) state.scheduleView = "draft";
    if (state.scheduleView === "draft" && !draft && published) state.scheduleView = "published";
    const schedule = state.scheduleView === "draft" ? draft || {} : published || {};
    const entries = arr(schedule.entries);
    const employees = firstArray(data.results[1]?.value, ["employees"]);
    const availabilityRows = firstArray(data.results[3]?.value, ["availability"]);
    const weekParties = firstArray(data.results[4]?.value, ["parties"]);
    const days = dates.scheduleDates(state.weekStart);
    const rows = arr(schedule.rows).filter((row) => state.scheduleType === "host" ? row.role_group === "host" : row.role_group !== "host");
    const dayNumber = (date) => new Date(`${date}T12:00:00Z`).getUTCDay();
    const findEntries = (row, day) => entries.filter((entry) => entry.employee_id && String(entry.row_id) === String(row.id) && Number(entry.day_of_week) === dayNumber(day.date));
    const dailyAssignmentCount = (employeeId, date) => entries.filter((entry) => entry.employee_id && String(entry.employee_id) === String(employeeId) && Number(entry.day_of_week) === dayNumber(date)).length;
    const rowTime = (row) => scheduleRows.find((item) => item[0] === row.label)?.[1] || "Connected shift time";
    const rowBand = (row) => row.role_group === "floor" ? "floor" : /PM/i.test(row.label) ? "pm" : "am";
    const defaultTimes = { AM1:["10:00","15:00"],AM2:["11:00","16:00"],AM3:["11:30","16:30"],AM4:["12:00","17:00"],PM1:["15:00","19:30"],PM2:["16:00","20:30"],PM3:["17:00","21:00"],FH1:["16:00","20:30"],FH2:["17:00","21:00"],FH3:["17:30","21:30"],FH4:["18:00","22:00"],"Host AM1":["11:00","16:00"],"Host PM1":["16:00","21:00"],"Host PM2":["17:00","21:00"] };
    const roleCompatible = (employee, row) => {
      const roles = [employee.role,...arr(employee.secondary_roles)].map((value)=>String(value||"").toLowerCase());
      if (row?.role_group === "host") return roles.some((role)=>/host|manager/.test(role));
      if (row?.role_group === "floor") return roles.some((role)=>/floor|server|wait|manager/.test(role));
      return !roles.length || roles.some((role)=>/main|kitchen|cook|prep|dish|server|wait|manager|employee/.test(role));
    };
    const employeeOptionsForCell = (row, day, assigned) => {
      const period = /PM|FH/i.test(row.label||"") ? "PM" : "AM";
      const dayName = dateLabel(day.date,{weekday:"short"}).slice(0,3).toLowerCase();
      const assignedIds = new Set(assigned.map((entry)=>String(entry.employee_id)));
      const [cellStart,cellEnd] = defaultTimes[row.label] || [null,null];
      return employees.filter((employee) => {
        if (assignedIds.has(String(employee.id))) return true;
        if (employee.active === false || employee.status !== "active" || !roleCompatible(employee,row)) return false;
        if (availabilityRows.some((slot)=>String(slot.employee_id)===String(employee.id)&&String(slot.day).slice(0,3).toLowerCase()===dayName&&String(slot.shift_key).toUpperCase()===period&&slot.status==="off")) return false;
        return !entries.some((entry)=>String(entry.employee_id)===String(employee.id)&&Number(entry.day_of_week)===dayNumber(day.date)&&String(entry.start_time||"")<String(cellEnd||"")&&String(entry.end_time||"")>String(cellStart||""));
      }).sort((a,b)=>String(a.display_name||a.name).localeCompare(String(b.display_name||b.name)));
    };
    const grid = `<div class="schedule-grid"><div class="schedule-cell head">Slot</div>${days.map((day) => `<div class="schedule-cell head"><span>${esc(day.name)}<br><small>${esc(dateLabel(day.date, { month: "short", day: "numeric" }))}</small></span></div>`).join("")}${rows.map((row) => `<div class="schedule-cell slot ${rowBand(row)}"><b>${esc(row.label)}</b><small>${esc(rowTime(row))}</small></div>${days.map((day) => {
      const cellEntries = entries.filter((entry)=>String(entry.row_id)===String(row.id)&&Number(entry.day_of_week)===dayNumber(day.date));
      const closed = cellEntries.some((entry)=>String(entry.notes||"").includes("HOP_SLOT_INACTIVE"));
      const cellKey = `${row.row_key}|${day.date}`;
      const selectedCell = state.selected?.type === "cell" && state.selected.row === row.row_key && state.selected.date === day.date;
      if (closed) return `<div class="schedule-cell shift-cell closed-cell ${selectedCell?"selected":""}" data-cell="${esc(cellKey)}" title="Closed shift · click to inspect"><button class="assignment closed" data-cell="${esc(cellKey)}" aria-label="Closed shift · click to inspect">—</button></div>`;
      const assigned = findEntries(row, day);
      const names = assigned.map((item) => employeeName(item, employees));
      const doubleCount = assigned.reduce((max,item)=>Math.max(max,dailyAssignmentCount(item.employee_id,day.date)),0);
      if (state.scheduleView === "draft" && schedule.id) {
        const options = employeeOptionsForCell(row,day,assigned);
        const activeEntry = assigned[0] || null;
        const timeLabel = activeEntry ? `${formatTime(activeEntry.start_time || defaultTimes[row.label]?.[0])}${activeEntry.end_time ? `–${formatTime(activeEntry.end_time)}` : ""}` : rowTime(row);
        return `<div class="schedule-cell shift-cell inline-assignment ${selectedCell?"selected":""}" data-cell="${esc(cellKey)}"><small class="cell-shift-time">${esc(timeLabel)}</small><div class="cell-picker-wrap"><select class="schedule-cell-picker ${assigned.length?"assigned":"open"}" data-schedule-cell-picker="${esc(cellKey)}" data-entry-id="${esc(activeEntry?.id||"")}" aria-label="Assign ${esc(row.label)} on ${esc(day.name)}"><option value="">Open shift</option>${options.map((employee)=>`<option value="${esc(employee.id)}" ${String(activeEntry?.employee_id)===String(employee.id)?"selected":""}>${esc(employee.display_name||employee.name)}</option>`).join("")}</select>${doubleCount>1?`<span class="assignment-count cell-count" title="Double shift that day">x${doubleCount}</span>`:""}</div><button class="cell-edit-link" data-cell="${esc(cellKey)}">Edit time / close</button></div>`;
      }
      if (!assigned.length) return `<div class="schedule-cell shift-cell inline-assignment published-cell ${selectedCell?"selected":""}" data-cell="${esc(cellKey)}"><small class="cell-shift-time">${esc(rowTime(row))}</small><button class="schedule-cell-picker open readonly-picker" data-cell="${esc(cellKey)}">Open shift</button><span class="cell-edit-link readonly-label">Published · protected</span></div>`;
      const publishedTime=`${assigned[0].start_time?formatTime(assigned[0].start_time):rowTime(row)}${assigned[0].end_time?`–${formatTime(assigned[0].end_time)}`:""}`;
      return `<div class="schedule-cell shift-cell inline-assignment published-cell ${selectedCell?"selected":""}" data-cell="${esc(cellKey)}"><small class="cell-shift-time">${esc(publishedTime)}</small><div class="cell-picker-wrap"><button class="schedule-cell-picker assigned readonly-picker" data-cell="${esc(cellKey)}">${esc(names.join(" + "))}</button>${doubleCount>1?`<span class="assignment-count cell-count" title="Double shift that day">x${doubleCount}</span>`:""}</div><span class="cell-edit-link readonly-label">Published · protected</span></div>`;
    }).join("")}`).join("")}</div>`;
    const selected = state.selected?.type === "cell" ? state.selected : { row: rows[0]?.row_key || "", date: days[0].date };
    const selectedRow = rows.find((row) => row.row_key === selected.row) || rows[0];
    const selectedEntries = selectedRow ? findEntries(selectedRow, { date: selected.date }) : [];
    const selectedCellEntries = selectedRow ? entries.filter((entry)=>String(entry.row_id)===String(selectedRow.id)&&Number(entry.day_of_week)===dayNumber(selected.date)) : [];
    const selectedClosed = selectedCellEntries.some((entry)=>String(entry.notes||"").includes("HOP_SLOT_INACTIVE"));
    const selectedPeriod = /PM|FH/i.test(selectedRow?.label||"") ? "PM" : "AM";
    const selectedDayName = dateLabel(selected.date,{weekday:"short"}).slice(0,3);
    const available = employees.filter((employee) => employee.active !== false && employee.status === "active" && roleCompatible(employee,selectedRow) && !availabilityRows.some((slot)=>String(slot.employee_id)===String(employee.id)&&String(slot.day).slice(0,3).toLowerCase()===selectedDayName.toLowerCase()&&String(slot.shift_key).toUpperCase()===selectedPeriod&&slot.status==="off") && !selectedEntries.some((entry)=>String(entry.employee_id)===String(employee.id)));
    const editEntry = selectedEntries[0] || {};
    const editTimes = [editEntry.start_time || defaultTimes[selectedRow?.label]?.[0] || "", editEntry.end_time || defaultTimes[selectedRow?.label]?.[1] || ""];
    const conflictBox = state.scheduleConflict ? `<div class="schedule-conflict"><b>Conflict found</b><span>${esc(state.scheduleConflict)}</span></div>` : `<div class="schedule-clear"><b>No conflict detected</b><span>The server overlap guard will verify again when saved.</span></div>`;
    const assignedList = selectedEntries.length ? `<div class="compact-list">${selectedEntries.map((entry) => `<div class="compact-row"><span class="initial">${esc(initials(employeeName(entry, employees)))}</span><span class="row-copy"><b>${esc(employeeName(entry, employees))}</b><small>${esc(`${formatTime(entry.start_time)}${entry.end_time ? ` – ${formatTime(entry.end_time)}` : ""}`)}</small></span>${state.scheduleView === "draft" ? `<button class="danger-button" data-schedule-remove="${esc(entry.id)}">Remove</button>` : ""}</div>`).join("")}</div>` : `<div class="control-note">No employee is assigned to this shift.</div>`;
    const inspector = `<section class="card schedule-inspector context-inspector">${inspectorTitle("SHIFT DETAILS", `${selectedRow?.label || "Select a cell"} · ${dateLabel(selected.date, { weekday: "short", month: "short", day: "numeric" })}`, selectedRow ? rowTime(selectedRow) : "", selectedClosed?"closed":rowBand(selectedRow || {}))}<div class="card-body"><div class="detail-section"><h4>Assigned (${selectedEntries.length})</h4>${selectedClosed?`<div class="info-banner warning">This cell is intentionally closed and will not appear as an open shift.</div>`:assignedList}</div>${state.scheduleView === "draft"&&!selectedClosed ? `<div class="shift-editor"><div class="form-control full"><label>Available employee for this role</label><select data-schedule-picker><option value="">Open / unassigned</option>${[...selectedEntries.map((entry)=>employees.find((item)=>String(item.id)===String(entry.employee_id))).filter(Boolean),...available].filter((item,index,list)=>list.findIndex((other)=>String(other.id)===String(item.id))===index).map((employee)=>`<option value="${esc(employee.id)}" ${String(editEntry.employee_id)===String(employee.id)?"selected":""}>${esc(employee.display_name||employee.name)} · ${esc(titleCase(employee.role))}</option>`).join("")}</select></div><div class="shift-time-grid"><div class="form-control"><label>Start</label><input type="time" data-schedule-start value="${esc(String(editTimes[0]).slice(0,5))}"></div><div class="form-control"><label>End</label><input type="time" data-schedule-end value="${esc(String(editTimes[1]).slice(0,5))}"></div></div>${conflictBox}<button class="primary-button" data-action="schedule-save-cell">Save cell</button></div>` : `<div class="control-note">${selectedClosed?"This published cell is closed. Open Draft to reopen or edit it.":"Published cells are selectable for review. Open Draft to make changes."}</div>`}</div><div class="sticky-actions">${state.scheduleView==="draft"?`<button class="${selectedClosed?"button":"danger-button"}" data-action="${selectedClosed?"schedule-open-cell":"schedule-close-cell"}">${selectedClosed?"Reopen cell":"Close cell"}</button>`:""}<button class="danger-button" ${state.scheduleView === "draft" && selectedEntries.length ? "" : "disabled"} data-schedule-remove="${esc(selectedEntries[0]?.id || "")}">Clear assignment</button><button class="button" data-action="schedule-print">Preview / print</button></div></section>`;
    const primaryAction = state.scheduleView === "draft" && draft ? `<button class="primary-button" data-action="schedule-publish">Review & Publish</button>` : published && !draft ? `<button class="primary-button" data-action="schedule-create-revision">Create Revision</button>` : !draft ? `<button class="primary-button" data-action="schedule-new-empty">+ New Empty Draft</button>` : "";
    const views = `<div class="view-switch"><button class="${state.scheduleView === "published" ? "active" : ""}" data-schedule-view="published" ${published ? "" : "disabled"}>Published${published ? ` v${esc(published.version_number || 1)}` : ""}</button><button class="${state.scheduleView === "draft" ? "active" : ""}" data-schedule-view="draft" ${draft ? "" : "disabled"}>Draft${draft ? ` · ${arr(draft.entries).length} shifts` : ""}</button></div>`;
    const draftTools = `<button class="button" data-action="schedule-copy-previous" ${state.scheduleView === "draft" && draft ? "" : "disabled"}>Copy last week</button><button class="button" data-action="schedule-autofill" ${state.scheduleView === "draft" && draft ? "" : "disabled"}>Autofill open cells</button><button class="button" data-action="schedule-export">Wall Board Preview</button>${state.scheduleView === "draft" && draft ? `<button class="danger-button" data-action="schedule-clear">Clear draft</button>` : ""}`;
    const assignedEmployees = new Set(entries.filter((entry) => entry.employee_id).map((entry) => String(entry.employee_id))).size;
    const coverage = `<div class="schedule-ribbon"><span><small>Assignments</small><b>${entries.length}</b></span><span><small>Staff scheduled</small><b>${assignedEmployees}</b></span><span><small>Parties</small><b>${weekParties.length}</b></span><span><small>Morning</small><b>${entries.filter((entry) => { const row=arr(schedule.rows).find((r)=>String(r.id)===String(entry.row_id)); return /am/i.test(row?.label||""); }).length}</b></span><span><small>Evening / floor</small><b>${entries.filter((entry) => { const row=arr(schedule.rows).find((r)=>String(r.id)===String(entry.row_id)); return /pm|fh/i.test(row?.label||""); }).length}</b></span><span class="ribbon-good"><small>Protection</small><b>Overlap guard on</b></span></div>`;
    const partyStrip = weekParties.length ? `<div class="schedule-party-strip"><b>Party staffing</b>${days.map((day)=>{const items=weekParties.filter((party)=>String(party.date||party.party_date).slice(0,10)===day.date);return `<span><small>${esc(day.name.slice(0,3))}</small>${items.length?items.map((party)=>`<button data-route="parties" data-week="${esc(day.date)}"><b>${esc(party.time?formatTime(party.time):"TBD")}</b> ${esc(party.name||"Party")} · ${esc(party.count||"?")} guests</button>`).join(""):`<i>No party</i>`}</span>`}).join("")}</div>` : "";
    return `<div class="page">${pageHead("schedule", `${savedState()}<button class="button" data-action="schedule-print">Print</button><button class="button" data-action="schedule-export">Export / Preview</button>${primaryAction}`)}<div class="schedule-context"><div class="week-picker"><button data-week-move="-7">‹</button><b>${esc(dateLabel(state.weekStart, { month: "long", day: "numeric" }))} – ${esc(dateLabel(dates.addDays(state.weekStart, 5), { month: "short", day: "numeric" }))}</b><button data-week-move="7">›</button></div>${views}<div class="segmented"><button class="${state.scheduleType === "main" ? "active" : ""}" data-schedule-type="main">Main</button><button class="${state.scheduleType === "host" ? "active" : ""}" data-schedule-type="host">Host</button></div>${draftTools}</div>${coverage}${partyStrip}<div class="schedule-with-rail"><aside class="coverage-rail"><span>Coverage</span><b>${entries.length}</b></aside><div class="schedule-shell"><div><div class="schedule-grid-wrap">${grid || empty("No schedule created", "Use New Empty Draft to start this week.", "schedule")}</div><button class="expand-grid" data-action="schedule-expand">↗ &nbsp; Expand grid &nbsp; <small>(Toggle focus mode)</small></button></div>${inspector}</div></div></div>`;
  }

  function enhanceEmployeePanel(employee) {
    const panel = $(".employee-profile-panel");
    if (!panel || !employee) return;
    const reveal = panel.querySelector('[data-action="employee-pin-toggle"]');
    if (reveal) reveal.textContent = "Reveal saved digits";
    const security = reveal?.closest(".detail-section");
    if (security && !security.querySelector(".employee-security-actions")) {
      security.insertAdjacentHTML("beforeend", `<div class="employee-security-actions"><button class="button" data-action="employee-pin-toggle">Reveal saved digits</button><button class="button" data-action="employee-edit" data-id="${esc(employee.id)}">Reset PIN</button></div>`);
    }
  }

  function renderEmployees(data) {
    let employees = firstArray(data.results[0]?.value, ["employees"]);
    const published = data.results[1]?.value?.schedule || {};
    const availability = firstArray(data.results[2]?.value, ["availability"]);
    const query = state.search.toLowerCase();
    if (query) employees = employees.filter((item) => `${item.display_name || item.name} ${item.phone || ""} ${item.pin_last4 || ""}`.toLowerCase().includes(query));
    const selected = employees.find((item) => item.id === state.selected?.id) || employees[0];
    queueMicrotask(() => enhanceEmployeePanel(selected));
    const rows = employees.length ? employees.map((employee) => `<tr class="${selected?.id === employee.id ? "selected" : ""}" data-select-employee="${esc(employee.id)}"><td><div class="cell-person"><span class="initial">${esc(initials(employee.display_name || employee.name))}</span><span><b>${esc(employee.display_name || employee.name)}</b><small>${esc(employee.email || "No email")}</small></span></div></td><td>${pill(employee.role)}</td><td>${arr(employee.secondary_roles).map((role) => pill(role)).join(" ") || "—"}</td><td>${pill(employee.status)}</td><td class="masked">${employee.pin_configured ? `•••• ${esc(employee.pin_last4 || "")}` : "Not set"}</td><td>${esc(employee.phone || "—")}</td><td><button class="ellipsis" data-action="employee-edit" data-id="${esc(employee.id)}" aria-label="Edit ${esc(employee.display_name || employee.name)}">⋯</button></td></tr>`).join("") : `<tr><td colspan="7">${empty("No employees match", "Adjust the search or filters, or add an employee.", "employees")}</td></tr>`;
    const employeeCards = employees.length ? `<div class="employee-card-grid">${employees.map((employee) => `<button class="employee-directory-card ${selected?.id === employee.id ? "selected" : ""}" data-select-employee="${esc(employee.id)}"><span class="initial">${esc(initials(employee.display_name || employee.name))}</span><span class="row-copy"><b>${esc(employee.display_name || employee.name)}</b><small>${esc(titleCase(employee.role))} · ${esc(employee.phone || "No phone")}</small></span>${pill(employee.status)}</button>`).join("")}</div>` : empty("No employees match", "Adjust the search or add an employee.", "employees");
    const selectedShifts = selected ? arr(published.entries).filter((entry) => String(entry.employee_id) === String(selected.id)) : [];
    const shiftRows = selectedShifts.length ? `<div class="compact-list">${selectedShifts.slice(0, 8).map((entry) => { const row = arr(published.rows).find((item) => String(item.id) === String(entry.row_id)); const workedRole = row?.role_group || entry.role || selected.role; return `<div class="compact-row"><span class="date-tile"><b>${esc((["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][Number(entry.day_of_week)] || "Day").slice(0,3))}</b><span>${esc(row?.label || "Shift")}</span></span><span class="row-copy"><b>${esc(workedRole === "host" ? "Hosting" : workedRole === "floor" ? "Floor help" : "Waiting tables")}</b><small>${esc(formatTime(entry.start_time))} – ${esc(formatTime(entry.end_time))}</small></span>${pill(workedRole)}</div>`; }).join("")}</div>` : empty("No published shifts", "This employee has no assignments in the selected published week.", "schedule");
    const availabilityRows = availability.filter((item)=>String(item.employee_id)===String(selected?.id));
    const availabilityPreview = `<div class="employee-availability"><div></div>${["Tue","Wed","Thu","Fri","Sat","Sun"].map((day)=>`<b>${day}</b>`).join("")}<b>AM</b>${["Tue","Wed","Thu","Fri","Sat","Sun"].map((day)=>{const slot=availabilityRows.find((item)=>String(item.day).slice(0,3).toLowerCase()===day.toLowerCase()&&String(item.shift_key).toUpperCase()==="AM");return `<span class="${slot?.status==="off"?"off":slot?"available":"unknown"}">${slot?.status==="off"?"−":slot?"✓":"•"}</span>`}).join("")}<b>PM</b>${["Tue","Wed","Thu","Fri","Sat","Sun"].map((day)=>{const slot=availabilityRows.find((item)=>String(item.day).slice(0,3).toLowerCase()===day.toLowerCase()&&String(item.shift_key).toUpperCase()==="PM");return `<span class="${slot?.status==="off"?"off":slot?"available":"unknown"}">${slot?.status==="off"?"−":slot?"✓":"•"}</span>`}).join("")}</div>`;
    const roleRates = [selected?.role,...arr(selected?.secondary_roles)].filter(Boolean).map((role)=>{const cents=selected?.role_pay_rates?.[role] ?? selected?.pay_rate_cents;return `<span class="detail-item"><span>${esc(titleCase(role))}</span><b>${cents==null?"Not set":`${money(cents)}/h`}</b></span>`}).join("");
    const inspector = selected ? `<section class="card inspector context-inspector employee-profile-panel">${inspectorTitle("EMPLOYEE DETAILS", selected.display_name || selected.name, selected.full_name || selected.email || "Employee record", selected.status)}<div class="card-body"><div class="profile-head employee-profile-head"><span class="initial">${esc(initials(selected.display_name || selected.name))}</span><div><b>${esc(selected.display_name || selected.name)}</b><small>${esc(titleCase(selected.role))} · ${esc(titleCase(selected.employee_type))}</small></div><button class="primary-button" data-action="employee-edit" data-id="${esc(selected.id)}">Edit profile</button></div><div class="employee-contact-band"><span><small>Phone</small><b>${esc(selected.phone || "Not set")}</b></span><span><small>Email</small><b>${esc(selected.email || "Not set")}</b></span></div><div class="detail-section"><h4>Roles & hourly pay</h4><div class="detail-grid">${roleRates || `<span class="detail-item"><span>Pay rate</span><b>Not set</b></span>`}</div></div><div class="detail-section"><h4>Secure account</h4><div class="detail-grid"><span class="detail-item"><span>PIN</span><b class="employee-pin-value" data-pin-last4="${esc(selected.pin_last4 || "")}">${selected.pin_configured ? "••••" : "Not set"}</b>${selected.pin_configured?`<button class="inline-link" data-action="employee-pin-toggle">Show last 4</button>`:""}</span><span class="detail-item"><span>Access</span><b>${esc(selected.status === "active" ? "Employee app enabled" : "Employee app disabled")}</b></span></div></div><div class="detail-section"><h4>Availability <button class="inline-link" data-route="availability">Open full week</button></h4>${availabilityPreview}${miniLegend()}</div><div class="detail-section"><h4>Upcoming published shifts</h4>${shiftRows}</div><div class="detail-section"><h4>Manager notes</h4><p>${esc(selected.notes || selected.manager_notes || "No manager notes recorded.")}</p></div></div><div class="sticky-actions"><button class="button" data-action="employee-edit" data-id="${esc(selected.id)}">Edit employee</button><button class="danger-button" data-action="employee-delete" data-id="${esc(selected.id)}">Delete employee</button></div></section>` : card("Employee Details", empty("Select an employee", "Choose a row to inspect the employee record.", "employees"));
    const directory = state.employeeView === "grid" ? `<section class="card workspace-panel"><div class="table-toolbar"><input class="field table-search" data-local-search placeholder="Search name, phone, or PIN" value="${esc(state.search)}"><span class="table-meta">Staff directory · Published week ${esc(dateLabel(state.weekStart))}</span></div>${employeeCards}</section>` : `<section class="card table-card"><div class="table-toolbar"><input class="field table-search" data-local-search placeholder="Search name, phone, or PIN" value="${esc(state.search)}"><span class="table-meta">Staff directory · Published week ${esc(dateLabel(state.weekStart))}</span></div><table class="data-table"><thead><tr><th>Employee</th><th>Primary role</th><th>Extra role</th><th>Status</th><th>PIN</th><th>Phone</th><th>Actions</th></tr></thead><tbody>${rows}</tbody></table></section>`;
    return `<div class="page">${pageHead("employees", `${savedState("Directory synced")}<button class="button" data-employee-view="${state.employeeView === "grid" ? "table" : "grid"}">${state.employeeView === "grid" ? "Table view" : "Grid view"}</button><button class="primary-button" data-action="employee-new">+ Add Employee</button>`)}${filterToolbar({search:"Search name, phone, or PIN",filters:[{label:"All roles",active:true},{label:"Active"},{label:"All employee types"}],meta:`${employees.length} employees`})}<div class="split-layout">${directory}${inspector}</div></div>`;
  }

  function renderInbox(data) {
    const requests = firstArray(data.results[0]?.value, ["requests", "items", "pending"]);
    const notifications = firstArray(data.results[1]?.value, ["notifications"]);
    const history = firstArray(data.results[2]?.value, ["requests", "items", "history"]);
    const employees = firstArray(data.results[3]?.value, ["employees"]);
    const announcements = notifications.filter((item) => /announcement/i.test(`${item.category || ""} ${item.audience || ""}`));
    const source = state.inboxTab === "pending" ? requests : state.inboxTab === "history" ? history : state.inboxTab === "announcements" ? announcements : notifications;
    const selected = source.find((item) => String(item.id) === String(state.selected?.id)) || source[0];
    const isRequest = state.inboxTab === "pending" || state.inboxTab === "history";
    const requestTypes = requests.reduce((map, item) => { const key = titleCase(item.type || item.request_type || "Other"); map[key] = (map[key] || 0) + 1; return map; }, {});
    const overview = `<section class="card workspace-panel"><div class="card-head"><div><h3>Pending Overview</h3><p>Live request categories</p></div>${pill(requests.length ? `${requests.length} open` : "Clear")}</div><div class="card-body"><div class="master-list">${Object.entries(requestTypes).length ? Object.entries(requestTypes).map(([label,count]) => `<div class="master-row"><span class="initial">${esc(label.slice(0,1))}</span><span class="row-copy"><b>${esc(label)}</b><small>${count === 1 ? "1 request" : `${count} requests`}</small></span>${pill(count)}</div>`).join("") : `<div class="info-banner">No pending request categories need review.</div>`}</div><div class="section-label">Aging</div><div class="info-banner ${requests.length ? "warning" : ""}">${requests.length ? "Review older requests before building the next schedule." : "The manager queue is current."}</div></div></section>`;
    const list = source.length ? source.map((item) => {
      const label = isRequest ? titleCase(item.type || item.request_type) : item.title;
      const detail = isRequest ? `${employeeName(item, employees)} · ${dateLabel(item.date || item.start_date)}` : `${titleCase(item.category)} · ${dateLabel(item.created_at, { hour: "numeric", minute: "2-digit" })}`;
      return `<button class="master-row ${String(selected?.id) === String(item.id) ? "selected" : ""}" data-select-inbox="${esc(item.id)}"><span class="initial">${esc(initials(isRequest ? employeeName(item, employees) : label))}</span><span class="row-copy"><b>${esc(label)}</b><small>${esc(detail)}</small></span>${pill(isRequest ? item.status : (item.read_at || item.read ? "read" : "unread"))}</button>`;
    }).join("") : empty(`No ${state.inboxTab} records`, "Connected records will remain available in the appropriate tab.", "inbox");
    const requestItems = arr(selected?.items);
    const requestConflicts = requestItems.flatMap((item)=>arr(item.conflict_hints)).filter((hint)=>hint&&String(hint)!=="No conflicts found.");
    const itemTimeline = requestItems.length ? `<div class="request-item-timeline">${requestItems.map((item)=>`<div class="compact-row"><span class="date-tile"><b>${esc(dateLabel(item.item_date,{day:"numeric"}))}</b><span>${esc(dateLabel(item.item_date,{month:"short",day:undefined}))}</span></span><span class="row-copy"><b>${esc(dateLabel(item.item_date,{weekday:"long",month:"short",day:"numeric"}))}</b><small>${esc(arr(item.conflict_hints).join(" · ")||"No schedule conflict")}</small></span>${pill(item.status||"pending")}</div>`).join("")}</div>` : `<div class="compact-row"><span class="row-copy"><b>${esc(dateLabel(selected?.date||selected?.start_date))}</b><small>${esc(selected?.conflict_hint||"No returned schedule conflict")}</small></span>${pill(selected?.status||"pending")}</div>`;
    const inspector = selected ? isRequest ? `<section class="card context-inspector">${inspectorTitle("REQUEST DETAILS", employeeName(selected, employees), titleCase(selected.type || selected.request_type), selected.status || "pending")}<div class="card-body"><div class="request-hero"><span class="initial">${esc(initials(employeeName(selected,employees)))}</span><div><b>${esc(employeeName(selected,employees))}</b><small>Submitted ${esc(dateLabel(selected.created_at,{hour:"numeric",minute:"2-digit"}))}</small></div></div><div class="detail-section"><h4>Employee note</h4><p>${esc(selected.note || selected.message || "No employee note was included.")}</p></div><div class="detail-section"><h4>Affected dates & schedule impact</h4>${itemTimeline}</div>${requestConflicts.length?`<div class="info-banner warning"><b>${requestConflicts.length} conflict${requestConflicts.length===1?"":"s"} need manager review.</b><br>${esc([...new Set(requestConflicts)].join(" · "))}</div>`:`<div class="info-banner">No schedule conflict was returned for this request.</div>`}<div class="detail-section"><h4>Decision</h4><div class="detail-grid"><span class="detail-item"><span>Reviewed by</span><b>${esc(selected.reviewed_by_name||selected.manager_name||"Not decided")}</b></span><span class="detail-item"><span>Reviewed</span><b>${esc(selected.reviewed_at?dateLabel(selected.reviewed_at,{hour:"numeric",minute:"2-digit"}):"Pending")}</b></span></div><p>${esc(selected.manager_note||"No manager note recorded.")}</p></div></div><div class="sticky-actions"><button class="${state.inboxTab === "pending" ? "primary-button" : "button"}" data-action="request-open" data-id="${esc(selected.id)}" data-source="${state.inboxTab === "pending" ? "pending" : "history"}">${state.inboxTab === "pending" ? "Review & decide" : "View full decision"}</button></div></section>` : `<section class="card context-inspector">${inspectorTitle("NOTIFICATION DETAILS", selected.title || "Manager alert", titleCase(selected.category), selected.read_at || selected.read ? "read" : "unread")}<div class="card-body"><p>${esc(selected.message || "No notification detail returned.")}</p><div class="detail-section"><h4>Delivery</h4><div class="detail-grid"><span class="detail-item"><span>Audience</span><b>${esc(titleCase(selected.audience || "manager"))}</b></span><span class="detail-item"><span>Created</span><b>${esc(dateLabel(selected.created_at, { hour: "numeric", minute: "2-digit" }))}</b></span><span class="detail-item"><span>Source</span><b>${esc(titleCase(selected.related_type||selected.source_module||"System"))}</b></span><span class="detail-item"><span>State</span><b>${esc(selected.read_at||selected.read?"Read":"Unread")}</b></span></div></div></div><div class="sticky-actions"><button class="primary-button" data-action="notification-open" data-id="${esc(selected.id)}">Mark / review notification</button></div></section>` : card("Details", empty("Select a record", "Choose a request or notification to inspect.", "inbox"));
    const tabs = tabBar([["pending","Pending",requests.length],["notifications","Notifications",notifications.length],["announcements","Announcements",announcements.length],["history","History",history.length]], state.inboxTab, "inbox-tab");
    return `<div class="page">${pageHead("inbox", `${savedState("Queue synced")}<button class="primary-button" data-action="notification-new">+ New announcement</button>`)}${tabs}${filterToolbar({ search: "Search employee or request", filters: [{label:"All types",active:true},{label:"Day Off"},{label:"Availability"},{label:"Shift Switch"}], meta:`${source.length} records` })}<div class="workspace-three inbox-workspace">${overview}<section class="card workspace-panel"><div class="card-head"><div><h3>${esc(titleCase(state.inboxTab))}</h3><p>Newest connected activity first</p></div></div>${list}</section>${inspector}</div></div>`;
  }

  function renderApplications(data) {
    const apps = firstArray(data.results[0]?.value, ["applications"]);
    const stages = ["new","reviewing","interview","hired","closed"];
    const stageCounts = stages.map((stage) => [stage, titleCase(stage), apps.filter((item) => stage === "closed" ? /closed|rejected|archived/i.test(item.status) : String(item.status || "new").toLowerCase() === stage).length]);
    const visibleApps = state.applicationsTab === "all" ? apps : apps.filter((item) => state.applicationsTab === "closed" ? /closed|rejected|archived/i.test(item.status) : String(item.status || "new").toLowerCase() === state.applicationsTab);
    const selectedSummary = visibleApps.find((item) => String(item.id) === String(state.selected?.id)) || visibleApps[0];
    const selected = String(state.applicationDetail?.id) === String(selectedSummary?.id) ? state.applicationDetail : selectedSummary;
    const rows = visibleApps.length ? visibleApps.map((item) => `<button class="master-row ${String(selected?.id) === String(item.id) ? "selected" : ""}" data-select-application="${esc(item.id)}"><span class="initial">${esc(initials(item.full_name || item.name || "Applicant"))}</span><span class="row-copy"><b>${esc(item.full_name || item.name || "Applicant")}</b><small>${esc(arr(item.positions_applied_for).map(titleCase).join(", ") || item.position || item.role || "Position not specified")} · Applied ${esc(dateLabel(item.created_at || item.applied_at))}</small></span>${pill(item.status || "new")}</button>`).join("") : empty("No applicants in this stage", "Choose another stage or wait for connected applications.", "applications");
    const positions = arr(selected?.positions_applied_for).map(titleCase).join(", ") || selected?.position || selected?.role || "Not specified";
    const availableDays = selected?.available_days || {};
    const availableShifts = selected?.available_shifts || {};
    const availabilitySummary = `<div class="app-availability"><div></div>${["Tue","Wed","Thu","Fri","Sat","Sun"].map((day)=>`<b>${day}</b>`).join("")}<b>AM</b>${["tuesday","wednesday","thursday","friday","saturday","sunday"].map((day)=>`<span class="${availableDays[day]===false||availableShifts[`${day}_am`]===false?"partial":"available"}"></span>`).join("")}<b>PM</b>${["tuesday","wednesday","thursday","friday","saturday","sunday"].map((day)=>`<span class="${availableDays[day]===false||availableShifts[`${day}_pm`]===false?"partial":"available"}"></span>`).join("")}</div>`;
    const inspector = selected ? `<section class="card application-detail">${inspectorTitle("APPLICANT REVIEW", selected.full_name || selected.name || "Applicant", `Applied for ${positions}`, selected.status || "new")}<div class="applicant-contact-bar"><span><small>Submitted</small><b>${esc(dateLabel(selected.created_at,{month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}))}</b></span><span><small>Phone</small><b>${esc(selected.phone||"Not set")}</b></span><span><small>Email</small><b>${esc(selected.email||"Not set")}</b></span></div><div class="inspector-tabs"><button class="active">Overview</button><button>Availability</button><button>Documents</button><button>Manager Notes</button><button>Activity</button></div><div class="application-detail-grid"><div class="card-body"><div class="detail-section"><h4>1. Contact information</h4><div class="detail-grid"><span class="detail-item"><span>Phone</span><b>${esc(selected.phone||"Not set")}</b></span><span class="detail-item"><span>Email</span><b>${esc(selected.email||"Not set")}</b></span></div></div><div class="detail-section"><h4>2. Position & experience</h4><div class="detail-grid"><span class="detail-item"><span>Applied position</span><b>${esc(positions)}</b></span><span class="detail-item"><span>Restaurant experience</span><b>${selected.restaurant_experience?"Yes":"No / not stated"}</b></span><span class="detail-item"><span>Experience notes</span><b>${esc(selected.experience_notes||"Not provided")}</b></span><span class="detail-item"><span>Earliest start</span><b>${esc(dateLabel(selected.start_date))}</b></span></div></div><div class="detail-section"><h4>3. Work eligibility</h4><div class="detail-grid"><span class="detail-item"><span>Over 16</span><b>${selected.is_over_16===false?"No":"Yes / confirmed"}</b></span><span class="detail-item"><span>Transportation</span><b>${esc(selected.transportation||"Not stated")}</b></span><span class="detail-item"><span>Weekend availability</span><b>${selected.weekend_available?"Available":"Limited / not stated"}</b></span></div></div><div class="detail-section"><h4>4. Additional information</h4><p>${esc(selected.applicant_notes||"No additional applicant note was submitted.")}</p></div></div><aside class="application-side"><section><h4>Availability summary</h4>${availabilitySummary}<button class="inline-link" data-action="application-open" data-id="${esc(selected.id)}">Open connected application ↗</button></section><section><h4>Documents</h4><div class="info-banner">${selected.resume_url||selected.resume_path?"1 applicant document is attached.":"No applicant documents were returned."}</div></section><section><h4>Manager Notes</h4><textarea disabled>${esc(selected.manager_notes||"")}</textarea><small>Open the application editor to update manager-only notes.</small></section></aside></div><div class="sticky-actions application-actions"><button class="button" data-action="application-open" data-id="${esc(selected.id)}">Preview Application Sheet</button><button class="button" data-action="schedule-print">Print / Save As</button><button class="button" data-action="application-open" data-id="${esc(selected.id)}">Move to Interview</button><button class="primary-button" data-action="application-convert" data-id="${esc(selected.id)}" ${selected.converted_employee_id?"disabled":""}>Convert to Employee</button></div><div class="info-banner">Conversion reuses applicant name, contact, position, and availability. Duplicate employee records are prevented.</div></section>` : card("Applicant profile", empty("Select an applicant", "Choose an applicant to review.", "applications"));
    return `<div class="page">${pageHead("applications", `<span class="save-state"><span class="status-dot"></span>Public /jobs/ connected</span><button class="button" data-action="jobs-open">Application Link & QR</button>`)}${filterToolbar({search:"Search applicants",filters:[{label:"All positions",active:true},{label:"All stages"},{label:"Availability"},{label:"Newest first"}],meta:`${apps.length} total applicants`})}${tabBar([["all","All",apps.length],...stageCounts], state.applicationsTab, "applications-tab")}<div class="applications-workspace"><section class="card workspace-panel application-list"><div class="card-head"><div><h3>Applicants</h3><p>Applied date, availability, documents, and stage</p></div></div>${rows}<div class="list-footer">Showing ${visibleApps.length} of ${apps.length} · 1&nbsp; 2&nbsp; 3&nbsp; ›</div>${miniLegend()}</section>${inspector}</div></div>`;
  }

  function renderWebsite(data) {
    const content=data.results[0]?.value||{},home=content.home||{},hero=home.hero||{},identity=content.identity||{},footer=content.footer||{};
    const media=firstArray(data.results[1]?.value,["media"]),heroImage=mediaUrl(hero.image||hero.image_url),headline=[hero.headlineBefore,hero.highlight,hero.headlineAfter].filter(Boolean).join(" ")||"Fresh pizza, pasta, dine in, carry out.";
    const pages=[["home","Home","Live"],["menu","Menu","Live"],["catering","Catering","Live"],["about","About","Live"],["jobs","Jobs","Connected"],["contact","Contact","Live"]];
    const pageTree=`<section class="card editor-list website-tree"><div class="card-head"><div><h3>Website pages</h3><p>Public pages sharing one live identity</p></div></div><div class="card-body">${pages.map(([id,name,status])=>`<button class="editor-item ${state.websitePage===id&&state.websiteTab==="content"?"active":""}" data-website-page="${id}"><span>${esc(name)}</span>${pill(status)}</button>`).join("")}<div class="section-label">Shared site</div><button class="editor-item ${state.websiteTab==="navigation"?"active":""}" data-website-tab="navigation"><span>Navigation & footer</span><span>›</span></button><button class="editor-item ${state.websiteTab==="business"?"active":""}" data-website-tab="business"><span>Business information</span><span>›</span></button><div class="info-banner">Pages stay separate while reusing the same menu, restaurant identity, header, and footer.</div></div></section>`;
    const imageOptions=media.map((item)=>`<option value="${esc(item.url||item.path)}" ${String(hero.image||"")===String(item.url||item.path)?"selected":""}>${esc(item.name)}</option>`).join("");
    const features=arr(home.features).slice(0,3);
    const homeEditor=`<div class="inspector-tabs"><button class="active">Hero</button><button>Feature Cards</button><button>Popular Picks</button><button>Catering</button></div><div class="card-body website-editor-body"><div class="info-banner">This is the real connected homepage structure—not a second copy.</div><div class="section-label">Hero content</div><div class="form-grid"><div class="form-control full"><label>Eyebrow / label</label><input name="hero_eyebrow" value="${esc(hero.eyebrow||"")}"></div><div class="form-control"><label>Headline before highlight</label><input name="hero_before" value="${esc(hero.headlineBefore||"")}"></div><div class="form-control"><label>Highlighted words</label><input name="hero_highlight" value="${esc(hero.highlight||"")}"></div><div class="form-control full"><label>Headline ending</label><input name="hero_after" value="${esc(hero.headlineAfter||"")}"></div><div class="form-control full"><label>Supporting text</label><textarea name="hero_description">${esc(hero.description||"")}</textarea></div><div class="form-control"><label>Primary button</label><input name="hero_primary_text" value="${esc(hero.primaryCta?.text||"")}"></div><div class="form-control"><label>Primary link</label><input name="hero_primary_link" value="${esc(hero.primaryCta?.link||"")}"></div><div class="form-control"><label>Secondary button</label><input name="hero_secondary_text" value="${esc(hero.secondaryCta?.text||"")}"></div><div class="form-control"><label>Secondary link</label><input name="hero_secondary_link" value="${esc(hero.secondaryCta?.link||"")}"></div></div><div class="section-label">Hero image</div><div class="website-media-manager"><div class="media-thumbnail" data-website-image-preview>${heroImage?`<img src="${esc(heroImage)}" alt="Homepage hero">`:`<span>No hero image</span>`}</div><div class="form-control"><label>Existing image library (${media.length})</label><select name="website_image_url" data-website-image-select><option value="">Current / no change</option>${imageOptions}</select><small>Recommended 1920 × 1080 · JPG, PNG, or WebP</small></div><div class="form-control"><label>Upload from this computer</label><input name="website_image" type="file" accept="image/jpeg,image/png,image/webp"></div></div><div class="section-label">Feature cards</div><div class="feature-editor-grid">${features.map((item,index)=>`<section><b>Card ${index+1}</b><input name="feature_${index}_title" value="${esc(item.title||"")}" aria-label="Feature ${index+1} title"><input name="feature_${index}_subtitle" value="${esc(item.subtitle||"")}" aria-label="Feature ${index+1} subtitle"></section>`).join("")}</div><div class="section-label">Popular picks</div><div class="website-picks">${arr(home.featuredItems).slice(0,4).map((item)=>`<span>${item.image?`<img src="${esc(mediaUrl(item.image))}" alt="">`:""}<b>${esc(item.name)}</b><small>${esc(item.price||"")}</small></span>`).join("")}</div></div>`;
    const pageData=state.websitePage==="menu"?content.menuPage?.hero:state.websitePage==="catering"?content.catering?.hero:state.websitePage==="about"?content.story:state.websitePage==="jobs"?content.jobs:identity;
    const pageTitle=pages.find(([id])=>id===state.websitePage)?.[1]||"Page";
    const secondaryEditor=`<div class="card-body website-editor-body"><div class="info-banner">Editing ${esc(pageTitle)} public content.</div><div class="form-grid"><div class="form-control full"><label>Page title</label><input name="page_title" value="${esc(pageData?.title||pageData?.heroTitle||identity.restaurantName||"")}"></div><div class="form-control full"><label>Eyebrow</label><input name="page_eyebrow" value="${esc(pageData?.eyebrow||"")}"></div><div class="form-control full"><label>Description</label><textarea name="page_description">${esc(pageData?.description||pageData?.heroSubtitle||identity.footerDescription||"")}</textarea></div></div></div>`;
    const navigationEditor=`<div class="card-body website-editor-body"><div class="info-banner">One navigation and footer serve every public page.</div><div class="form-control full"><label>Quick links · one per line as Label | URL</label><textarea name="quick_links" rows="10">${esc(arr(footer.quickLinks).map((item)=>`${item.label} | ${item.url}`).join("\n"))}</textarea></div><div class="form-control full"><label>Footer newsletter title</label><input name="newsletter_title" value="${esc(footer.newsletterTitle||"")}"></div><div class="form-control full"><label>Footer newsletter text</label><textarea name="newsletter_text">${esc(footer.newsletterText||"")}</textarea></div></div>`;
    const businessEditor=`<div class="card-body website-editor-body"><div class="form-grid"><div class="form-control full"><label>Restaurant name</label><input name="business_name" value="${esc(identity.restaurantName||"")}"></div><div class="form-control"><label>Phone</label><input name="business_phone" value="${esc(identity.phone||"")}"></div><div class="form-control"><label>Email</label><input name="business_email" value="${esc(identity.email||"")}"></div><div class="form-control full"><label>Street address</label><input name="business_address1" value="${esc(identity.addressLine1||"")}"></div><div class="form-control full"><label>City / state / ZIP</label><input name="business_address2" value="${esc(identity.addressLine2||"")}"></div><div class="form-control full"><label>Public description</label><textarea name="business_description">${esc(identity.footerDescription||"")}</textarea></div><div class="form-control full"><label>Hours · one line per day</label><textarea name="business_hours" rows="8">${esc(arr(footer.hours).join("\n"))}</textarea></div></div></div>`;
    const editorBody=state.websiteTab==="navigation"?navigationEditor:state.websiteTab==="business"?businessEditor:state.websitePage==="home"?homeEditor:secondaryEditor;
    const editor=`<section class="card workspace-panel website-main-editor"><div class="card-head"><div><h3>${state.websiteTab==="content"?`${esc(pageTitle)} page`:state.websiteTab==="navigation"?"Navigation & footer":"Business information"}</h3><p>Connected public-site content</p></div>${savedState()}</div>${editorBody}<div class="sticky-actions"><button class="button" data-refresh>Revert</button><button class="primary-button" data-action="website-save">Save changes</button></div></section>`;
    const previewFeatures=features.map((item)=>`<span><b>${esc(item.title)}</b><small>${esc(item.subtitle)}</small></span>`).join("");
    const preview=`<section class="card context-inspector website-preview-panel"><div class="card-head"><div><h3>Live preview</h3><p>Responsive composition from connected data</p></div>${pill("Live")}</div><div class="inspector-tabs"><button class="active">Desktop</button><button>Tablet</button><button>Mobile</button></div><div class="card-body"><div class="preview-browser"><div class="preview-browser-bar"><i></i><i></i><i></i><span>houseofpizzagaffney.com</span></div><div class="website-preview-nav"><img src="./assets/official-hop-logo.png" alt=""><span>Home</span><span>Menu</span><span>Catering</span><span>About</span><span>Jobs</span><span>Contact</span></div><div class="preview-hero website-rich-hero" ${heroImage?`style="background-image:linear-gradient(90deg,rgba(8,22,18,.82),rgba(8,22,18,.24)),url('${esc(heroImage)}')"`:""}><span class="eyebrow" data-preview-eyebrow>${esc(hero.eyebrow||"HOUSE OF PIZZA & PASTA")}</span><h3 data-preview-headline>${esc(headline)}</h3><p data-preview-description>${esc(hero.description||"")}</p><div><button class="primary-button" data-preview-primary>${esc(hero.primaryCta?.text||"View Menu")}</button><span class="button preview-button">${esc(hero.secondaryCta?.text||"Call or Visit")}</span></div></div><div class="preview-cards rich">${previewFeatures}</div><div class="website-preview-picks"><h4>Popular Picks</h4>${arr(home.featuredItems).slice(0,3).map((item)=>`<span>${item.image?`<img src="${esc(mediaUrl(item.image))}" alt="">`:""}<b>${esc(item.name)}</b></span>`).join("")}</div></div></div><div class="sticky-actions"><button class="button" data-action="website-preview">Open live site</button></div></section>`;
    return `<div class="page" id="websitePage">${pageHead("website", `<span class="save-state"><span class="status-dot"></span>houseofpizzagaffney.com · Live</span>${savedState()}<button class="button" data-action="website-preview">Open live site</button><button class="primary-button" data-action="website-save">Save changes</button>`)}${tabBar([["content","Page content"],["navigation","Navigation"],["business","Business info"]],state.websiteTab,"website-tab")}<div class="editor-layout website-layout">${pageTree}${editor}${preview}</div></div>`;
  }

  function renderSimpleTable(route, items, columns, actions = "") {
    const rows = items.length ? items.map((item) => `<tr>${columns.map((column) => `<td>${column.render ? column.render(item) : esc(item[column.key] ?? "—")}</td>`).join("")}</tr>`).join("") : `<tr><td colspan="${columns.length}">${empty(`No ${modules.find((module) => module.id === route).label.toLowerCase()} records`, "Nothing connected matches the current view.", route)}</td></tr>`;
    return `<div class="page">${pageHead(route, actions)}<section class="card table-card"><div class="table-toolbar"><input class="field table-search" placeholder="Search this module"><span class="table-meta">${items.length} connected record${items.length === 1 ? "" : "s"}</span></div><table class="data-table"><thead><tr>${columns.map((column) => `<th>${esc(column.label)}</th>`).join("")}</tr></thead><tbody>${rows}</tbody></table></section></div>`;
  }

  function renderMenu(data) {
    const payload = data.results[0]?.value || {};
    const items = firstArray(payload, ["items", "menu_items"]);
    const categories = [...new Set(items.map((item) => item.category_name || item.category).filter(Boolean))];
    const visibleItems = state.menuCategory === "all" ? items : items.filter((item) => String(item.category_name || item.category || "").toLowerCase() === state.menuCategory);
    const selected = visibleItems.find((item) => String(item.id) === String(state.selected?.id)) || visibleItems[0];
    const itemImage = (item) => mediaUrl(item?.image_url || item?.image || item?.photo_url);
    const sizeOptions = (entry) => {
      const source = entry?.size_prices || entry?.sizes || entry?.price_options || entry?.variations;
      if (Array.isArray(source)) return source;
      if (source && typeof source === "object") return Object.entries(source).map(([name,price])=>({name,price,price_cents:Math.round(Number(price||0)*100)}));
      return [];
    };
    const sizes = sizeOptions(selected);
    const rows = visibleItems.length ? visibleItems.map((item) => `<button class="master-row ${String(selected?.id) === String(item.id) ? "selected" : ""}" data-select-menu="${esc(item.id)}">${itemImage(item) ? `<img class="menu-thumb" src="${esc(itemImage(item))}" alt="">` : `<span class="initial">${esc(String(item.name || "M").slice(0,1))}</span>`}<span class="row-copy"><b>${esc(item.name || "Menu item")}</b><small>${esc(item.category_name || item.category || "Uncategorized")} · ${esc(item.kitchen_route || item.station || "No kitchen route")}</small></span><b>${money(item.price_cents ?? Math.round(Number(item.price || 0) * 100))}</b>${pill(item.active === false ? "inactive" : "active")}</button>`).join("") : empty("No items in this category", "Choose another connected menu category.", "menu");
    const menuTable = visibleItems.length ? `<div class="menu-table-wrap"><table class="data-table"><thead><tr><th>Item</th><th>Category</th><th>Sizes / price</th><th>Website</th><th>Status</th><th>Route</th><th></th></tr></thead><tbody>${visibleItems.map((item)=>{const itemSizes=sizeOptions(item);return `<tr class="${String(selected?.id)===String(item.id)?"selected":""}" data-select-menu="${esc(item.id)}"><td><div class="cell-person">${itemImage(item)?`<img class="menu-thumb" src="${esc(itemImage(item))}" alt="${esc(item.name||"")}">`:`<span class="menu-thumb">${esc(String(item.name||"M").slice(0,1))}</span>`}<span><b>${esc(item.name||"Menu item")}</b><small>${esc(item.description||"No description")}</small></span></div></td><td>${esc(item.category_name||item.category||"—")}</td><td><b>${itemSizes.length?esc(itemSizes.map((size)=>`${size.name||size.label}: ${money(size.price_cents??Math.round(Number(size.price||0)*100))}`).join(" · ")):money(item.price_cents??Math.round(Number(item.price||0)*100))}</b></td><td>${pill(item.website_visible===false?"hidden":"visible")}</td><td>${pill(item.active===false?"inactive":"active")}</td><td>${esc(item.kitchen_route||item.station||"Not set")} · ${esc(item.kitchen_copies||1)}×</td><td><button class="ellipsis" data-action="menu-open" data-id="${esc(item.id)}">•••</button></td></tr>`}).join("")}</tbody></table><div class="list-footer">Showing ${visibleItems.length} of ${items.length} · connected menu records</div></div>` : rows;
    const inspector = selected ? `<section class="card context-inspector">${inspectorTitle("MENU ITEM", selected.name || "Menu item", selected.category_name || selected.category || "Uncategorized", selected.active === false ? "inactive" : "active")}<div class="inspector-tabs"><button class="active">Details</button><button>Sizes & Prices</button><button>Modifiers</button><button>Display</button><button>Kitchen</button></div><div class="card-body"><div class="form-grid"><div class="form-control full"><label>Item name</label><input value="${esc(selected.name || "")}" disabled></div><div class="form-control full"><label>Description</label><textarea disabled>${esc(selected.description || "")}</textarea></div></div><div class="detail-section"><h4>Sizes & prices</h4>${sizes.length ? sizes.map((size) => `<div class="compact-row"><span class="row-copy"><b>${esc(size.name || size.label || "Size")}</b><small>Connected price option</small></span><b>${money(size.price_cents ?? Math.round(Number(size.price || 0) * 100))}</b></div>`).join("") : `<div class="compact-row"><span class="row-copy"><b>Base price</b><small>Single-price item</small></span><b>${money(selected.price_cents ?? Math.round(Number(selected.price || 0) * 100))}</b></div>`}</div><div class="detail-section"><h4>Visibility & ordering</h4><div class="detail-grid"><span class="detail-item"><span>Website</span><b>${selected.website_visible === false ? "Hidden" : "Visible"}</b></span><span class="detail-item"><span>Most ordered</span><b>${selected.featured ? "Featured" : "Standard"}</b></span><span class="detail-item"><span>Kitchen route</span><b>${esc(selected.kitchen_route || selected.station || "Not set")}</b></span><span class="detail-item"><span>Ticket copies</span><b>${esc(selected.kitchen_copies || 1)}</b></span></div></div><div class="info-banner">Modifiers, public visibility, and ticket routing remain connected to this item—not a duplicate menu.</div></div><div class="sticky-actions"><button class="button" data-action="menu-open" data-id="${esc(selected.id)}">Edit item</button><button class="primary-button" data-action="menu-open" data-id="${esc(selected.id)}">Open full editor</button></div></section>` : card("Item editor", empty("Select a menu item", "Choose an item to inspect details and routing.", "menu"));
    return `<div class="page">${pageHead("menu", `<button class="button" data-action="website-preview">Public menu</button>${savedState("Menu synced")}<button class="primary-button" data-action="menu-new">+ Add item</button>`)}${tabBar([["all","All items",items.length],...categories.slice(0,7).map((name) => [String(name).toLowerCase(),name,items.filter((item) => (item.category_name || item.category) === name).length])], state.menuCategory, "menu-category")}${filterToolbar({search:"Search item, category, or kitchen route",filters:[{label:"Active",active:true},{label:"Website visible"},{label:"Most ordered"}],meta:`${items.length} items`})}<div class="workspace-two menu-workspace"><section class="card workspace-panel"><div class="card-head"><div><h3>Menu items</h3><p>Image, sizes, price, website visibility, status, and ticket routing</p></div></div>${menuTable}</section>${inspector}</div></div>`;
  }

  function renderAvailability(data) {
    const submissions = firstArray(data.results[0]?.value, ["submissions", "availability", "entries"]);
    const employees = firstArray(data.results[1]?.value, ["employees"]);
    const schedules = firstArray(data.results[2]?.value,["schedules"]);
    const teamSchedule = schedules.find((item)=>item.status==="published") || schedules.find((item)=>item.status==="draft") || {};
    const weekTeamIds = new Set(arr(teamSchedule.entries).filter((entry)=>entry.employee_id).map((entry)=>String(entry.employee_id)));
    const scopeEmployees = state.availabilityScope === "team" ? employees.filter((employee)=>weekTeamIds.has(String(employee.id))) : employees;
    const selectedEmployee = scopeEmployees.find((item)=>String(item.id)===String(state.selected?.id)) || scopeEmployees[0];
    const selectedRows = submissions.filter((item)=>String(item.employee_id)===String(selectedEmployee?.id));
    const days = dates.scheduleDates(state.weekStart);
    const employeeList = scopeEmployees.length ? scopeEmployees.map((employee) => {
      const records = submissions.filter((item) => String(item.employee_id) === String(employee.id));
      return `<button class="master-row ${String(selectedEmployee?.id)===String(employee.id)?"selected":""}" data-select-availability="${esc(employee.id)}"><span class="initial">${esc(initials(employee.display_name || employee.name))}</span><span class="row-copy"><b>${esc(employee.display_name || employee.name)}</b><small>${esc(titleCase(employee.role))} · ${records.length ? `${records.length}/12 slots saved` : "Default availability"}</small></span>${pill(records.some((row)=>row.status==="off")?"custom":"available")}</button>`;
    }).join("") : empty("No active employees", "Active employee records appear here.", "availability");
    const matrixRows = scopeEmployees.map((employee) => {
      const records = submissions.filter((item) => String(item.employee_id) === String(employee.id));
      return `<div class="employee-cell">${esc(employee.display_name || employee.name)}</div>${days.map((day) => ["AM","PM"].map((period) => {
        const record = records.find((row)=>String(row.day).slice(0,3).toLowerCase()===String(day.name).slice(0,3).toLowerCase()&&String(row.shift_key).toUpperCase()===period);
        const status = record?.status || "available";
        return `<button class="availability-cell ${record ? (status === "off" ? "off" : "available") : "unknown"}" data-availability-toggle="${esc(employee.id)}|${esc(day.name)}|${period}" title="One click: ${esc(day.name)} ${period} is ${esc(status)}">${status === "off" ? "OFF" : record ? "AVAILABLE" : "DEFAULT"}</button>`;
      }).join("")).join("")}`;
    }).join("");
    const matrix = `<section class="card workspace-panel"><div class="card-head"><div><h3>${state.availabilityScope==="team"?"Scheduled week team":"All employees"}</h3><p>AM / PM availability at a glance · ${scopeEmployees.length} visible</p></div>${savedState("Source synced")}</div><div style="overflow:auto"><div class="availability-grid"><div class="grid-head">Employee</div>${days.map((day) => `<div class="grid-head" style="grid-column:span 2">${esc(day.name)} ${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</div>`).join("")}<div class="grid-head"></div>${days.map(() => `<div class="grid-head">AM</div><div class="grid-head">PM</div>`).join("")}${matrixRows}</div></div><div class="card-body">${miniLegend()}</div></section>`;
    const slotList = selectedEmployee ? days.map((day)=>`<div class="availability-quick-row"><b>${esc(day.name.slice(0,3))}<small>${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</small></b>${["AM","PM"].map((period)=>{const record=selectedRows.find((row)=>String(row.day).slice(0,3).toLowerCase()===String(day.name).slice(0,3).toLowerCase()&&String(row.shift_key).toUpperCase()===period);const status=record?.status||"available";return `<button class="availability-cell ${status==="off"?"off":"available"}" data-availability-toggle="${esc(selectedEmployee.id)}|${esc(day.name)}|${period}">${period}<small>${status==="off"?"OFF":"AVAILABLE"}</small></button>`}).join("")}</div>`).join("") : "";
    const inspector = selectedEmployee ? `<section class="card context-inspector">${inspectorTitle("QUICK AVAILABILITY", selectedEmployee.display_name||selectedEmployee.name, `Week of ${dateLabel(state.weekStart)}`, selectedRows.length?"custom":"default")}<div class="card-body"><div class="info-banner">Tap a green or red cell once to switch Available ↔ Off. Locked employee weeks ask for an explicit manager unlock.</div><div class="availability-quick-grid">${slotList}</div></div><div class="sticky-actions"><button class="primary-button" data-action="availability-open" data-id="${esc(selectedEmployee.id)}">Detailed edit</button></div></section>` : card("Availability inspector", empty("Select an employee", "Choose a team member to inspect their submission.", "availability"));
    return `<div class="page">${pageHead("availability", `<div class="week-picker"><button data-week-move="-7">‹</button><b>${esc(dateLabel(state.weekStart))}</b><button data-week-move="7">›</button></div><button class="button" data-route="schedule">Open Schedule</button>`)}<div class="info-banner" style="margin-bottom:9px">Availability shown here is connected to employee submissions and protected locked weeks.</div>${filterToolbar({search:"Find employee",filters:[{label:"All employees",active:state.availabilityScope==="all",attr:'data-availability-scope="all"'},{label:`Week team (${weekTeamIds.size})`,active:state.availabilityScope==="team",attr:'data-availability-scope="team"'}],meta:`${scopeEmployees.length} shown · ${new Set(submissions.map((row)=>row.employee_id)).size}/${employees.length} customized`})}<div class="workspace-three"><section class="card workspace-panel"><div class="card-head"><div><h3>${state.availabilityScope==="team"?"Week team":"Employees"}</h3><p>Availability state</p></div></div>${employeeList}</section>${matrix}${inspector}</div></div>`;
  }

  function renderTasks(data) {
    const tasks = firstArray(data.results[0]?.value, ["tasks", "assignments"]);
    const schedules = firstArray(data.results[1]?.value, ["schedules"]);
    const taskSchedule = schedules.find((item)=>item.status==="published") || schedules.find((item)=>item.status==="draft") || {};
    const taskMatchesTeam = (item) => {
      const role = String(item.role_group || item.role || "main").toLowerCase();
      return state.taskTeam === "host" ? role === "host" : state.taskTeam === "floor" ? role === "floor" || role === "support" || /floor|fh/.test(role) : !["host", "floor", "support"].includes(role) && !/^fh/.test(role);
    };
    const visibleTasks = tasks.filter(taskMatchesTeam);
    const selected = visibleTasks.find((item) => String(item.id) === String(state.selected?.id)) || visibleTasks[0];
    const completed = tasks.filter((item) => item.completed_at || /complete|verified/i.test(item.status)).length;
    const waiting = tasks.filter((item) => /waiting|review|complete/i.test(item.status) && !/verified/i.test(item.status)).length;
    const libraryItems = [...new Set(tasks.map((item) => item.title).filter(Boolean))].slice(0,10);
    const taskDays = dates.scheduleDates(state.weekStart);
    const allTaskLanes = arr(taskSchedule.rows).map((row)=>({label:row.label,role:row.role_group||"main",shift:/PM|FH/i.test(row.label)?"PM":/AM/i.test(row.label)?"AM":"all",shiftNumber:Number(String(row.label).match(/\d+/)?.[0]||0),row}));
    const taskLanes = allTaskLanes.filter((lane)=>state.taskTeam==="floor" ? lane.role==="floor" || lane.role==="support" || /^FH/i.test(lane.label) : state.taskTeam==="host" ? lane.role==="host" : lane.role!=="host"&&lane.role!=="floor"&&lane.role!=="support"&&!/^FH/i.test(lane.label));
    const interactiveTaskMatrix = `<div class="task-week-grid task-assignment-board"><div class="task-grid-head">Schedule shift</div>${taskDays.map((day)=>`<div class="task-grid-head"><b>${esc(day.name.slice(0,3))}</b><small>${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</small></div>`).join("")}${taskLanes.map((lane)=>`<div class="task-lane"><b>${esc(lane.label)}</b><small>${esc(titleCase(lane.role))}</small></div>${taskDays.map((day)=>{const dayNumber=new Date(`${day.date}T12:00:00Z`).getUTCDay();const slot=`${dayNumber}|${lane.role}|${lane.shift}|${lane.shiftNumber}`;const assigned=arr(taskSchedule.entries).filter((entry)=>String(entry.row_id)===String(lane.row.id)&&Number(entry.day_of_week)===dayNumber&&entry.employee_id);const laneTasks=tasks.filter((item)=>(item.day_of_week===null||item.day_of_week===undefined||Number(item.day_of_week)===dayNumber)&&(item.role_group==="all"||item.role_group===lane.role)&&(item.shift==="all"||lane.shift==="all"||String(item.shift).toUpperCase()===lane.shift)&&(!item.shift_number||Number(item.shift_number)===lane.shiftNumber));return `<div class="task-day-cell task-click-cell" role="button" tabindex="0" data-task-cell="${esc(slot)}"><div class="task-cell-head"><small>${esc(assigned.map((entry)=>entry.employee_name||entry.display_name).filter(Boolean).join(" · ")||"Open shift")}</small><span>＋</span></div>${laneTasks.slice(0,4).map((item)=>`<button data-select-task="${esc(item.id)}" class="task-chip ${item.completed_at||/complete|verified/i.test(item.status)?"done":""}"><b>${esc(item.title)}</b><small>${esc(item.area||"Shift assignment")}</small></button>`).join("")||`<span class="task-cell-empty">Click anywhere to assign a task</span>`}</div>`}).join("")}`).join("")}</div>`;
    const taskWallboard = `<article class="task-wallboard-export"><header><img src="./assets/official-hop-logo.png" alt=""><div><b>HOUSE OF PIZZA &amp; PASTA</b><h2>${esc(titleCase(state.taskTeam))} DAILY TASK BOARD</h2><span>${esc(dateLabel(state.weekStart))} – ${esc(dateLabel(dates.addDays(state.weekStart,5)))}</span></div><strong>${visibleTasks.length}<small>ASSIGNMENTS</small></strong></header><div class="task-wallboard-grid"><div class="task-wallboard-head">SHIFT</div>${taskDays.map((day)=>`<div class="task-wallboard-head"><b>${esc(day.name.toUpperCase())}</b><small>${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</small></div>`).join("")}${taskLanes.map((lane)=>`<div class="task-wallboard-lane"><b>${esc(lane.label)}</b><small>${esc(titleCase(lane.role))}</small></div>${taskDays.map((day)=>{const dayNumber=new Date(`${day.date}T12:00:00Z`).getUTCDay();const laneTasks=tasks.filter((item)=>(item.day_of_week===null||item.day_of_week===undefined||Number(item.day_of_week)===dayNumber)&&(item.role_group==="all"||item.role_group===lane.role)&&(item.shift==="all"||String(item.shift).toUpperCase()===lane.shift)&&(!item.shift_number||Number(item.shift_number)===lane.shiftNumber));return `<div class="task-wallboard-cell">${laneTasks.map((item)=>`<span>□ ${esc(item.title)}</span>`).join("")||"<i>________________________________</i>"}</div>`}).join("")}`).join("")}</div><footer>Generated by HOP Command Center · Complete and initial each assignment</footer></article>`;
    const taskMatrix = `<div class="task-week-grid"><div class="task-grid-head">Schedule shift</div>${taskDays.map((day)=>`<div class="task-grid-head"><b>${esc(day.name.slice(0,3))}</b><small>${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</small></div>`).join("")}${taskLanes.map((lane)=>`<div class="task-lane"><b>${esc(lane.label)}</b><small>${esc(titleCase(lane.role))}</small></div>${taskDays.map((day)=>{const dayNumber=new Date(`${day.date}T12:00:00Z`).getUTCDay();const assigned=arr(taskSchedule.entries).filter((entry)=>String(entry.row_id)===String(lane.row.id)&&Number(entry.day_of_week)===dayNumber&&entry.employee_id);const laneTasks=tasks.filter((item)=>(item.day_of_week===null||item.day_of_week===undefined||Number(item.day_of_week)===dayNumber)&&(item.role_group==="all"||item.role_group===lane.role)&&(item.shift==="all"||lane.shift==="all"||String(item.shift).toUpperCase()===lane.shift)&&(!item.shift_number||Number(item.shift_number)===lane.shiftNumber));return `<div class="task-day-cell"><small class="shift-staff">${esc(assigned.map((entry)=>entry.employee_name||entry.display_name).filter(Boolean).join(" · ")||"Open shift")}</small>${laneTasks.slice(0,4).map((item)=>`<button data-select-task="${esc(item.id)}" class="task-chip ${item.completed_at||/complete|verified/i.test(item.status)?"done":""}"><b>${esc(item.title)}</b><small>Assigned to this shift</small></button>`).join("")||`<button class="task-add-cell" data-action="task-new" data-task-slot="${dayNumber}|${esc(lane.role)}|${lane.shift}|${lane.shiftNumber}">＋ Assign to shift</button>`}</div>`}).join("")}`).join("")}</div>`;
    const library = `<section class="card workspace-panel"><div class="card-head"><div><h3>Task Library</h3><p>Connected recurring work</p></div></div><div class="card-body"><div class="module-search" style="min-width:0"><span>⌕</span><input class="table-search" placeholder="Search library"></div></div><div class="master-list">${libraryItems.length ? libraryItems.map((title) => `<div class="master-row"><span class="initial">✓</span><span class="row-copy"><b>${esc(title)}</b><small>Reusable schedule-aware task</small></span></div>`).join("") : `<div class="info-banner" style="margin:8px">Create assignments to build the reusable task library.</div>`}</div><div class="sticky-actions"><button class="button" data-action="task-reminders">Run due reminders</button><button class="danger-button" data-action="task-clear-done">Clear done</button></div></section>`;
    const rows = visibleTasks.length ? `<table class="data-table"><thead><tr><th>Date</th><th>Task</th><th>Role / employee</th><th>Shift</th><th>Status</th></tr></thead><tbody>${visibleTasks.map((item) => `<tr class="${String(selected?.id) === String(item.id) ? "selected" : ""}" data-select-task="${esc(item.id)}"><td>${esc(dateLabel(item.task_date || dates.today(),{weekday:"short",month:"short",day:"numeric"}))}</td><td><b>${esc(item.title)}</b><br><small>${esc(item.notes || item.area || "Operational task")}</small></td><td>${esc(item.employee_name || item.role || item.role_group || "All staff")}</td><td>${pill(item.shift || "All")}</td><td>${pill(item.status || (item.completed_at ? "completed" : "assigned"))}</td></tr>`).join("")}</tbody></table>` : empty(`No ${state.taskTeam} tasks assigned`, "Use a shift cell or the task library to add one.", "tasks");
    const plan = `<section class="card workspace-panel"><div class="card-head"><div><h3>${esc(titleCase(state.taskTeam))} shift assignments</h3><p>Click any day and shift cell to assign work to that position</p></div>${savedState()}</div>${filterToolbar({search:"Search weekly tasks",filters:[["main","Main"],["host","Host"],["floor","Floor"]].map(([id,label])=>({label,active:state.taskTeam===id,attr:`data-task-team="${id}"`})),meta:`${taskLanes.length} schedule positions`})}<div class="task-matrix-wrap">${interactiveTaskMatrix}</div><div class="card-body"><div class="section-label">Assignment records</div></div>${rows}<button class="card-footer-link" data-action="task-new">＋ Add from task library or create a one-time task</button></section>`;
    const inspector = selected ? `<section class="card context-inspector">${inspectorTitle("TASK DETAILS", selected.title || "Task", `${dateLabel(selected.task_date || dates.today())} · ${titleCase(selected.shift || "all shifts")}`, selected.status || (selected.completed_at ? "completed" : "assigned"))}<div class="card-body"><div class="detail-section"><h4>Assigned to</h4><div class="profile-head"><span class="initial">${esc(initials(selected.employee_name || selected.role || "All"))}</span><div><b>${esc(selected.employee_name || titleCase(selected.role || selected.role_group) || "All staff")}</b><small>${esc(titleCase(selected.shift || "All shifts"))}</small></div></div></div><div class="detail-section"><h4>Task status</h4><div class="compact-row"><span class="status-dot"></span><span class="row-copy"><b>${esc(titleCase(selected.status || "Assigned"))}</b><small>${selected.completed_at ? `Completed ${esc(dateLabel(selected.completed_at,{hour:"numeric",minute:"2-digit"}))}` : "Waiting for employee completion"}</small></span></div></div><div class="form-control"><label>Manager note</label><textarea disabled>${esc(selected.notes || "")}</textarea></div></div><div class="sticky-actions"><button class="button" data-action="task-open" data-id="${esc(selected.id)}">Edit task</button><button class="primary-button" data-action="task-open" data-id="${esc(selected.id)}">Review status</button></div></section>` : card("Shift inspector", empty("Select a task", "Choose an assignment to inspect.", "tasks"));
    const verificationItems = tasks.filter((item) => /waiting|review|complete/i.test(item.status || "") && !/verified/i.test(item.status || ""));
    const verificationView = `<div class="workspace-two"><section class="card workspace-panel"><div class="card-head"><div><h3>Verification Queue</h3><p>Employee completions waiting for manager review</p></div>${pill(`${verificationItems.length} waiting`)}</div><div class="master-list">${verificationItems.map((item) => `<button class="master-row" data-select-task="${esc(item.id)}"><span class="initial">✓</span><span class="row-copy"><b>${esc(item.title)}</b><small>${esc(item.employee_name || titleCase(item.role || item.role_group) || "All staff")} · ${esc(dateLabel(item.task_date || dates.today()))}</small></span>${pill(item.status || "waiting")}</button>`).join("") || empty("Verification queue is clear", "Completed work needing manager review will appear here.", "tasks")}</div></section>${inspector}</div>`;
    const libraryView = `<div class="workspace-two">${library}${card("Connected task patterns", `<div class="info-banner">Library entries come from saved task definitions already used by the weekly plan. Choose Assign task to reuse one or create a one-time assignment.</div><div class="record-summary"><span><small>Saved patterns</small><b>${libraryItems.length}</b></span><span><small>Current assignments</small><b>${tasks.length}</b></span></div>`)}</div>`;
    const activeTaskView = state.tasksTab === "verification" ? verificationView : state.tasksTab === "library" ? libraryView : `<div class="workspace-three">${library}${plan}${inspector}</div>`;
    return `<div class="page">${pageHead("tasks", `${savedState()}<button class="button" data-action="task-export">Print wallboard</button><button class="primary-button" data-action="task-new">+ Assign task</button>`)}${tabBar([["week","Week Plan",tasks.length],["verification","Verification Queue",waiting],["library","Task Library",libraryItems.length]], state.tasksTab, "tasks-tab")}<div class="metric-grid">${metric("Assigned",tasks.length,"This connected view")}${metric("Verified",completed,"Manager confirmed")}${metric("Waiting verification",waiting,"Needs review")}${metric("Not started",Math.max(0,tasks.length-completed-waiting),"Assigned")}</div>${activeTaskView}${taskWallboard}</div>`;
  }

  function renderParties(data) {
    const parties = firstArray(data.results[0]?.value, ["parties"]);
    const history = firstArray(data.results[1]?.value, ["parties"]);
    const contacts = firstArray(data.results[2]?.value, ["contacts"]);
    const days = dates.scheduleDates(state.weekStart);
    const monthAnchor=new Date(`${state.partyMonth}-01T12:00:00Z`);const monthStart=new Date(Date.UTC(monthAnchor.getUTCFullYear(),monthAnchor.getUTCMonth(),1));const gridStart=new Date(monthStart);gridStart.setUTCDate(1-monthStart.getUTCDay());const monthDays=Array.from({length:42},(_,index)=>{const value=new Date(gridStart);value.setUTCDate(gridStart.getUTCDate()+index);return {date:value.toISOString().slice(0,10),current:value.getUTCMonth()===monthStart.getUTCMonth(),day:value.getUTCDate()};});
    const weekDates = new Set(days.map((day)=>day.date));
    const weekParties = parties.filter((party)=>weekDates.has(String(party.date || party.party_date).slice(0,10)));
    const periodParties = state.partiesView === "week" ? weekParties : parties;
    const totalGuests = periodParties.reduce((sum, party) => sum + Number(party.count || 0), 0);
    const unassigned = periodParties.filter((party) => !party.assigned_waitress_id).length;
    const selectedDay = state.selected?.day && weekDates.has(state.selected.day) ? state.selected.day : days.find((day) => weekParties.some((party) => String(party.date || party.party_date).slice(0,10) === day.date))?.date || days[0].date;
    const dayParties = weekParties.filter((party) => String(party.date || party.party_date).slice(0,10) === selectedDay && (state.partiesFilter !== "unassigned" || !party.assigned_waitress_id));
    const selected = dayParties.find((party) => String(party.id) === String(state.selected?.id)) || dayParties[0] || null;
    const weekGuests = weekParties.reduce((sum,party)=>sum+Number(party.count||0),0);
    const weekUnassigned = weekParties.filter((party)=>!party.assigned_waitress_id).length;
    const rail = `<section class="card workspace-panel"><div class="card-head"><div><h3>This Week</h3><p>${weekParties.length} parties · ${weekGuests} guests</p></div></div><div class="card-body"><div class="day-rail">${days.map((day) => { const count=weekParties.filter((party) => String(party.date || party.party_date).slice(0,10)===day.date).length; return `<button class="day-button ${selectedDay===day.date?"active":""}" data-party-day="${day.date}"><b>${esc(day.name.slice(0,3))}</b><span>${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</span><span>${esc(count)}</span></button>`; }).join("")}</div><div class="section-label">Quick filters</div><button class="filter-chip ${state.partiesFilter==="all"?"active":""}" data-party-filter="all">All parties</button> <button class="filter-chip ${state.partiesFilter==="unassigned"?"active":""}" data-party-filter="unassigned">Unassigned ${weekUnassigned}</button><div class="section-label">Returning contacts</div><div class="compact-list">${contacts.slice(0,3).map((contact) => `<div class="compact-row"><span class="initial">${esc(initials(contact.name))}</span><span class="row-copy"><b>${esc(contact.name)}</b><small>${esc(contact.party_count || 0)} past parties</small></span></div>`).join("") || `<div class="info-banner">No contact history returned.</div>`}</div></div></section>`;
    const table = dayParties.length ? `<table class="data-table"><thead><tr><th>Time</th><th>Party</th><th>Guests</th><th>Area</th><th>Type</th><th>Waitress</th><th>Status</th></tr></thead><tbody>${dayParties.map((party) => `<tr class="${String(selected?.id)===String(party.id)?"selected":""}" data-select-party="${esc(party.id)}"><td><b>${esc(party.time?formatTime(party.time):"TBD")}</b></td><td><b>${esc(party.name)}</b><br><small>${esc(party.phone||"No phone")}</small></td><td>${esc(party.count||"—")}</td><td>${pill(party.area||"TBD")}</td><td>${esc(titleCase(party.party_type||party.type||"Party"))}</td><td>${esc(party.assigned_waitress_name||"Unassigned")}</td><td>${pill(party.status||"booked")}</td></tr>`).join("")}</tbody></table>` : empty("No parties on this day", "Choose another day or add a connected party booking.", "parties");
    const center = `<section class="card workspace-panel"><div class="card-head"><div><h3>${esc(dateLabel(selectedDay,{weekday:"long",month:"long",day:"numeric"}))}</h3><p>Selected-day operational list</p></div>${pill(`${dayParties.length} parties`)}</div>${filterToolbar({search:"Search party or phone",filters:[{label:"All areas",active:true},{label:"All types"}],meta:`${dayParties.reduce((sum,p)=>sum+Number(p.count||0),0)} guests`})}${table}</section>`;
    const inspector = selected ? `<section class="card context-inspector">${inspectorTitle("EDIT PARTY", selected.name || "Party booking", `${selected.time?formatTime(selected.time):"Time TBD"} · ${selected.count||"?"} guests`, selected.status || "booked")}<div class="card-body"><div class="record-summary"><span><small>Date</small><b>${esc(dateLabel(selected.date||selected.party_date))}</b></span><span><small>Area</small><b>${esc(titleCase(selected.area||"Not set"))}</b></span><span><small>Start</small><b>${esc(selected.time?formatTime(selected.time):"Not set")}</b></span><span><small>Waitress</small><b>${esc(selected.assigned_waitress_name||"Unassigned")}</b></span></div><div class="detail-section"><h4>Contact</h4><div class="detail-grid"><span class="detail-item"><span>Phone</span><b>${esc(selected.phone||"Not set")}</b></span><span class="detail-item"><span>Linked contact</span><b>${contacts.some((c)=>c.phone===selected.phone)?"Contact book":"New guest"}</b></span></div></div>${unassigned&& !selected.assigned_waitress_id?`<div class="info-banner warning">This party is not assigned to a waitress. Review staffing before the event.</div>`:""}<div class="detail-section"><h4>Notes</h4><p>${esc(selected.notes||selected.note||"No party notes recorded.")}</p></div></div><div class="sticky-actions"><button class="button" data-action="party-open" data-id="${esc(selected.id)}">Edit details</button><button class="primary-button" data-action="party-open" data-id="${esc(selected.id)}">Open party</button></div></section>` : card("Party editor", empty("Select a party", "Choose a booking to inspect.", "parties"));
    const calendar = `<section class="card party-calendar-view"><div class="card-head"><div><h3>${esc(new Intl.DateTimeFormat("en-US",{timeZone:"UTC",month:"long",year:"numeric"}).format(monthStart))}</h3><p>Full-month party calendar · area, guests, waitress, and time</p></div>${pill(`${parties.length} bookings`)}</div><div class="card-body"><div class="party-month-head">${["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].map((day)=>`<b>${day}</b>`).join("")}</div><div class="party-month-grid">${monthDays.map((day)=>{const dayItems=parties.filter((party)=>String(party.date||party.party_date).slice(0,10)===day.date);return `<div class="party-month-day ${day.current?"":"outside"}"><div><b>${day.day}</b>${dayItems.length?pill(dayItems.length):""}</div>${dayItems.map((party)=>`<button class="party-month-event" data-select-party="${esc(party.id)}"><b>${esc(party.time?formatTime(party.time):"TBD")}</b> ${esc(party.name)}<small>${esc(party.count||"?")} guests · ${esc(party.area||"TBD")} · ${esc(party.assigned_waitress_name||"Unassigned")}</small></button>`).join("")}</div>`}).join("")}</div></div></section>`;
    const contactsView = `<section class="card table-card"><div class="card-head"><div><h3>Party contacts</h3><p>Returning customers and reservation history</p></div>${pill(`${contacts.length} contacts`)}</div>${filterToolbar({search:"Search customer or phone",meta:`${contacts.length} saved contacts`})}<table class="data-table"><thead><tr><th>Customer</th><th>Phone</th><th>Last party</th><th>Past parties</th><th>Notes</th></tr></thead><tbody>${contacts.length?contacts.map((contact)=>`<tr><td><div class="cell-person"><span class="initial">${esc(initials(contact.name))}</span><span><b>${esc(contact.name)}</b><small>Party contact</small></span></div></td><td>${esc(contact.phone||"—")}</td><td>${esc(dateLabel(contact.last_party_date||contact.updated_at))}</td><td><b>${esc(contact.party_count||0)}</b></td><td>${esc(contact.notes||"—")}</td></tr>`).join(""):`<tr><td colspan="5">${empty("No party contacts","Saved returning customers appear here.","parties")}</td></tr>`}</tbody></table></section>`;
    const historyView = `<section class="card table-card"><div class="card-head"><div><h3>Completed & cancelled parties</h3><p>Read-only reservation history</p></div>${pill(`${history.length} records`)}</div>${filterToolbar({search:"Search history",meta:`${history.length} historical records`})}<table class="data-table"><thead><tr><th>Date</th><th>Party</th><th>Guests</th><th>Area</th><th>Waitress</th><th>Status</th><th></th></tr></thead><tbody>${history.length?history.map((party)=>`<tr><td>${esc(dateLabel(party.date||party.party_date))}</td><td><b>${esc(party.name||"Party")}</b><br><small>${esc(party.phone||"No phone")}</small></td><td>${esc(party.count||"—")}</td><td>${esc(party.area||"—")}</td><td>${esc(party.assigned_waitress_name||"Unassigned")}</td><td>${pill(party.status||"completed")}</td><td><button class="ellipsis" data-action="party-open-history" data-id="${esc(party.id)}">•••</button></td></tr>`).join(""):`<tr><td colspan="7">${empty("No party history","Completed and cancelled bookings remain here.","parties")}</td></tr>`}</tbody></table></section>`;
    const activeView = state.partiesView === "calendar" ? calendar : state.partiesView === "contacts" ? contactsView : state.partiesView === "history" ? historyView : `<div class="party-shell">${rail}${center}${inspector}</div>`;
    const periodPicker=state.partiesView==="calendar"?`<div class="week-picker"><button data-month-move="-1">‹</button><b>${esc(new Intl.DateTimeFormat("en-US",{timeZone:"UTC",month:"long",year:"numeric"}).format(monthStart))}</b><button data-month-move="1">›</button></div>`:`<div class="week-picker"><button data-week-move="-7">‹</button><b>${esc(dateLabel(state.weekStart))}</b><button data-week-move="7">›</button></div>`;
    return `<div class="page">${pageHead("parties", `${periodPicker}<button class="button" data-action="party-export">Party Board Preview</button><button class="primary-button" data-action="party-new">+ New party</button>`)}${tabBar([["week","Week Board",weekParties.length],["calendar","Calendar",parties.length],["contacts","Contacts",contacts.length],["history","History",history.length]], state.partiesView, "parties-view")}<div class="metric-grid">${metric("Parties",periodParties.length,state.partiesView==="week"?"Bookings this schedule week":"Bookings in loaded month")}${metric("Guests",totalGuests,"Expected guests")}${metric("Unassigned",unassigned,"Needs waitress review")}${metric("Returning contacts",contacts.length,"Contact book")}</div><div class="info-banner warning" style="margin-bottom:9px">Employee party requests remain requests in Manager Inbox; only confirmed customer bookings appear on this board.</div>${activeView}</div>`;
  }

  function renderInvoices(data) {
    const cateringResult = data.results[0] || {};
    const orders = firstArray(cateringResult.value, ["orders"]);
    const activeDocuments = firstArray(data.results[1]?.value, ["invoices"]);
    const archivedDocuments = firstArray(data.results[2]?.value, ["invoices"]);
    const tab = state.documentsTab;
    const cateringOnline = cateringResult.ok !== false;
    const selectedOrder = state.cateringDetail || orders.find((item) => String(item.id) === String(state.selected?.kind === "catering" ? state.selected.id : "")) || orders[0] || null;
    const sourceDocuments = tab === "archive" ? archivedDocuments : activeDocuments;
    const visibleDocuments = state.invoiceSource === "all" ? sourceDocuments : sourceDocuments.filter((doc)=>state.invoiceSource === "catering" ? Boolean(doc.catering_order_id) : !doc.catering_order_id);
    const selectedDocument = state.invoiceDetail || visibleDocuments.find((item) => String(item.id) === String(state.selected?.kind === "invoice" ? state.selected.id : "")) || visibleDocuments[0] || null;
    const tabs = `<div class="document-tabs"><button class="${tab === "documents" ? "active" : ""}" data-documents-tab="documents">Invoices & quotes <span>${activeDocuments.length}</span></button><button class="${tab === "catering" ? "active" : ""}" data-documents-tab="catering">Catering fulfillment <span>${orders.length}</span></button><button class="${tab === "archive" ? "active" : ""}" data-documents-tab="archive">Archive <span>${archivedDocuments.length}</span></button></div>`;
    const headerAction = tab === "catering"
      ? `<button class="primary-button" data-action="catering-new" ${cateringOnline ? "" : "disabled title=\"Deploy the included Catering API patch first\""}>+ New catering order</button>`
      : `<button class="button" data-action="catering-new" ${cateringOnline ? "" : "disabled"}>+ Catering plan</button><button class="primary-button" data-action="invoice-new">+ New invoice / quote</button>`;
    const metrics = `<div class="metric-grid documents-metrics">${metric("Upcoming catering", orders.filter((item) => item.event_date).length, "Future fulfillment")}${metric("Needs action", orders.reduce((sum, item) => sum + Number(item.open_action_count || 0), 0), "Operational follow-up")}${metric("Active documents", activeDocuments.length, "Quotes and invoices")}${metric("Archived", archivedDocuments.length, "Retained records")}</div>`;

    if (tab === "catering") {
      const list = orders.length ? orders.map((order) => `<button class="document-row ${selectedOrder?.id === order.id ? "selected" : ""}" data-select-catering="${esc(order.id)}"><span class="date-tile"><b>${esc(dateLabel(order.event_date, { day: "numeric" }))}</b><span>${esc(dateLabel(order.event_date, { month: "short", day: undefined }))}</span></span><span class="row-copy"><b>${esc(order.customer_name)}</b><small>${esc(titleCase(order.service_type))} · ${esc(order.event_time ? formatTime(order.event_time) : "Time TBD")} · ${esc(order.guest_count || "?")} guests</small></span>${Number(order.open_action_count || 0) ? pill(`${order.open_action_count} open`) : pill(order.status)}</button>`).join("") : empty(cateringOnline ? "No catering orders yet" : "Catering connection not deployed", cateringOnline ? "Create the first connected large-order record." : "The included Hostinger patch adds the shared catering tables and routes.", "invoices");
      const orderItems = arr(selectedOrder?.items);
      const requirements = arr(selectedOrder?.required_actions);
      const documents = arr(selectedOrder?.documents);
      const detail = selectedOrder ? `<section class="card document-detail"><div class="card-head"><div><h3>${esc(selectedOrder.customer_name)}</h3><p>${esc(selectedOrder.order_number || "Catering order")} · ${esc(dateLabel(selectedOrder.event_date))} at ${esc(selectedOrder.event_time ? formatTime(selectedOrder.event_time) : "Time TBD")}</p></div>${pill(selectedOrder.status)}</div><div class="card-body"><div class="record-summary"><span><small>Fulfillment</small><b>${esc(titleCase(selectedOrder.service_type))}</b></span><span><small>Ready by</small><b>${esc(selectedOrder.ready_by_time ? formatTime(selectedOrder.ready_by_time) : "Not set")}</b></span><span><small>Guests</small><b>${esc(selectedOrder.guest_count || "Not set")}</b></span><span><small>Contact</small><b>${esc(selectedOrder.contact_name || selectedOrder.customer_phone || "Not set")}</b></span></div>${selectedOrder.venue_address ? `<div class="control-note"><b>Destination:</b> ${esc(selectedOrder.venue_address)}</div>` : ""}<div class="detail-section"><h4>Order items</h4>${orderItems.length ? `<table class="data-table"><thead><tr><th>Qty</th><th>Item</th><th>Size / details</th></tr></thead><tbody>${orderItems.map((item) => `<tr><td>${esc(item.quantity)}</td><td><b>${esc(item.description)}</b></td><td>${esc(item.size_details || "—")}</td></tr>`).join("")}</tbody></table>` : `<div class="control-note">Open Edit Order to add menu items and preparation details.</div>`}</div><div class="document-detail-columns"><div class="detail-section"><h4>Dietary & supplies</h4><p>${esc(arr(selectedOrder.dietary_requirements).join(" · ") || "No dietary requirements recorded.")}</p><small>${esc(Object.entries(selectedOrder.supplies || {}).filter(([,value]) => value).map(([key]) => titleCase(key)).join(" · ") || "No supplies selected.")}</small></div><div class="detail-section"><h4>Required actions</h4>${requirements.length ? requirements.map((item) => `<button class="compact-action ${item.status === "completed" ? "done" : ""}" data-action="catering-action-toggle" data-order-id="${esc(selectedOrder.id)}" data-id="${esc(item.id)}" data-completed="${item.status !== "completed"}"><span>${item.status === "completed" ? "✓" : "○"}</span><b>${esc(item.description)}</b><small>${esc(item.due_date ? `Due ${dateLabel(item.due_date)}` : "No due date")}</small></button>`).join("") : `<p>No open preparation actions.</p>`}</div></div><div class="detail-section"><h4>Linked documents</h4>${documents.length ? documents.map((doc) => `<button class="linked-document" data-documents-tab-go="documents" data-id="${esc(doc.id)}"><b>${esc(doc.invoice_number)}</b>${pill(doc.document_type)}${pill(doc.status)}</button>`).join("") : `<div class="control-note">No quote or invoice has been created for this order.</div>`}</div><div class="document-actions"><button class="button" data-action="catering-edit" data-id="${esc(selectedOrder.id)}">Edit order</button><button class="button" data-action="invoice-from-catering" data-document-type="quote" data-id="${esc(selectedOrder.id)}">Create quote</button><button class="primary-button" data-action="invoice-from-catering" data-document-type="invoice" data-id="${esc(selectedOrder.id)}">Create invoice</button></div></div></section>` : card("Catering order", empty("Select an order", "Choose a catering order to review preparation and documents.", "invoices"));
      const planning = selectedOrder ? `<section class="card context-inspector">${inspectorTitle("PLANNING & DOCUMENTS", selectedOrder.customer_name || "Catering order", selectedOrder.order_number || "Connected order", selectedOrder.status)}<div class="inspector-tabs"><button class="active">Planning</button><button>Documents</button><button>Follow-up</button></div><div class="card-body"><div class="detail-section"><h4>Fulfillment timeline</h4><div class="compact-row"><span class="status-dot"></span><span class="row-copy"><b>Event</b><small>${esc(dateLabel(selectedOrder.event_date))} · ${esc(selectedOrder.event_time?formatTime(selectedOrder.event_time):"Time TBD")}</small></span></div><div class="compact-row"><span class="status-dot"></span><span class="row-copy"><b>Ready by</b><small>${esc(selectedOrder.ready_by_time?formatTime(selectedOrder.ready_by_time):"Not set")}</small></span></div></div><div class="detail-section"><h4>Required actions</h4>${requirements.length ? requirements.map((item) => `<button class="compact-action ${item.status === "completed" ? "done" : ""}" data-action="catering-action-toggle" data-order-id="${esc(selectedOrder.id)}" data-id="${esc(item.id)}" data-completed="${item.status !== "completed"}"><span>${item.status === "completed" ? "✓" : "○"}</span><b>${esc(item.description)}</b><small>${esc(item.due_date ? `Due ${dateLabel(item.due_date)}` : "No due date")}</small></button>`).join("") : `<div class="info-banner">No open preparation actions.</div>`}</div><div class="detail-section"><h4>Documents</h4>${documents.length ? documents.map((doc) => `<button class="linked-document" data-documents-tab-go="documents" data-id="${esc(doc.id)}"><b>${esc(doc.invoice_number)}</b>${pill(doc.document_type)}${pill(doc.status)}</button>`).join("") : `<div class="info-banner warning">No quote or invoice is linked to this catering order.</div>`}</div><div class="form-control"><label>Customer follow-up</label><textarea disabled>${esc(selectedOrder.follow_up_note || "")}</textarea></div></div><div class="sticky-actions"><button class="button" data-action="catering-edit" data-id="${esc(selectedOrder.id)}">Edit order</button><button class="primary-button" data-action="invoice-from-catering" data-document-type="invoice" data-id="${esc(selectedOrder.id)}">Create invoice</button></div></section>` : card("Planning", empty("Select an order", "Choose a catering order to plan fulfillment.", "invoices"));
      return `<div class="page">${pageHead("invoices", `${savedState("Catering synced")}${headerAction}`)}${tabs}${metrics}${tabBar([["upcoming","Upcoming",orders.length],["attention","Needs Attention",orders.filter((item)=>Number(item.open_action_count||0)>0).length],["all","All Orders",orders.length]], "upcoming", "catering-view")}<div class="documents-workspace"><section class="card document-list"><div class="card-head"><div><h3>Upcoming orders</h3><p>Sorted by fulfillment date</p></div></div><div class="card-body">${list}</div></section>${detail}${planning}</div></div>`;
    }

    const documentList = visibleDocuments.length ? visibleDocuments.map((doc) => `<button class="document-row ${selectedDocument?.id === doc.id ? "selected" : ""}" data-select-invoice="${esc(doc.id)}"><span class="document-icon">${String(doc.document_type) === "quote" ? "Q" : "I"}</span><span class="row-copy"><b>${esc(doc.invoice_number)}</b><small>${esc(doc.customer_name)} · ${esc(dateLabel(doc.event_date || doc.issue_date))}</small></span>${pill(doc.status)}</button>`).join("") : empty(tab === "archive" ? "Archive is empty" : "No documents yet", tab === "archive" ? "Archived quotes and invoices remain available here." : "Create a quote or invoice, or import one from Catering.", "invoices");
    const sourceTabs=`<div class="invoice-source-tabs"><button class="${state.invoiceSource==="all"?"active":""}" data-invoice-source="all">All documents <span>${sourceDocuments.length}</span></button><button class="${state.invoiceSource==="regular"?"active":""}" data-invoice-source="regular">Regular menu <span>${sourceDocuments.filter((doc)=>!doc.catering_order_id).length}</span></button><button class="${state.invoiceSource==="catering"?"active":""}" data-invoice-source="catering">Catering menu <span>${sourceDocuments.filter((doc)=>doc.catering_order_id).length}</span></button></div>`;
    const documentItems = arr(selectedDocument?.items);
    const chargeItems = selectedDocument ? [["Delivery fee", selectedDocument.delivery_fee_cents], ["Gratuity", selectedDocument.gratuity_cents], ["Other fee", selectedDocument.other_fee_cents]].filter(([, amount]) => Number(amount) > 0).map(([description, amount]) => ({ description, quantity: 1, unit_price_cents: Number(amount), line_total_cents: Number(amount), source_type: "document_charge" })) : [];
    const items = [...documentItems, ...chargeItems];
    const documentLabel=titleCase(selectedDocument?.document_type||"invoice");
    const taxRate=Number(selectedDocument?.tax_rate_basis_points||0)/100;
    const customerLines=[selectedDocument?.contact_name,selectedDocument?.customer_phone,selectedDocument?.customer_email,selectedDocument?.customer_address].filter(Boolean);
    const preview = selectedDocument ? `<section class="invoice-paper main-site-invoice"><header class="invoice-export-head"><img src="./assets/official-hop-logo.png" alt="House of Pizza"><div><span>HOUSE OF PIZZA &amp; PASTA</span><h2>${esc(documentLabel.toUpperCase())}</h2><small>Gaffney, South Carolina · houseofpizzagaffney.com</small></div><b>CUSTOMER COPY</b></header><div class="invoice-export-rule"></div><div class="invoice-export-parties"><section><small>BILL TO</small><h3>${esc(selectedDocument.customer_name)}</h3>${customerLines.map((line)=>`<span>${esc(line)}</span>`).join("")}</section><dl><div><dt>${esc(documentLabel)}</dt><dd>${esc(selectedDocument.invoice_number)}</dd></div><div><dt>Issued</dt><dd>${esc(dateLabel(selectedDocument.issue_date))}</dd></div><div><dt>Due</dt><dd>${esc(dateLabel(selectedDocument.due_date||selectedDocument.event_date))}</dd></div>${selectedDocument.event_date?`<div><dt>Order date</dt><dd>${esc(dateLabel(selectedDocument.event_date))}</dd></div>`:""}<div><dt>Status</dt><dd>${esc(titleCase(selectedDocument.status))}</dd></div></dl></div><table class="invoice-export-table"><thead><tr><th>DESCRIPTION</th><th>QTY</th><th>RATE</th><th>AMOUNT</th></tr></thead><tbody>${items.length?items.map((item)=>`<tr><td>${esc(item.description)}</td><td>${esc(item.quantity)}</td><td>${money(item.unit_price_cents)}</td><td>${money(item.line_total_cents)}</td></tr>`).join(""):`<tr><td colspan="4">Open the document to load its complete printable items.</td></tr>`}</tbody></table><div class="invoice-export-bottom"><section><small>CUSTOMER NOTE</small><p>${esc(selectedDocument.customer_note||"Thank you for choosing House of Pizza & Pasta.")}</p></section><div class="invoice-export-totals"><span>Subtotal <b>${money(selectedDocument.subtotal_cents)}</b></span>${Number(selectedDocument.discount_cents)?`<span>Discount <b>−${money(selectedDocument.discount_cents)}</b></span>`:""}<span>Sales tax${taxRate?` (${esc(Number.isInteger(taxRate)?taxRate:taxRate.toFixed(2))}%)`:""} <b>${money(selectedDocument.tax_cents)}</b></span><strong>Cash / check total <b>${money(selectedDocument.total_cents)}</b></strong><span class="card-total">Card total${Number(selectedDocument.card_fee_basis_points)?` (${esc((Number(selectedDocument.card_fee_basis_points)/100).toFixed(2))}% fee)`:""} <b>${money(selectedDocument.card_total_cents||selectedDocument.total_cents)}</b></span></div></div><footer class="invoice-export-footer"><span><b>Thank you for choosing House of Pizza &amp; Pasta.</b><small>Great food. Family tradition.</small></span><span>Payment method<b>${esc(titleCase(String(selectedDocument.payment_method||"not selected").replace("not-set","not selected")))}</b></span></footer></section>` : empty("Select a document", "Choose a quote or invoice to preview it.", "invoices");
    const documentActions = selectedDocument ? `<div class="document-actions"><button class="button" data-action="invoice-print" data-id="${esc(selectedDocument.id)}">Print</button><button class="primary-button" data-action="invoice-export" data-id="${esc(selectedDocument.id)}">Export PDF</button><button class="button" data-action="invoice-open" data-id="${esc(selectedDocument.id)}">Edit document</button>${selectedDocument.document_type === "quote" && tab !== "archive" ? `<button class="button" data-action="invoice-convert" data-id="${esc(selectedDocument.id)}">Convert</button>` : ""}<button class="${tab === "archive" ? "button" : "danger-button"}" data-action="invoice-archive" data-id="${esc(selectedDocument.id)}" data-archived="${tab !== "archive"}">${tab === "archive" ? "Restore" : "Delete"}</button></div>` : "";
    const editor = selectedDocument ? `<section class="card document-detail">${inspectorTitle("EDIT DOCUMENT", selectedDocument.invoice_number || titleCase(selectedDocument.document_type), selectedDocument.customer_name, selectedDocument.status)}<div class="inspector-tabs"><button class="active">Details</button><button>Line items</button><button>Payment</button><button>Notes</button></div><div class="card-body">${selectedDocument.catering_order_id ? `<div class="info-banner">Linked catering order · source details stay connected.</div>` : ""}<div class="form-grid"><div class="form-control"><label>Document type</label><input value="${esc(titleCase(selectedDocument.document_type))}" disabled></div><div class="form-control"><label>Status</label><input value="${esc(titleCase(selectedDocument.status))}" disabled></div><div class="form-control full"><label>Customer</label><input value="${esc(selectedDocument.customer_name)}" disabled></div><div class="form-control"><label>Issue date</label><input value="${esc(dateLabel(selectedDocument.issue_date))}" disabled></div><div class="form-control"><label>Due date</label><input value="${esc(dateLabel(selectedDocument.due_date||selectedDocument.event_date))}" disabled></div></div><div class="detail-section"><h4>Line items</h4>${items.length ? items.map((item) => `<div class="compact-row"><span class="row-copy"><b>${esc(item.quantity)} × ${esc(item.description)}</b><small>${money(item.unit_price_cents)} each</small></span><b>${money(item.line_total_cents)}</b></div>`).join("") : `<div class="info-banner">Open the editor to add document line items.</div>`}</div><div class="record-summary"><span><small>Subtotal</small><b>${money(selectedDocument.subtotal_cents)}</b></span><span><small>Tax</small><b>${money(selectedDocument.tax_cents)}</b></span><span><small>Total</small><b>${money(selectedDocument.total_cents)}</b></span><span><small>Balance</small><b>${money(selectedDocument.balance_due_cents)}</b></span></div></div><div class="sticky-actions"><button class="primary-button" data-action="invoice-open" data-id="${esc(selectedDocument.id)}">Edit & save document</button></div></section>` : card("Edit document", empty("Select a document", "Choose a quote or invoice to edit.", "invoices"));
    const previewPanel = `<section class="card document-preview"><div class="card-head"><div><h3>Print preview</h3><p>US Letter · Fit</p></div>${selectedDocument ? pill(selectedDocument.status) : ""}</div><div class="card-body">${preview}${documentActions}</div></section>`;
    const documentPicker = activeDocuments.length ? `<label class="invoice-document-picker"><span>Open document</span><select data-invoice-document-select>${activeDocuments.map((doc)=>`<option value="${esc(doc.id)}" ${String(selectedDocument?.id)===String(doc.id)?"selected":""}>${esc(doc.invoice_number)} · ${esc(doc.customer_name)}</option>`).join("")}</select></label>` : "";
    const singleEditor = selectedDocument ? editor : `<section class="card invoice-start-card"><div class="card-body"><span class="document-icon">I</span><h3>Build one clean document</h3><p>Add regular-menu, catering-menu, or custom lines in the same editor. The preview and final portrait export stay matched.</p><button class="primary-button" data-action="invoice-new">Create invoice / quote</button></div></section>`;
    return `<div class="page invoice-single-page">${pageHead("invoices", `${documentPicker}${selectedDocument?`<button class="button" data-action="invoice-print" data-id="${esc(selectedDocument.id)}">Print</button><button class="button" data-action="invoice-export" data-id="${esc(selectedDocument.id)}">Export PDF</button>`:""}<button class="primary-button" data-action="invoice-new">+ New invoice / quote</button>`)}<div class="invoice-single-banner"><div><span>CONNECTED DOCUMENT STUDIO</span><h3>Invoice & quote builder</h3><p>Regular menu, catering menu, custom lines, charges, preview, and portrait export in one place.</p></div>${savedState("Connected database")}</div><div class="invoice-single-workspace">${singleEditor}${previewPanel}</div></div>`;
  }

  function renderReports(data) {
    const invoices = firstArray(data.results[0]?.value, ["invoices"]);
    const history = firstArray(data.results[1]?.value, ["requests", "items", "history"]);
    const employees = firstArray(data.results[2]?.value, ["employees"]);
    const schedules = firstArray(data.results[3]?.value, ["schedules"]);
    const schedule = schedules.find((item) => state.scheduleView === "draft" ? item.status === "draft" : item.status === "published") || schedules[0] || {};
    const parties = firstArray(data.results[4]?.value, ["parties"]);
    const entries = arr(schedule.entries);
    const scheduleRowsById = new Map(arr(schedule.rows).map((row)=>[String(row.id),row]));
    const employeeRows = employees.map((employee) => {
      const shifts = entries.filter((entry) => String(entry.employee_id) === String(employee.id));
      const hours = shifts.reduce((sum, entry) => {
        const start=String(entry.start_time||"").match(/^(\d+):(\d+)/); const end=String(entry.end_time||"").match(/^(\d+):(\d+)/);
        return sum + (start&&end ? Math.max(0,(Number(end[1])+Number(end[2])/60)-(Number(start[1])+Number(start[2])/60)) : 0);
      },0);
      const workedRates = shifts.map((entry)=>{const role=scheduleRowsById.get(String(entry.row_id))?.role_group||entry.role||employee.role;return Number(employee.role_pay_rates?.[role] ?? employee.pay_rate_cents);}).filter(Number.isFinite);
      const estimatedPayCents = shifts.reduce((sum,entry)=>{const start=String(entry.start_time||"").match(/^(\d+):(\d+)/);const end=String(entry.end_time||"").match(/^(\d+):(\d+)/);const shiftHours=start&&end?Math.max(0,(Number(end[1])+Number(end[2])/60)-(Number(start[1])+Number(start[2])/60)):0;const role=scheduleRowsById.get(String(entry.row_id))?.role_group||entry.role||employee.role;const rate=Number(employee.role_pay_rates?.[role] ?? employee.pay_rate_cents);return sum+(Number.isFinite(rate)?Math.round(shiftHours*rate):0);},0);
      const payRateCents=workedRates.length?Math.round(workedRates.reduce((sum,value)=>sum+value,0)/workedRates.length):null;
      return {employee,shifts,hours,payRateCents,estimatedPayCents:workedRates.length?estimatedPayCents:null};
    }).filter((row)=>row.shifts.length).sort((a,b)=>b.hours-a.hours);
    const staffingTable = employeeRows.length ? `<table class="data-table"><thead><tr><th>Employee</th><th>Role</th><th>Shifts</th><th>Estimated hours</th><th>Rate</th><th>Estimated pay</th><th>Conflicts</th></tr></thead><tbody>${employeeRows.map(({employee,shifts,hours,payRateCents,estimatedPayCents}) => `<tr><td><div class="cell-person"><span class="initial">${esc(initials(employee.display_name||employee.name))}</span><span><b>${esc(employee.display_name||employee.name)}</b><small>${esc(shifts.map((s)=>formatTime(s.start_time)).filter(Boolean).slice(0,3).join(" · ")||"Connected shifts")}</small></span></div></td><td>${pill(employee.role)}</td><td>${shifts.length}</td><td><b>${hours.toFixed(1)} h</b></td><td>${payRateCents==null?"Not set":`${money(payRateCents)}/h`}</td><td><b>${estimatedPayCents==null?"—":money(estimatedPayCents)}</b></td><td>${pill("Guarded")}</td></tr>`).join("")}</tbody></table>` : empty("No schedule assignments", "Choose a connected draft or published week with assignments.", "reports");
    const warnings = [];
    if (!entries.length) warnings.push("No assignments are available for this report view.");
    if (parties.length && !employeeRows.length) warnings.push(`${parties.length} parties are connected but no staffing assignments were returned.`);
    const auditRows = history.slice(0, 6);
    const dailyCoverage = dates.scheduleDates(state.weekStart).map((day)=>{const dayNumber=new Date(`${day.date}T12:00:00Z`).getUTCDay();const dayEntries=entries.filter((entry)=>Number(entry.day_of_week)===dayNumber);const dayParties=parties.filter((party)=>String(party.date||party.party_date).slice(0,10)===day.date);return `<div class="coverage-row"><span><b>${esc(day.name.slice(0,3))}</b><small>${esc(dateLabel(day.date,{month:"short",day:"numeric"}))}</small></span><i style="--coverage:${Math.min(100,dayEntries.length*8)}%"></i><b>${dayEntries.length} shifts</b>${pill(`${dayParties.length} parties`)}</div>`}).join("");
    const staffingView = `<div class="workspace-two"><section class="card workspace-panel"><div class="card-head"><div><h3>Employee Hours</h3><p>Current ${esc(titleCase(schedule.status||"schedule"))} · estimated from connected shift times</p></div></div>${staffingTable}</section><section class="card context-inspector"><div class="card-head"><div><h3>Day-by-day coverage</h3><p>${parties.length} parties connected this week</p></div></div><div class="card-body"><div class="coverage-list">${dailyCoverage}</div>${warnings.length ? warnings.map((warning)=>`<div class="info-banner warning">${esc(warning)}</div>`).join("") : `<div class="info-banner">No report-level warnings were generated from returned data.</div>`}<div class="detail-section"><h4>Manager audit</h4>${auditRows.map((item)=>`<div class="compact-row"><span class="row-copy"><b>${esc(titleCase(item.type||item.request_type))}</b><small>${esc(employeeName(item,employees))} · ${esc(dateLabel(item.reviewed_at||item.updated_at))}</small></span>${pill(item.status)}</div>`).join("")||"No recent decisions."}</div><div class="policy-note">Hours are estimates from schedule start/end times. Payroll remains outside this report.</div></div></section></div>`;
    const behaviorView = `<section class="card table-card"><div class="card-head"><div><h3>Hours & schedule behavior</h3><p>Connected shift count, estimated hours, and multi-shift load</p></div>${savedState("Calculated from schedule")}</div><table class="data-table"><thead><tr><th>Employee</th><th>Role</th><th>Assignments</th><th>Estimated hours</th><th>Multiple shifts</th><th>Protection</th></tr></thead><tbody>${employeeRows.map(({employee,shifts,hours})=>`<tr><td><b>${esc(employee.display_name||employee.name)}</b></td><td>${pill(employee.role)}</td><td>${shifts.length}</td><td><b>${hours.toFixed(1)} h</b></td><td>${pill(shifts.length>6?"review":"normal")}</td><td>${pill("Overlap guarded")}</td></tr>`).join("")||`<tr><td colspan="6">${empty("No behavior data","This week has no connected assignments to analyze.","reports")}</td></tr>`}</tbody></table><div class="card-body"><div class="policy-note">These are operational estimates only; they are not payroll or performance ratings.</div></div></section>`;
    const auditView = `<section class="card table-card"><div class="card-head"><div><h3>Manager audit</h3><p>Connected request decisions and recorded manager activity</p></div>${pill(`${history.length} records`)}</div><table class="data-table"><thead><tr><th>Date</th><th>Employee</th><th>Record</th><th>Status</th><th>Manager note</th></tr></thead><tbody>${history.map((item)=>`<tr><td>${esc(dateLabel(item.reviewed_at||item.updated_at||item.created_at,{month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}))}</td><td>${esc(employeeName(item,employees))}</td><td>${esc(titleCase(item.type||item.request_type||"activity"))}</td><td>${pill(item.status)}</td><td>${esc(item.manager_note||item.decision_note||"—")}</td></tr>`).join("")||`<tr><td colspan="5">${empty("No audit activity","Manager decisions will remain available here.","reports")}</td></tr>`}</tbody></table></section>`;
    const reportContent = state.reportsTab === "behavior" ? behaviorView : state.reportsTab === "audit" ? auditView : staffingView;
    const scheduleControls = state.reportsTab === "audit" ? "" : `<div class="schedule-context"><div class="view-switch"><button class="${state.scheduleView==="draft"?"active":""}" data-schedule-view="draft">Current Draft</button><button class="${state.scheduleView==="published"?"active":""}" data-schedule-view="published">Published</button></div>${pill(schedule.status||"No schedule")}</div>`;
    const weekEnd=dates.addDays(state.weekStart,5);const weekInvoices=invoices.filter((item)=>String(item.issue_date||item.event_date||"").slice(0,10)>=state.weekStart&&String(item.issue_date||item.event_date||"").slice(0,10)<=weekEnd);const weeklyInvoiceTotal=weekInvoices.reduce((sum,item)=>sum+Number(item.total_cents||0),0);const weeklyPayroll=employeeRows.reduce((sum,row)=>sum+Number(row.estimatedPayCents||0),0);
    return `<div class="page">${pageHead("reports", `<div class="week-picker"><button data-week-move="-7">‹</button><b>${esc(dateLabel(state.weekStart))}</b><button data-week-move="7">›</button></div>${savedState("Report calculated")}<button class="button" data-action="schedule-print">Print / Save As</button><button class="button" data-action="schedule-export">Export PNG</button><button class="primary-button" data-action="reports-export">Export CSV</button>`)}${tabBar([["staffing","Weekly Staffing"],["behavior","Hours & Behavior"],["audit","Manager Audit",history.length]], state.reportsTab, "reports-tab")}${scheduleControls}<div class="metric-grid report-metrics-six">${metric("Assigned cells",entries.length,"Connected schedule")}${metric("Staff scheduled",employeeRows.length,"Visible employees")}${metric("Estimated hours",employeeRows.reduce((sum,row)=>sum+row.hours,0).toFixed(1),"Calculated from shift times")}${metric("Weekly payroll",money(weeklyPayroll),"Role-specific estimate")}${metric("Invoice total",money(weeklyInvoiceTotal),`${weekInvoices.length} weekly documents`)}${metric("Warnings",warnings.length,"Review before export")}</div>${reportContent}</div>`;
  }

  function renderHopClub(data) {
    const dashboard = data.results[0]?.value?.dashboard || {};
    const customers = firstArray(data.results[1]?.value, ["customers"]);
    const rewards = firstArray(data.results[2]?.value, ["reward_rules", "rewards"]);
    const campaigns = firstArray(data.results[3]?.value, ["campaigns"]);
    const audit = firstArray(data.results[4]?.value, ["audit"]);
    const rewardMedia = firstArray(data.results[5]?.value, ["media"]);
    const selected = customers.find((item) => String(item.id) === String(state.selected?.id)) || customers[0];
    const memberRows = customers.length ? customers.map((member) => `<button class="master-row ${String(selected?.id)===String(member.id)?"selected":""}" data-select-hopclub="${esc(member.id)}"><span class="initial">${esc(initials(member.name))}</span><span class="row-copy"><b>${esc(member.name||"Member")}</b><small>${esc(member.phone||member.email||member.member_code||"No contact")}</small></span><b>${esc(Number(member.points_balance||0).toLocaleString())} pts</b>${pill(member.status||"active")}</button>`).join("") : empty("No HOP Club members", "New members will appear from the connected loyalty database.", "employees");
    const memberPanel = selected ? `<section class="card context-inspector">${inspectorTitle("MEMBER PROFILE",selected.name||"Member",selected.member_code||selected.phone||"HOP Club",selected.status||"active")}<div class="card-body"><div class="metric-grid compact-metrics">${metric("Points",Number(selected.points_balance||0).toLocaleString(),"Available balance")}${metric("Visits",selected.visit_count||selected.visits||0,"Recorded visits")}</div><div class="detail-grid"><span class="detail-item"><span>Phone</span><b>${esc(selected.phone||"Not set")}</b></span><span class="detail-item"><span>Email</span><b>${esc(selected.email||"Not set")}</b></span><span class="detail-item"><span>Birthday</span><b>${esc(selected.birthday||"Not set")}</b></span><span class="detail-item"><span>Joined</span><b>${esc(dateLabel(selected.created_at))}</b></span></div></div><div class="sticky-actions"><button class="button" data-action="hopclub-points" data-id="${esc(selected.id)}">Adjust points</button><button class="primary-button" data-action="hopclub-member-edit" data-id="${esc(selected.id)}">Edit member</button></div></section>` : card("Member profile",empty("Select a member","Choose a customer to inspect their connected account.","employees"));
    const overview = `<div class="metric-grid">${metric("Members",dashboard.total_members||customers.length,`${dashboard.new_members_30d||0} new in 30 days`)}${metric("Points outstanding",Number(dashboard.points_outstanding||0).toLocaleString(),"Current member balances")}${metric("Orders today",dashboard.orders_today||0,`${dashboard.active_orders||0} active`)}${metric("Today's sales",money(Math.round(Number(dashboard.sales_today||0)*100)),"HOP Club orders")}</div><div class="workspace-two"><section class="card workspace-panel"><div class="card-head"><div><h3>Recent members</h3><p>Connected customer and points records</p></div><button class="primary-button" data-action="hopclub-member-new">+ Add member</button></div>${memberRows}</section>${memberPanel}</div>`;
    const members = `<div class="workspace-two"><section class="card workspace-panel"><div class="card-head"><div><h3>Members</h3><p>${customers.length} connected HOP Club customers</p></div><button class="primary-button" data-action="hopclub-member-new">+ Add member</button></div>${filterToolbar({search:"Search name, phone, email, or member code"})}${memberRows}</section>${memberPanel}</div>`;
    const rewardView = `<section class="card"><div class="card-head"><div><h3>Reward ladder</h3><p>Visual rewards connected to the shared picture library</p></div><button class="primary-button" data-action="hopclub-reward-new">+ Add reward</button></div><div class="card-body"><div class="reward-card-grid">${rewards.map((rule)=>`<article class="reward-card">${rule.image_url?`<img src="${esc(mediaUrl(rule.image_url))}" alt="${esc(rule.title||rule.name)}">`:`<div class="reward-placeholder">★</div>`}<div><span>${esc(rule.trigger_type==="visit_count"?`${rule.visits_required||10} PURCHASES`:`${rule.points_required||0} POINTS`)}</span><h4>${esc(rule.title||rule.name)}</h4><p>${esc(rule.description||"")}</p><small>${esc(rule.code||"No code")} · ${rule.is_active===false?"Inactive":"Active"}</small></div><button class="button" data-action="hopclub-reward-edit" data-id="${esc(rule.id||rule.code)}">Edit</button></article>`).join("")||empty("No rewards configured","Create the first connected reward rule.","employees")}</div><div class="info-banner">Completed HOP Club tickets count as purchases. The 10-purchase dessert reward uses completed purchase history and consumes ten visit credits when redeemed.</div><small>${rewardMedia.length} reward pictures available in the shared media library.</small></div></section>`;
    const campaignView = `<div class="workspace-two"><section class="card workspace-panel"><div class="card-head"><div><h3>Announcements & campaigns</h3><p>Push now or schedule for HOP Club audiences</p></div><button class="primary-button" data-action="hopclub-campaign-new">+ New campaign</button></div>${campaigns.map((campaign)=>`<div class="document-row"><span class="row-copy"><b>${esc(campaign.title)}</b><small>${esc(titleCase(campaign.audience))} · ${esc(campaign.repeat_rule||"once")} · ${esc(campaign.schedule_at?dateLabel(campaign.schedule_at,{hour:"numeric",minute:"2-digit"}):"Immediate")}</small></span>${pill(campaign.status)}${campaign.status!=="sent"&&campaign.status!=="canceled"?`<button class="button" data-action="hopclub-campaign-send" data-id="${esc(campaign.id)}">Send now</button>`:""}</div>`).join("")||empty("No campaigns yet","Create a targeted member announcement.","notifications")}</section><section class="card context-inspector"><div class="card-head"><div><h3>Manager activity</h3><p>Audited loyalty changes</p></div></div><div class="card-body">${audit.slice(0,12).map((item)=>`<div class="compact-row"><span class="status-dot"></span><span class="row-copy"><b>${esc(titleCase(item.action))}</b><small>${esc(item.manager_name||"Manager")} · ${esc(dateLabel(item.created_at,{hour:"numeric",minute:"2-digit"}))}</small></span></div>`).join("")||`<div class="info-banner">No recent HOP Club management activity.</div>`}</div></section></div>`;
    const body = state.hopclubTab === "members" ? members : state.hopclubTab === "rewards" ? rewardView : state.hopclubTab === "campaigns" ? campaignView : overview;
    return `<div class="page">${pageHead("hopclub",`${savedState("Loyalty database synced")}<button class="primary-button" data-action="hopclub-campaign-new">Send announcement</button>`)}${tabBar([["overview","Overview"],["members","Members",customers.length],["rewards","Rewards",rewards.length],["campaigns","Campaigns",campaigns.length]],state.hopclubTab,"hopclub-tab")}${body}</div>`;
  }

  function renderNotifications(data) {
    const notifications = firstArray(data.results[0]?.value, ["notifications"]);
    const employees = firstArray(data.results[1]?.value, ["employees"]);
    const pushSummary = data.results[2]?.value || {};
    const subscriptions = firstArray(data.results[3]?.value, ["subscriptions"]);
    const pendingRequests = firstArray(data.results[4]?.value, ["requests","items","pending"]);
    const requestById = new Map(pendingRequests.map((request)=>[String(request.id),request]));
    const smartNotification = (item)=>{const linked=requestById.get(String(item.payload?.request_id||item.related_id||""));if(!linked)return {title:item.title||"Manager notification",detail:item.message||""};const who=employeeName(linked,employees);const type=titleCase(linked.type||linked.request_type||"request");const when=dateLabel(linked.start_date||linked.date);const conflicts=arr(linked.items).flatMap((entry)=>arr(entry.conflict_hints)).filter((hint)=>String(hint)!=="No conflicts found.");return {title:`${who} · ${type}`,detail:`${when}${conflicts.length?` · ${conflicts.length} schedule conflict${conflicts.length===1?"":"s"}`:" · no schedule conflict"}`};};
    const unread = notifications.filter((item)=>!(item.read_at||item.read)).length;
    const announcements = notifications.filter((item)=>/announcement/i.test(`${item.category||""} ${item.audience||""}`)).length;
    let visibleNotifications = state.notificationsTab === "announcements" ? notifications.filter((item)=>/announcement/i.test(`${item.category||""} ${item.audience||""}`)) : notifications;
    if (state.notificationsCategory !== "all") visibleNotifications = visibleNotifications.filter((item)=>String(item.category||"System").toLowerCase()===state.notificationsCategory);
    if (state.notificationsUnread) visibleNotifications = visibleNotifications.filter((item)=>!item.read_at&&!item.read);
    const selected = visibleNotifications.find((item) => String(item.id) === String(state.selected?.id)) || visibleNotifications[0];
    const categories = notifications.reduce((map,item)=>{const key=titleCase(item.category||"System");map[key]=(map[key]||0)+1;return map;},{});
    const categoryRail = `<section class="card workspace-panel"><div class="card-head"><div><h3>Categories</h3><p>Connected alert types</p></div></div><div class="subnav"><button class="${state.notificationsCategory==="all"?"active":""}" data-notification-category="all">All notifications <span>${notifications.length}</span></button>${Object.entries(categories).map(([name,count])=>`<button class="${state.notificationsCategory===name.toLowerCase()?"active":""}" data-notification-category="${esc(name.toLowerCase())}">${esc(name)} <span>${count}</span></button>`).join("")}</div><div class="card-body"><label class="compact-row"><span class="row-copy"><b>Unread only</b><small>Filter the current feed</small></span><input type="checkbox" data-notification-unread ${state.notificationsUnread?"checked":""}></label><div class="section-label">Date range</div><span class="filter-chip active">Latest 200 connected records</span></div></section>`;
    const feed = visibleNotifications.length ? visibleNotifications.map((item,index)=>{const smart=smartNotification(item);return `${index===0?`<div class="section-label" style="padding:0 9px">Today / Recent</div>`:""}<button class="master-row ${String(selected?.id)===String(item.id)?"selected":""}" data-select-notification="${esc(item.id)}"><span class="initial">${/schedule/i.test(item.category)?"S":/party/i.test(item.category)?"P":"!"}</span><span class="row-copy"><b>${esc(smart.title)}</b><small>${esc(smart.detail)} · ${esc(dateLabel(item.created_at,{hour:"numeric",minute:"2-digit"}))}</small></span>${pill(item.read_at||item.read?"read":"unread")}</button>`}).join("") : empty("No notifications in this view", "Choose another notification tab.", "notifications");
    const detail = selected ? `<section class="card context-inspector">${inspectorTitle("NOTIFICATION DETAILS", selected.title||"Manager notification", titleCase(selected.category||"System"), selected.read_at||selected.read?"read":"unread")}<div class="card-body"><p>${esc(selected.message||"No notification detail returned.")}</p><div class="detail-section"><h4>Source & audience</h4><div class="detail-grid"><span class="detail-item"><span>Category</span><b>${esc(titleCase(selected.category||"System"))}</b></span><span class="detail-item"><span>Audience</span><b>${esc(titleCase(selected.audience||"Manager"))}</b></span><span class="detail-item"><span>Created</span><b>${esc(dateLabel(selected.created_at,{hour:"numeric",minute:"2-digit"}))}</b></span><span class="detail-item"><span>Delivery</span><b>${esc(titleCase(selected.delivery_status||"Recorded"))}</b></span></div></div><div class="info-banner">Delivery status is shown only when returned by the connected push service.</div><div class="detail-section"><h4>Related record</h4><p>${esc(selected.related_type||selected.source_module||"No related module was identified.")}</p></div></div><div class="sticky-actions"><button class="button" data-action="notification-open" data-id="${esc(selected.id)}">Open details</button><button class="primary-button" data-action="notification-open" data-id="${esc(selected.id)}">Mark / review</button></div></section>` : card("Notification details",empty("Select a notification","Choose an alert to inspect.","notifications"));
    const deliveryRows = subscriptions.map((item)=>`<tr><td><b>${esc(item.employee_name||item.customer_name||titleCase(item.user_type||"Device"))}</b><br><small>${esc(titleCase(item.user_type||"subscription"))}</small></td><td>${pill(item.is_active===false?"inactive":"active")}</td><td>${esc(item.last_success_at?dateLabel(item.last_success_at,{hour:"numeric",minute:"2-digit"}):"Never")}</td><td>${esc(item.last_failure_at?dateLabel(item.last_failure_at,{hour:"numeric",minute:"2-digit"}):"—")}</td></tr>`).join("");
    const deliveryView = `<div class="workspace-two notification-delivery-workspace"><section class="card table-card"><div class="card-head"><div><h3>Registered notification devices</h3><p>Real push subscription state returned by Hostinger</p></div>${pill(pushSummary.configured?"configured":"needs setup")}</div><table class="data-table"><thead><tr><th>Recipient / device</th><th>Status</th><th>Last success</th><th>Last failure</th></tr></thead><tbody>${deliveryRows||`<tr><td colspan="4">No registered notification devices were returned.</td></tr>`}</tbody></table></section><section class="card context-inspector"><div class="card-head"><div><h3>Delivery health</h3><p>Current server summary</p></div></div><div class="card-body"><div class="detail-grid"><span class="detail-item"><span>Active devices</span><b>${esc(pushSummary.active_subscriptions||0)}</b></span><span class="detail-item"><span>Inactive devices</span><b>${esc(pushSummary.inactive_subscriptions||0)}</b></span><span class="detail-item"><span>Staff enabled</span><b>${esc(pushSummary.employees_with_notifications||0)}</b></span><span class="detail-item"><span>Staff missing</span><b>${esc(pushSummary.employees_without_notifications||0)}</b></span></div><div class="info-banner ${pushSummary.configured?"":"warning"}">${pushSummary.configured?"Push keys are configured. Delivery still depends on each registered device and browser permission.":esc(pushSummary.warning||"Push keys are not configured on the server.")}</div></div></section></div>`;
    const notificationView = `<div class="workspace-three">${categoryRail}<section class="card workspace-panel"><div class="card-head"><div><h3>Notification feed</h3><p>Newest connected alerts first</p></div></div>${feed}</section>${detail}</div>`;
    return `<div class="page">${pageHead("notifications", `<button class="button" data-action="notifications-read-all">Mark all read</button><button class="primary-button" data-action="notification-new">+ New announcement</button>`)}${tabBar([["all","All Notifications",notifications.length],["announcements","Announcements",announcements],["delivery","Delivery & Devices",subscriptions.length]], state.notificationsTab, "notifications-tab")}<div class="metric-grid">${metric("Unread",unread,"Manager alerts")}${metric("Active devices",pushSummary.active_subscriptions||0,pushSummary.configured?"Push configured":"Push needs setup")}${metric("Staff enabled",pushSummary.employees_with_notifications||0,`${pushSummary.employees_without_notifications||0} staff missing`)}${metric("Announcements",announcements,"Recorded staff messages")}</div>${state.notificationsTab==="delivery"?deliveryView:notificationView}</div>`;
  }

  function renderSettings(data) {
    const raw = data.results[0]?.value || {};
    const settings = raw.settings || raw;
    const get = (key, fallback = "") => settings[key]?.value ?? settings[key] ?? fallback;
    const prefs = appearancePreferences();
    const profile = get("restaurant_profile", {}); const pricing = get("hop_pricing", {}); const notifications = get("notifications", {});
    const publishedPricing = pricing.published || pricing;
    const draftPricing = pricing.draft || publishedPricing;
    const printStatus = data.results[1]?.value || {};
    const printConfig = printStatus.config || {};
    const printJobs = arr(printStatus.jobs);
    const printCounts = Object.fromEntries(arr(printStatus.counts).map((item)=>[item.status,Number(item.count||0)]));
    const copyRules = printConfig.copy_rules || {};
    const copyRuleRow = (key,label,defaults) => `<div class="copy-rule-row"><span><b>${esc(label)}</b><small>${esc(key==="purchase"?"Completed loyalty purchase":key==="reward"?"Reward redemption":"Manager points adjustment")}</small></span>${["customer","drawer","kitchen","manager"].map((destination)=>`<label><input type="checkbox" name="copy_${esc(key)}_${destination}" ${(copyRules[key]?.[destination] ?? defaults[destination])?"checked":""}><span>${esc(titleCase(destination))}</span></label>`).join("")}</div>`;
    const pricingCard = card("Pricing & tax", `<div class="form-grid"><div class="form-control"><label>Published tax rate</label><input value="${esc((Number(publishedPricing.rate_basis_points || 0) / 100).toFixed(2))}%" disabled></div><div class="form-control"><label>Draft tax rate (%)</label><input name="tax_rate" type="number" min="0" max="25" step="0.01" value="${esc(Number(draftPricing.rate_basis_points || 0) / 100)}"></div><div class="form-control"><label>Tax enabled</label><select name="tax_enabled"><option value="true" ${draftPricing.tax_enabled !== false ? "selected" : ""}>Enabled</option><option value="false" ${draftPricing.tax_enabled === false ? "selected" : ""}>Disabled</option></select></div><div class="form-control"><label>Menu prices include tax</label><select name="prices_include_tax"><option value="false" ${draftPricing.prices_include_tax !== true ? "selected" : ""}>No — add tax at checkout</option><option value="true" ${draftPricing.prices_include_tax === true ? "selected" : ""}>Yes — tax already included</option></select></div><div class="form-control full"><label>Calculation contract</label><input value="Tax = rounded taxable subtotal × rate; 10% is stored as 1000 basis points" disabled></div></div><div class="policy-note">${pricing.draft_dirty ? "A tax draft differs from the published checkout rate." : "Draft and published tax settings match."} Saving here updates the draft safely; publishing remains a separate manager action in the HOP pricing manager.</div>`, "Published checkout and draft pricing are shown separately");
    const nav = `<section class="card subnav">${[["general","General"],["access","Access & Security"],["notifications","Notifications"],["printing","Printing & Export"],["connections","Connections & Devices"],["appearance","Appearance"],["about","About"]].map(([id,label])=>`<button class="${state.settingsTab===id?"active":""}" data-settings-tab="${id}">${esc(label)}</button>`).join("")}</section>`;
    const connections = `<div class="settings-stack"><section class="card"><div class="card-head"><div><h3>Connections & Devices</h3><p>Verified services and local equipment</p></div>${savedState("Connection state current")}</div><div class="connection-card"><span class="connection-icon">H</span><div><h4>Hostinger Backend</h4><p>Shared manager API and PostgreSQL data source.</p><div class="connection-meta"><span>${esc(API_BASE||"Same origin")}</span><span>America/New_York</span></div></div>${pill("connected")}</div><div class="connection-card"><span class="connection-icon">P</span><div><h4>Employee PWA & Push</h4><p>Employee schedule, availability, requests, and registered push topics.</p><div class="connection-meta"><span>Registration managed by connected API</span></div></div>${pill("connected")}</div><div class="connection-card"><span class="connection-icon">⌁</span><div><h4>Schedule Printer</h4><p>Printer address and paper defaults require a configured Print Bridge device.</p></div>${pill("not configured")}</div><div class="connection-card"><span class="connection-icon">D</span><div><h4>DoorDash</h4><p>No approved DoorDash connection was returned by current settings.</p></div>${pill("not connected")}</div></section><section class="card"><div class="card-head"><div><h3>Data & Export</h3><p>Safe local output preferences</p></div></div><div class="card-body"><div class="form-grid"><div class="form-control"><label>Schedule export</label><select disabled><option>PNG + Print</option></select></div><div class="form-control"><label>Document paper</label><select disabled><option>US Letter</option></select></div></div><div class="info-banner">Exports use connected records already loaded in the manager session. No parallel database is created.</div></div></section></div>`;
    const general = `<div class="settings-stack">${card("Restaurant & schedule", `<div class="form-grid"><div class="form-control"><label>Restaurant time zone</label><input value="America/New_York" disabled></div><div class="form-control"><label>Schedule week</label><input value="Tuesday–Sunday (closed Monday)" disabled></div><div class="form-control"><label>Restaurant name</label><input name="restaurant_name" value="${esc(profile.name || "House of Pizza & Pasta")}"></div><div class="form-control"><label>Phone</label><input name="restaurant_phone" value="${esc(profile.phone || "")}"></div></div>`, "Canonical dates are enforced across desktop and web")}${pricingCard}${card("Manager notifications", `<div class="form-grid"><div class="form-control"><label>Day-off alerts</label><select name="manager_day_off"><option value="true" ${notifications.managerDayOff !== false ? "selected" : ""}>Enabled</option><option value="false" ${notifications.managerDayOff === false ? "selected" : ""}>Disabled</option></select></div><div class="form-control"><label>Sound</label><select name="notification_sound"><option value="true" ${notifications.sound !== false ? "selected" : ""}>Enabled</option><option value="false" ${notifications.sound === false ? "selected" : ""}>Disabled</option></select></div></div>`)}</div>`;
    const access = `<div class="settings-stack">${card("Access & security", `<div class="record-summary"><span><small>Signed in as</small><b>${esc(manager()?.name||"Manager")}</b></span><span><small>PIN storage</small><b>Salted scrypt hash</b></span><span><small>Session</small><b>Manager-only</b></span><span><small>Time zone</small><b>America/New_York</b></span></div><div class="policy-note">Existing web and employee flows remain available. This pilot uses the same authenticated backend.</div><button class="danger-button" id="logoutButton" style="margin-top:10px">Sign out</button>`)}</div>`;
    const notificationPanel = `<div class="settings-stack">${card("Push Notification Center",`<div class="detail-grid"><span class="detail-item"><span>Staff delivery</span><b>All staff, managers, or one employee</b></span><span class="detail-item"><span>HOP Club audiences</span><b>All, VIP, or inactive members</b></span><span class="detail-item"><span>Scheduling</span><b>Once, daily, or weekly campaigns</b></span><span class="detail-item"><span>Audit</span><b>Manager reason recorded</b></span></div><button class="primary-button" data-action="notification-new" style="margin-top:12px">Open Notification Center</button>`,`Connected staff and customer push workflows`)}</div>`;
    const bridgeFresh = state.bridge.running || (printStatus.bridge?.last_seen && Date.now()-new Date(printStatus.bridge.last_seen).getTime()<180000);
    const printRows = printJobs.slice(0,40).map((job)=>`<tr><td><b>${esc(titleCase(job.job_type))}</b><br><small>${esc(job.printer_key||"front counter")}</small></td><td>${pill(job.status)}</td><td>${esc(job.attempts||0)}</td><td>${esc(job.last_error||"—")}</td><td><div class="row-actions">${/pending|retry/.test(job.status)?`<button class="danger-button" data-action="print-job-cancel" data-id="${esc(job.id)}">Cancel</button>`:""}${job.status==="retry"?`<button class="button" data-action="print-job-retry" data-id="${esc(job.id)}">Retry</button>`:""}${/printed|archived|canceled/.test(job.status)?`<button class="button" data-action="print-job-reprint" data-id="${esc(job.id)}">Reprint</button>`:""}</div></td></tr>`).join("");
    const printing = `<div class="settings-stack"><section class="card"><div class="card-head"><div><h3>Printer Center</h3><p>Automatic Windows bridge, queue, and copy rules</p></div>${pill(bridgeFresh&&!state.bridge.lastError?"online":"offline")}</div><div class="card-body"><div class="metric-grid compact-metrics">${metric("Waiting",(printCounts.pending||0)+(printCounts.retry||0),"Queue")}${metric("Printed",printCounts.printed||0,"Completed")}${metric("Archived",printCounts.archived||0,"Audit kept")}${metric("Bridge",bridgeFresh?"Running":"Offline",state.bridge.lastError||printStatus.bridge?.message||"No recent heartbeat")}</div><div class="info-banner">The installed app discovers Windows printers, pairs securely, claims queued tickets, prints, and reports the result automatically.</div><div class="form-grid"><div class="form-control"><label>Enabled</label><select name="print_enabled"><option value="true" ${printConfig.enabled!==false?"selected":""}>Enabled</option><option value="false" ${printConfig.enabled===false?"selected":""}>Paused</option></select></div><div class="form-control"><label>Windows printer</label><input name="printer_name" value="${esc(state.bridge.printer||printConfig.printer_name||"")}" placeholder="Use Detect printers"></div><div class="form-control"><label>Network address (optional)</label><input name="printer_ip" value="${esc(printConfig.printer_ip||"")}" placeholder="Not needed for Windows spooler"></div><div class="form-control"><label>Default copies</label><input name="print_copies" type="number" min="1" max="3" value="${esc(printConfig.copies||1)}"></div></div><div class="section-label">Automatic copy rules</div><div class="copy-rule-grid"><div class="copy-rule-head"><span>Event</span><span>Customer</span><span>Drawer</span><span>Kitchen</span><span>Manager</span></div>${copyRuleRow("purchase","Loyalty purchase",{customer:false,drawer:true,kitchen:false,manager:false})}${copyRuleRow("reward","Reward redemption",{customer:false,drawer:true,kitchen:true,manager:false})}${copyRuleRow("manual_adjustment","Points adjustment",{customer:false,drawer:true,kitchen:false,manager:true})}</div><div class="bridge-detail"><span><small>Bridge ID</small><b>${esc(state.bridge.id||printStatus.bridge?.bridge_id||"Not connected")}</b></span><span><small>Last heartbeat</small><b>${esc(state.bridge.heartbeatAt?dateLabel(state.bridge.heartbeatAt,{hour:"numeric",minute:"2-digit"}):printStatus.bridge?.last_seen?dateLabel(printStatus.bridge.last_seen,{hour:"numeric",minute:"2-digit"}):"Never")}</b></span><span><small>Printer response</small><b>${esc(state.bridge.lastError||printStatus.bridge?.message||"Ready to pair")}</b></span></div><div class="sticky-actions inline-actions"><button class="button" data-action="printer-discover">Detect printers</button><button class="button" data-action="bridge-connect">Connect this computer</button><button class="button" data-action="print-test">Print test ticket</button><button class="button" data-action="print-retry-failed">Retry failed</button><button class="button" data-action="print-cancel-waiting">Cancel waiting</button><button class="button" data-action="print-clear-completed">Archive completed</button><button class="primary-button" data-action="print-settings-save">Save printer</button></div></div></section><section class="card"><div class="card-head"><div><h3>Print queue</h3><p>Latest 40 jobs; completed history is archived, never deleted</p></div>${savedState("Queue synced")}</div><div class="table-card"><table class="data-table"><thead><tr><th>Job</th><th>Status</th><th>Attempts</th><th>Last error</th><th>Action</th></tr></thead><tbody>${printRows||`<tr><td colspan="5">No print jobs returned.</td></tr>`}</tbody></table></div></section>${card("File exports",`<div class="detail-grid"><span class="detail-item"><span>Schedule</span><b>Preview + PNG + Print/PDF</b></span><span class="detail-item"><span>Invoices</span><b>Live preview + US Letter/PDF</b></span><span class="detail-item"><span>Reports</span><b>CSV</b></span><span class="detail-item"><span>Applications</span><b>Print / Save PDF</b></span></div>`)}</div>`;
    const appearance = `<div class="settings-stack">${card("Appearance & workspace",`<div class="form-grid"><div class="form-control"><label>Theme</label><select name="appearance_theme"><option value="system" ${prefs.theme==="system"?"selected":""}>Follow device</option><option value="light" ${prefs.theme==="light"?"selected":""}>Light</option><option value="dark" ${prefs.theme==="dark"?"selected":""}>Dark</option></select></div><div class="form-control"><label>Font size</label><select name="appearance_font"><option value="standard" ${prefs.font==="standard"?"selected":""}>Standard</option><option value="large" ${prefs.font==="large"?"selected":""}>Large · recommended</option></select></div><div class="form-control"><label>Workspace density</label><select name="appearance_density"><option value="comfortable" ${prefs.density==="comfortable"?"selected":""}>Comfortable</option><option value="compact" ${prefs.density==="compact"?"selected":""}>Compact</option></select></div><div class="form-control"><label>Automatic refresh</label><select name="appearance_refresh"><option value="0" ${prefs.autoRefresh==="0"?"selected":""}>Manual only</option><option value="2" ${prefs.autoRefresh==="2"?"selected":""}>Every 2 minutes</option><option value="5" ${prefs.autoRefresh==="5"?"selected":""}>Every 5 minutes</option><option value="10" ${prefs.autoRefresh==="10"?"selected":""}>Every 10 minutes</option></select></div><label class="settings-check"><input type="checkbox" name="appearance_remember" ${prefs.rememberRoute?"checked":""}><span><b>Reopen the last module</b><small>Remember this computer's workspace.</small></span></label><label class="settings-check"><input type="checkbox" name="appearance_conflicts" ${prefs.showConflicts?"checked":""}><span><b>Always show schedule conflicts</b><small>Keep warnings visible until resolved or manager-overridden.</small></span></label></div><div class="policy-note">Display preferences are saved on this computer. Shared restaurant data remains unchanged.</div>`)}</div>`;
    const about = `<div class="settings-stack">${card("HOP Command Center",`<div class="record-summary"><span><small>Edition</small><b>Native manager pilot</b></span><span><small>Data source</small><b>Shared Hostinger PostgreSQL</b></span><span><small>Web manager</small><b>Preserved separately</b></span><span><small>Week contract</small><b>Tuesday–Sunday</b></span></div>`)}</div>`;
    const content = state.settingsTab==="connections" ? connections : state.settingsTab==="printing" ? printing : state.settingsTab==="access" ? access : state.settingsTab==="notifications" ? notificationPanel : state.settingsTab==="appearance" ? appearance : state.settingsTab==="about" ? about : general;
    const saveActions = state.settingsTab==="general" ? `${savedState()}<button class="button" data-refresh>Discard changes</button><button class="primary-button" data-action="settings-save">Save settings</button>` : state.settingsTab==="appearance" ? `${savedState("Saved on this computer")}<button class="primary-button" data-action="appearance-save">Apply appearance</button>` : savedState("Connected settings loaded");
    return `<div class="page" id="settingsPage">${pageHead("settings", saveActions)}<div class="info-banner" style="margin-bottom:9px">Connection controls never claim a service or printer is online unless the connected system returns that state.</div><div class="settings-workspace">${nav}${content}</div></div>`;
  }

  function renderEmployeeMobile(data) {
    const payload = data.results[0]?.value || {};
    const employee = payload.employee || { display_name: "Mo", role: "employee" };
    const health = payload.health || {};
    const checks = arr(health.checks);
    const release = payload.release || {};
    const summary = payload.summary || {};
    const entries = arr(payload.schedule?.entries);
    const availability = arr(payload.availability?.availability);
    const assignments = arr(payload.tasks?.assignments);
    const notifications = arr(payload.notifications);
    const requests = arr(payload.requests);
    const telemetry = arr(payload.telemetry);
    const dayOffset = (day) => ({2:0,3:1,4:2,5:3,6:4,0:5})[Number(day)] ?? 0;
    const shiftDate = (entry) => dates.addDays(payload.week_start || state.weekStart, dayOffset(entry.day_of_week));
    const previewTabs = [["home","Home"],["schedule","Shifts"],["availability","Availability"],["requests","Requests"],["tasks","Tasks"],["notifications","Alerts"],["profile","Profile"]];
    const studio = {
      accent: localStorage.getItem("hop_mobile_accent") || "#08745d",
      surface: localStorage.getItem("hop_mobile_surface") || "#fffdf8",
      radius: localStorage.getItem("hop_mobile_radius") || "24",
      density: localStorage.getItem("hop_mobile_density") || "comfortable",
      motion: localStorage.getItem("hop_mobile_motion") || "soft"
    };
    const mobileEmpty = (title, detail) => `<div class="employee-phone-empty"><b>${esc(title)}</b><small>${esc(detail)}</small></div>`;
    const shiftList = entries.length ? entries.map((entry)=>`<article class="employee-phone-row"><span class="employee-phone-date"><b>${esc(dateLabel(shiftDate(entry),{weekday:"short"}))}</b><small>${esc(dateLabel(shiftDate(entry),{month:"short",day:"numeric"}))}</small></span><span><b>${esc(entry.shift_label||entry.row_label||entry.role||"Shift")}</b><small>${esc(formatTime(entry.start_time))} – ${esc(formatTime(entry.end_time))}</small></span>${pill(entry.role||"scheduled")}</article>`).join("") : mobileEmpty("No published shifts", "The preview matches what Mo receives for this week.");
    const availabilityGrid = availability.length ? `<div class="employee-phone-availability">${availability.map((slot)=>`<span class="${esc(slot.status||"default")}"><b>${esc(titleCase(slot.day).slice(0,3))} ${esc(slot.shift_key)}</b><small>${esc(titleCase(slot.status||"default"))}</small></span>`).join("")}</div>` : mobileEmpty("Default availability", "No custom Mo availability was returned for this week.");
    const requestList = requests.length ? requests.slice(0,8).map((item)=>`<article class="employee-phone-row"><span class="employee-phone-symbol">↗</span><span><b>${esc(titleCase(item.type||item.request_type||"Request"))}</b><small>${esc(dateLabel(item.date||item.start_date||item.created_at))}</small></span>${pill(item.status||"pending")}</article>`).join("") : mobileEmpty("No pending requests", "Mo has no open requests in the manager queue.");
    const taskList = assignments.length ? assignments.slice(0,10).map((item)=>`<article class="employee-phone-row"><span class="employee-phone-symbol">${item.completed_at||item.done?"✓":"○"}</span><span><b>${esc(item.title||"Shift task")}</b><small>${esc(item.assignment_label||item.shift_label||item.task_date||"")}</small></span></article>`).join("") : mobileEmpty("No shift tasks", "Tasks appear only when they match Mo's published shift.");
    const notificationList = notifications.length ? notifications.slice(0,8).map((item)=>`<article class="employee-phone-row"><span class="employee-phone-symbol">${item.read_at||item.read?"✓":"!"}</span><span><b>${esc(item.title||"Notification")}</b><small>${esc(item.message||dateLabel(item.created_at))}</small></span></article>`).join("") : mobileEmpty("No notifications", "No staff notifications were returned for Mo.");
    const home = `<div class="employee-phone-hero"><span>${esc(dateLabel(dates.today(),{weekday:"long",month:"short",day:"numeric"}))}</span><h3>Welcome back, ${esc(employee.display_name||"Mo")}</h3><small>${esc(titleCase(employee.role||"employee"))} · Mo canary</small></div><div class="employee-phone-stats"><span><small>Shifts</small><b>${esc(summary.shifts||0)}</b></span><span><small>Hours</small><b>${esc(summary.hours||0)}h</b></span><span><small>Tasks</small><b>${esc(summary.tasks_open||0)}</b></span><span><small>Unread</small><b>${esc(summary.notifications_unread||0)}</b></span></div><section class="employee-phone-card"><h4>This week</h4>${entries[0]?`<div class="employee-phone-next"><b>${esc(entries[0].shift_label||entries[0].row_label||"Next published shift")}</b><small>${esc(dateLabel(shiftDate(entries[0]),{weekday:"long",month:"short",day:"numeric"}))} · ${esc(formatTime(entries[0].start_time))}–${esc(formatTime(entries[0].end_time))}</small></div>`:mobileEmpty("No published shift yet","The app will update after a manager publishes the week.")}</section><section class="employee-phone-card"><h4>Latest notifications</h4>${notifications.slice(0,2).map((item)=>`<div class="employee-phone-next"><b>${esc(item.title||"Staff update")}</b><small>${esc(item.message||"")}</small></div>`).join("")||mobileEmpty("You're caught up","No staff alerts are waiting.")}</section>`;
    const screens = {
      home,
      schedule: `<div class="employee-phone-title"><span>MY WEEK</span><h3>Published shifts</h3></div>${shiftList}`,
      availability: `<div class="employee-phone-title"><span>WEEK OF ${esc(dateLabel(payload.week_start))}</span><h3>Availability</h3></div>${availabilityGrid}<div class="employee-phone-note">Preview only. Managers cannot change Mo's availability from this screen.</div>`,
      requests: `<div class="employee-phone-title"><span>CONNECTED REQUESTS</span><h3>My requests</h3></div>${requestList}`,
      tasks: `<div class="employee-phone-title"><span>ASSIGNED BY SHIFT</span><h3>Side work</h3></div>${taskList}`,
      notifications: `<div class="employee-phone-title"><span>STAFF UPDATES</span><h3>Notifications</h3></div>${notificationList}`,
      profile: `<div class="employee-phone-title"><span>EMPLOYEE ACCOUNT</span><h3>${esc(employee.display_name||"Mo")}</h3></div><div class="employee-phone-profile"><span class="employee-phone-avatar">${esc(initials(employee.display_name||"Mo"))}</span><b>${esc(titleCase(employee.role||"employee"))}</b><small>${esc(employee.status||"active")} · ${esc(release.scope||"Mo only")}</small></div><section class="employee-phone-card"><div class="employee-phone-next"><b>App build</b><small>${esc(release.build||"unknown")} · ${esc(release.cache||"unknown cache")}</small></div><div class="employee-phone-next"><b>Push device</b><small>${esc(arr(payload.devices).length)} active device(s)</small></div></section>`
    };
    const activeScreen = screens[state.employeeMobileScreen] ? state.employeeMobileScreen : "home";
    const checkList = checks.map((check)=>`<button class="employee-health-row" data-route="watchdog"><span class="employee-health-icon ${esc(check.status)}">${check.status==="healthy"?"✓":"!"}</span><span><b>${esc(check.name)}</b><small>${esc(check.message||"No detail returned.")}</small></span>${pill(check.status)}</button>`).join("") || mobileEmpty("Diagnostics unavailable","Refresh after the connected backend is updated.");
    const rail = `<section class="card employee-mobile-rail"><div class="card-head"><div><h3>Mo canary</h3><p>One employee, controlled rollout</p></div>${pill(employee.status||"unknown")}</div><div class="card-body"><div class="employee-canary-person"><span class="initial">${esc(initials(employee.display_name||"Mo"))}</span><span><b>${esc(employee.display_name||"Mo")}</b><small>${esc(titleCase(employee.role||"employee"))}</small></span></div><div class="employee-health-summary ${esc(payload.status||"warning")}"><b>${esc(titleCase(payload.status||"unavailable"))}</b><small>${esc(health.issue_count||0)} issues · ${esc(health.warning_count||0)} warnings</small></div><div class="section-label">Live checks</div>${checkList}</div></section>`;
    const phone = `<section class="employee-mobile-preview"><div class="employee-preview-tabs">${previewTabs.map(([id,label])=>`<button class="${activeScreen===id?"active":""}" data-mobile-screen="${id}">${esc(label)}</button>`).join("")}</div><div class="employee-device mobile-density-${esc(studio.density)} mobile-motion-${esc(studio.motion)}" style="--mobile-accent:${esc(studio.accent)};--mobile-surface:${esc(studio.surface)};--mobile-radius:${esc(studio.radius)}px"><div class="employee-device-notch"></div><header><img src="./assets/official-hop-logo.png" alt="HOP"><span><b>HOP STAFF</b><small>MY SHIFT · MY TEAM</small></span><i class="${esc(payload.status||"warning")}"></i></header><main>${screens[activeScreen]}</main><nav>${[["home","⌂","Home"],["schedule","▦","Shifts"],["requests","↗","Requests"],["tasks","✓","Tasks"],["profile","○","Me"]].map(([id,symbol,label])=>`<button class="${activeScreen===id?"active":""}" data-mobile-screen="${id}"><b>${symbol}</b><small>${label}</small></button>`).join("")}</nav></div><div class="employee-preview-policy">${esc(payload.preview_policy||"Read-only manager preview. No employee data is changed.")}</div></section>`;
    const studioPanel = state.employeeMobileStudio ? `<section class="card mobile-studio-panel"><div class="card-head"><div><h3>Employee Mobile Studio</h3><p>Visual controls affect this manager preview only until published.</p></div>${pill("Preview")}</div><div class="card-body"><div class="form-grid"><div class="form-control"><label>Brand color</label><input type="color" value="${esc(studio.accent)}" data-mobile-style="accent"></div><div class="form-control"><label>Surface color</label><input type="color" value="${esc(studio.surface)}" data-mobile-style="surface"></div><div class="form-control"><label>Card corners</label><input type="range" min="8" max="36" value="${esc(studio.radius)}" data-mobile-style="radius"><small>${esc(studio.radius)} px</small></div><div class="form-control"><label>Layout density</label><select data-mobile-style="density"><option value="comfortable" ${studio.density==="comfortable"?"selected":""}>Comfortable</option><option value="compact" ${studio.density==="compact"?"selected":""}>Compact</option><option value="spacious" ${studio.density==="spacious"?"selected":""}>Spacious</option></select></div><div class="form-control"><label>Motion</label><select data-mobile-style="motion"><option value="soft" ${studio.motion==="soft"?"selected":""}>Soft</option><option value="none" ${studio.motion==="none"?"selected":""}>None</option><option value="spring" ${studio.motion==="spring"?"selected":""}>Spring</option></select></div></div><div class="studio-component-row"><button class="button" data-mobile-screen="home">Cards</button><button class="button" data-mobile-screen="schedule">Schedule rows</button><button class="button" data-mobile-screen="requests">Drawers & requests</button><button class="button" data-mobile-screen="notifications">Notifications</button></div><div class="info-banner">This studio never signs in as Mo. The phone preview is populated by Mo's real published schedule, requests, tasks, notification and device-health APIs.</div></div></section>` : "";
    const last = telemetry[0];
    const inspector = `<section class="card context-inspector employee-mobile-inspector">${inspectorTitle("EMPLOYEE APP STATUS",payload.status==="healthy"?"Mo app is responding":"Mo app needs attention",payload.checked_at?`Checked ${new Date(payload.checked_at).toLocaleString()}`:"No completed check",payload.status||"warning")}<div class="card-body"><div class="metric-grid compact-metrics">${metric("Build",release.build||"unknown","Employee Next")}${metric("Devices",arr(payload.devices).length,"Active push")}</div><div class="detail-section"><h4>Last device heartbeat</h4>${last?`<div class="employee-telemetry"><b>${esc(titleCase(last.event||last.action))}</b><small>${esc(new Date(last.created_at).toLocaleString())}</small><p>${esc(last.message||"No message")}</p></div>`:`<div class="info-banner warning">No device heartbeat yet. It will appear after Mo opens the updated app.</div>`}</div><div class="detail-section"><h4>Release proof</h4><div class="detail-grid"><span class="detail-item"><span>Route</span><b>${esc(release.route||"/employee-next/")}</b></span><span class="detail-item"><span>Cache</span><b>${esc(release.cache||"unknown")}</b></span><span class="detail-item"><span>Assets</span><b>${esc(arr(release.files).filter((item)=>item.present).length)}/${esc(arr(release.files).length||4)} present</b></span><span class="detail-item"><span>Scope</span><b>${esc(release.scope||"Mo only")}</b></span></div></div><div class="info-banner">This screen uses manager authentication and never signs in as Mo.</div></div><div class="sticky-actions"><button class="button" data-route="watchdog">Open Watchdog</button><button class="primary-button" data-refresh>Run check now</button></div></section>`;
    return `<div class="page">${pageHead("employee-mobile",`${savedState(payload.checked_at?"Connected check complete":"Waiting for backend")}<button class="button" data-action="employee-mobile-studio">${state.employeeMobileStudio?"Close Studio":"Open Visual Studio"}</button><button class="button" data-route="watchdog">Diagnostics</button><button class="primary-button" data-refresh>Refresh Mo app</button>`)}<div class="metric-grid">${metric("Employee",employee.display_name||"Mo","Canary only")}${metric("Published shifts",summary.shifts||0,`${summary.hours||0} hours`)}${metric("Open tasks",summary.tasks_open||0,"Shift-matched")}${metric("Unread alerts",summary.notifications_unread||0,"Connected notifications")}</div>${studioPanel}<div class="employee-mobile-shell">${rail}${phone}${inspector}</div></div>`;
  }

  function renderWatchdog(data) {
    const payload = data.results[0]?.value || {};
    const checks = arr(payload.checks);
    const issues = checks.filter((check)=>!/healthy|ok|connected|ready/i.test(check.status||""));
    const selected = checks.find((check)=>String(check.name)===String(state.selected?.id)) || issues[0] || checks[0];
    const rail = `<section class="card workspace-panel"><div class="card-head"><div><h3>Monitoring</h3><p>Read-only controls</p></div></div><div class="subnav"><button class="active">Overview <span>${checks.length}</span></button><button>Active issues <span>${issues.length}</span></button><button>History</button><button>Repairs</button></div><div class="card-body"><div class="section-label">Monitoring schedule</div><div class="compact-row"><span class="row-copy"><b>Automatic checks</b><small>State returned by API</small></span>${pill(payload.monitoring_enabled===false?"off":"on")}</div><div class="info-banner">Audit calls are read-only. Repair controls require an explicit approved backend action.</div></div></section>`;
    const list = checks.length ? checks.map((check)=>`<button class="master-row ${selected?.name===check.name?"selected":""}" data-select-watchdog="${esc(check.name)}"><span class="initial">${/healthy|ok|connected|ready/i.test(check.status||"")?"✓":"!"}</span><span class="row-copy"><b>${esc(check.name)}</b><small>${esc(check.latency_ms||0)} ms · ${esc(JSON.stringify(check.detail||{}).slice(0,70))}</small></span>${pill(check.status)}</button>`).join("") : empty("No audit results","Confirm the manager connection and run the read-only audit.","watchdog");
    const center = `<section class="card workspace-panel"><div class="card-head"><div><h3>${issues.length?"Active issues & recent checks":"Recent checks"}</h3><p>${esc(payload.checked_at?`Last checked ${new Date(payload.checked_at).toLocaleString()}`:"No completed audit")}</p></div>${pill(`${issues.length} issues`)}</div>${list}</section>`;
    const detail = selected ? `<section class="card context-inspector">${inspectorTitle("CHECK DETAILS",selected.name||"System check",`${selected.latency_ms||0} ms`,selected.status||"unavailable")}<div class="card-body"><div class="detail-section"><h4>Connected detail</h4><pre class="technical-detail">${esc(JSON.stringify(selected.detail||{},null,2))}</pre></div><div class="detail-section"><h4>Assessment</h4><div class="record-summary"><span><small>Confidence</small><b>${esc(selected.confidence||"API result")}</b></span><span><small>Approval</small><b>${issues.includes(selected)?"Required":"Not needed"}</b></span></div></div>${issues.includes(selected)?`<div class="info-banner warning">This check needs review. No automatic repair will run from this screen.</div>`:`<div class="info-banner">No repair is proposed for a healthy connected check.</div>`}<div class="policy-note">${esc(payload.repair_policy||"Repairs require approval, an audit record, and a reversible rollback payload.")}</div></div><div class="sticky-actions"><button class="button" disabled>Dismiss</button><button class="primary-button" disabled title="No approved repair action returned">Approve safe repair</button></div></section>` : card("Issue details",empty("No check selected","Run the connected audit to inspect system health.","watchdog"));
    return `<div class="page">${pageHead("watchdog", `<button class="button" data-route="settings">Back to Settings</button>${checks.length?`<button class="primary-button" data-refresh>Run full audit</button>`:`<button class="button" disabled>Audit unavailable</button>`}`)}<div class="metric-grid">${metric("Systems checked",checks.length,"Connected diagnostics")}${metric("Healthy",checks.length-issues.length,"No issue returned")}${metric("Active issues",issues.length,"Needs review")}${metric("Repair mode","Approval only","Guarded and reversible")}</div><div class="watchdog-workspace">${rail}${center}${detail}</div></div>`;
  }

  function employeeDialog(employee = null) {
    const roles = ["waitress", "host", "floor", "manager", "kitchen", "driver", "other"];
    const statuses = ["active", "inactive", "on_leave", "terminated"];
    const types = ["part", "full", "seasonal", "temporary"];
    openActionDialog({
      eyebrow: employee ? "EMPLOYEE RECORD" : "NEW EMPLOYEE",
      title: employee ? `Edit ${employee.display_name || employee.name}` : "Add employee",
      description: "Changes are saved to the same employee record used by the web Command Center.",
      body: `<div class="form-grid"><div class="form-control"><label>Display name</label><input name="display_name" required value="${esc(employee?.display_name || "")}"></div><div class="form-control"><label>Full name</label><input name="full_name" required value="${esc(employee?.full_name || employee?.display_name || "")}"></div><div class="form-control"><label>Primary role</label><select name="role">${roles.map((role) => `<option value="${role}" ${employee?.role === role ? "selected" : ""}>${esc(titleCase(role))}</option>`).join("")}</select></div><div class="form-control full"><label>Approved secondary roles</label><div class="role-choice-grid">${roles.filter((role)=>role!=="other").map((role)=>`<label><input type="checkbox" name="secondary_role_${role}" ${arr(employee?.secondary_roles).includes(role)?"checked":""}><span>${esc(titleCase(role))}</span></label>`).join("")}</div><small>Choose from the shared role list so schedule matching cannot drift from employee data.</small></div><div class="form-control"><label>Status</label><select name="status">${statuses.map((status) => `<option value="${status}" ${employee?.status === status ? "selected" : ""}>${esc(titleCase(status))}</option>`).join("")}</select></div><div class="form-control"><label>Employee type</label><select name="employee_type">${types.map((type) => `<option value="${type}" ${employee?.employee_type === type ? "selected" : ""}>${esc(titleCase(type))}</option>`).join("")}</select></div><div class="form-control"><label>Phone</label><input name="phone" value="${esc(employee?.phone || "")}"></div><div class="form-control"><label>Email</label><input name="email" type="email" value="${esc(employee?.email || "")}"></div><div class="form-control full role-pay-editor"><label>Hourly pay by approved role</label><div class="role-pay-grid">${roles.filter((role)=>role!=="other").map((role)=>`<label><span>${esc(titleCase(role))}</span><input name="pay_role_${role}" type="number" min="0" max="1000" step="0.01" value="${employee?.role_pay_rates?.[role]==null?"":esc((Number(employee.role_pay_rates[role])/100).toFixed(2))}" placeholder="Not used"></label>`).join("")}</div><small>The report uses the rate for the role worked. The default below is used only when a role rate is empty.</small></div><div class="form-control"><label>Default hourly pay</label><input name="pay_rate" type="number" min="0" max="1000" step="0.01" value="${employee?.pay_rate_cents==null?"":esc((Number(employee.pay_rate_cents)/100).toFixed(2))}"></div><div class="form-control"><label>${employee ? "New PIN (blank keeps current)" : "PIN (optional, 4–8 digits)"}</label><input name="pin" type="password" inputmode="numeric" maxlength="8"></div></div>`,
      buttons: [{ label: "Cancel", action: "close" }, { label: employee ? "Save employee" : "Create employee", action: "save", className: "primary-button", submit: true }],
      onSubmit: async (values) => {
        const payload = {
          display_name: values.display_name,
          full_name: values.full_name,
          role: values.role,
          secondary_roles: roles.filter((role)=>values[`secondary_role_${role}`]).filter((role)=>role!==values.role),
          status: values.status,
          employee_type: values.employee_type,
          phone: values.phone,
          email: values.email,
          pay_rate_cents: values.pay_rate === "" ? null : Math.round(Number(values.pay_rate || 0) * 100),
          role_pay_rates: Object.fromEntries(roles.map((role)=>[role,values[`pay_role_${role}`]]).filter(([,value])=>value!==undefined&&value!=="").map(([role,value])=>[role,Math.round(Number(value)*100)]))
        };
        if (values.pin) payload.pin = values.pin;
        await runConnectedAction(() => api(employee ? `/api/employees/${employee.id}` : "/api/employees", { method: employee ? "PUT" : "POST", body: JSON.stringify(payload) }), employee ? "Employee updated." : "Employee created.", "employees");
      }
    });
    const employeeDialogElement = $("#actionDialog");
    employeeDialogElement.classList.add("employee-workspace-dialog");
    const employeeBody = $("#actionBody");
    employeeBody.insertAdjacentHTML("afterbegin", `<div class="employee-editor-hero"><span class="initial">${esc(initials(employee?.display_name || employee?.name || "New employee"))}</span><div><b>${esc(employee?.display_name || employee?.name || "Create employee profile")}</b><small>${employee ? `${esc(titleCase(employee.role))} · Connected employee account` : "Set identity, roles, pay, and secure access in one place"}</small></div>${employee ? pill(employee.status || "active") : pill("new")}</div>`);
    const pinInput = employeeBody.querySelector('input[name="pin"]');
    if (pinInput) {
      pinInput.parentElement.classList.add("employee-pin-editor");
      pinInput.insertAdjacentHTML("afterend", `<button type="button" class="button employee-pin-reveal" data-employee-dialog-pin>Reveal</button><small>Only a newly entered PIN can be revealed. Existing PINs remain securely hashed.</small>`);
      employeeBody.querySelector("[data-employee-dialog-pin]")?.addEventListener("click", (event) => {
        const revealed = pinInput.type === "text";
        pinInput.type = revealed ? "password" : "text";
        event.currentTarget.textContent = revealed ? "Reveal" : "Hide";
      });
    }
  }

  function notificationDialog(notification) {
    const payload = notification.payload || {};
    const requestLike = /request|shift.?switch/i.test(`${notification.category||""} ${notification.title||""}`);
    openActionDialog({
      eyebrow: "MANAGER NOTIFICATION",
      title: notification.title || "Notification",
      description: notification.message || "",
      body: `<div class="record-summary"><span><small>Category</small><b>${esc(titleCase(notification.category))}</b></span><span><small>Status</small><b>${esc(notification.read_at ? "Read" : "Unread")}</b></span><span><small>Created</small><b>${esc(dateLabel(notification.created_at, { hour: "numeric", minute: "2-digit" }))}</b></span><span><small>Audience</small><b>${esc(titleCase(notification.audience))}</b></span></div>${requestLike ? `<div class="control-note">This alert can be matched against connected Pending and History records, including older alerts that did not store a request ID.</div>` : ""}`,
      buttons: [{ label: "Close", action: "close" }, ...(!notification.read_at ? [{ label: "Mark read", action: "read", className: requestLike ? "button" : "primary-button", submit: true }] : []), ...(requestLike ? [{ label: "Review connected request", action: "request", className: "primary-button", submit: true }] : [])],
      onSubmit: async (_values, action) => {
        if (action === "request") return openNotificationRequest(notification);
        return runConnectedAction(() => api(`/api/notifications/${notification.id}/read`, { method: "POST" }), "Notification marked read.", state.route);
      }
    });
  }

  async function openNotificationRequest(notification) {
    const requestId = notification.payload?.request_id || notification.related_id;
    if (!notification.read_at) await api(`/api/notifications/${notification.id}/read`, { method:"POST" }).catch(()=>undefined);
    closeActionDialog();
    state.inboxTab = "pending";
    await navigate("inbox");
    const requests = firstArray(state.data.inbox?.results?.[0]?.value,["requests","items","pending"]);
    const history = firstArray(state.data.inbox?.results?.[2]?.value,["requests","items","history"]);
    const employees = firstArray(state.data.inbox?.results?.[3]?.value,["employees"]);
    const allRequests = [...requests,...history];
    const notificationText = `${notification.title||""} ${notification.message||""}`.toLowerCase();
    const requestTypeHint = /day off|time off/.test(notificationText) ? "day_off" : /extra shift/.test(notificationText) ? "extra_shift" : /shift switch/.test(notificationText) ? "shift_switch" : "";
    const createdAt = Date.parse(notification.created_at||"")||0;
    const inferred = allRequests.filter((item)=>{
      const name = employeeName(item,employees).toLowerCase();
      const type = String(item.type||item.request_type||"").toLowerCase();
      return name && notificationText.includes(name) && (!requestTypeHint || type.includes(requestTypeHint));
    }).sort((a,b)=>Math.abs((Date.parse(a.created_at||"")||0)-createdAt)-Math.abs((Date.parse(b.created_at||"")||0)-createdAt))[0];
    const request = allRequests.find((item)=>String(item.id)===String(requestId)) || inferred;
    if (!request) {
      notify("No exact request record could be matched. Inbox is open with the connected records.", "info");
      return;
    }
    state.inboxTab = requests.some((item)=>String(item.id)===String(request.id)) ? "pending" : "history";
    if (state.inboxTab === "history") await navigate("inbox");
    state.selected = { id: request.id };
    $("#appMain").innerHTML = renderInbox(state.data.inbox);
    requestDialog(request, employees, true);
  }

  function newAnnouncementDialog() {
    const employees = firstArray(state.data.notifications?.results?.[1]?.value, ["employees"]);
    openActionDialog({
      eyebrow: "PUSH NOTIFICATION CENTER",
      title: "Create notification",
      description: "Send staff notifications now or schedule a targeted HOP Club campaign.",
      body: `<div class="form-grid"><div class="form-control"><label>Channel</label><select name="channel"><option value="staff">Staff</option><option value="hopclub">HOP Club members</option></select></div><div class="form-control"><label>Staff recipient</label><select name="staff_recipient"><option value="all_staff">All staff</option><option value="manager">Managers</option>${employees.map((employee)=>`<option value="${esc(employee.id)}">${esc(employee.display_name||employee.name)}</option>`).join("")}</select></div><div class="form-control"><label>HOP Club audience</label><select name="club_audience"><option value="all_members">All members</option><option value="vip">VIP members</option><option value="inactive_30d">Inactive 30+ days</option></select></div><div class="form-control"><label>Delivery</label><select name="delivery"><option value="now">Send now</option><option value="scheduled">Schedule</option></select></div><div class="form-control full"><label>Title</label><input name="title" required maxlength="100"></div><div class="form-control full"><label>Message</label><textarea name="message" required maxlength="500"></textarea></div><div class="form-control"><label>Schedule date & time</label><input name="schedule_at" type="datetime-local"></div><div class="form-control"><label>Repeat</label><select name="repeat_rule"><option value="once">Once</option><option value="daily">Daily</option><option value="weekly">Weekly</option></select></div><div class="form-control"><label>Category</label><select name="category"><option value="announcement">Announcement</option><option value="schedule">Schedule</option><option value="general">General</option></select></div><div class="form-control"><label>Manager reason</label><input name="reason" placeholder="Why this message is being sent"></div></div><div class="info-banner">Scheduled delivery is available for HOP Club campaigns. Staff notices are delivered immediately to the selected recipient.</div>`,
      buttons: [{ label: "Cancel", action: "close" }, { label: "Send / schedule", action: "send", className: "primary-button", submit: true }],
      onSubmit: async (values) => {
        if (values.channel === "hopclub") {
          if (values.delivery === "scheduled" && !values.schedule_at) throw new Error("Choose a delivery date and time.");
          await runConnectedAction(() => api("/api/hopclub/campaigns", { method: "POST", body: JSON.stringify({ title: values.title, body: values.message, audience: values.club_audience, schedule_at: values.delivery === "scheduled" ? values.schedule_at : null, repeat_rule: values.repeat_rule, send_now: values.delivery === "now", reason: values.reason || "Manager announcement" }) }), values.delivery === "now" ? "HOP Club announcement sent." : "HOP Club announcement scheduled.", state.route);
          return;
        }
        const employeeId = !["all_staff","manager"].includes(values.staff_recipient) ? values.staff_recipient : null;
        await runConnectedAction(() => api("/api/notifications", { method: "POST", body: JSON.stringify({ title: values.title, message: values.message, category: values.category, audience: employeeId ? "employee" : values.staff_recipient, employee_id: employeeId }) }), "Staff notification sent.", state.route);
      }
    });
  }

  function hopClubMemberDialog(member = null) {
    openActionDialog({ eyebrow: "HOP CLUB MEMBER", title: member ? `Edit ${member.name}` : "Add member", description: "The member stays in the shared HOP Club customer database.", body: `<div class="form-grid"><div class="form-control full"><label>Name</label><input name="name" required value="${esc(member?.name||"")}"></div><div class="form-control"><label>Phone (10 digits)</label><input name="phone" required value="${esc(member?.phone||"")}"></div><div class="form-control"><label>Username</label><input name="username" value="${esc(member?.username||"")}"></div>${member?"":`<div class="form-control"><label>Temporary PIN</label><input name="pin" inputmode="numeric" minlength="4"></div>`}<div class="form-control full"><label>Manager reason</label><input name="reason" required placeholder="Member profile update"></div></div>`, buttons:[{label:"Cancel",action:"close"},{label:member?"Save member":"Add member",action:"save",className:"primary-button",submit:true}], onSubmit:async(values)=>runConnectedAction(()=>api(member?`/api/hopclub/admin/customers/${member.id}`:"/api/hopclub/admin/customers",{method:member?"PATCH":"POST",body:JSON.stringify(values)}),member?"Member updated.":"Member added.","hopclub") });
  }

  function hopClubPointsDialog(member) {
    openActionDialog({ eyebrow:"POINTS ADJUSTMENT",title:member.name||"HOP Club member",description:`Current balance: ${Number(member.points_balance||0).toLocaleString()} points`,body:`<div class="form-control"><label>Adjustment (+ or −)</label><input name="delta" type="number" required step="1" placeholder="100 or -100"></div><div class="form-control"><label>Manager reason</label><textarea name="reason" required placeholder="Explain this audited adjustment"></textarea></div>`,buttons:[{label:"Cancel",action:"close"},{label:"Apply adjustment",action:"save",className:"primary-button",submit:true}],onSubmit:async(values)=>runConnectedAction(()=>api(`/api/hopclub/admin/customers/${member.id}/points-adjustment`,{method:"POST",body:JSON.stringify({delta:Number(values.delta),reason:values.reason})}),"Member points updated.","hopclub") });
  }

  function hopClubRewardDialog(rule = null) {
    const media=firstArray(state.data.hopclub?.results?.[5]?.value,["media"]);
    openActionDialog({eyebrow:"REWARD MANAGER",title:rule?`Edit ${rule.title}`:"Add reward",description:"Configure the connected customer reward ladder and picture.",body:`<div class="form-grid"><div class="form-control"><label>Title</label><input name="title" required value="${esc(rule?.title||"")}"></div><div class="form-control"><label>Code</label><input name="code" value="${esc(rule?.code||"")}"></div><div class="form-control full"><label>Description</label><textarea name="description">${esc(rule?.description||"")}</textarea></div><div class="form-control"><label>Trigger</label><select name="trigger_type"><option value="point_threshold" ${rule?.trigger_type!=="visit_count"?"selected":""}>Points</option><option value="visit_count" ${rule?.trigger_type==="visit_count"?"selected":""}>Completed purchases / visits</option></select></div><div class="form-control"><label>Points required</label><input name="points_required" type="number" min="0" value="${esc(rule?.points_required||0)}"></div><div class="form-control"><label>Purchases required</label><input name="visits_required" type="number" min="0" value="${esc(rule?.visits_required||0)}"></div><div class="form-control"><label>Status</label><select name="is_active"><option value="true" ${rule?.is_active!==false?"selected":""}>Active</option><option value="false" ${rule?.is_active===false?"selected":""}>Inactive</option></select></div><div class="form-control full"><label>Reward picture library (${media.length})</label><select name="image_url"><option value="">No picture</option>${media.map((item)=>`<option value="${esc(item.url||item.path)}" ${String(rule?.image_url||"")===String(item.url||item.path)?"selected":""}>${esc(item.name||item.filename||"Reward picture")}</option>`).join("")}</select></div><div class="form-control full"><label>Upload reward picture</label><input name="reward_image" type="file" accept="image/jpeg,image/png,image/webp"></div><div class="form-control full"><label>Manager reason</label><input name="reason" required value="Reward configuration updated"></div></div>`,buttons:[{label:"Cancel",action:"close"},{label:"Save reward",action:"save",className:"primary-button",submit:true}],onSubmit:async(values)=>{const imageFile=values.reward_image instanceof File&&values.reward_image.size?values.reward_image:null;delete values.reward_image;if(imageFile){const uploaded=await api("/api/media/upload",{method:"POST",body:JSON.stringify({target:"reward_image",filename:imageFile.name,data_url:await fileToDataUrl(imageFile)})});values.image_url=uploaded.media?.url||uploaded.media?.path||values.image_url;}return runConnectedAction(()=>api("/api/hopclub/admin/reward-rules",{method:"POST",body:JSON.stringify({...rule,...values,points_required:Number(values.points_required),visits_required:Number(values.visits_required),is_active:values.is_active==="true"})}),"Reward saved.","hopclub");}});
    const body=$("#actionBody");
    body.insertAdjacentHTML("afterbegin",`<div class="reward-editor-preview" data-reward-preview>${rule?.image_url?`<img src="${esc(mediaUrl(rule.image_url))}" alt="Reward preview">`:`<span>★<small>Choose a reward picture</small></span>`}</div>`);
    const preview=$('[data-reward-preview]',body);
    $('[name="image_url"]',body)?.addEventListener("change",(event)=>{preview.innerHTML=event.target.value?`<img src="${esc(mediaUrl(event.target.value))}" alt="Reward preview">`:`<span>★<small>Choose a reward picture</small></span>`;});
    $('[name="reward_image"]',body)?.addEventListener("change",async(event)=>{if(event.target.files?.[0])preview.innerHTML=`<img src="${await fileToDataUrl(event.target.files[0])}" alt="New reward preview">`;});
  }

  function requestDialog(request, employees, canReview) {
    const items = arr(request.items);
    const hasConflict = items.some((item)=>arr(item.conflict_hints).some((hint)=>!/^no conflicts found\.?$/i.test(String(hint).trim())));
    openActionDialog({
      eyebrow: canReview ? "MANAGER REVIEW" : "REQUEST HISTORY",
      title: `${employeeName(request, employees)} · ${titleCase(request.type || request.request_type)}`,
      description: request.note || request.message || "No employee note was provided.",
      body: `<div class="record-summary"><span><small>Status</small><b>${esc(titleCase(request.status))}</b></span><span><small>Date range</small><b>${esc(dateLabel(request.start_date || request.date))}${request.end_date && request.end_date !== request.start_date ? ` – ${esc(dateLabel(request.end_date))}` : ""}</b></span></div>${items.length ? `<div class="compact-list">${items.map((item) => `<div class="compact-row"><span class="date-tile"><b>${esc(dateLabel(item.item_date, { day: "numeric" }))}</b><span>${esc(dateLabel(item.item_date, { month: "short", day: undefined }))}</span></span><span class="row-copy"><b>${esc(titleCase(item.status))}</b><small>${esc(arr(item.conflict_hints).join(" · ") || "No conflicts returned")}</small></span></div>`).join("")}</div>` : ""}${hasConflict?`<div class="info-banner warning"><b>Schedule conflict detected.</b> Approval requires the signed-in manager PIN. Genuine overlapping shifts remain blocked.</div>`:""}${canReview ? `<div class="form-control"><label>Manager note</label><textarea name="manager_note" placeholder="Optional note for the employee"></textarea></div><div class="form-control"><label>Manager PIN ${hasConflict?"for conflict override":"(requested only if approval conflicts)"}</label><input name="manager_pin" type="password" inputmode="numeric" autocomplete="current-password"><small>The exact signed-in manager account is verified; duplicate display names cannot interfere.</small></div>` : ""}`,
      buttons: canReview ? [{ label: "Cancel", action: "close" }, { label: "Deny", action: "deny", className: "danger-button", submit: true }, { label: "Approve", action: "approve", className: "primary-button", submit: true }] : [{ label: "Close", action: "close" }],
      onSubmit: async (values, action) => {
        if (action === "approve" && hasConflict && !values.manager_pin) throw new Error("Enter the signed-in manager PIN to override this conflict.");
        return runConnectedAction(() => api(`/api/requests/${request.id}/${action}`, { method: "POST", body: JSON.stringify({ manager_note: values.manager_note, manager_pin: values.manager_pin }) }), `Request ${action === "approve" ? "approved" : "denied"}.`, "inbox");
      }
    });
  }

  function partyDialog(party = null, readOnly = false) {
    const data = state.data.parties;
    const employees = firstArray(data?.results?.[3]?.value, ["employees"]);
    openActionDialog({
      eyebrow: readOnly ? "PARTY HISTORY" : party ? "PARTY RESERVATION" : "NEW PARTY",
      title: party ? party.name : "Add party",
      description: readOnly ? "Historical party record." : "Save reservation details to the shared party board.",
      body: `<div class="form-grid"><div class="form-control"><label>Party name</label><input name="name" required ${readOnly ? "disabled" : ""} value="${esc(party?.name || "")}"></div><div class="form-control"><label>Phone</label><input name="phone" ${readOnly ? "disabled" : ""} value="${esc(party?.phone || "")}"></div><div class="form-control"><label>Date</label><input name="date" type="date" required ${readOnly ? "disabled" : ""} value="${esc(String(party?.date || state.weekStart).slice(0, 10))}"></div><div class="form-control"><label>Time</label><input name="time" type="time" ${readOnly ? "disabled" : ""} value="${esc(String(party?.time || "").slice(0, 5))}"></div><div class="form-control"><label>Guests</label><input name="count" type="number" min="1" ${readOnly ? "disabled" : ""} value="${esc(party?.count || "")}"></div><div class="form-control"><label>Area</label><select name="area" ${readOnly ? "disabled" : ""}>${["BR","B","C"].map((area) => `<option value="${area}" ${party?.area === area ? "selected" : ""}>${area}</option>`).join("")}</select></div><div class="form-control"><label>Status</label><select name="status" ${readOnly ? "disabled" : ""}>${["Booked","Confirmed","Completed","Cancelled"].map((status) => `<option value="${status}" ${party?.status === status ? "selected" : ""}>${status}</option>`).join("")}</select></div><div class="form-control"><label>Assigned waitress</label><select name="assigned_waitress_id" ${readOnly ? "disabled" : ""}><option value="">Unassigned</option>${employees.map((employee) => `<option value="${esc(employee.id)}" ${String(party?.assigned_waitress_id) === String(employee.id) ? "selected" : ""}>${esc(employee.display_name || employee.name)}</option>`).join("")}</select></div><div class="form-control full"><label>Notes</label><textarea name="notes" ${readOnly ? "disabled" : ""}>${esc(party?.notes || "")}</textarea></div></div>`,
      buttons: readOnly ? [{ label: "Close", action: "close" }] : [{ label: "Cancel", action: "close" }, { label: party ? "Save party" : "Add party", action: "save", className: "primary-button", submit: true }],
      onSubmit: async (values) => runConnectedAction(() => api(party ? `/api/parties/${party.id}` : "/api/parties", { method: party ? "PATCH" : "POST", body: JSON.stringify({ ...values, count: Number(values.count) || null, assigned_waitress_id: values.assigned_waitress_id || null }) }), party ? "Party updated." : "Party added.", "parties")
    });
  }

  function scheduleCurrent() {
    const schedules = firstArray(state.data.schedule?.results?.[0]?.value, ["schedules"]);
    return state.scheduleView === "draft" ? schedules.find((item) => item.status === "draft") : schedules.filter((item) => item.status === "published").sort((a, b) => Number(b.version_number || 0) - Number(a.version_number || 0))[0];
  }

  function mergeScheduleEntry(entry) {
    const schedule = scheduleCurrent();
    if (!schedule || !entry) return;
    const entries = arr(schedule.entries);
    const index = entries.findIndex((item)=>String(item.id)===String(entry.id));
    if (index >= 0) entries[index] = entry;
    else entries.push(entry);
    schedule.entries = entries;
  }

  async function scheduleAction(action) {
    const schedule = scheduleCurrent();
    if (action === "schedule-expand") {
      document.body.classList.toggle("schedule-focus");
      notify(document.body.classList.contains("schedule-focus") ? "Schedule focus mode enabled." : "Schedule focus mode closed.");
      return;
    }
    if (action === "schedule-autofill") {
      if (!schedule?.id || state.scheduleView !== "draft") return notify("Open a draft before using autofill.", true);
      const employees = firstArray(state.data.schedule?.results?.[1]?.value,["employees"]);
      const availability = firstArray(state.data.schedule?.results?.[3]?.value,["availability"]);
      const days = dates.scheduleDates(state.weekStart);
      const timeMap = { AM1:["10:00","15:00"],AM2:["11:00","16:00"],AM3:["11:30","16:30"],AM4:["12:00","17:00"],PM1:["15:00","19:30"],PM2:["16:00","20:30"],PM3:["17:00","21:00"],FH1:["16:00","20:30"],FH2:["17:00","21:00"],FH3:["17:30","21:30"],FH4:["18:00","22:00"],"Host AM1":["11:00","16:00"],"Host PM1":["16:00","21:00"],"Host PM2":["17:00","21:00"] };
      const counts = new Map(employees.map((employee)=>[String(employee.id),arr(schedule.entries).filter((entry)=>String(entry.employee_id)===String(employee.id)).length]));
      const planned = [];
      const roleOk = (employee,row)=>{const roles=[employee.role,...arr(employee.secondary_roles)].map((value)=>String(value||"").toLowerCase());if(row.role_group==="host")return roles.some((role)=>/host|manager/.test(role));if(row.role_group==="floor")return roles.some((role)=>/floor|server|wait|manager/.test(role));return roles.some((role)=>/main|kitchen|cook|prep|dish|server|wait|manager|employee/.test(role));};
      for (const row of arr(schedule.rows)) for (const day of days) {
        const dayNumber = new Date(`${day.date}T12:00:00Z`).getUTCDay();
        const cell = arr(schedule.entries).filter((entry)=>String(entry.row_id)===String(row.id)&&Number(entry.day_of_week)===dayNumber);
        if (cell.some((entry)=>entry.employee_id||String(entry.notes||"").includes("HOP_SLOT_INACTIVE"))) continue;
        const period = /PM|FH/i.test(row.label||"")?"PM":"AM";
        const candidates = employees.filter((employee)=>employee.active!==false&&employee.status==="active"&&roleOk(employee,row)&&!availability.some((slot)=>String(slot.employee_id)===String(employee.id)&&String(slot.day).slice(0,3).toLowerCase()===day.name.slice(0,3).toLowerCase()&&String(slot.shift_key).toUpperCase()===period&&slot.status==="off")&&!arr(schedule.entries).some((entry)=>String(entry.employee_id)===String(employee.id)&&Number(entry.day_of_week)===dayNumber&&String(entry.start_time||"")<String(timeMap[row.label]?.[1]||"")&&String(entry.end_time||"")>String(timeMap[row.label]?.[0]||""))&&!planned.some((entry)=>String(entry.employee_id)===String(employee.id)&&entry.day_of_week===dayNumber&&entry.start_time<String(timeMap[row.label]?.[1]||"")&&entry.end_time>String(timeMap[row.label]?.[0]||""))).sort((a,b)=>(counts.get(String(a.id))||0)-(counts.get(String(b.id))||0));
        const employee = candidates[0];
        if (!employee) continue;
        const [start_time,end_time]=timeMap[row.label]||[null,null];
        planned.push({row_id:row.id,row_label:row.label,employee_id:employee.id,employee_name:employee.display_name||employee.name,day_of_week:dayNumber,day_name:day.name,start_time,end_time,shift_label:`${start_time||""} - ${end_time||""}`,role:row.role_group,updated_by:manager()?.id||null});
        counts.set(String(employee.id),(counts.get(String(employee.id))||0)+1);
      }
      if (!planned.length) return notify("No conflict-free open cells could be autofilled.", true);
      openActionDialog({eyebrow:"SCHEDULE AUTOFILL",title:`Review ${planned.length} suggested assignments`,description:"Suggestions respect role, submitted availability, existing shift overlap, and balanced assignment counts. The server overlap guard validates every save again.",body:`<div class="compact-list autofill-preview">${planned.slice(0,60).map((entry)=>`<div class="compact-row"><span class="row-copy"><b>${esc(entry.day_name)} · ${esc(entry.row_label)}</b><small>${esc(entry.start_time)}–${esc(entry.end_time)}</small></span><strong>${esc(entry.employee_name)}</strong></div>`).join("")}</div>`,buttons:[{label:"Cancel",action:"close"},{label:"Apply suggestions",action:"apply",className:"primary-button",submit:true}],onSubmit:async()=>{let saved=0;const conflicts=[];for(const entry of planned){try{await api(`/api/schedules/draft/${schedule.id}/entries`,{method:"POST",body:JSON.stringify(entry)});saved+=1;}catch(error){conflicts.push(`${entry.day_name} ${entry.row_label}: ${error.message}`);}}closeActionDialog();notify(`${saved} suggested assignments saved${conflicts.length?`; ${conflicts.length} conflicts remained open`:""}.`,Boolean(conflicts.length));await navigate("schedule",{keepSelection:true});}});
      return;
    }
    if (action === "schedule-save-cell") {
      const row = arr(schedule?.rows).find((item)=>item.row_key===state.selected?.row);
      if (!schedule?.id || !row) return notify("Select a draft cell first.", true);
      const day = new Date(`${state.selected.date}T12:00:00Z`).getUTCDay();
      const existing = arr(schedule.entries).find((entry)=>String(entry.row_id)===String(row.id)&&Number(entry.day_of_week)===day&&entry.employee_id);
      const employeeId = $("[data-schedule-picker]")?.value || null;
      const startTime = $("[data-schedule-start]")?.value || null;
      const endTime = $("[data-schedule-end]")?.value || null;
      if (startTime && endTime && startTime >= endTime) { state.scheduleConflict = "End time must be later than start time."; $("#appMain").innerHTML = renderSchedule(state.data.schedule); return; }
      try {
        const saved = await api(`/api/schedules/draft/${schedule.id}/entries`, { method:"POST", body:JSON.stringify({ id:existing?.id||null,row_id:row.id,employee_id:employeeId,day_of_week:day,start_time:startTime,end_time:endTime,shift_label:startTime&&endTime?`${startTime} - ${endTime}`:null,role:row.role_group,notes:null,updated_by:manager()?.id||null }) });
        mergeScheduleEntry(saved.entry); const warnings=arr(saved.entry?.assignment_warnings); state.scheduleConflict=warnings.map((item)=>item.user_message||item.message||item.code).filter(Boolean).join(" · ")||null; notify(employeeId ? "Shift assignment and time saved." : "Cell saved as open."); $("#appMain").innerHTML=renderSchedule(state.data.schedule);
      } catch (error) {
        const issues = arr(error.payload?.issues || error.payload?.conflicts || error.payload?.assignment_warnings);
        state.scheduleConflict = issues.map((item)=>item.user_message||item.message||item.code).filter(Boolean).join(" · ") || error.message;
        $("#appMain").innerHTML = renderSchedule(state.data.schedule);
      }
      return;
    }
    if (action === "schedule-close-cell" || action === "schedule-open-cell") {
      const row = arr(schedule?.rows).find((item)=>item.row_key===state.selected?.row);
      if (!schedule?.id || !row || !state.selected?.date) return notify("Select a draft schedule cell first.",true);
      const day = new Date(`${state.selected.date}T12:00:00Z`).getUTCDay();
      const existing = arr(schedule.entries).find((entry)=>String(entry.row_id)===String(row.id)&&Number(entry.day_of_week)===day);
      if (action === "schedule-close-cell" && existing?.employee_id && !window.confirm("Close this cell and remove its current assignment?")) return;
      const saved=await api(`/api/schedules/draft/${schedule.id}/entries`,{method:"POST",body:JSON.stringify({id:existing?.id||null,row_id:row.id,employee_id:null,day_of_week:day,shift_label:null,start_time:null,end_time:null,role:row.role_group,notes:action==="schedule-close-cell"?"HOP_SLOT_INACTIVE":"HOP_SLOT_ACTIVE",updated_by:manager()?.id||null})});
      mergeScheduleEntry(saved.entry); notify(action==="schedule-close-cell"?"Schedule cell closed.":"Schedule cell reopened."); $("#appMain").innerHTML=renderSchedule(state.data.schedule); return;
    }
    if (action === "schedule-add-selected") {
      const employeeId = $("[data-schedule-picker]")?.value;
      if (!employeeId) return notify("Choose an employee first.", true);
      const row = arr(schedule?.rows).find((item) => item.row_key === state.selected?.row);
      const timeMap = { AM1:["10:00","15:00"],AM2:["11:00","16:00"],AM3:["11:30","16:30"],AM4:["12:00","17:00"],PM1:["15:00","19:30"],PM2:["16:00","20:30"],PM3:["17:00","21:00"],FH1:["16:00","20:30"],FH2:["17:00","21:00"],FH3:["17:30","21:30"],FH4:["18:00","22:00"],"Host AM1":["11:00","16:00"],"Host PM1":["16:00","21:00"],"Host PM2":["17:00","21:00"] };
      const times = timeMap[row?.label] || [null,null];
      const day = new Date(`${state.selected?.date}T12:00:00Z`).getUTCDay();
      await api(`/api/schedules/draft/${schedule.id}/entries`,{method:"POST",body:JSON.stringify({row_id:row.id,employee_id:employeeId,day_of_week:day,start_time:times[0],end_time:times[1],shift_label:`${times[0]||""} - ${times[1]||""}`,role:row.role_group,updated_by:manager()?.id||null})});
      notify("Employee assigned to draft shift."); await navigate("schedule",{keepSelection:true}); return;
    }
    if (action === "schedule-create-revision" || action === "schedule-new-empty") {
      const endpoint = action === "schedule-create-revision" ? "/api/schedules/draft/from-published" : "/api/schedules/draft/empty";
      await api(endpoint, { method: "POST", body: JSON.stringify({ week_start_date: state.weekStart, actor_id: manager()?.id || null }) });
      state.scheduleView = "draft";
      notify(action === "schedule-create-revision" ? "Revision draft created from the published schedule." : "New empty draft created.");
      await navigate("schedule", { keepSelection: true });
      return;
    }
    if (!schedule?.id) return notify("No connected draft is available for this action.", true);
    if (action === "schedule-copy-previous") {
      if (!window.confirm("Replace this draft with the previous published week's assignments?")) return;
      return runConnectedAction(() => api(`/api/schedules/draft/${schedule.id}/copy-previous`, { method: "POST", body: JSON.stringify({ actor_id: manager()?.id || null }) }), "Previous published week copied into this draft.", "schedule");
    }
    if (action === "schedule-clear") {
      if (!window.confirm("Clear every assignment from this draft? The published schedule will not change.")) return;
      return runConnectedAction(() => api(`/api/schedules/draft/${schedule.id}/clear`, { method: "POST", body: JSON.stringify({ actor_id: manager()?.id || null }) }), "Draft assignments cleared.", "schedule");
    }
    if (action === "schedule-publish") {
      const finishPublish=async(values,override=false)=>{await api(`/api/schedules/${schedule.id}/publish`,{method:"POST",body:JSON.stringify({publish_notes:values.publish_notes,override_conflicts:override,manager_pin:values.manager_pin})});state.scheduleView="published";closeActionDialog();notify("Schedule published and employee calendars updated.");await navigate("schedule",{keepSelection:true});};
      openActionDialog({ eyebrow: "PUBLISH SCHEDULE", title: "Review & publish", description: "Publishing creates a protected version for employees. Genuine overlapping assignments can never be bypassed.", body: `<div class="record-summary"><span><small>Week</small><b>${esc(dateLabel(state.weekStart))}</b></span><span><small>Assignments</small><b>${esc(arr(schedule.entries).length)}</b></span></div><div class="form-control"><label>Publish note</label><textarea name="publish_notes" placeholder="Optional manager note"></textarea></div>`, buttons: [{ label: "Cancel", action: "close" }, { label: "Publish schedule", action: "publish", className: "primary-button", submit: true }], onSubmit: async (values) => {try{await finishPublish(values,false);}catch(error){const conflicts=arr(error.payload?.conflicts||error.payload?.issues);if(error.payload?.can_override!==true)throw error;openActionDialog({eyebrow:"CONFLICT REVIEW",title:"Manager override required",description:"These operational warnings may be overridden. Same-employee time overlaps remain blocked.",body:`<div class="compact-list">${conflicts.map((item)=>`<div class="info-banner warning">${esc(item.user_message||item.message||item.code||"Schedule warning")}</div>`).join("")}</div><div class="form-control"><label>Manager PIN</label><input name="manager_pin" type="password" inputmode="numeric" required></div><input type="hidden" name="publish_notes" value="${esc(values.publish_notes||"")}">`,buttons:[{label:"Cancel",action:"close"},{label:"Override & publish",action:"override",className:"danger-button",submit:true}],onSubmit:(overrideValues)=>finishPublish(overrideValues,true)});}} });
    }
  }

  function scheduleExportDialog() {
    const schedule = scheduleCurrent() || {};
    const employees = firstArray(state.data.schedule?.results?.[1]?.value,["employees"]);
    const exportDays = dates.scheduleDates(state.weekStart);
    const visibleRows = arr(schedule.rows).filter((row)=>state.scheduleType==="host"?row.role_group==="host":row.role_group!=="host");
    const dayNumber = (date)=>new Date(`${date}T12:00:00Z`).getUTCDay();
    const dailyCount=(employeeId,date)=>arr(schedule.entries).filter((entry)=>entry.employee_id&&String(entry.employee_id)===String(employeeId)&&Number(entry.day_of_week)===dayNumber(date)).length;
    const timeFor=(entry,fallback)=>entry?.start_time?`${formatTime(entry.start_time)}${entry.end_time?`–${formatTime(entry.end_time)}`:""}`:fallback;
    const rowBand=(row)=>row.role_group==="floor"||row.role_group==="host"?"floor":/PM/i.test(row.label)?"pm":"am";
    const rows=visibleRows.map((row)=>{const fallback=scheduleRows.find((item)=>item[0]===row.label)?.[1]||row.shift_label||"Connected shift time";return {label:row.label,defaultTime:fallback,band:rowBand(row),roleLabel:row.role_group==="floor"?"Floor help":titleCase(row.role_group),cells:exportDays.map((day)=>{const entries=arr(schedule.entries).filter((entry)=>String(entry.row_id)===String(row.id)&&Number(entry.day_of_week)===dayNumber(day.date));const assigned=entries.filter((entry)=>entry.employee_id);const closed=entries.some((entry)=>String(entry.notes||"").includes("HOP_SLOT_INACTIVE"));const doubleCount=assigned.reduce((max,entry)=>Math.max(max,dailyCount(entry.employee_id,day.date)),0);return {closed,required:/^(AM1|AM2|PM1|PM2|PM3|Host AM1|Host PM1)$/i.test(row.label),time:timeFor(assigned[0],fallback),assignmentCount:doubleCount,assignments:assigned.map((entry)=>({name:employeeName(entry,employees),dailyCount:dailyCount(entry.employee_id,day.date)}))};})};});
    const assignedEntries=arr(schedule.entries).filter((entry)=>entry.employee_id&&visibleRows.some((row)=>String(row.id)===String(entry.row_id)));
    const parties=firstArray(state.data.schedule?.results?.[4]?.value,["parties"]);
    const model={weekStart:state.weekStart,weekEnd:exportDays.at(-1)?.date||dates.addDays(state.weekStart,5),days:exportDays,rows,department:state.scheduleType==="host"?"Host":"Main / Waitress",status:titleCase(schedule.status||state.scheduleView||"Schedule"),generatedLabel:new Intl.DateTimeFormat("en-US",{timeZone:"America/New_York",month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}).format(new Date()),assignmentCount:assignedEntries.length,staffCount:new Set(assignedEntries.map((entry)=>String(entry.employee_id))).size,partyCount:parties.length,partiesByDay:Object.fromEntries(exportDays.map((day)=>[day.date,parties.filter((party)=>String(party.date||party.party_date).slice(0,10)===day.date).map((party)=>({name:party.name||"Party",time:party.time?formatTime(party.time):"TBD",count:party.count||"?",area:party.area||"TBD"}))]))};
    const preview=window.HopExportService.scheduleHtml(model);
    openActionDialog({eyebrow:"SCHEDULE EXPORT",title:"Wall Board v2 preview",description:"Matched to the approved wall-board reference. Print uses US Letter landscape; PNG is 2200 px wide.",body:`<div class="form-grid"><div class="form-control"><label>Department</label><select name="department"><option>${esc(model.department)}</option></select></div><div class="form-control"><label>Paper</label><select name="paper"><option>US Letter · Landscape</option></select></div></div><div class="wallboard-preview">${preview}</div>`,buttons:[{label:"Cancel",action:"close"},{label:"Print / Save PDF",action:"print",className:"button",submit:true},{label:"Download PNG",action:"png",className:"primary-button",submit:true}],onSubmit:async(_values,action)=>{if(action==="print"){window.HopExportService.printSchedule();return;}await window.HopExportService.schedulePng(model);notify("High-resolution wall-board PNG downloaded.");}});
    $("#actionDialog").classList.add("wallboard-dialog");
  }

  function partyExportDialog() {
    const allParties=firstArray(state.data.parties?.results?.[0]?.value,["parties"]);
    const exportDays=dates.scheduleDates(state.weekStart);
    const weekDates=new Set(exportDays.map((day)=>day.date));
    const parties=allParties.filter((party)=>weekDates.has(String(party.date||party.party_date).slice(0,10)));
    const model={
      weekStart:state.weekStart,weekEnd:exportDays.at(-1)?.date||dates.addDays(state.weekStart,5),days:exportDays,
      generatedLabel:new Intl.DateTimeFormat("en-US",{timeZone:"America/New_York",month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}).format(new Date()),
      partyCount:parties.length,guestCount:parties.reduce((sum,party)=>sum+Number(party.count||0),0),unassignedCount:parties.filter((party)=>!party.assigned_waitress_id).length,
      partiesByDay:Object.fromEntries(exportDays.map((day)=>[day.date,parties.filter((party)=>String(party.date||party.party_date).slice(0,10)===day.date).map((party)=>({name:party.name||"Party",time:party.time?formatTime(party.time):"TBD",count:party.count||"?",area:party.area||"TBD",waitress:party.assigned_waitress_name||"Unassigned",phone:party.phone||"",notes:party.notes||party.note||""}))]))
    };
    const preview=window.HopExportService.partyHtml(model);
    openActionDialog({eyebrow:"PARTY EXPORT",title:"Party Board preview",description:"The same polished wall-board workflow as Schedule · US Letter landscape · 2200 px PNG",body:`<div class="form-grid"><div class="form-control"><label>Content</label><select><option>Confirmed party bookings</option></select></div><div class="form-control"><label>Paper</label><select><option>US Letter · Landscape</option></select></div></div><div class="wallboard-preview">${preview}</div>`,buttons:[{label:"Cancel",action:"close"},{label:"Print / Save PDF",action:"print",className:"button",submit:true},{label:"Download PNG",action:"png",className:"primary-button",submit:true}],onSubmit:async(_values,action)=>{if(action==="print"){window.HopExportService.printSchedule();return;}await window.HopExportService.partyPng(model);notify("High-resolution party-board PNG downloaded.");}});
    $("#actionDialog").classList.add("wallboard-dialog");
  }

  async function saveSettings() {
    const page = $("#settingsPage");
    const current = state.data.settings?.results?.[0]?.value?.settings || {};
    const profile = { ...(current.restaurant_profile || {}), name: page.querySelector('[name="restaurant_name"]').value.trim(), phone: page.querySelector('[name="restaurant_phone"]').value.trim() };
    const pricingWrapper = current.hop_pricing || {};
    const pricing = {
      ...(pricingWrapper.draft || pricingWrapper.published || pricingWrapper),
      rate_basis_points: Math.round(Number(page.querySelector('[name="tax_rate"]').value || 0) * 100),
      tax_enabled: page.querySelector('[name="tax_enabled"]').value === "true",
      prices_include_tax: page.querySelector('[name="prices_include_tax"]').value === "true"
    };
    const notifications = { ...(current.notifications || {}), managerDayOff: page.querySelector('[name="manager_day_off"]').value === "true", sound: page.querySelector('[name="notification_sound"]').value === "true" };
    localStorage.setItem("hop_notification_sound", String(notifications.sound));
    await Promise.all([
      ...[["restaurant_profile", profile], ["notifications", notifications]].map(([key, value]) => api(`/api/settings/${key}`, { method: "PUT", body: JSON.stringify({ value, updated_by: manager()?.name || "manager" }) })),
      api("/api/pricing/draft", { method: "PUT", body: JSON.stringify({ config: pricing, updated_by: manager()?.name || "manager" }) })
    ]);
    notify("Settings saved to Hostinger.");
    await navigate("settings", { keepSelection: true });
  }

  async function savePrintSettings() {
    const page = $("#settingsPage");
    const checked = (name) => Boolean(page.querySelector(`[name="${name}"]`)?.checked);
    const payload = {
      enabled: page.querySelector('[name="print_enabled"]').value === "true",
      printer_name: page.querySelector('[name="printer_name"]').value.trim(),
      printer_ip: page.querySelector('[name="printer_ip"]').value.trim(),
      copies: Math.max(1, Math.min(3, Number(page.querySelector('[name="print_copies"]').value || 1))),
      copy_rules: Object.fromEntries(["purchase","reward","manual_adjustment"].map((eventName)=>[eventName,Object.fromEntries(["customer","drawer","kitchen","manager"].map((destination)=>[destination,checked(`copy_${eventName}_${destination}`)]))]))
    };
    await api("/api/print-center/settings", { method:"PUT", body:JSON.stringify(payload) });
    if (IS_DESKTOP && TAURI_INVOKE && payload.enabled) await startPrintBridge(payload.printer_name);
    notify("Printer Center settings saved.");
    await navigate("settings", { keepSelection:true });
  }

  function saveAppearanceSettings() {
    const page = $("#settingsPage");
    localStorage.setItem("hop_command_theme", page.querySelector('[name="appearance_theme"]').value);
    localStorage.setItem("hop_command_font", page.querySelector('[name="appearance_font"]').value);
    localStorage.setItem("hop_command_density", page.querySelector('[name="appearance_density"]').value);
    localStorage.setItem("hop_command_auto_refresh", page.querySelector('[name="appearance_refresh"]').value);
    localStorage.setItem("hop_command_remember_route", String(page.querySelector('[name="appearance_remember"]').checked));
    localStorage.setItem("hop_command_show_conflicts", String(page.querySelector('[name="appearance_conflicts"]').checked));
    applyAppearancePreferences();
    configureAutoRefresh();
    notify("Appearance and workspace automation saved.");
  }

  function applicationDialog(application) {
    const statuses = ["new", "reviewing", "interview", "hired", "rejected", "archived"];
    openActionDialog({ eyebrow: "JOB APPLICATION", title: application.full_name || application.name || "Applicant", description: `${application.phone || "No phone"} · ${application.email || "No email"}`, body: `<div class="record-summary"><span><small>Position</small><b>${esc(arr(application.positions_applied_for).map(titleCase).join(", ") || application.position || "Not specified")}</b></span><span><small>Start date</small><b>${esc(dateLabel(application.start_date))}</b></span><span><small>Weekend</small><b>${application.weekend_available ? "Available" : "Not available"}</b></span><span><small>Experience</small><b>${application.restaurant_experience ? "Restaurant experience" : "No restaurant experience"}</b></span></div><div class="form-control"><label>Stage</label><select name="status">${statuses.map((status) => `<option value="${status}" ${application.status === status ? "selected" : ""}>${esc(titleCase(status))}</option>`).join("")}</select></div><div class="form-control"><label>Manager notes</label><textarea name="manager_notes">${esc(application.manager_notes || "")}</textarea></div>`, buttons: [{ label: "Cancel", action: "close" }, { label: "Save application", action: "save", className: "primary-button", submit: true }], onSubmit: async (values) => runConnectedAction(() => api(`/api/job-applications/${application.id}`, { method: "PATCH", body: JSON.stringify(values) }), "Application updated.", "applications") });
  }

  function applicationSheetDialog(application) {
    const positions=arr(application.positions_applied_for).map(titleCase).join(", ")||application.position||"Not specified";
    const availability=application.availability&&typeof application.availability==="object"?Object.entries(application.availability).map(([day,value])=>`${titleCase(day)}: ${typeof value==="object"?Object.entries(value).filter(([,enabled])=>enabled).map(([period])=>titleCase(period)).join(", ")||"Unavailable":String(value)}`).join(" · "):"Availability was not included in this submission.";
    openActionDialog({eyebrow:"APPLICATION PREVIEW",title:application.full_name||application.name||"Applicant",description:"Exact printable preview · US Letter portrait",body:`<section class="application-paper"><header><img src="./assets/official-hop-logo.png" alt="House of Pizza"><div><b>HOUSE OF PIZZA & PASTA</b><span>EMPLOYMENT APPLICATION · MANAGER REVIEW COPY</span></div><strong>${esc(titleCase(application.status||"new"))}</strong></header><h2>${esc(application.full_name||application.name||"Applicant")}</h2><div class="application-paper-grid"><span><small>Phone</small><b>${esc(application.phone||"Not set")}</b></span><span><small>Email</small><b>${esc(application.email||"Not set")}</b></span><span><small>Position</small><b>${esc(positions)}</b></span><span><small>Applied</small><b>${esc(dateLabel(application.created_at||application.applied_at))}</b></span><span><small>Earliest start</small><b>${esc(dateLabel(application.start_date))}</b></span><span><small>Weekend</small><b>${application.weekend_available?"Available":"Limited / not stated"}</b></span><span><small>Work eligibility</small><b>${application.is_over_16===false?"Review required":"Confirmed / not flagged"}</b></span><span><small>Transportation</small><b>${esc(application.transportation||"Not stated")}</b></span></div><h3>Weekly availability</h3><p class="application-availability">${esc(availability)}</p><h3>Experience</h3><p>${esc(application.experience_notes||"No experience note provided.")}</p><h3>Applicant notes</h3><p>${esc(application.applicant_notes||"No additional note provided.")}</p><h3>Manager notes</h3><p>${esc(application.manager_notes||"No manager note recorded.")}</p><footer class="application-review"><span>Reviewed by ____________________</span><span>Date ____________________</span><span>Decision ____________________</span></footer></section>`,buttons:[{label:"Close",action:"close"},{label:"Print / Save PDF",action:"print",className:"primary-button",submit:true}],onSubmit:async()=>{document.body.classList.add("printing-application");window.HopExportService.print();setTimeout(()=>document.body.classList.remove("printing-application"),500);notify("Application export opened with the exact preview layout.");}});
  }

  async function saveWebsite() {
    const page = $("#websitePage");
    const current = state.data.website?.results?.[0]?.value || {};
    const payload = JSON.parse(JSON.stringify(current));
    const value=(name)=>page.querySelector(`[name="${name}"]`)?.value.trim();
    if(state.websiteTab==="content"&&state.websitePage==="home"){
      payload.home={...(payload.home||{})};payload.home.hero={...(payload.home.hero||{})};const hero=payload.home.hero;
      hero.eyebrow=value("hero_eyebrow");hero.headlineBefore=value("hero_before");hero.highlight=value("hero_highlight");hero.headlineAfter=value("hero_after");hero.description=value("hero_description");
      hero.primaryCta={...(hero.primaryCta||{}),text:value("hero_primary_text"),link:value("hero_primary_link")};hero.secondaryCta={...(hero.secondaryCta||{}),text:value("hero_secondary_text"),link:value("hero_secondary_link")};
      payload.home.features=arr(payload.home.features).map((item,index)=>({...item,title:value(`feature_${index}_title`)??item.title,subtitle:value(`feature_${index}_subtitle`)??item.subtitle}));
      const imageFile=page.querySelector('[name="website_image"]')?.files?.[0];
      if(imageFile){const uploaded=await api("/api/media/upload",{method:"POST",body:JSON.stringify({target:"homepage_hero",filename:imageFile.name,data_url:await fileToDataUrl(imageFile)})});hero.image=uploaded.media?.url||uploaded.media?.path||hero.image;}
      else if(value("website_image_url")) hero.image=value("website_image_url");
    } else if(state.websiteTab==="content") {
      const target=state.websitePage==="menu"?(payload.menuPage??={} ).hero??={}:state.websitePage==="catering"?(payload.catering??={}).hero??={}:state.websitePage==="about"?(payload.story??={}):state.websitePage==="jobs"?(payload.jobs??={}):(payload.identity??={});
      if(state.websitePage==="jobs"){target.heroTitle=value("page_title");target.heroSubtitle=value("page_description");}
      else if(state.websitePage==="contact"){target.restaurantName=value("page_title");target.footerDescription=value("page_description");}
      else {target.title=value("page_title");target.eyebrow=value("page_eyebrow");target.description=value("page_description");}
    } else if(state.websiteTab==="navigation") {
      payload.footer={...(payload.footer||{}),quickLinks:String(value("quick_links")||"").split(/\r?\n/).map((line)=>{const [label,...url]=line.split("|");return {label:label?.trim(),url:url.join("|").trim()};}).filter((item)=>item.label&&item.url),newsletterTitle:value("newsletter_title"),newsletterText:value("newsletter_text")};
    } else {
      payload.identity={...(payload.identity||{}),restaurantName:value("business_name"),phone:value("business_phone"),email:value("business_email"),addressLine1:value("business_address1"),addressLine2:value("business_address2"),footerDescription:value("business_description")};
      payload.footer={...(payload.footer||{}),hours:String(value("business_hours")||"").split(/\r?\n/).map((line)=>line.trim()).filter(Boolean)};
    }
    await api("/api/website-content", { method: "PUT", body: JSON.stringify(payload) });
    notify("Website content saved.");
    await navigate("website", { keepSelection: true });
  }

  async function menuItemDialog(item = null) {
    const categoriesPayload = await api("/api/menu/categories");
    const categories = firstArray(categoriesPayload, ["categories"]);
    const media = firstArray(state.data.menu?.results?.[1]?.value, ["media"]);
    const imageOptions = media.map((entry)=>`<option value="${esc(entry.url||entry.path)}" ${String(item?.image_url||"")===String(entry.url||entry.path)?"selected":""}>${esc(entry.name)}</option>`).join("");
    openActionDialog({ eyebrow: item ? "MENU ITEM" : "NEW MENU ITEM", title: item ? `Edit ${item.name}` : "Add menu item", description: "This updates the shared menu catalog and reuses the existing Hostinger picture library.", body: `<div class="form-grid"><div class="form-control"><label>Name</label><input name="name" required value="${esc(item?.name || "")}"></div><div class="form-control"><label>Category</label><select name="category_id"><option value="">Uncategorized</option>${categories.map((category) => `<option value="${esc(category.id)}" ${String(item?.category_id) === String(category.id) ? "selected" : ""}>${esc(category.name)}</option>`).join("")}</select></div><div class="form-control full"><label>Description</label><textarea name="description">${esc(item?.description || "")}</textarea></div><div class="form-control"><label>Price</label><input name="price" type="number" min="0" step="0.01" value="${esc(item?.price ?? Number(item?.price_cents || 0) / 100)}"></div><div class="form-control"><label>Status</label><select name="is_active"><option value="true" ${item?.is_active !== false && item?.active !== false ? "selected" : ""}>Active</option><option value="false" ${item?.is_active === false || item?.active === false ? "selected" : ""}>Inactive</option></select></div><div class="form-control full"><label>Existing picture library (${media.length})</label><select name="image_url" data-menu-library-select><option value="">No picture</option>${imageOptions}</select><div class="media-library-preview" data-menu-library-preview>${item?.image_url?`<img src="${esc(mediaUrl(item.image_url))}" alt="Current menu picture">`:`<span>Select an existing picture or upload a new one.</span>`}</div></div><div class="form-control full"><label>Upload a new picture (JPEG, PNG, or WebP)</label><input name="menu_image" type="file" accept="image/jpeg,image/png,image/webp"><small>New uploads are added to the same shared media library and linked to this menu record.</small></div></div>`, buttons: [{ label: "Cancel", action: "close" }, { label: item ? "Save item" : "Add item", action: "save", className: "primary-button", submit: true }], onSubmit: async (values) => {
      const imageFile = values.menu_image instanceof File && values.menu_image.size ? values.menu_image : null;
      delete values.menu_image;
      const saved = await api(item ? `/api/menu/items/${item.id}` : "/api/menu/items", { method: item ? "PATCH" : "POST", body: JSON.stringify({ ...item, ...values, price: Number(values.price) || 0, is_active: values.is_active === "true" }) });
      const savedItem = saved.item || saved.menu_item || saved;
      const itemId = savedItem.id || item?.id;
      if (imageFile) await api("/api/media/upload", { method: "POST", body: JSON.stringify({ target: "menu_item_image", menu_item_id: itemId, filename: imageFile.name, data_url: await fileToDataUrl(imageFile) }) });
      closeActionDialog(); notify(item ? "Menu item and picture updated." : "Menu item added."); await navigate("menu", { keepSelection: true });
    } });
    const librarySelect = $("[data-menu-library-select]", $("#actionBody"));
    librarySelect?.addEventListener("change",()=>{const preview=$("[data-menu-library-preview]",$("#actionBody"));preview.innerHTML=librarySelect.value?`<img src="${esc(mediaUrl(librarySelect.value))}" alt="Selected menu picture">`:`<span>No picture selected.</span>`;});
  }

  async function availabilityDialog(employee) {
    const payload = await api(`/api/availability/employee/${employee.id}?week_start=${state.weekStart}`);
    const slots = arr(payload.availability);
    const locked = payload.locked === true;
    const slotGrid = slots.map((slot)=>`<div class="form-control"><label>${esc(slot.day)} · ${esc(slot.shift_key)}</label><select name="slot_${esc(slot.day)}_${esc(slot.shift_key)}" ${locked?"disabled":""}><option value="available" ${slot.status!=="off"?"selected":""}>Available</option><option value="off" ${slot.status==="off"?"selected":""}>Off</option></select></div>`).join("");
    openActionDialog({ eyebrow: "EMPLOYEE AVAILABILITY", title: employee.display_name||employee.name||"Availability record", description: `Week of ${dateLabel(state.weekStart)} · ${payload.status_label||titleCase(payload.status)}`, body: `${locked?`<div class="info-banner warning">This employee confirmed the week. Unlock it before editing so the change remains explicit.</div>`:""}<div class="form-grid">${slotGrid}</div>`, buttons: locked ? [{label:"Close",action:"close"},{label:"Unlock for editing",action:"unlock",className:"primary-button",submit:true}] : [{label:"Cancel",action:"close"},{label:"Save availability",action:"save",className:"primary-button",submit:true}], onSubmit:async(values,action)=>{
      if(action==="unlock") return runConnectedAction(()=>api(`/api/availability/employee/${employee.id}/unlock`,{method:"POST",body:JSON.stringify({week_start:state.weekStart,unlocked_by:manager()?.id||null})}),"Availability unlocked for manager editing.","availability");
      const updated=slots.map((slot)=>({...slot,status:values[`slot_${slot.day}_${slot.shift_key}`]||slot.status}));
      await runConnectedAction(()=>api(`/api/availability/employee/${employee.id}/save`,{method:"POST",body:JSON.stringify({week_start:state.weekStart,slots:updated})}),"Availability saved.","availability");
    }});
  }

  async function toggleAvailabilityCell(employeeId, day, period) {
    const payload = await api(`/api/availability/employee/${employeeId}?week_start=${state.weekStart}`);
    if (payload.locked) {
      const employee = firstArray(state.data.availability?.results?.[1]?.value,["employees"]).find((item)=>String(item.id)===String(employeeId));
      if (employee) await availabilityDialog(employee);
      return;
    }
    const slots = arr(payload.availability);
    const target = slots.find((slot)=>String(slot.day).slice(0,3).toLowerCase()===String(day).slice(0,3).toLowerCase()&&String(slot.shift_key).toUpperCase()===String(period).toUpperCase());
    if (!target) return notify("This availability slot was not returned by the server.", true);
    const nextStatus = target.status === "off" ? "available" : "off";
    const updated = slots.map((slot)=>slot===target?{...slot,status:nextStatus}:slot);
    await api(`/api/availability/employee/${employeeId}/save`,{method:"POST",body:JSON.stringify({week_start:state.weekStart,slots:updated})});
    notify(`${day} ${period} changed to ${nextStatus}.`);
    await navigate("availability",{keepSelection:true});
  }

  function taskDialog(task = null) {
    openActionDialog({ eyebrow: task ? "MANAGER TASK" : "NEW TASK", title: task ? task.title : "Assign task", description: "Tasks remain connected to the employee task workflow.", body: `<div class="form-grid"><div class="form-control full"><label>Task</label><input name="title" required value="${esc(task?.title || "")}"></div><div class="form-control"><label>Area</label><input name="area" value="${esc(task?.area || "Side work")}"></div><div class="form-control"><label>Role group</label><select name="role_group">${["all","main","host","support"].map((role) => `<option value="${role}" ${task?.role_group === role ? "selected" : ""}>${esc(titleCase(role))}</option>`).join("")}</select></div><div class="form-control"><label>Shift</label><select name="shift">${["all","AM","PM"].map((shift) => `<option value="${shift}" ${task?.shift === shift ? "selected" : ""}>${esc(shift === "all" ? "All shifts" : shift)}</option>`).join("")}</select></div><div class="form-control"><label>Status</label><select name="status"><option value="open" ${task?.status !== "done" ? "selected" : ""}>Open</option><option value="done" ${task?.status === "done" ? "selected" : ""}>Done</option></select></div><div class="form-control full"><label>Notes</label><textarea name="notes">${esc(task?.notes || "")}</textarea></div></div>`, buttons: [{ label: "Cancel", action: "close" }, { label: task ? "Save task" : "Assign task", action: "save", className: "primary-button", submit: true }], onSubmit: async (values) => runConnectedAction(() => api(task ? `/api/tasks/${task.id}` : "/api/tasks", { method: task ? "PATCH" : "POST", body: JSON.stringify(values) }), task ? "Task updated." : "Task assigned.", "tasks") });
  }

  function parseRows(value, mapper) {
    return String(value || "").split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line, index) => mapper(line.split("|").map((part) => part.trim()), index)).filter(Boolean);
  }

  function taskDialogV2(task = null, requestedSlot = "") {
    const roles = ["all","main","host","support"];
    const days = [["","Every day"],[2,"Tuesday"],[3,"Wednesday"],[4,"Thursday"],[5,"Friday"],[6,"Saturday"],[0,"Sunday"]];
    const schedules = firstArray(state.data.tasks?.results?.[1]?.value,["schedules"]);
    const taskSchedule = schedules.find((item)=>item.status==="published") || schedules.find((item)=>item.status==="draft") || {};
    const scheduleSlots = dates.scheduleDates(state.weekStart).flatMap((day)=>arr(taskSchedule.rows).map((row)=>{const dayOfWeek=new Date(`${day.date}T12:00:00Z`).getUTCDay();const shift=/PM|FH/i.test(row.label)?"PM":"AM";const number=Number(String(row.label).match(/\d+/)?.[0]||0);const value=`${dayOfWeek}|${row.role_group||"main"}|${shift}|${number}`;const staff=arr(taskSchedule.entries).filter((entry)=>String(entry.row_id)===String(row.id)&&Number(entry.day_of_week)===dayOfWeek&&entry.employee_id).map((entry)=>entry.employee_name||entry.display_name).filter(Boolean).join(", ");return {value,label:`${day.name} · ${row.label} · ${staff||"Open shift"}`};}));
    const taskSlot=task ? `${task.day_of_week??""}|${task.role_group||"all"}|${task.shift||"all"}|${task.shift_number||""}` : requestedSlot;
    openActionDialog({
      eyebrow: task ? "TASK LIBRARY ITEM" : "NEW TASK",
      title: task ? task.title : "Create a reusable shift task",
      description: "Day, role, AM/PM, and shift number determine exactly which scheduled employees receive this task.",
      body: `<div class="form-grid"><div class="form-control full"><label>Connected schedule slot</label><select name="assignment_slot"><option value="">Reusable for several shifts</option>${scheduleSlots.map((slot)=>`<option value="${esc(slot.value)}" ${slot.value===taskSlot?"selected":""}>${esc(slot.label)}</option>`).join("")}</select><small>Choosing a slot automatically targets its day, team, AM/PM period, and shift number. The task follows whoever is scheduled there.</small></div><div class="form-control full"><label>Task</label><input name="title" required value="${esc(task?.title||"")}" list="task-library-suggestions"><datalist id="task-library-suggestions">${[...new Set(firstArray(state.data.tasks?.results?.[0]?.value,["tasks","assignments"]).map((item)=>item.title).filter(Boolean))].map((title)=>`<option value="${esc(title)}"></option>`).join("")}</datalist></div><div class="form-control"><label>Area</label><input name="area" value="${esc(task?.area||"Side work")}"></div><div class="form-control"><label>Role group</label><select name="role_group">${roles.map((role)=>`<option value="${role}" ${task?.role_group===role?"selected":""}>${esc(titleCase(role))}</option>`).join("")}</select></div><div class="form-control"><label>Shift</label><select name="shift">${["all","AM","PM"].map((shift)=>`<option value="${shift}" ${task?.shift===shift?"selected":""}>${shift==="all"?"All shifts":shift}</option>`).join("")}</select></div><div class="form-control"><label>Shift number</label><select name="shift_number"><option value="">All numbers</option>${[1,2,3,4].map((number)=>`<option value="${number}" ${Number(task?.shift_number)===number?"selected":""}>${number}</option>`).join("")}</select></div><div class="form-control"><label>Day</label><select name="day_of_week">${days.map(([value,label])=>`<option value="${value}" ${String(task?.day_of_week??"")===String(value)?"selected":""}>${label}</option>`).join("")}</select></div><div class="form-control"><label>Status</label><select name="status"><option value="open" ${task?.status!=="done"?"selected":""}>Open</option><option value="done" ${task?.status==="done"?"selected":""}>Done</option></select></div><div class="form-control full"><label>Instructions</label><textarea name="notes">${esc(task?.notes||"")}</textarea></div></div>`,
      buttons:[{label:"Cancel",action:"close"},...(task?[{label:"Delete",action:"delete",className:"danger-button",submit:true}]:[]),{label:task?"Save task":"Create task",action:"save",className:"primary-button",submit:true}],
      onSubmit:async(values,action)=>{if(action==="delete"){if(!window.confirm("Delete this task definition and its connected completions?"))return;await runConnectedAction(()=>api(`/api/tasks/${task.id}`,{method:"DELETE"}),"Task deleted.","tasks");return;}if(values.assignment_slot){const [day,role,shift,number]=values.assignment_slot.split("|");values.day_of_week=day;values.role_group=role;values.shift=shift;values.shift_number=number;}delete values.assignment_slot;const payload={...values,shift_number:values.shift_number?Number(values.shift_number):null,day_of_week:values.day_of_week===""?null:Number(values.day_of_week)};await runConnectedAction(()=>api(task?`/api/tasks/${task.id}`:"/api/tasks",{method:task?"PATCH":"POST",body:JSON.stringify(payload)}),task?"Task updated.":"Task created.","tasks");}
    });
  }

  async function cateringDialog(order = null) {
    if (order?.id && !order.items) order = (await api(`/api/command/v2/catering/${order.id}`)).order;
    const menuItems = firstArray(state.data.invoices?.results?.[3]?.value, ["items", "menu_items"]);
    const itemText = arr(order?.items).map((item) => `${item.quantity} | ${item.description} | ${item.size_details || ""} | ${(Number(item.unit_price_cents || 0) / 100).toFixed(2)}`).join("\n");
    const actionText = arr(order?.required_actions).map((item) => `${item.description} | ${String(item.due_date || "").slice(0, 10)} | ${item.status || "open"}`).join("\n");
    const supplies = order?.supplies || {};
    openActionDialog({
      eyebrow: order ? "CATERING ORDER" : "NEW CATERING ORDER",
      title: order ? order.order_number || order.customer_name : "Plan a connected catering order",
      description: "Preparation, customer details, required actions, and financial documents stay linked in one record.",
      body: `<div class="form-grid"><div class="form-control"><label>Customer / organization</label><input name="customer_name" required value="${esc(order?.customer_name || "")}"></div><div class="form-control"><label>Contact name</label><input name="contact_name" value="${esc(order?.contact_name || "")}"></div><div class="form-control"><label>Phone</label><input name="customer_phone" value="${esc(order?.customer_phone || "")}"></div><div class="form-control"><label>Email</label><input name="customer_email" type="email" value="${esc(order?.customer_email || "")}"></div><div class="form-control"><label>Event date</label><input name="event_date" type="date" value="${esc(String(order?.event_date || "").slice(0, 10))}"></div><div class="form-control"><label>Service</label><select name="service_type">${["pickup","delivery","dine_in"].map((value) => `<option value="${value}" ${order?.service_type === value ? "selected" : ""}>${esc(titleCase(value))}</option>`).join("")}</select></div><div class="form-control"><label>Event time</label><input name="event_time" type="time" value="${esc(String(order?.event_time || "").slice(0, 5))}"></div><div class="form-control"><label>Ready-by time</label><input name="ready_by_time" type="time" value="${esc(String(order?.ready_by_time || "").slice(0, 5))}"></div><div class="form-control"><label>Guest count</label><input name="guest_count" type="number" min="1" value="${esc(order?.guest_count || "")}"></div><div class="form-control"><label>Status</label><select name="status">${["inquiry","quoted","confirmed","preparing","ready","completed","cancelled"].map((value) => `<option value="${value}" ${order?.status === value ? "selected" : ""}>${esc(titleCase(value))}</option>`).join("")}</select></div><div class="form-control full"><label>Destination / venue</label><input name="venue_address" value="${esc(order?.venue_address || "")}"></div><div class="form-control full"><label>Items — one per line: quantity | description | size/details | unit price</label><textarea name="items_text" required rows="6" placeholder="10 | Large pizzas | 5 pepperoni, 5 cheese | 17.00">${esc(itemText)}</textarea></div><div class="form-control full"><label>Dietary requirements — comma separated</label><input name="dietary_text" value="${esc(arr(order?.dietary_requirements).join(", "))}"></div><div class="form-control full"><label>Supplies — comma separated</label><input name="supplies_text" value="${esc(Object.entries(supplies).filter(([,enabled]) => enabled).map(([key]) => titleCase(key)).join(", "))}" placeholder="Plates, napkins, dressings, bread, drinks"></div><div class="form-control full"><label>Required actions — one per line: task | due date | open/completed</label><textarea name="actions_text" rows="4" placeholder="Confirm delivery access | 2026-09-04 | open">${esc(actionText)}</textarea></div><div class="form-control"><label>Tax rate (%)</label><input name="tax_rate" type="number" min="0" max="25" step="0.01" value="${esc(Number(order?.tax_rate_basis_points ?? 800) / 100)}"></div><div class="form-control"><label>Deposit received</label><input name="deposit" type="number" min="0" step="0.01" value="${esc(Number(order?.deposit_cents || 0) / 100)}"></div><div class="form-control full"><label>Payment instructions</label><textarea name="payment_instruction">${esc(order?.payment_instruction || "")}</textarea></div><div class="form-control full"><label>Internal preparation notes</label><textarea name="notes">${esc(order?.notes || "")}</textarea></div><div class="form-control full"><label>Follow-up note</label><textarea name="follow_up_note">${esc(order?.follow_up_note || "")}</textarea></div></div>`,
      buttons: [{ label: "Cancel", action: "close" }, { label: order ? "Save catering order" : "Create catering order", action: "save", className: "primary-button", submit: true }],
      onSubmit: async (values) => {
        const items = parseRows(values.items_text, ([qty, description, details, price]) => description ? ({ quantity: Number(qty) || 1, description, size_details: details || null, unit_price_cents: Math.round(Number(price || 0) * 100) }) : null);
        const requiredActions = parseRows(values.actions_text, ([description, dueDate, status]) => description ? ({ description, due_date: dueDate || null, status: status || "open" }) : null);
        const supplyNames = String(values.supplies_text || "").split(",").map((item) => item.trim().toLowerCase().replace(/\s+/g, "_")).filter(Boolean);
        const payload = { ...order, ...values, guest_count: Number(values.guest_count) || null, tax_rate_basis_points: Math.round(Number(values.tax_rate || 0) * 100), deposit_cents: Math.round(Number(values.deposit || 0) * 100), dietary_requirements: String(values.dietary_text || "").split(",").map((item) => item.trim()).filter(Boolean), supplies: Object.fromEntries(supplyNames.map((name) => [name, true])), items, required_actions: requiredActions };
        delete payload.items_text; delete payload.actions_text; delete payload.dietary_text; delete payload.supplies_text; delete payload.deposit;
        await runConnectedAction(() => api(order ? `/api/command/v2/catering/${order.id}` : "/api/command/v2/catering", { method: order ? "PUT" : "POST", body: JSON.stringify(payload) }), order ? "Catering order updated." : "Catering order created.", "invoices");
      }
    });
    const itemsField = $('[name="items_text"]', $("#actionBody"));
    if (itemsField && menuItems.length) {
      itemsField.closest(".form-control").insertAdjacentHTML("beforebegin", `<div class="form-control full connected-item-picker"><label>Add from catering / restaurant menu</label><div class="inline-picker"><select data-catering-menu-picker><option value="">Choose a connected menu item…</option>${menuItems.map((item)=>`<option value="${esc(item.id)}">${esc(item.category_name||item.category||"Menu")} · ${esc(item.name)} · ${money(item.price_cents??Math.round(Number(item.price||0)*100))}</option>`).join("")}</select><input data-catering-menu-qty type="number" min="1" value="1"><button type="button" class="button" data-catering-menu-add>Add</button></div></div>`);
      $("[data-catering-menu-add]",$("#actionBody")).addEventListener("click",()=>{const picker=$("[data-catering-menu-picker]",$("#actionBody"));const item=menuItems.find((entry)=>String(entry.id)===String(picker.value));if(!item)return notify("Choose a menu item first.",true);const qty=Math.max(1,Number($("[data-catering-menu-qty]",$("#actionBody")).value||1));const price=Number(item.price_cents??Math.round(Number(item.price||0)*100))/100;itemsField.value=[itemsField.value.trim(),`${qty} | ${item.name} | ${item.size_name||item.size_details||"Menu item"} | ${price.toFixed(2)}`].filter(Boolean).join("\n");picker.value="";notify(`${item.name} added from the connected menu.`);});
    }
  }

  async function invoiceWorkspaceDialog(invoice = null) {
    if (invoice?.id && !invoice.items) invoice = (await api(`/api/invoices/${invoice.id}`)).invoice;
    const readOnly = Boolean(invoice?.locked);
    const cateringOrders = firstArray(state.data.invoices?.results?.[0]?.value, ["orders"]);
    const menuItems = firstArray(state.data.invoices?.results?.[3]?.value, ["items", "menu_items"]);
    const isCateringItem = (item) => String(item.category_slug || item.category_name || item.category || "").toLowerCase().includes("cater");
    const expandCatalog = (items) => items.flatMap((item) => {
      const sizes = item.size_prices && typeof item.size_prices === "object" && !Array.isArray(item.size_prices) ? Object.entries(item.size_prices) : [];
      if (!sizes.length) return [{ ...item, picker_id: `${item.id}||${item.price_cents ?? Math.round(Number(item.price || 0) * 100)}` }];
      return sizes.map(([size, price]) => ({ ...item, picker_id: `${item.id}|${encodeURIComponent(size)}|${Math.round(Number(price || 0) * 100)}`, picker_name: `${item.name} · ${size}`, price_cents: Math.round(Number(price || 0) * 100) }));
    });
    const regularMenu = expandCatalog(menuItems.filter((item) => !isCateringItem(item)));
    const cateringMenu = expandCatalog(menuItems.filter(isCateringItem));
    let lines = arr(invoice?.items).map((item) => ({
      description: item.description || "",
      quantity: Number(item.quantity || 1),
      unit_price_cents: Number(item.unit_price_cents || 0),
      source_type: item.source_type || "custom",
      source_id: item.source_id || null
    }));
    const recentCustom = (() => {
      try { return JSON.parse(localStorage.getItem("hop_invoice_custom_items") || "[]"); }
      catch { return []; }
    })();
    const dollars = (field) => (Number(invoice?.[field] || 0) / 100).toFixed(2);
    const optionList = (items, placeholder) => `<option value="">${esc(placeholder)}</option>${items.map((item) => `<option value="${esc(item.picker_id)}">${esc(item.category_name || item.category || "Menu")} · ${esc(item.picker_name || item.name)} · ${money(item.price_cents ?? Math.round(Number(item.price || 0) * 100))}</option>`).join("")}`;

    openActionDialog({
      eyebrow: invoice ? "DOCUMENT WORKSPACE" : "NEW DOCUMENT",
      title: invoice ? invoice.invoice_number : "Create quote or invoice",
      description: invoice ? `${invoice.customer_name} · ${titleCase(invoice.status)}` : "Build from the connected menu, add reusable custom lines, then preview before saving.",
      body: `<div class="invoice-builder-layout">
        <div class="invoice-builder-main">
          <section class="invoice-builder-section">
            <div class="invoice-section-head"><div><span>01</span><h3>Document & customer</h3></div><small>Connected billing record</small></div>
            <div class="form-grid invoice-document-fields">
              <div class="form-control"><label>Document type</label><select name="document_type" ${readOnly ? "disabled" : ""}>${["quote","invoice"].map((value) => `<option value="${value}" ${(invoice?.document_type || "invoice") === value ? "selected" : ""}>${esc(titleCase(value))}</option>`).join("")}</select></div>
              <div class="form-control"><label>Status</label><select name="status" ${readOnly ? "disabled" : ""}>${["draft","printed","sent","partial","paid"].map((value) => `<option value="${value}" ${(invoice?.status || "draft") === value ? "selected" : ""}>${esc(titleCase(value))}</option>`).join("")}</select></div>
              <div class="form-control"><label>Customer / organization</label><input name="customer_name" required ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_name || "")}"></div>
              <div class="form-control"><label>Contact name</label><input name="contact_name" ${readOnly ? "disabled" : ""} value="${esc(invoice?.contact_name || "")}"></div>
              <div class="form-control"><label>Phone</label><input name="customer_phone" ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_phone || "")}"></div>
              <div class="form-control"><label>Email</label><input name="customer_email" type="email" ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_email || "")}"></div>
              <div class="form-control"><label>Issue date</label><input name="issue_date" type="date" required ${readOnly ? "disabled" : ""} value="${esc(String(invoice?.issue_date || dates.today()).slice(0,10))}"></div>
              <div class="form-control"><label>Due date</label><input name="due_date" type="date" ${readOnly ? "disabled" : ""} value="${esc(String(invoice?.due_date || "").slice(0,10))}"></div>
              <div class="form-control"><label>Event date</label><input name="event_date" type="date" ${readOnly ? "disabled" : ""} value="${esc(String(invoice?.event_date || "").slice(0,10))}"></div>
              <div class="form-control"><label>Linked catering order</label><select name="catering_order_id" ${readOnly ? "disabled" : ""}><option value="">Not linked</option>${cateringOrders.map((order) => `<option value="${esc(order.id)}" ${String(invoice?.catering_order_id) === String(order.id) ? "selected" : ""}>${esc(order.order_number || "Catering")} · ${esc(order.customer_name)}</option>`).join("")}</select></div>
              <div class="form-control full"><label>Billing / delivery address</label><input name="customer_address" ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_address || "")}"></div>
            </div>
          </section>
          <section class="invoice-builder-section">
            <div class="invoice-section-head"><div><span>02</span><h3>Line items</h3></div><small>Menu-connected and fully editable</small></div>
            ${readOnly ? "" : `<div class="invoice-catalog-toolbar">
              <div><label>Regular menu</label><div class="invoice-add-control"><select data-invoice-picker="regular">${optionList(regularMenu,"Choose regular menu item…")}</select><input data-invoice-qty="regular" type="number" min="1" step="1" value="1" aria-label="Quantity"><button type="button" class="button" data-invoice-add-menu="regular">Add</button></div></div>
              <div><label>Catering menu</label><div class="invoice-add-control"><select data-invoice-picker="catering">${optionList(cateringMenu,"Choose catering item…")}</select><input data-invoice-qty="catering" type="number" min="1" step="1" value="1" aria-label="Quantity"><button type="button" class="button" data-invoice-add-menu="catering">Add</button></div></div>
            </div>`}
            <div class="invoice-line-table" data-invoice-lines></div>
            ${readOnly ? "" : `<div class="invoice-custom-composer">
              <div><label>Custom item</label><input data-custom-description list="invoice-custom-history" placeholder="Description, setup charge, special package…"><datalist id="invoice-custom-history">${recentCustom.map((item) => `<option value="${esc(item)}"></option>`).join("")}</datalist></div>
              <div><label>Qty</label><input data-custom-quantity type="number" min="0.01" step="0.01" value="1"></div>
              <div><label>Unit price</label><input data-custom-price type="number" min="0" step="0.01" placeholder="0.00"></div>
              <button type="button" class="primary-button" data-invoice-add-custom>+ Add custom line</button>
            </div>`}
          </section>
          <section class="invoice-builder-section">
            <div class="invoice-section-head"><div><span>03</span><h3>Charges & payment</h3></div><small>Shown as clear document lines</small></div>
            <div class="invoice-charge-grid">
              <div class="form-control"><label>Discount ($)</label><input name="discount" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("discount_cents"))}"></div>
              <div class="form-control"><label>Discount (%)</label><input name="discount_rate" type="number" min="0" max="100" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(Number(invoice?.discount_basis_points || 0) / 100)}"></div>
              <div class="form-control"><label>Tax rate (%)</label><input name="tax_rate" type="number" min="0" max="25" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(Number(invoice?.tax_rate_basis_points ?? 800) / 100)}"></div>
              <div class="form-control invoice-charge-control"><label>Delivery fee</label><span>DELIVERY LINE</span><input name="delivery_fee" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("delivery_fee_cents"))}"></div>
              <div class="form-control invoice-charge-control"><label>Gratuity</label><span>GRATUITY LINE</span><input name="gratuity" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("gratuity_cents"))}"></div>
              <div class="form-control invoice-charge-control"><label>Other fee</label><span>OTHER FEE LINE</span><input name="other_fee" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("other_fee_cents"))}"></div>
              <div class="form-control"><label>Card fee (%)</label><input name="card_fee_rate" type="number" min="0" max="25" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(Number(invoice?.card_fee_basis_points ?? 350) / 100)}"></div>
              <div class="form-control"><label>Amount paid</label><input name="amount_paid" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("amount_paid_cents"))}"></div>
              <div class="form-control"><label>Payment method</label><select name="payment_method" ${readOnly ? "disabled" : ""}>${["not-set","cash","check","card","online"].map((value) => `<option value="${value}" ${String(invoice?.payment_method || "not-set") === value ? "selected" : ""}>${esc(titleCase(value.replace("not-set","not selected")))}</option>`).join("")}</select></div>
            </div>
          </section>
          <section class="invoice-builder-section invoice-notes-section">
            <div class="invoice-section-head"><div><span>04</span><h3>Notes</h3></div></div>
            <div class="form-grid"><div class="form-control"><label>Customer note</label><textarea name="customer_note" ${readOnly ? "disabled" : ""}>${esc(invoice?.customer_note || "")}</textarea></div><div class="form-control"><label>Internal note</label><textarea name="internal_note" ${readOnly ? "disabled" : ""}>${esc(invoice?.internal_note || "")}</textarea></div></div>
          </section>
        </div>
        <aside class="invoice-builder-preview"><div class="invoice-preview-label"><span>LIVE DOCUMENT</span><b data-invoice-preview-status>Ready</b></div><section class="invoice-live-preview" data-invoice-live-preview></section></aside>
      </div>`,
      buttons: readOnly ? [{ label: "Close", action: "close" }] : [{ label: "Cancel", action: "close" }, { label: invoice ? "Save document" : "Create document", action: "save", className: "primary-button", submit: true }],
      onSubmit: async (values) => {
        if (!lines.length) throw new Error("Add at least one item before saving this document.");
        const customDescriptions = lines.filter((item) => item.source_type === "custom").map((item) => item.description).filter(Boolean);
        localStorage.setItem("hop_invoice_custom_items", JSON.stringify([...new Set([...customDescriptions, ...recentCustom])].slice(0, 20)));
        const payload = {
          ...invoice, ...values, actor_id: manager()?.id || null,
          items: lines.map((item) => ({ ...item, quantity: Number(item.quantity), unit_price_cents: Number(item.unit_price_cents) })),
          discount_cents: Math.round(Number(values.discount || 0) * 100), discount_basis_points: Math.round(Number(values.discount_rate || 0) * 100),
          tax_rate_basis_points: Math.round(Number(values.tax_rate || 0) * 100), gratuity_cents: Math.round(Number(values.gratuity || 0) * 100),
          delivery_fee_cents: Math.round(Number(values.delivery_fee || 0) * 100), other_fee_cents: Math.round(Number(values.other_fee || 0) * 100),
          card_fee_basis_points: Math.round(Number(values.card_fee_rate || 0) * 100), amount_paid_cents: Math.round(Number(values.amount_paid || 0) * 100)
        };
        ["discount","discount_rate","tax_rate","gratuity","delivery_fee","other_fee","card_fee_rate","amount_paid"].forEach((key) => delete payload[key]);
        await runConnectedAction(() => api(invoice ? `/api/invoices/${invoice.id}` : "/api/invoices", { method: invoice ? "PUT" : "POST", body: JSON.stringify(payload) }), invoice ? "Document updated." : "Document created.", "invoices");
      }
    });

    const dialog = $("#actionDialog");
    const root = $("#actionBody");
    dialog.classList.add("invoice-workspace-dialog");
    const currentMoney = (name) => Math.max(0, Math.round(Number($(`[name="${name}"]`, root)?.value || 0) * 100));
    function renderLines() {
      const target = $("[data-invoice-lines]", root);
      target.innerHTML = `<div class="invoice-line-head"><span>Description</span><span>Qty</span><span>Unit price</span><span>Total</span><span></span></div>${lines.length ? lines.map((item, index) => `<div class="invoice-line-row" data-line-index="${index}"><input data-line-field="description" value="${esc(item.description)}" ${readOnly ? "disabled" : ""}><input data-line-field="quantity" type="number" min="0.01" step="0.01" value="${esc(item.quantity)}" ${readOnly ? "disabled" : ""}><div class="money-input"><span>$</span><input data-line-field="unit_price" type="number" min="0" step="0.01" value="${esc((Number(item.unit_price_cents || 0) / 100).toFixed(2))}" ${readOnly ? "disabled" : ""}></div><b>${money(Number(item.quantity) * Number(item.unit_price_cents))}</b>${readOnly ? `<span></span>` : `<div class="invoice-line-actions"><button type="button" data-line-duplicate="${index}" title="Duplicate line">⧉</button><button type="button" data-line-remove="${index}" title="Remove line">×</button></div>`}</div>`).join("") : `<div class="invoice-lines-empty"><b>No items yet</b><span>Choose from either connected menu or add a custom line below.</span></div>`}`;
      renderPreview();
    }
    function calculatePreview() {
      const subtotal = lines.reduce((sum, item) => sum + Math.round(Number(item.quantity || 0) * Number(item.unit_price_cents || 0)), 0);
      const fixed = currentMoney("discount");
      const discountRate = Number($('[name="discount_rate"]', root)?.value || 0);
      const discount = Math.min(subtotal, fixed + Math.round(subtotal * discountRate / 100));
      const taxable = Math.max(0, subtotal - discount);
      const taxRate = Number($('[name="tax_rate"]', root)?.value || 0);
      const tax = Math.round(taxable * taxRate / 100);
      const delivery = currentMoney("delivery_fee");
      const gratuity = currentMoney("gratuity");
      const other = currentMoney("other_fee");
      return { subtotal, discount, taxRate, tax, delivery, gratuity, other, total: taxable + tax + delivery + gratuity + other };
    }
    function renderPreview() {
      const totals = calculatePreview();
      const charges = [["Delivery fee", totals.delivery], ["Gratuity", totals.gratuity], ["Other fee", totals.other]].filter(([, amount]) => amount > 0);
      const customer = $('[name="customer_name"]', root)?.value || "Customer / organization";
      const type = ($('[name="document_type"]', root)?.value || "invoice").toUpperCase();
      $("[data-invoice-live-preview]", root).innerHTML = `<div class="invoice-preview-head"><span>HOUSE OF PIZZA &amp; PASTA</span><b>${esc(type)}</b></div><div class="invoice-preview-meta"><strong>${esc(customer)}</strong><span>${esc($('[name="issue_date"]', root)?.value || dates.today())}</span></div><div class="invoice-preview-lines">${lines.length ? lines.map((item) => `<div><span>${esc(item.quantity)} × ${esc(item.description)}</span><b>${money(Number(item.quantity) * Number(item.unit_price_cents))}</b></div>`).join("") : `<div class="empty-line">Add an item to begin this document.</div>`}${charges.map(([label, amount]) => `<div class="charge-line"><span>1 × ${esc(label)}</span><b>${money(amount)}</b></div>`).join("")}</div><div class="invoice-preview-total"><span>Subtotal <b>${money(totals.subtotal)}</b></span>${totals.discount ? `<span>Discount <b>−${money(totals.discount)}</b></span>` : ""}<span>Tax (${esc(totals.taxRate)}%) <b>${money(totals.tax)}</b></span><strong>Total <b>${money(totals.total)}</b></strong></div>`;
    }
    root.addEventListener("click", (event) => {
      const addMenu = event.target.closest("[data-invoice-add-menu]");
      if (addMenu) {
        const kind = addMenu.dataset.invoiceAddMenu;
        const picker = $(`[data-invoice-picker="${kind}"]`, root);
        const [itemId, encodedSize, selectedPrice] = String(picker?.value || "").split("|");
        const item = menuItems.find((entry) => String(entry.id) === String(itemId));
        if (!item) return notify("Choose a menu item first.", true);
        const quantity = Math.max(0.01, Number($(`[data-invoice-qty="${kind}"]`, root)?.value || 1));
        const size = decodeURIComponent(encodedSize || "");
        const unitPrice = Number(selectedPrice || item.price_cents || Math.round(Number(item.price || 0) * 100));
        lines.push({ description: `${item.name}${size ? ` (${size})` : ""}`, quantity, unit_price_cents: unitPrice, source_type: kind === "catering" ? "catering_menu_item" : "menu_item", source_id: item.id });
        picker.value = "";
        renderLines();
        return;
      }
      if (event.target.closest("[data-invoice-add-custom]")) {
        const description = $("[data-custom-description]", root)?.value.trim();
        if (!description) return notify("Enter a custom item description.", true);
        lines.push({ description, quantity: Math.max(0.01, Number($("[data-custom-quantity]", root)?.value || 1)), unit_price_cents: Math.max(0, Math.round(Number($("[data-custom-price]", root)?.value || 0) * 100)), source_type: "custom", source_id: null });
        $("[data-custom-description]", root).value = "";
        $("[data-custom-price]", root).value = "";
        renderLines();
        return;
      }
      const duplicate = event.target.closest("[data-line-duplicate]");
      if (duplicate) { lines.splice(Number(duplicate.dataset.lineDuplicate) + 1, 0, { ...lines[Number(duplicate.dataset.lineDuplicate)] }); renderLines(); return; }
      const remove = event.target.closest("[data-line-remove]");
      if (remove) { lines.splice(Number(remove.dataset.lineRemove), 1); renderLines(); }
    });
    root.addEventListener("input", (event) => {
      const row = event.target.closest("[data-line-index]");
      if (row && event.target.dataset.lineField) {
        const line = lines[Number(row.dataset.lineIndex)];
        if (event.target.dataset.lineField === "description") line.description = event.target.value;
        if (event.target.dataset.lineField === "quantity") line.quantity = Math.max(0.01, Number(event.target.value || 1));
        if (event.target.dataset.lineField === "unit_price") line.unit_price_cents = Math.max(0, Math.round(Number(event.target.value || 0) * 100));
        const totalCell = row.querySelector(":scope > b");
        if (totalCell) totalCell.textContent = money(Number(line.quantity) * Number(line.unit_price_cents));
      }
      renderPreview();
    });
    root.addEventListener("change", (event) => {
      if (event.target.name === "catering_order_id" && event.target.value) {
        const order = cateringOrders.find((item) => String(item.id) === String(event.target.value));
        const deliveryInput = $('[name="delivery_fee"]', root);
        if (order && deliveryInput && Number(deliveryInput.value || 0) === 0 && Number(order.delivery_fee_cents || 0) > 0) deliveryInput.value = (Number(order.delivery_fee_cents) / 100).toFixed(2);
      }
      renderPreview();
    });
    renderLines();
  }

  async function printInvoiceDocument(id, exportMode = false) {
    if (!id) throw new Error("Select a document before printing.");
    const payload = await api(`/api/invoices/${id}`);
    if (!payload?.invoice || !Array.isArray(payload.invoice.items)) throw new Error("The complete document could not be loaded for printing.");
    state.invoiceDetail = payload.invoice;
    state.selected = { kind: "invoice", id: payload.invoice.id };
    $("#appMain").innerHTML = renderInvoices(state.data.invoices);
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    document.body.classList.add("printing-invoice");
    try {
      window.HopExportService.print();
      if (exportMode) notify("Choose Save as PDF. The exported document now includes every loaded item and charge line.");
    } finally {
      setTimeout(() => document.body.classList.remove("printing-invoice"), 500);
    }
  }

  async function invoiceDialog(invoice = null) {
    if (invoice?.id && !invoice.items) invoice = (await api(`/api/invoices/${invoice.id}`)).invoice;
    const readOnly = Boolean(invoice?.locked);
    const cateringOrders = firstArray(state.data.invoices?.results?.[0]?.value, ["orders"]);
    const menuItems = firstArray(state.data.invoices?.results?.[3]?.value, ["items", "menu_items"]);
    const cateringCatalog = menuItems.filter((item)=>String(item.category_slug||item.category_name||item.category||"").toLowerCase().includes("cater"));
    const regularCatalog = menuItems.filter((item)=>!cateringCatalog.includes(item));
    const expandCatalogSizes = (items) => items.flatMap((item)=>{
      const sizes = item.size_prices && typeof item.size_prices === "object" && !Array.isArray(item.size_prices) ? Object.entries(item.size_prices) : [];
      if (!sizes.length) return [{ ...item, id:`${item.id}||${item.price_cents??Math.round(Number(item.price||0)*100)}` }];
      return sizes.map(([size,price])=>({ ...item, id:`${item.id}|${encodeURIComponent(size)}|${Math.round(Number(price||0)*100)}`, name:`${item.name} · ${size}`, price_cents:Math.round(Number(price||0)*100) }));
    });
    const regularMenuItems = expandCatalogSizes(regularCatalog);
    const cateringMenuItems = expandCatalogSizes(cateringCatalog);
    const itemText = arr(invoice?.items).map((item) => `${item.quantity} | ${item.description} | ${(Number(item.unit_price_cents || 0) / 100).toFixed(2)}`).join("\n");
    const dollars = (field) => (Number(invoice?.[field] || 0) / 100).toFixed(2);
    openActionDialog({
      eyebrow: invoice ? "QUOTE / INVOICE" : "NEW QUOTE / INVOICE", title: invoice ? invoice.invoice_number : "Create quote or invoice",
      description: invoice ? `${invoice.customer_name} · ${titleCase(invoice.status)}` : "Tax, fees, payments, and line totals use exact cent-based calculations.",
      body: `<div class="form-grid"><div class="form-control"><label>Document type</label><select name="document_type" ${readOnly ? "disabled" : ""}>${["quote","invoice"].map((value) => `<option value="${value}" ${(invoice?.document_type || "invoice") === value ? "selected" : ""}>${esc(titleCase(value))}</option>`).join("")}</select></div><div class="form-control"><label>Status</label><select name="status" ${readOnly ? "disabled" : ""}>${["draft","printed","sent","partial","paid"].map((value) => `<option value="${value}" ${(invoice?.status || "draft") === value ? "selected" : ""}>${esc(titleCase(value))}</option>`).join("")}</select></div><div class="form-control"><label>Customer / organization</label><input name="customer_name" required ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_name || "")}"></div><div class="form-control"><label>Contact name</label><input name="contact_name" ${readOnly ? "disabled" : ""} value="${esc(invoice?.contact_name || "")}"></div><div class="form-control"><label>Phone</label><input name="customer_phone" ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_phone || "")}"></div><div class="form-control"><label>Email</label><input name="customer_email" type="email" ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_email || "")}"></div><div class="form-control"><label>Issue date</label><input name="issue_date" type="date" required ${readOnly ? "disabled" : ""} value="${esc(String(invoice?.issue_date || dates.today()).slice(0, 10))}"></div><div class="form-control"><label>Due date</label><input name="due_date" type="date" ${readOnly ? "disabled" : ""} value="${esc(String(invoice?.due_date || "").slice(0, 10))}"></div><div class="form-control"><label>Event date</label><input name="event_date" type="date" ${readOnly ? "disabled" : ""} value="${esc(String(invoice?.event_date || "").slice(0, 10))}"></div><div class="form-control"><label>Linked catering order</label><select name="catering_order_id" ${readOnly ? "disabled" : ""}><option value="">Not linked</option>${cateringOrders.map((order) => `<option value="${esc(order.id)}" ${String(invoice?.catering_order_id) === String(order.id) ? "selected" : ""}>${esc(order.order_number)} · ${esc(order.customer_name)}</option>`).join("")}</select></div><div class="form-control full"><label>Billing / delivery address</label><input name="customer_address" ${readOnly ? "disabled" : ""} value="${esc(invoice?.customer_address || "")}"></div>${readOnly?"":`<div class="form-control full"><label>Connected item catalog</label><div class="invoice-catalog-split"><section><b>Regular Menu</b><small>${regularMenuItems.length} items</small><div class="inline-picker"><select data-invoice-menu-picker="regular"><option value="">Choose regular menu item…</option>${regularMenuItems.map((item)=>`<option value="${esc(item.id)}">${esc(item.category_name||"Menu")} · ${esc(item.name)} · ${money(item.price_cents??Math.round(Number(item.price||0)*100))}</option>`).join("")}</select><input data-invoice-menu-qty="regular" type="number" min="1" value="1" aria-label="Regular item quantity"><button type="button" class="button" data-invoice-menu-add="regular">Add</button></div></section><section><b>Catering Menu</b><small>${cateringMenuItems.length} items</small><div class="inline-picker"><select data-invoice-menu-picker="catering"><option value="">Choose catering item…</option>${cateringMenuItems.map((item)=>`<option value="${esc(item.id)}">${esc(item.name)} · ${money(item.price_cents??Math.round(Number(item.price||0)*100))}</option>`).join("")}</select><input data-invoice-menu-qty="catering" type="number" min="1" value="1" aria-label="Catering item quantity"><button type="button" class="button" data-invoice-menu-add="catering">Add</button></div></section></div></div>`}<div class="form-control full"><label>Invoice items</label><textarea name="items_text" required rows="6" ${readOnly ? "disabled" : ""} placeholder="Choose from either catalog, or enter: 2 | Custom item | 18.95">${esc(itemText)}</textarea><small>Regular and catering records come from the same authoritative menu database. Custom lines remain supported.</small></div><div class="form-control"><label>Discount</label><input name="discount" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("discount_cents"))}"></div><div class="form-control"><label>Tax rate (%)</label><input name="tax_rate" type="number" min="0" max="25" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(Number(invoice?.tax_rate_basis_points ?? 800) / 100)}"></div><div class="form-control"><label>Gratuity</label><input name="gratuity" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("gratuity_cents"))}"></div><div class="form-control"><label>Delivery fee</label><input name="delivery_fee" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("delivery_fee_cents"))}"></div><div class="form-control"><label>Other fee</label><input name="other_fee" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("other_fee_cents"))}"></div><div class="form-control"><label>Card fee (%)</label><input name="card_fee_rate" type="number" min="0" max="25" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(Number(invoice?.card_fee_basis_points ?? 350) / 100)}"></div><div class="form-control"><label>Amount paid</label><input name="amount_paid" type="number" min="0" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(dollars("amount_paid_cents"))}"></div><div class="form-control"><label>Payment method</label><input name="payment_method" ${readOnly ? "disabled" : ""} value="${esc(invoice?.payment_method || "not-set")}"></div><div class="form-control full"><label>Customer note</label><textarea name="customer_note" ${readOnly ? "disabled" : ""}>${esc(invoice?.customer_note || "")}</textarea></div><div class="form-control full"><label>Internal note</label><textarea name="internal_note" ${readOnly ? "disabled" : ""}>${esc(invoice?.internal_note || "")}</textarea></div></div>${invoice ? `<div class="record-summary"><span><small>Total</small><b>${money(invoice.total_cents)}</b></span><span><small>Card total</small><b>${money(invoice.card_total_cents)}</b></span><span><small>Balance</small><b>${money(invoice.balance_due_cents)}</b></span></div>` : ""}`,
      buttons: readOnly ? [{ label: "Close", action: "close" }] : [{ label: "Cancel", action: "close" }, { label: invoice ? "Save document" : "Create document", action: "save", className: "primary-button", submit: true }],
      onSubmit: async (values) => {
        const items = parseRows(values.items_text, ([qty, description, price]) => description ? ({ quantity: Number(qty) || 1, description, unit_price_cents: Math.round(Number(price || 0) * 100) }) : null);
        const payload = { ...invoice, ...values, actor_id: manager()?.id || null, items, discount_cents: Math.round(Number(values.discount || 0) * 100), discount_basis_points: Math.round(Number(values.discount_rate || 0) * 100), tax_rate_basis_points: Math.round(Number(values.tax_rate || 0) * 100), gratuity_cents: Math.round(Number(values.gratuity || 0) * 100), delivery_fee_cents: Math.round(Number(values.delivery_fee || 0) * 100), other_fee_cents: Math.round(Number(values.other_fee || 0) * 100), card_fee_basis_points: Math.round(Number(values.card_fee_rate || 0) * 100), amount_paid_cents: Math.round(Number(values.amount_paid || 0) * 100) };
        ["items_text","discount","discount_rate","gratuity","delivery_fee","other_fee","amount_paid"].forEach((key) => delete payload[key]);
        await runConnectedAction(() => api(invoice ? `/api/invoices/${invoice.id}` : "/api/invoices", { method: invoice ? "PUT" : "POST", body: JSON.stringify(payload) }), invoice ? "Document updated." : "Document created.", "invoices");
      }
    });
    $$("[data-invoice-menu-add]", $("#actionBody")).forEach((addMenuItem)=>addMenuItem.addEventListener("click", () => {
      const catalog = addMenuItem.dataset.invoiceMenuAdd;
      const picker = $(`[data-invoice-menu-picker="${catalog}"]`, $("#actionBody"));
      const quantity = Math.max(1, Number($(`[data-invoice-menu-qty="${catalog}"]`, $("#actionBody"))?.value || 1));
      const [menuItemId,encodedSize,selectedPrice] = String(picker?.value||"").split("|");
      const menuItem = menuItems.find((entry)=>String(entry.id)===String(menuItemId));
      if (!menuItem) return notify("Choose a menu item first.", true);
      const price = Number(selectedPrice || menuItem.price_cents || Math.round(Number(menuItem.price||0)*100))/100;
      const size = decodeURIComponent(encodedSize||"");
      const textarea = $('[name="items_text"]', $("#actionBody"));
      textarea.value = [textarea.value.trim(),`${quantity} | ${menuItem.name}${size?` (${size})`:""} | ${price.toFixed(2)}`].filter(Boolean).join("\n");
      picker.value = "";
      renderInvoicePreview();
    }));
    const previewRoot = $("#actionBody");
    const fixedDiscount = $('[name="discount"]', previewRoot)?.closest(".form-control");
    fixedDiscount?.insertAdjacentHTML("afterend", `<div class="form-control"><label>Discount (%)</label><input name="discount_rate" type="number" min="0" max="100" step="0.01" ${readOnly ? "disabled" : ""} value="${esc(Number(invoice?.discount_basis_points||0)/100)}"><small>Percentage and fixed discount can be combined.</small></div>`);
    previewRoot.insertAdjacentHTML("beforeend", `<section class="invoice-live-preview" data-invoice-live-preview></section>`);
    function renderInvoicePreview() {
      const lines = parseRows($('[name="items_text"]', previewRoot)?.value, ([qty, description, price])=>description?{quantity:Number(qty)||1,description,unit_price_cents:Math.round(Number(price||0)*100)}:null);
      const subtotal = lines.reduce((sum,item)=>sum+item.quantity*item.unit_price_cents,0);
      const fixedDiscount = Math.round(Number($('[name="discount"]',previewRoot)?.value||0)*100);
      const discountRate = Number($('[name="discount_rate"]',previewRoot)?.value||0);
      const discount = Math.min(subtotal, fixedDiscount + Math.round(subtotal*discountRate/100));
      const taxable = Math.max(0,subtotal-discount);
      const taxRate = Number($('[name="tax_rate"]',previewRoot)?.value||0);
      const tax = Math.round(taxable*taxRate/100);
      const fees = ["gratuity","delivery_fee","other_fee"].reduce((sum,name)=>sum+Math.round(Number($(`[name="${name}"]`,previewRoot)?.value||0)*100),0);
      const total = taxable+tax+fees;
      const customer = $('[name="customer_name"]',previewRoot)?.value||"Customer / organization";
      $("[data-invoice-live-preview]",previewRoot).innerHTML = `<div class="invoice-preview-head"><span>HOUSE OF PIZZA &amp; PASTA</span><b>${esc(($('[name="document_type"]',previewRoot)?.value||"invoice").toUpperCase())}</b></div><div class="invoice-preview-meta"><strong>${esc(customer)}</strong><span>${esc($('[name="issue_date"]',previewRoot)?.value||dates.today())}</span></div><div class="invoice-preview-lines">${lines.length?lines.map((item)=>`<div><span>${esc(item.quantity)} × ${esc(item.description)}</span><b>${money(item.quantity*item.unit_price_cents)}</b></div>`).join(""):`<div class="empty-line">Choose items from the connected menu to build this document.</div>`}</div><div class="invoice-preview-total"><span>Subtotal <b>${money(subtotal)}</b></span><span>Tax (${esc(taxRate)}%) <b>${money(tax)}</b></span><strong>Total <b>${money(total)}</b></strong></div>`;
    }
    previewRoot.addEventListener("input",renderInvoicePreview);
    previewRoot.addEventListener("change",renderInvoicePreview);
    renderInvoicePreview();
  }

  function renderRoute(route, data) {
    const renderers = {
      home: renderHome, schedule: renderSchedule, employees: renderEmployees, inbox: renderInbox,
      applications: renderApplications, website: renderWebsite, menu: renderMenu, hopclub: renderHopClub, availability: renderAvailability,
      tasks: renderTasks, parties: renderParties, invoices: renderInvoices,
      reports: renderReports, notifications: renderNotifications, settings: renderSettings, watchdog: renderWatchdog,
    };
    return renderers[route](data);
  }

  async function navigate(route, options = {}) {
    if (!modules.some((item) => item.id === route)) route = "home";
    state.route = route;
    state.selected = options.keepSelection ? state.selected : null;
    if (options.week) state.weekStart = dates.startOfTuesdayWeek(options.week);
    location.hash = route;
    renderNav();
    const module = modules.find((item) => item.id === route);
    $("#pageTitle").textContent = module.label;
    $("#breadcrumb").textContent = route === "home" ? "Operations" : `Operations / ${module.label}`;
    $("#appMain").innerHTML = loading();
    $("#appMain").focus();
    state.loading = true;
    try {
      const data = await loadRouteData(route);
      state.data[route] = data;
      $("#appMain").innerHTML = renderRoute(route, data);
      if (route === "invoices" && !state.invoiceDetail) {
        const documents = firstArray(data.results?.[1]?.value, ["invoices"]);
        const firstDocument = documents.find((item) => String(item.id) === String(state.selected?.id)) || documents[0];
        if (firstDocument?.id) {
          const payload = await api(`/api/invoices/${firstDocument.id}`);
          state.invoiceDetail = payload.invoice || payload;
          state.selected = { kind: "invoice", id: firstDocument.id };
          $("#appMain").innerHTML = renderInvoices(data);
        }
      }
      if (data.offline) notify("Connected data is unavailable. The screen is showing safe empty states.", true);
    } catch (error) {
      $("#appMain").innerHTML = `<div class="page">${pageHead(route, `<button class="button" data-refresh>Try again</button>`)}${card("Could not load this module", empty("Connection unavailable", error.message, "watchdog"))}</div>`;
      notify(error.message, true);
    } finally { state.loading = false; }
  }

  function openLogin() {
    const dialog = $("#loginDialog");
    if (!dialog.open) dialog.showModal();
  }

  async function validateSession() {
    if (LOCAL_PREVIEW) return true;
    if (!localStorage.getItem(TOKEN_KEY)) return false;
    try {
      const payload = await api("/api/command-auth/session");
      localStorage.setItem(MANAGER_KEY, JSON.stringify(payload.manager || {}));
      return true;
    } catch (_error) { return false; }
  }

  document.addEventListener("click", (event) => {
    const homeTeam = event.target.closest("[data-home-team]");
    if (homeTeam) {
      state.homeTeamType = homeTeam.dataset.homeTeam;
      $("#appMain").innerHTML = renderHome(state.data.home);
      return;
    }
    const button = event.target.closest("button");
    const action = button?.dataset.action;
    const taskCell = event.target.closest("[data-task-cell]");
    if (taskCell && !event.target.closest("[data-select-task]")) {
      taskDialogV2(null, taskCell.dataset.taskCell || "");
      return;
    }
    if (action === "schedule-print") {
      if (state.route === "applications") { const apps=firstArray(state.data.applications?.results?.[0]?.value,["applications"]);const application=apps.find((item)=>String(item.id)===String(state.selected?.id))||apps[0];if(application)applicationSheetDialog(application);return; }
      window.HopExportService.print();
      return;
    }
    if (action === "schedule-export") {
      scheduleExportDialog();
      return;
    }
    if (action === "party-export") { partyExportDialog(); return; }
    if (action === "task-export") {
      document.body.classList.add("printing-taskboard");
      const cleanup = () => document.body.classList.remove("printing-taskboard");
      window.addEventListener("afterprint", cleanup, { once: true });
      window.HopExportService.print();
      setTimeout(cleanup, 2000);
      return;
    }
    if (action === "reports-export") {
      const invoices = firstArray(state.data.reports?.results?.[0]?.value, ["invoices"]);
      window.HopExportService.exportCsv(`HOP-Operational-Records-${dates.today()}.csv`, [
        { label: "Document", value: "invoice_number" }, { label: "Customer", value: "customer_name" },
        { label: "Issue date", value: "issue_date" }, { label: "Status", value: "status" },
        { label: "Total cents", value: "total_cents" }, { label: "Balance cents", value: "balance_due_cents" },
      ], invoices);
      notify("Connected operational records exported to CSV.");
      return;
    }
    if (action === "employee-new") { employeeDialog(); return; }
    if (action === "employee-mobile-studio") {
      state.employeeMobileStudio = !state.employeeMobileStudio;
      $("#appMain").innerHTML = renderEmployeeMobile(state.data["employee-mobile"] || {results:[]});
      return;
    }
    if (action === "employee-edit") {
      const employees = firstArray(state.data.employees?.results?.[0]?.value, ["employees"]);
      const employee = employees.find((item) => String(item.id) === String(button.dataset.id || state.selected?.id));
      if (employee) employeeDialog(employee);
      return;
    }
    if (action === "employee-pin-toggle") {
      const value = $(".employee-pin-value");
      if (value?.dataset.pinLast4) {
        const shown = value.textContent.includes(value.dataset.pinLast4);
        value.textContent = shown ? "••••" : `•••• ${value.dataset.pinLast4}`;
        button.textContent = shown ? "Show last 4" : "Hide";
      }
      return;
    }
    if (action === "employee-delete") {
      const employees = firstArray(state.data.employees?.results?.[0]?.value, ["employees"]);
      const employee = employees.find((item)=>String(item.id)===String(button.dataset.id));
      if (!employee) return;
      openActionDialog({
        eyebrow:"EMPLOYEE ACCESS",
        title:`Remove ${employee.display_name || employee.name}?`,
        description:"The employee is deactivated and retained in historical schedules, reports, and audit records.",
        body:`<div class="info-banner warning">This removes employee-app access and excludes the employee from new schedules. Existing history is preserved.</div><div class="form-control"><label>Type REMOVE to confirm</label><input name="confirmation" autocomplete="off"></div>`,
        buttons:[{label:"Cancel",action:"close"},{label:"Remove employee",action:"remove",className:"danger-button",submit:true}],
        onSubmit:async(values)=>{if(values.confirmation!=="REMOVE")throw new Error("Type REMOVE exactly to confirm.");state.selected=null;await runConnectedAction(()=>api(`/api/employees/${employee.id}`,{method:"DELETE"}),"Employee access removed and history preserved.","employees");}
      });
      return;
    }
    if (action === "notification-new") { newAnnouncementDialog(); return; }
    if (action === "hopclub-member-new") { hopClubMemberDialog(); return; }
    if (action === "hopclub-member-edit" || action === "hopclub-points") {
      const customers = firstArray(state.data.hopclub?.results?.[1]?.value, ["customers"]);
      const member = customers.find((item)=>String(item.id)===String(button.dataset.id));
      if (member) (action === "hopclub-points" ? hopClubPointsDialog : hopClubMemberDialog)(member);
      return;
    }
    if (action === "hopclub-reward-new" || action === "hopclub-reward-edit") {
      const rewards = firstArray(state.data.hopclub?.results?.[2]?.value, ["reward_rules","rewards"]);
      const rule = action === "hopclub-reward-edit" ? rewards.find((item)=>String(item.id||item.code)===String(button.dataset.id)) : null;
      hopClubRewardDialog(rule); return;
    }
    if (action === "hopclub-campaign-new") { newAnnouncementDialog(); return; }
    if (action === "hopclub-campaign-send") {
      if (!window.confirm("Send this HOP Club campaign now?")) return;
      runConnectedAction(()=>api(`/api/hopclub/campaigns/${button.dataset.id}/send`,{method:"POST",body:JSON.stringify({reason:"Manager approved immediate send"})}),"Campaign sent.","hopclub"); return;
    }
    if (action === "notification-open") {
      const notifications = firstArray(state.data[state.route]?.results?.[state.route === "inbox" ? 1 : 0]?.value, ["notifications"]);
      const notification = notifications.find((item) => String(item.id) === String(button.dataset.id));
      if (notification) notificationDialog(notification);
      return;
    }
    if (action === "notifications-read-all") {
      openActionDialog({ eyebrow: "NOTIFICATIONS", title: "Mark all manager alerts read?", description: "The notification records remain available; only their read status changes.", body: "", buttons: [{ label: "Cancel", action: "close" }, { label: "Mark all read", action: "read", className: "primary-button", submit: true }], onSubmit: async () => runConnectedAction(() => api("/api/notifications/manager/read-all", { method: "POST" }), "All manager notifications marked read.", "notifications") });
      return;
    }
    if (action === "request-open") {
      const sourceIndex = button.dataset.source === "pending" ? 0 : 2;
      const requests = firstArray(state.data.inbox?.results?.[sourceIndex]?.value, ["requests", "items", button.dataset.source]);
      const employees = firstArray(state.data.inbox?.results?.[3]?.value, ["employees"]);
      const request = requests.find((item) => String(item.id) === String(button.dataset.id));
      if (request) requestDialog(request, employees, button.dataset.source === "pending");
      return;
    }
    if (action === "party-new") { partyDialog(); return; }
    if (action === "party-open" || action === "party-open-history") {
      const sourceIndex = action === "party-open" ? 0 : 1;
      const parties = firstArray(state.data.parties?.results?.[sourceIndex]?.value, ["parties"]);
      const party = parties.find((item) => String(item.id) === String(button.dataset.id));
      if (party) partyDialog(party, action === "party-open-history");
      return;
    }
    if (action === "application-open") {
      const applications = firstArray(state.data.applications?.results?.[0]?.value, ["applications"]);
      const application = applications.find((item) => String(item.id) === String(button.dataset.id));
      if (application) (/Preview Application Sheet/i.test(button.textContent)?applicationSheetDialog(application):applicationDialog(application));
      return;
    }
    if (action === "application-convert") {
      if (!window.confirm("Convert this applicant into a connected employee record? Existing employee matches will be protected by the server.")) return;
      api(`/api/job-applications/${button.dataset.id}/convert-to-employee`, {
        method: "POST",
        body: JSON.stringify({ actor_id: manager()?.id || null })
      }).then((payload) => {
        state.applicationDetail = payload.application || state.applicationDetail;
        notify(payload.already_converted ? "This applicant was already linked to an employee." : "Applicant converted to an employee.");
        return navigate("applications", { keepSelection: true });
      }).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "jobs-open") { window.open(`${API_BASE || location.origin}/jobs/`, "_blank", "noopener"); return; }
    if (action === "website-preview") { window.open("https://www.houseofpizzagaffney.com", "_blank", "noopener"); return; }
    if (action === "website-save") { saveWebsite().catch((error) => notify(error.message, true)); return; }
    if (action === "menu-new" || action === "menu-open") {
      const items = firstArray(state.data.menu?.results?.[0]?.value, ["items", "menu_items"]);
      const item = action === "menu-open" ? items.find((entry) => String(entry.id) === String(button.dataset.id)) : null;
      menuItemDialog(item).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "availability-open") {
      const employees = firstArray(state.data.availability?.results?.[1]?.value, ["employees"]);
      const employee = employees.find((entry) => String(entry.id) === String(button.dataset.id));
      if (employee) availabilityDialog(employee).catch((error)=>notify(error.message,true));
      return;
    }
    if (action === "task-new" || action === "task-open") {
      const tasks = firstArray(state.data.tasks?.results?.[0]?.value, ["tasks", "assignments"]);
      const task = action === "task-open" ? tasks.find((entry) => String(entry.id) === String(button.dataset.id)) : null;
      taskDialogV2(task, button.dataset.taskSlot || "");
      return;
    }
    if (action === "task-reminders") { runConnectedAction(()=>api("/api/tasks/run-reminders",{method:"POST",body:"{}"}),"Due-shift task reminders processed.","tasks"); return; }
    if (action === "task-clear-done") { if(!window.confirm("Delete all completed task definitions? Open tasks remain."))return;runConnectedAction(()=>api("/api/tasks/clear-done",{method:"POST",body:"{}"}),"Completed tasks cleared.","tasks");return; }
    if (action === "catering-new" || action === "catering-edit") {
      const orders = firstArray(state.data.invoices?.results?.[0]?.value, ["orders"]);
      const order = action === "catering-edit" ? (state.cateringDetail || orders.find((entry) => String(entry.id) === String(button.dataset.id))) : null;
      cateringDialog(order).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "catering-action-toggle") {
      runConnectedAction(() => api(`/api/command/v2/catering/${button.dataset.orderId}/actions/${button.dataset.id}`, { method: "POST", body: JSON.stringify({ completed: button.dataset.completed === "true" }) }), button.dataset.completed === "true" ? "Preparation action completed." : "Preparation action reopened.", "invoices");
      return;
    }
    if (action === "invoice-from-catering") {
      api(`/api/invoices/from-catering/${button.dataset.id}`, { method: "POST", body: JSON.stringify({ document_type: button.dataset.documentType, actor_id: manager()?.id || null }) }).then((payload) => {
        state.documentsTab = "documents"; state.invoiceDetail = payload.invoice; state.selected = { kind: "invoice", id: payload.invoice.id };
        notify(`${titleCase(button.dataset.documentType)} created from the catering order.`);
        return navigate("invoices", { keepSelection: true });
      }).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "invoice-new" || action === "invoice-open") {
      const active = firstArray(state.data.invoices?.results?.[1]?.value, ["invoices"]);
      const archived = firstArray(state.data.invoices?.results?.[2]?.value, ["invoices"]);
      const invoice = action === "invoice-open" ? (state.invoiceDetail || [...active, ...archived].find((entry) => String(entry.id) === String(button.dataset.id))) : null;
      invoiceWorkspaceDialog(invoice).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "invoice-print" || action === "invoice-export") {
      printInvoiceDocument(button.dataset.id, action === "invoice-export").catch((error) => notify(error.message, true));
      return;
    }
    if (action === "invoice-convert") {
      if (!window.confirm("Convert this quote into a new linked invoice? The original quote will remain unchanged.")) return;
      api(`/api/invoices/${button.dataset.id}/convert`, { method: "POST", body: JSON.stringify({ actor_id: manager()?.id || null }) }).then((payload) => {
        state.invoiceDetail = payload.invoice; state.selected = { kind: "invoice", id: payload.invoice.id }; notify("Quote converted to a linked invoice.");
        return navigate("invoices", { keepSelection: true });
      }).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "invoice-archive") {
      const archived = button.dataset.archived === "true";
      if (archived && !window.confirm("Move this document to the recoverable Archive? It can be restored later.")) return;
      api(`/api/invoices/${button.dataset.id}/archive`, { method: "POST", body: JSON.stringify({ archived, actor_id: manager()?.id || null }) }).then(() => {
        state.invoiceDetail = null; state.selected = null; notify(archived ? "Document moved to the recoverable Archive." : "Document restored.");
        return navigate("invoices", { keepSelection: true });
      }).catch((error) => notify(error.message, true));
      return;
    }
    if (action === "print-settings-save") { savePrintSettings().catch((error)=>notify(error.message,true)); return; }
    if (action === "appearance-save") { saveAppearanceSettings(); $("#appMain").innerHTML = renderSettings(state.data.settings); return; }
    if (action === "printer-discover") {
      discoverWindowsPrinters().then((printers)=>{
        if(!printers.length)throw new Error("Windows did not return an installed printer.");
        openActionDialog({eyebrow:"WINDOWS PRINTERS",title:"Choose the automatic printer",description:"Detected directly from this computer. No manual IP is required.",body:`<div class="form-control"><label>Installed printer</label><select name="printer_name">${printers.map((printer)=>`<option value="${esc(printer.name)}" ${printer.is_default?"selected":""}>${esc(printer.name)}${printer.is_default?" · Default":""}</option>`).join("")}</select></div>`,buttons:[{label:"Cancel",action:"close"},{label:"Use & connect",action:"connect",className:"primary-button",submit:true}],onSubmit:async(values)=>{const field=$('#settingsPage [name="printer_name"]');if(field)field.value=values.printer_name;closeActionDialog();await savePrintSettings();}});
      }).catch((error)=>notify(error.message,true)); return;
    }
    if (action === "bridge-connect") { const printer=$('#settingsPage [name="printer_name"]')?.value.trim(); startPrintBridge(printer).then(()=>{notify("This computer is connected as the automatic Print Bridge.");navigate("settings",{keepSelection:true});}).catch((error)=>notify(error.message,true)); return; }
    if (action === "print-test") { runConnectedAction(()=>api("/api/print-center/test",{method:"POST",body:"{}"}),"Test ticket added to the print queue.","settings"); return; }
    if (action === "print-retry-failed") { runConnectedAction(()=>api("/api/print-center/jobs/retry-failed",{method:"POST",body:"{}"}),"Failed print jobs returned to the queue.","settings"); return; }
    if (action === "print-cancel-waiting") {
      if (!window.confirm("Cancel every waiting print job? Completed audit history will remain.")) return;
      runConnectedAction(()=>api("/api/print-center/jobs/cancel-waiting",{method:"POST",body:"{}"}),"Waiting print jobs canceled.","settings"); return;
    }
    if (action === "print-clear-completed") { runConnectedAction(()=>api("/api/print-center/jobs/clear-completed",{method:"POST",body:"{}"}),"Completed print jobs archived.","settings"); return; }
    if (action === "print-job-retry") {
      runConnectedAction(()=>api(`/api/print-center/jobs/${button.dataset.id}/retry`,{method:"POST",body:"{}"}),"Print job returned to the queue.","settings"); return;
    }
    if (action === "print-job-cancel") {
      if (!window.confirm("Cancel this waiting print job?")) return;
      runConnectedAction(()=>api(`/api/print-center/jobs/${button.dataset.id}/cancel`,{method:"POST",body:"{}"}),"Print job canceled.","settings"); return;
    }
    if (action === "print-job-reprint") {
      runConnectedAction(()=>api(`/api/print-center/jobs/${button.dataset.id}/reprint`,{method:"POST",body:"{}"}),"Print job copied back into the queue.","settings"); return;
    }
    if (action?.startsWith("schedule-")) { scheduleAction(action).catch((error) => notify(error.message, true)); return; }
    if (action === "settings-save") { saveSettings().catch((error) => notify(error.message, true)); return; }
    const dialogAction = button?.dataset.dialogAction;
    if (dialogAction === "close") { closeActionDialog(); return; }
    if (button?.id === "managerButton") {
      const profile = manager() || {};
      openActionDialog({ eyebrow: "SECURE SESSION", title: profile.name || "Manager", description: "Authenticated against the shared Hostinger manager session.", body: `<div class="record-summary"><span><small>Role</small><b>${esc(titleCase(profile.role || "manager"))}</b></span><span><small>Connection</small><b>Hostinger live API</b></span></div>`, buttons: [{ label: "Close", action: "close" }, { label: "Sign out", action: "logout", className: "danger-button", submit: true }], onSubmit: async () => { localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(MANAGER_KEY); closeActionDialog(); openLogin(); } });
      return;
    }
    const routeButton = event.target.closest("[data-route]");
    if (routeButton) {
      const week = routeButton.dataset.week;
      if (routeButton.dataset.scheduleType) state.scheduleType = routeButton.dataset.scheduleType;
      navigate(routeButton.dataset.route, { week });
      document.body.classList.remove("nav-open");
      return;
    }
    if (event.target.closest("[data-refresh]")) { navigate(state.route, { keepSelection: true }); return; }
    const mobileScreen = event.target.closest("[data-mobile-screen]");
    if (mobileScreen) {
      state.employeeMobileScreen = mobileScreen.dataset.mobileScreen || "home";
      $("#appMain").innerHTML = renderEmployeeMobile(state.data["employee-mobile"] || { results: [] });
      return;
    }
    const monthMove = event.target.closest("[data-month-move]");
    if (monthMove) { const anchor=new Date(`${state.partyMonth}-01T12:00:00Z`); anchor.setUTCMonth(anchor.getUTCMonth()+Number(monthMove.dataset.monthMove)); state.partyMonth=anchor.toISOString().slice(0,7); state.selected=null; navigate("parties",{keepSelection:true}); return; }
    const move = event.target.closest("[data-week-move]");
    if (move) { state.weekStart = dates.addDays(state.weekStart, Number(move.dataset.weekMove)); navigate(state.route, { keepSelection: true }); return; }
    const type = event.target.closest("[data-schedule-type]");
    if (type) { state.scheduleType = type.dataset.scheduleType; navigate("schedule", { keepSelection: true }); return; }
    const view = event.target.closest("[data-schedule-view]");
    if (view && !view.disabled) { state.scheduleView = view.dataset.scheduleView; state.selected = null; $("#appMain").innerHTML = state.route === "reports" ? renderReports(state.data.reports) : renderSchedule(state.data.schedule); return; }
    const inboxTab = event.target.closest("[data-inbox-tab]");
    if (inboxTab) { state.inboxTab = inboxTab.dataset.inboxTab; $("#appMain").innerHTML = renderInbox(state.data.inbox); return; }
    const documentsTab = event.target.closest("[data-documents-tab]");
    if (documentsTab) {
      state.documentsTab = documentsTab.dataset.documentsTab; state.selected = null; state.cateringDetail = null; state.invoiceDetail = null;
      $("#appMain").innerHTML = renderInvoices(state.data.invoices); return;
    }
    const employeeView = event.target.closest("[data-employee-view]");
    if (employeeView) {
      state.employeeView = employeeView.dataset.employeeView;
      $("#appMain").innerHTML = renderEmployees(state.data.employees);
      return;
    }
    const watchdogSection = event.target.closest(".watchdog-workspace .subnav button");
    if (watchdogSection) {
      watchdogSection.parentElement.querySelectorAll("button").forEach((item) => item.classList.toggle("active", item === watchdogSection));
      const label = watchdogSection.textContent.trim().toLowerCase();
      if (label.startsWith("active issues")) {
        const checks = arr(state.data.watchdog?.results?.[0]?.value?.checks);
        const issue = checks.find((check) => !/healthy|ok|connected|ready/i.test(check.status || ""));
        if (issue) {
          state.selected = { id: issue.name };
          $("#appMain").innerHTML = renderWatchdog(state.data.watchdog);
          $(".context-inspector")?.scrollIntoView({ behavior: "smooth", block: "nearest" });
        } else notify("No active watchdog issues were returned.");
      } else if (label.startsWith("history")) {
        notify("The connected watchdog currently returns a live snapshot; no history records were returned.");
      } else if (label.startsWith("repairs")) {
        notify("No approved repair action was returned. Repairs remain locked until the backend supplies one.");
      } else {
        $(".watchdog-workspace .workspace-panel:nth-child(2)")?.scrollIntoView({ behavior: "smooth", block: "nearest" });
      }
      return;
    }
    const invoiceSource = event.target.closest("[data-invoice-source]");
    if(invoiceSource){state.invoiceSource=invoiceSource.dataset.invoiceSource;state.selected=null;state.invoiceDetail=null;$("#appMain").innerHTML=renderInvoices(state.data.invoices);return;}
    const simpleTabs = [
      ["[data-applications-tab]", "applicationsTab", "applicationsTab", "applications", renderApplications],
      ["[data-website-tab]", "websiteTab", "websiteTab", "website", renderWebsite],
      ["[data-menu-category]", "menuCategory", "menuCategory", "menu", renderMenu],
      ["[data-hopclub-tab]", "hopclubTab", "hopclubTab", "hopclub", renderHopClub],
      ["[data-tasks-tab]", "tasksTab", "tasksTab", "tasks", renderTasks],
      ["[data-parties-view]", "partiesView", "partiesView", "parties", renderParties],
      ["[data-reports-tab]", "reportsTab", "reportsTab", "reports", renderReports],
      ["[data-notifications-tab]", "notificationsTab", "notificationsTab", "notifications", renderNotifications],
      ["[data-settings-tab]", "settingsTab", "settingsTab", "settings", renderSettings],
    ];
    for (const [selector, key, datasetKey, route, renderer] of simpleTabs) {
      const control = event.target.closest(selector);
      if (control) { state[key] = control.dataset[datasetKey]; state.selected = null; $("#appMain").innerHTML = renderer(state.data[route]); return; }
    }
    const linkedDocument = event.target.closest("[data-documents-tab-go]");
    if (linkedDocument) {
      state.documentsTab = linkedDocument.dataset.documentsTabGo; state.selected = { kind: "invoice", id: linkedDocument.dataset.id };
      api(`/api/invoices/${linkedDocument.dataset.id}`).then((payload) => { state.invoiceDetail = payload.invoice; $("#appMain").innerHTML = renderInvoices(state.data.invoices); }).catch((error) => notify(error.message, true));
      return;
    }
    const catering = event.target.closest("[data-select-catering]");
    if (catering) {
      state.selected = { kind: "catering", id: catering.dataset.selectCatering }; state.cateringDetail = null;
      $("#appMain").innerHTML = renderInvoices(state.data.invoices);
      api(`/api/command/v2/catering/${catering.dataset.selectCatering}`).then((payload) => { state.cateringDetail = payload.order; $("#appMain").innerHTML = renderInvoices(state.data.invoices); }).catch((error) => notify(error.message, true));
      return;
    }
    const invoice = event.target.closest("[data-select-invoice]");
    if (invoice) {
      state.selected = { kind: "invoice", id: invoice.dataset.selectInvoice }; state.invoiceDetail = null;
      $("#appMain").innerHTML = renderInvoices(state.data.invoices);
      api(`/api/invoices/${invoice.dataset.selectInvoice}`).then((payload) => { state.invoiceDetail = payload.invoice; $("#appMain").innerHTML = renderInvoices(state.data.invoices); }).catch((error) => notify(error.message, true));
      return;
    }
    const selectors = [
      ["[data-select-inbox]", "inbox", renderInbox, "selectInbox"],
      ["[data-select-application]", "applications", renderApplications, "selectApplication"],
      ["[data-select-menu]", "menu", renderMenu, "selectMenu"],
      ["[data-select-hopclub]", "hopclub", renderHopClub, "selectHopclub"],
      ["[data-select-availability]", "availability", renderAvailability, "selectAvailability"],
      ["[data-select-task]", "tasks", renderTasks, "selectTask"],
      ["[data-select-party]", "parties", renderParties, "selectParty"],
      ["[data-select-notification]", "notifications", renderNotifications, "selectNotification"],
      ["[data-select-watchdog]", "watchdog", renderWatchdog, "selectWatchdog"],
    ];
    for (const [selector, route, renderer, datasetKey] of selectors) {
      const row = event.target.closest(selector);
      if (row) {
        state.selected = { id: row.dataset[datasetKey] };
        if (route === "applications") {
          state.applicationDetail = null;
          $("#appMain").innerHTML = renderer(state.data[route]);
          api(`/api/job-applications/${row.dataset[datasetKey]}`).then((payload) => {
            if (String(state.selected?.id) !== String(row.dataset[datasetKey])) return;
            state.applicationDetail = payload.application || payload;
            $("#appMain").innerHTML = renderApplications(state.data.applications);
          }).catch((error) => notify(error.message, true));
          return;
        }
        $("#appMain").innerHTML = renderer(state.data[route]);
        return;
      }
    }
    const partyDay = event.target.closest("[data-party-day]");
    if (partyDay) { state.selected = { day: partyDay.dataset.partyDay }; $("#appMain").innerHTML = renderParties(state.data.parties); return; }
    const partyFilter = event.target.closest("[data-party-filter]");
    if (partyFilter) { state.partiesFilter = partyFilter.dataset.partyFilter; state.selected = null; $("#appMain").innerHTML = renderParties(state.data.parties); return; }
    const websitePage = event.target.closest("[data-website-page]");
    if (websitePage) { state.websitePage=websitePage.dataset.websitePage;state.websiteTab="content";$("#appMain").innerHTML=renderWebsite(state.data.website);return; }
    const inspectorTab = event.target.closest(".inspector-tabs button:not([disabled])");
    if (inspectorTab) {
      const tabs = inspectorTab.parentElement;
      tabs.querySelectorAll("button").forEach((item)=>item.classList.toggle("active",item===inspectorTab));
      const label = inspectorTab.textContent.trim().toLowerCase();
      const root = inspectorTab.closest(".context-inspector,.application-detail,.document-detail,.workspace-panel") || $("#appMain");
      if (["desktop","tablet","mobile"].includes(label)) {
        const preview = root.querySelector(".preview-browser");
        if (preview) preview.dataset.viewport = label;
        return;
      }
      const aliases = { overview:["contact","details"], availability:["availability"], documents:["documents"], "manager notes":["manager notes","notes"], activity:["activity","additional information"], details:["contact","document type"], "sizes & prices":["sizes & prices"], modifiers:["modifiers"], display:["visibility & ordering"], kitchen:["kitchen","visibility & ordering"], planning:["fulfillment timeline"], "line items":["line items"], payment:["payment","total"], notes:["notes"], "follow-up":["customer follow-up"] };
      const candidates = aliases[label] || [label];
      const heading = [...root.querySelectorAll("h4,.section-label,label")].find((item)=>candidates.some((candidate)=>item.textContent.trim().toLowerCase().includes(candidate)));
      (heading || root.querySelector(".card-body"))?.scrollIntoView({behavior:"smooth",block:"nearest"});
      return;
    }
    const notificationCategory = event.target.closest("[data-notification-category]");
    if (notificationCategory) { state.notificationsCategory=notificationCategory.dataset.notificationCategory; state.selected=null; $("#appMain").innerHTML=renderNotifications(state.data.notifications); return; }
    const taskTeam = event.target.closest("[data-task-team]");
    if (taskTeam) { state.taskTeam=taskTeam.dataset.taskTeam; state.selected=null; $("#appMain").innerHTML=renderTasks(state.data.tasks); return; }
    const availabilityScope = event.target.closest("[data-availability-scope]");
    if (availabilityScope) { state.availabilityScope=availabilityScope.dataset.availabilityScope; state.selected=null; $("#appMain").innerHTML=renderAvailability(state.data.availability); return; }
    const availabilityToggle = event.target.closest("[data-availability-toggle]");
    if (availabilityToggle) {
      const [employeeId, day, period] = availabilityToggle.dataset.availabilityToggle.split("|");
      toggleAvailabilityCell(employeeId, day, period).catch((error)=>notify(error.message,true));
      return;
    }
    const cellMenu = event.target.closest("[data-cell-menu]");
    if (cellMenu) {
      const [row, date] = cellMenu.dataset.cellMenu.split("|");
      state.scheduleConflict = null;
      state.selected = { type:"cell", row, date };
      $("#appMain").innerHTML = renderSchedule(state.data.schedule);
      $(".schedule-inspector")?.scrollIntoView({behavior:"smooth",block:"nearest"});
      return;
    }
    const cell = event.target.closest("[data-cell]");
    if (cell) {
      if (event.target.closest("[data-schedule-cell-picker]")) return;
      const [row, date] = cell.dataset.cell.split("|");
      state.scheduleConflict = null;
      state.selected = { type: "cell", row, date };
      $("#appMain").innerHTML = renderSchedule(state.data.schedule);
      return;
    }
    const addEmployee = event.target.closest("[data-schedule-add]");
    if (addEmployee) {
      const schedule = scheduleCurrent();
      const row = arr(schedule?.rows).find((item) => item.row_key === state.selected?.row);
      const timeMap = { AM1:["10:00","15:00"],AM2:["11:00","16:00"],AM3:["11:30","16:30"],AM4:["12:00","17:00"],PM1:["15:00","19:30"],PM2:["16:00","20:30"],PM3:["17:00","21:00"],FH1:["16:00","20:30"],FH2:["17:00","21:00"],FH3:["17:30","21:30"],FH4:["18:00","22:00"],"Host AM1":["11:00","16:00"],"Host PM1":["16:00","21:00"],"Host PM2":["17:00","21:00"] };
      const times = timeMap[row?.label] || [null, null];
      const day = new Date(`${state.selected?.date}T12:00:00Z`).getUTCDay();
      api(`/api/schedules/draft/${schedule.id}/entries`, { method: "POST", body: JSON.stringify({ row_id: row.id, employee_id: addEmployee.dataset.scheduleAdd, day_of_week: day, start_time: times[0], end_time: times[1], shift_label: `${times[0] || ""} - ${times[1] || ""}`, role: row.role_group, updated_by: manager()?.id || null }) }).then(() => { notify("Employee assigned to draft shift."); navigate("schedule", { keepSelection: true }); }).catch((error) => notify(error.message, true));
      return;
    }
    const removeEntry = event.target.closest("[data-schedule-remove]");
    if (removeEntry) {
      const schedule = scheduleCurrent();
      api(`/api/schedules/draft/${schedule.id}/entries/${removeEntry.dataset.scheduleRemove}`, { method: "DELETE" }).then(() => { notify("Draft assignment removed."); navigate("schedule", { keepSelection: true }); }).catch((error) => notify(error.message, true));
      return;
    }
    const employee = event.target.closest("[data-select-employee]");
    if (employee) { state.selected = { id: employee.dataset.selectEmployee }; $("#appMain").innerHTML = renderEmployees(state.data.employees); return; }
    if (event.target.closest("#logoutButton")) {
      localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(MANAGER_KEY); openLogin();
    }
  });

  document.addEventListener("keydown", (event) => {
    const taskCell = event.target.closest?.("[data-task-cell]");
    if (!taskCell || !["Enter", " "].includes(event.key)) return;
    event.preventDefault();
    taskDialogV2(null, taskCell.dataset.taskCell || "");
  });

  document.addEventListener("change", async (event) => {
    const picker = event.target.closest("[data-schedule-cell-picker]");
    if (!picker) return;
    const schedule = scheduleCurrent();
    const [rowKey,date] = picker.dataset.scheduleCellPicker.split("|");
    const row = arr(schedule?.rows).find((item)=>item.row_key===rowKey);
    if (!schedule?.id || state.scheduleView !== "draft" || !row || !date) return notify("Open a draft cell before assigning an employee.",true);
    const day = new Date(`${date}T12:00:00Z`).getUTCDay();
    const employeeId = picker.value || null;
    const existing = arr(schedule.entries).find((entry)=>String(entry.id)===String(picker.dataset.entryId)) || null;
    const timeMap = { AM1:["10:00","15:00"],AM2:["11:00","16:00"],AM3:["11:30","16:30"],AM4:["12:00","17:00"],PM1:["15:00","19:30"],PM2:["16:00","20:30"],PM3:["17:00","21:00"],FH1:["16:00","20:30"],FH2:["17:00","21:00"],FH3:["17:30","21:30"],FH4:["18:00","22:00"],"Host AM1":["11:00","16:00"],"Host PM1":["16:00","21:00"],"Host PM2":["17:00","21:00"] };
    const [startTime,endTime] = existing ? [existing.start_time,existing.end_time] : (timeMap[row.label] || [null,null]);
    picker.disabled = true;
    state.selected = {type:"cell",row:rowKey,date};
    state.scheduleConflict = null;
    try {
      if (!employeeId && existing?.id) {
        await api(`/api/schedules/draft/${schedule.id}/entries/${existing.id}`,{method:"DELETE"});
        notify("Shift returned to open.");
      } else if (employeeId) {
        await api(`/api/schedules/draft/${schedule.id}/entries`,{method:"POST",body:JSON.stringify({id:existing?.id||null,row_id:row.id,employee_id:employeeId,day_of_week:day,start_time:startTime,end_time:endTime,shift_label:startTime&&endTime?`${startTime} - ${endTime}`:null,role:row.role_group,notes:null,updated_by:manager()?.id||null})});
        notify(existing ? "Schedule cell updated." : "Employee assigned to open shift.");
      } else {
        picker.disabled = false;
        return;
      }
      await navigate("schedule",{keepSelection:true});
    } catch (error) {
      const issues = arr(error.payload?.issues || error.payload?.conflicts || error.payload?.assignment_warnings);
      state.scheduleConflict = issues.map((item)=>item.user_message||item.message||item.code).filter(Boolean).join(" · ") || error.message;
      notify(state.scheduleConflict,true);
      await navigate("schedule",{keepSelection:true});
    }
  });

  document.addEventListener("input", (event) => {
    if (event.target.matches("[data-mobile-style]")) {
      const key=event.target.dataset.mobileStyle;const value=event.target.value;
      localStorage.setItem(`hop_mobile_${key}`,value);
      const device=$(".employee-device");
      if(device&&["accent","surface","radius"].includes(key))device.style.setProperty(`--mobile-${key}`,key==="radius"?`${value}px`:value);
      if(key==="radius")event.target.nextElementSibling.textContent=`${value} px`;
      return;
    }
    if(event.target.closest("#websitePage")){
      const name=event.target.name;
      if(["hero_before","hero_highlight","hero_after"].includes(name)){const page=$("#websitePage");const headline=[page.querySelector('[name="hero_before"]')?.value,page.querySelector('[name="hero_highlight"]')?.value,page.querySelector('[name="hero_after"]')?.value].filter(Boolean).join(" ");const target=$("[data-preview-headline]");if(target)target.textContent=headline;}
      if(name==="hero_eyebrow"&&$("[data-preview-eyebrow]"))$("[data-preview-eyebrow]").textContent=event.target.value;
      if(name==="hero_description"&&$("[data-preview-description]"))$("[data-preview-description]").textContent=event.target.value;
      if(name==="hero_primary_text"&&$("[data-preview-primary]"))$("[data-preview-primary]").textContent=event.target.value;
      if(event.target.matches("[data-website-image-select]")){const preview=$("[data-website-image-preview]");if(preview&&event.target.value)preview.innerHTML=`<img src="${esc(mediaUrl(event.target.value))}" alt="Selected homepage hero">`;}
      if(name==="website_image"&&event.target.files?.[0]){fileToDataUrl(event.target.files[0]).then((url)=>{const preview=$("[data-website-image-preview]");if(preview)preview.innerHTML=`<img src="${url}" alt="New homepage hero">`;});}
    }
    if (event.target.matches("[data-notification-unread]")) {
      state.notificationsUnread=event.target.checked; state.selected=null; $("#appMain").innerHTML=renderNotifications(state.data.notifications); return;
    }
    if (event.target.matches("[data-local-search]")) {
      state.search = event.target.value;
      const position = event.target.selectionStart;
      $("#appMain").innerHTML = renderEmployees(state.data.employees);
      const input = $("[data-local-search]"); input.focus(); input.setSelectionRange(position, position);
      return;
    }
    if (event.target.matches("#globalSearch, .table-search")) {
      const query = event.target.value.trim().toLowerCase();
      $$("#appMain .data-table tbody tr, #appMain .kanban-card, #appMain .party-card, #appMain .master-row, #appMain .document-row").forEach((row) => {
        row.hidden = Boolean(query) && !row.textContent.toLowerCase().includes(query);
      });
    }
  });

  document.addEventListener("change", (event) => {
    if (event.target.matches("[data-invoice-document-select]")) {
      const id = event.target.value;
      state.selected = { kind: "invoice", id };
      state.invoiceDetail = null;
      api(`/api/invoices/${id}`).then((payload)=>{state.invoiceDetail=payload.invoice;$("#appMain").innerHTML=renderInvoices(state.data.invoices);}).catch((error)=>notify(error.message,true));
      return;
    }
    if (event.target.matches("[data-mobile-style]")) {
      const key=event.target.dataset.mobileStyle;localStorage.setItem(`hop_mobile_${key}`,event.target.value);
      $("#appMain").innerHTML=renderEmployeeMobile(state.data["employee-mobile"]||{results:[]});
    }
  });

  $("#sidebarToggle").addEventListener("click", () => document.body.classList.toggle("shell-collapsed"));
  $("#mobileNav").addEventListener("click", () => document.body.classList.toggle("nav-open"));
  $("#syncButton").addEventListener("click", () => navigate(state.route, { keepSelection: true }));
  $("#actionClose").addEventListener("click", closeActionDialog);
  $("#actionForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const action = event.submitter?.dataset.dialogAction || "save";
    if (action === "close") { closeActionDialog(); return; }
    if (!state.action?.onSubmit) return;
    $("#actionError").textContent = "Working…";
    try { await state.action.onSubmit(formValues(event.currentTarget), action); }
    catch (error) { $("#actionError").textContent = error.message; }
  });
  const tauriWindow = window.__TAURI__?.window?.getCurrentWindow?.();
  if (tauriWindow) {
    $(".window-drag").addEventListener("mousedown", () => tauriWindow.startDragging());
    const controls = $$(".window-actions button");
    controls[0].addEventListener("click", () => tauriWindow.minimize());
    controls[1].addEventListener("click", () => tauriWindow.toggleMaximize());
    controls[2].addEventListener("click", () => tauriWindow.close());
  } else document.body.classList.add("web-runtime");
  $("#loginForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    $("#loginError").textContent = "Signing in…";
    const form = new FormData(event.currentTarget);
    try {
      const payload = await api("/api/command-auth/login", { method: "POST", body: JSON.stringify({ name: form.get("name"), pin: form.get("pin") }) });
      localStorage.setItem(TOKEN_KEY, payload.access_token);
      localStorage.setItem(MANAGER_KEY, JSON.stringify(payload.manager || {}));
      $("#loginDialog").close();
      $("#loginError").textContent = "";
      startManagerAlerts();
      await navigate(state.route);
    } catch (error) { $("#loginError").textContent = error.message; }
  });
  window.addEventListener("hashchange", () => { const route = location.hash.slice(1); if (route && route !== state.route) navigate(route); });

  (async function start() {
    renderNav();
    const profile = manager();
    if (profile) { $(".manager-button b").textContent = profile.name || "Manager"; $(".avatar").textContent = initials(profile.name || "Manager"); }
    const valid = await validateSession();
    if (!valid) openLogin();
    await navigate(state.route);
    if (valid) startManagerAlerts();
    if (valid && IS_DESKTOP && TAURI_INVOKE) startPrintBridge().catch((error)=>{state.bridge.lastError=error.message;});
  })();
})();
