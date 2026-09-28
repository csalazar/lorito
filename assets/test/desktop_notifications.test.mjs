import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const source = await readFile(new URL("../js/desktop_notifications.js", import.meta.url), "utf8");
const { default: hook } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);

function setup() {
  const storage = new Map();
  const notifications = [];
  const element = () => ({ addEventListener() {}, removeEventListener() {}, setAttribute() {} });
  const button = element();
  const status = element();
  globalThis.localStorage = {
    getItem: (key) => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, value),
  };
  globalThis.Notification = class {
    static permission = "granted";
    static async requestPermission() { return this.permission; }
    constructor(title, options) { Object.assign(this, { title, ...options }); notifications.push(this); }
    close() { this.closed = true; }
  };
  globalThis.window = {
    isSecureContext: true, Notification, addEventListener() {}, removeEventListener() {},
    dispatchEvent() {}, focus() { this.focused = true; }, location: { assign(url) { this.url = url; } },
  };
  globalThis.document = { hidden: true, addEventListener() {}, removeEventListener() {} };
  let queue = Promise.resolve();
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: {
    locks: { request(_key, callback) { queue = queue.then(callback); return queue; } },
  } });
  const mount = (controls = false, withStatus = true) => {
    const instance = { ...hook, el: { querySelector: (s) => controls ? (s === "[data-toggle]" ? button : (withStatus ? status : null)) : null },
      handleEvent(_name, callback) { this.receive = callback; } };
    instance.mounted();
    return instance;
  };
  return { mount, notifications, button, status };
}
const log = (id) => ({ id, protocol: "dns", workspace_id: null, title: "New DNS log", body: "Project / Workspace", url: `/_lorito/logs/${id}` });

test("opt-in, visibility, bursts, and click destination", async () => {
  const { mount, notifications } = setup();
  const h = mount();
  h.receive(log("ignored"));
  assert.equal(h.pending.size, 0);
  await h.onClick();
  document.hidden = false;
  h.receive(log("visible"));
  assert.equal(h.pending.size, 0);
  document.hidden = true;
  h.receive(log("1"));
  h.receive(log("1"));
  h.receive(log("2"));
  await h.flush();
  assert.equal(notifications.length, 1);
  assert.equal(notifications[0].title, "2 new DNS logs");
  notifications[0].onclick();
  assert.equal(window.location.url, "/_lorito/logs/2");
  assert.equal(window.focused, true);
  h.destroyed();
});

test("concurrent tabs claim a log once, including after remount", async () => {
  const { mount, notifications } = setup();
  const first = mount();
  await first.onClick();
  const second = mount();
  first.receive(log("1")); second.receive(log("1"));
  await Promise.all([first.flush(), second.flush()]);
  assert.equal(notifications.length, 1);
  first.destroyed(); second.destroyed();
  const third = mount();
  third.receive(log("1")); await third.flush();
  assert.equal(notifications.length, 1);
  third.destroyed();
});

test("blocked permission keeps the control clickable; unsupported browsers disable it", () => {
  const { mount, button, status } = setup();
  Notification.permission = "denied";
  const first = mount(true);
  assert.equal(button.disabled, false);
  assert.match(status.textContent, /blocked/);
  first.destroyed();
  window.isSecureContext = false;
  const second = mount(true);
  assert.equal(button.disabled, true);
  assert.match(status.textContent, /unavailable/);
  second.destroyed();
});

test("disable, visibility, disconnect and destruction cancel queued alerts", async () => {
  const { mount, notifications } = setup();
  const h = mount(); await h.onClick();
  h.receive(log("1"));
  h.onStorage({ key: "lorito:desktop-notifications", newValue: "false" });
  await h.flush();
  assert.equal(notifications.length, 0);
  await h.onClick(); h.receive(log("2"));
  document.hidden = false; h.onVisibility();
  assert.equal(h.pending.size, 0);
  document.hidden = true; h.receive(log("3")); h.disconnected();
  assert.equal(h.pending.size, 0);
  h.receive(log("4")); h.destroyed(); await h.flush();
  assert.equal(notifications.length, 0);
});


test("preferences control updates the shared listener without duplicate event handling", async () => {
  const { mount, notifications } = setup();
  const listener = mount();
  const controls = mount(true);
  assert.equal(controls.receive, undefined);
  window.dispatchEvent = () => listener.onPreference();
  await controls.onClick();
  assert.equal(listener.enabled, true);
  listener.receive(log("settings"));
  await listener.flush();
  assert.equal(notifications.length, 1);
  await controls.onClick();
  assert.equal(listener.enabled, false);
  listener.destroyed(); controls.destroyed();
});


test("groups by protocol and workspace and preserves earlier notifications", async () => {
  const { mount, notifications } = setup();
  const h = mount();
  await h.onClick();
  h.receive({ ...log("1"), workspace_id: "a" });
  h.receive({ ...log("2"), workspace_id: "a" });
  h.receive({ ...log("3"), workspace_id: "a", protocol: "http", title: "New HTTP log" });
  h.receive({ ...log("4"), workspace_id: "b" });
  await h.flush();
  assert.deepEqual(notifications.map((n) => n.title), ["2 new DNS logs", "New HTTP log", "New DNS log"]);
  notifications[0].onclick();
  assert.equal(window.location.url, "/_lorito/logs/2");
  h.receive({ ...log("5"), workspace_id: "a" });
  await h.flush();
  assert.equal(notifications.length, 4);
  assert.ok(notifications.every((n) => n.tag === undefined && !n.closed));
  h.destroyed();
});


test("preferences without a status element can mount, toggle, and handle errors", async () => {
  const { mount, button } = setup();
  const controls = mount(true, false);
  assert.equal(controls.status, null);
  await controls.onClick();
  assert.equal(controls.enabled, true);
  assert.equal(button.textContent, "Disable desktop notifications");
  await controls.onClick();
  assert.equal(controls.enabled, false);
  Notification.requestPermission = async () => { throw new Error("Permission failed"); };
  await controls.onClick();
  assert.equal(button.title, "Unable to enable desktop notifications.");
  controls.destroyed();
});


test("first enable click requests permission and enables notifications when granted", async () => {
  const { mount, button } = setup();
  Notification.permission = "default";
  let requests = 0;
  Notification.requestPermission = async () => {
    requests++;
    Notification.permission = "granted";
    return "granted";
  };
  const controls = mount(true, false);
  assert.equal(button.disabled, false);
  assert.equal(requests, 0);
  await controls.onClick();
  assert.equal(requests, 1);
  assert.equal(controls.enabled, true);
  assert.equal(localStorage.getItem("lorito:desktop-notifications"), "true");
  assert.equal(button.textContent, "Disable desktop notifications");
  controls.destroyed();
});
