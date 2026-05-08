'use strict';
// kollin_advanced_ui — HUD module

const HUD = (() => {
    const BARS = {
        health:  { el: null, fill: null, val: null },
        armor:   { el: null, fill: null, val: null },
        hunger:  { el: null, fill: null, val: null },
        thirst:  { el: null, fill: null, val: null },
        stamina: { el: null, fill: null, val: null },
        stress:  { el: null, fill: null, val: null },
        oxygen:  { el: null, fill: null, val: null },
    };

    let last = {};

    function init() {
        for (const key of Object.keys(BARS)) {
            BARS[key].el   = document.getElementById(`bar-${key}`);
            BARS[key].fill = document.getElementById(`fill-${key}`);
            BARS[key].val  = document.getElementById(`val-${key}`);
        }
    }

    function setBar(key, pct) {
        if (last[key] === pct) return;
        last[key] = pct;
        const b = BARS[key];
        if (!b.fill) return;
        b.fill.style.width = clamp(pct, 0, 100) + '%';
        if (b.val) b.val.textContent = Math.round(pct);

        // Low threshold pulsing
        const low = (key === 'health' && pct < 25) || (key === 'hunger' && pct < 20) || (key === 'thirst' && pct < 20);
        if (b.el) b.el.classList.toggle('low', low);

        // Dynamic color for health
        if (key === 'health' && b.fill) {
            b.fill.style.background = healthColor(pct);
        }
    }

    function update(d) {
        if (!d) return;
        setBar('health',  d.health  ?? 100);
        setBar('armor',   d.armor   ?? 0);
        setBar('hunger',  d.hunger  ?? 100);
        setBar('thirst',  d.thirst  ?? 100);
        setBar('stamina', d.stamina ?? 100);
        setBar('stress',  d.stress  ?? 0);
        setBar('oxygen',  d.oxygen  ?? 100);

        // Wanted
        const wantedEl = document.getElementById('hud-wanted');
        const wantedStars = document.getElementById('wanted-stars');
        if (wantedEl) {
            wantedEl.classList.toggle('hidden', !d.wanted || d.wanted === 0);
            if (wantedStars) wantedStars.textContent = d.wanted || 0;
        }

        // Location
        if (d.street !== last.street || d.zone !== last.zone) {
            last.street = d.street;
            last.zone   = d.zone;
            setText('hud-street', d.street || '');
            const zoneEl = document.getElementById('hud-zone');
            if (zoneEl) zoneEl.textContent = [d.crossing, d.zone].filter(Boolean).join(' · ');
        }

        // Time
        if (d.time !== last.time) {
            last.time = d.time;
            setText('hud-time', d.time || '00:00');
        }
    }

    function updateMoney({ cash, bank }) {
        setText('hud-cash', fmt(cash ?? 0));
        setText('hud-bank', fmt(bank ?? 0));
    }

    function setVisible(v) {
        const el = document.getElementById('hud-status');
        const info = document.getElementById('hud-info');
        if (el)   el.style.display   = v ? '' : 'none';
        if (info) info.style.display = v ? '' : 'none';
    }

    return { init, update, updateMoney, setVisible };
})();
