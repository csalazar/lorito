const preferenceKey = "lorito:desktop-notifications";
const historyKey = "lorito:notification-history";

export default {
  mounted() {
    this.alive = true;
    this.pending = new Map();
    this.button = this.el.querySelector("[data-toggle]");
    this.status = this.el.querySelector("[data-status]");
    this.canRequestPermission = window.isSecureContext && "Notification" in window;
    this.supported = this.canRequestPermission && !!navigator.locks;

    try {
      this.enabled = localStorage.getItem(preferenceKey) === "true";
    } catch {
      this.supported = false;
    }

    this.refresh = () => {
      if (!this.button) return;

      const denied = this.supported && Notification.permission === "denied";
      const enabled = this.enabled && this.supported && Notification.permission === "granted";

      this.button.disabled = !this.canRequestPermission;
      this.button.textContent = enabled ? "Disable desktop notifications" : "Enable desktop notifications";
      this.button.setAttribute("aria-pressed", String(!!enabled));

      this.setStatus(!this.supported
        ? "Desktop notifications are unavailable in this browser or connection."
        : denied
          ? "Notifications are blocked. Change this site's browser permissions to enable them."
          : "New logs notify you while this page is in the background.");
    };

    this.onClick = async () => {
      try {
        if (this.enabled && Notification.permission === "granted") {
          this.enabled = false;
        } else {
          // Permission must be requested directly from a user gesture.
          this.enabled = (await Notification.requestPermission()) === "granted";
        }

        localStorage.setItem(preferenceKey, String(this.enabled));
        if (!this.enabled) this.clearPending();
        this.refresh();
        window.dispatchEvent(new Event("lorito:notification-preference"));
      } catch {
        this.setStatus("Unable to enable desktop notifications.");
      }
    };

    this.onStorage = (event) => {
      if (event.key === preferenceKey || event.key === null) {
        this.enabled = event.newValue === "true";
        if (!this.enabled) this.clearPending();
        this.refresh();
      }
    };

    this.onPreference = () => {
      try {
        this.enabled = localStorage.getItem(preferenceKey) === "true";
        if (!this.enabled) this.clearPending();
        this.refresh();
      } catch {
        this.enabled = false;
        this.clearPending();
      }
    };

    this.onVisibility = () => {
      if (!document.hidden) this.clearPending();
      this.refresh();
    };

    this.button?.addEventListener("click", this.onClick);
    window.addEventListener("storage", this.onStorage);
    window.addEventListener("lorito:notification-preference", this.onPreference);
    document.addEventListener("visibilitychange", this.onVisibility);

    if (!this.button) this.handleEvent("log-created", (log) => {
      if (!this.canNotify()) return;

      this.pending.set(log.id, log);
      if (!this.timer) this.timer = setTimeout(() => this.flush(), 1000);
    });

    this.refresh();
  },

  setStatus(message) {
    if (this.status) this.status.textContent = message;
    if (this.button) this.button.title = message;
  },

  canNotify() {
    return this.alive && this.supported && this.enabled && document.hidden &&
      Notification.permission === "granted";
  },

  clearPending() {
    clearTimeout(this.timer);
    this.timer = null;
    this.pending.clear();
  },

  async flush() {
    const logs = [...this.pending.values()];
    this.clearPending();
    if (!this.canNotify()) return;

    try {
      // Serialize the claim across tabs. Keep a bounded, expiring history across navigation.
      await navigator.locks.request(historyKey, () => {
        if (!this.canNotify()) return;

        const now = Date.now();
        const history = JSON.parse(localStorage.getItem(historyKey) || "[]")
          .filter((entry) => entry.at > now - 60_000);
        const seen = new Set(history.map((entry) => entry.id));
        const fresh = logs.filter((log) => !seen.has(log.id));
        if (!fresh.length) return;

        const groups = new Map();

        for (const log of fresh) {
          const key = JSON.stringify([log.protocol, log.workspace_id]);
          if (!groups.has(key)) groups.set(key, []);
          groups.get(key).push(log);
        }

        for (const group of groups.values()) {
          const latest = group[group.length - 1];

          // No shared tag: each window adds alerts without replacing earlier ones.
          const notification = new Notification(
            group.length === 1 ? latest.title : `${group.length} new ${latest.protocol.toUpperCase()} logs`,
            { body: latest.body },
          );

          history.push(...group.map((log) => ({ id: log.id, at: now })));
          localStorage.setItem(historyKey, JSON.stringify(history.slice(-1000)));

          notification.onclick = () => {
            window.focus();
            window.location.assign(latest.url);
          };
        }
      });
    } catch {
      // Browser/OS restrictions must never interrupt the live log stream.
      if (this.alive) this.setStatus("Desktop notifications could not be displayed.");
    }
  },

  disconnected() {
    this.clearPending();
  },

  destroyed() {
    this.alive = false;
    this.clearPending();

    this.button?.removeEventListener("click", this.onClick);
    window.removeEventListener("storage", this.onStorage);
    window.removeEventListener("lorito:notification-preference", this.onPreference);
    document.removeEventListener("visibilitychange", this.onVisibility);
  },
};
