'use strict';
// kollin_advanced_ui — App core: state, dispatcher, utilities

const App = {
    settings: {
        theme:     'dark',
        scale:     1.0,
        speedUnit: 'MPH',
        notifPos:  'top-right',
        hud:       { bars: {}, showMoney: true, showLocation: true, showTime: true },
        speedo:    { enabled: true, showFuel: true, showRPM: true, showGear: true,
                     showSeatbelt: true, showEngineHealth: true, showBodyHealth: true },
    },
    framework: 'standalone',
};

// ── NUI bridge ────────────────────────────────────────────────────────
function nuiPost(action, data) {
    return fetch(`https://kollin_advanced_ui/${action}`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(data ?? {}),
    });
}

// ── Message dispatcher ────────────────────────────────────────────────
window.addEventListener('message', ({ data }) => {
    const { action } = data;
    switch (action) {
        case 'init':           onInit(data.data);               break;
        case 'applySettings':  applySettings(data.data);        break;
        case 'hud/update':     HUD.update(data.data);           break;
        case 'hud/money':      HUD.updateMoney(data.data);      break;
        case 'hud/visible':    HUD.setVisible(data.data.visible); break;
        case 'speedo/update':  Speedo.update(data.data);        break;
        case 'speedo/show':    Speedo.show();                   break;
        case 'speedo/hide':    Speedo.hide();                   break;
        case 'speedo/seatbelt':Speedo.setSeatbelt(data.data.on);break;
        case 'notify':         Notif.show(data.data);           break;
        case 'progress/start': ProgressBar.start(data.data);   break;
        case 'progress/stop':  ProgressBar.stop();              break;
        case 'context/open':   ContextMenu.open(data.data);     break;
        case 'context/close':  ContextMenu.close();             break;
        case 'menu/open':      Menu.open(data.data);            break;
        case 'menu/close':     Menu.close();                    break;
    }
});

function onInit({ settings, framework }) {
    App.framework = framework || 'standalone';
    applySettings(settings);
    HUD.init();
    Speedo.init();
}

function applySettings(s) {
    if (!s) return;
    Object.assign(App.settings, s);

    // Theme
    const validThemes = ['dark','light','cyberpunk','minimal','redDead'];
    const theme = validThemes.includes(s.theme) ? s.theme : 'dark';
    document.documentElement.setAttribute('data-theme', theme);

    // Scale — apply to entire page via viewport transform
    const scale = Math.max(0.5, Math.min(2.0, parseFloat(s.scale) || 1.0));
    document.documentElement.style.setProperty('--ui-scale', scale);
    document.body.style.zoom = scale;  // simplest cross-browser scale for FiveM CEF

    // Notification position
    const nc = document.getElementById('notif-container');
    if (nc && s.notifPos) {
        nc.className = `notif-container pos-${s.notifPos}`;
    }

    // HUD bar toggles
    if (s.hud && s.hud.bars) {
        const bars = ['health','armor','hunger','thirst','stamina','stress','oxygen'];
        for (const b of bars) {
            const el = document.getElementById(`bar-${b}`);
            if (el) el.classList.toggle('hidden', s.hud.bars[b] === false);
        }
        const money = document.getElementById('hud-money');
        if (money) money.classList.toggle('hidden', s.hud.showMoney === false);
    }
}

// ── Utilities ─────────────────────────────────────────────────────────
function el(tag, className) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    return e;
}
function qs(sel, ctx) { return (ctx || document).querySelector(sel); }
function qsa(sel, ctx){ return (ctx || document).querySelectorAll(sel); }
function setText(id, text) { const e = document.getElementById(id); if (e) e.textContent = text; }
function setWidth(id, pct) {
    const e = document.getElementById(id);
    if (e) e.style.width = Math.max(0, Math.min(100, pct)) + '%';
}

function fmt(n, prefix = '$') {
    return prefix + Number(n).toLocaleString('en-US');
}
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function healthColor(pct) {
    if (pct > 60) return 'var(--bar-health)';
    if (pct > 30) return '#e67e22';
    return '#ff1a1a';
}
function damageColor(pct) {
    if (pct > 70) return '#27ae60';
    if (pct > 40) return '#f39c12';
    return '#e74c3c';
}
function fuelColor(pct) {
    return pct < 20 ? 'var(--fuel-low)' : 'var(--fuel-ok)';
}
function rpmColor(rpm) {
    if (rpm > 0.85) return 'var(--rpm-high)';
    if (rpm > 0.60) return 'var(--rpm-mid)';
    return 'var(--rpm-low)';
}
