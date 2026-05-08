'use strict';
// kollin_advanced_ui — Settings panel builder

const Settings = (() => {
    const THEMES = [
        { id: 'dark',      label: 'Dark',      color: '#1a1a2e' },
        { id: 'light',     label: 'Light',      color: '#e8e8ff' },
        { id: 'cyberpunk', label: 'Cyberpunk',  color: '#00ff9f' },
        { id: 'minimal',   label: 'Minimal',    color: 'rgba(255,255,255,0.15)' },
        { id: 'redDead',   label: 'Red Dead',   color: '#c8a96e' },
    ];

    function build(s) {
        const container = document.getElementById('settings-content');
        if (!container) return;
        container.innerHTML = '';

        const current = s || App.settings;

        // ── Theme ──────────────────────────────────────────────────
        container.appendChild(makeRow(
            'Theme', 'Choose your UI colour theme',
            makeThemeSwatches(current.theme)
        ));

        // ── Scale ──────────────────────────────────────────────────
        container.appendChild(makeRow(
            'UI Scale', 'Scale the entire interface (0.5×–2.0×)',
            makeRange('scale', current.scale ?? 1.0, 0.5, 2.0, 0.05)
        ));

        // ── Speed Unit ─────────────────────────────────────────────
        container.appendChild(makeRow(
            'Speed Unit', 'Speedometer display unit',
            makeSelect('speedUnit', [
                { value: 'mph', label: 'MPH' },
                { value: 'kph', label: 'KPH' },
            ], current.speedUnit?.toLowerCase() || 'mph')
        ));

        // ── Notification Position ──────────────────────────────────
        container.appendChild(makeRow(
            'Notification Position', 'Where toast notifications appear',
            makeSelect('notifPos', [
                { value: 'top-right',    label: 'Top Right'     },
                { value: 'top-left',     label: 'Top Left'      },
                { value: 'bottom-right', label: 'Bottom Right'  },
                { value: 'bottom-left',  label: 'Bottom Left'   },
                { value: 'top-center',   label: 'Top Center'    },
            ], current.notifPos || 'top-right')
        ));

        // ── HUD Toggles ────────────────────────────────────────────
        const bars = ['health','armor','hunger','thirst','stamina'];
        for (const bar of bars) {
            const enabled = current.hud?.bars?.[bar] !== false;
            container.appendChild(makeRow(
                bar.charAt(0).toUpperCase() + bar.slice(1) + ' Bar',
                `Show ${bar} status bar`,
                makeToggle(`hud.bars.${bar}`, enabled)
            ));
        }

        container.appendChild(makeRow(
            'Money Display', 'Show cash and bank balance on HUD',
            makeToggle('hud.showMoney', current.hud?.showMoney !== false)
        ));

        container.appendChild(makeRow(
            'Location', 'Show street name and area',
            makeToggle('hud.showLocation', current.hud?.showLocation !== false)
        ));

        // ── Save / Reset ───────────────────────────────────────────
        const btnRow = el('div', 'settings-save-row');
        const saveBtn = el('button', 'btn-save');
        saveBtn.textContent = 'Save Settings';
        saveBtn.addEventListener('click', collectAndSave);

        const resetBtn = el('button', 'btn-reset');
        resetBtn.textContent = 'Reset to defaults';
        resetBtn.addEventListener('click', () => nuiPost('settings/reset', {}));

        btnRow.appendChild(saveBtn);
        btnRow.appendChild(resetBtn);
        container.appendChild(btnRow);
    }

    function collectAndSave() {
        const s = deepClone(App.settings);

        // Theme
        const activeTheme = document.querySelector('.theme-swatch.active');
        if (activeTheme) s.theme = activeTheme.dataset.theme;

        // Scale
        const scaleInput = document.getElementById('setting-scale');
        if (scaleInput) s.scale = parseFloat(scaleInput.value);

        // Speed unit
        const unitSel = document.getElementById('setting-speedUnit');
        if (unitSel) s.speedUnit = unitSel.value;

        // Notif pos
        const posSel = document.getElementById('setting-notifPos');
        if (posSel) s.notifPos = posSel.value;

        // HUD toggles
        s.hud = s.hud || {};
        s.hud.bars = s.hud.bars || {};
        document.querySelectorAll('[data-setting^="hud.bars."]').forEach(inp => {
            const bar = inp.dataset.setting.replace('hud.bars.', '');
            s.hud.bars[bar] = inp.checked;
        });
        const moneyToggle = document.querySelector('[data-setting="hud.showMoney"]');
        if (moneyToggle) s.hud.showMoney = moneyToggle.checked;
        const locToggle = document.querySelector('[data-setting="hud.showLocation"]');
        if (locToggle) s.hud.showLocation = locToggle.checked;

        nuiPost('settings/save', s);
        applySettings(s);
    }

    // ── Builders ──────────────────────────────────────────────────────
    function makeRow(label, desc, control) {
        const row = el('div', 'setting-row');
        row.innerHTML = `
            <div class="setting-info">
                <div class="setting-label">${sanitize(label)}</div>
                <div class="setting-desc">${sanitize(desc)}</div>
            </div>
        `;
        const wrap = el('div', 'setting-control');
        wrap.appendChild(control);
        row.appendChild(wrap);
        return row;
    }

    function makeThemeSwatches(activeTheme) {
        const wrap = el('div', 'theme-swatches');
        for (const t of THEMES) {
            const swatch = el('div', `theme-swatch${t.id === activeTheme ? ' active' : ''}`);
            swatch.dataset.theme = t.id;
            swatch.style.background = t.color;
            swatch.title = t.label;
            swatch.addEventListener('click', function() {
                document.querySelectorAll('.theme-swatch').forEach(s => s.classList.remove('active'));
                this.classList.add('active');
                // Live preview
                document.documentElement.setAttribute('data-theme', t.id);
                nuiPost('settings/preview', { ...App.settings, theme: t.id });
            });
            wrap.appendChild(swatch);
        }
        return wrap;
    }

    function makeRange(key, val, min, max, step) {
        const wrap = el('div', 'setting-range');
        const input = el('input');
        input.type  = 'range';
        input.id    = `setting-${key}`;
        input.min   = min; input.max = max; input.step = step;
        input.value = val;
        const display = el('span', 'range-val');
        display.textContent = Number(val).toFixed(2);
        input.addEventListener('input', function() {
            display.textContent = Number(this.value).toFixed(2);
            nuiPost('settings/preview', { ...App.settings, [key]: parseFloat(this.value) });
        });
        wrap.appendChild(input);
        wrap.appendChild(display);
        return wrap;
    }

    function makeSelect(key, options, selectedVal) {
        const sel = el('select', 'setting-select');
        sel.id = `setting-${key}`;
        for (const opt of options) {
            const o = document.createElement('option');
            o.value       = opt.value;
            o.textContent = opt.label;
            o.selected    = opt.value === selectedVal;
            sel.appendChild(o);
        }
        return sel;
    }

    function makeToggle(key, checked) {
        const label = el('label', 'toggle-switch');
        const input = el('input');
        input.type    = 'checkbox';
        input.checked = checked;
        input.dataset.setting = key;
        const track = el('div', 'toggle-track');
        const thumb = el('div', 'toggle-thumb');
        label.appendChild(input);
        label.appendChild(track);
        label.appendChild(thumb);
        return label;
    }

    function sanitize(str) {
        const d = document.createElement('div');
        d.textContent = str ?? '';
        return d.innerHTML;
    }

    function deepClone(obj) {
        return JSON.parse(JSON.stringify(obj));
    }

    return { build };
})();
