'use strict';
// kollin_advanced_ui — Main menu module

const Menu = (() => {
    let currentTab = 'player';
    let currentData = null;

    function init() {
        // Tab switching
        document.querySelectorAll('.menu-tab').forEach(btn => {
            btn.addEventListener('click', () => switchTab(btn.dataset.tab));
        });

        // Close button
        document.getElementById('menu-close-btn')?.addEventListener('click', () => {
            nuiPost('menu/close', {});
        });

        // Escape key
        document.addEventListener('keydown', e => {
            if (e.key === 'Escape' && !document.getElementById('menu-overlay').classList.contains('hidden')) {
                nuiPost('menu/close', {});
            }
        });

        // Emote search
        document.getElementById('emote-search')?.addEventListener('input', function() {
            filterEmotes(this.value.trim().toLowerCase());
        });
    }

    function switchTab(tab) {
        if (!tab) return;
        currentTab = tab;
        document.querySelectorAll('.menu-tab').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
        document.querySelectorAll('.menu-page').forEach(p => p.classList.toggle('active', p.id === `page-${tab}`));
    }

    function open({ player, vehicle, emotes, settings, animation }) {
        currentData = { player, vehicle, emotes };
        const overlay = document.getElementById('menu-overlay');
        if (!overlay) return;

        buildPlayerPage(player);
        buildVehiclePage(vehicle);
        buildEmotePage(emotes);
        buildSettingsPage(settings);

        // Show/hide admin tab
        const adminTab = document.getElementById('tab-admin');
        if (adminTab) adminTab.classList.toggle('hidden', !player?.isAdmin);

        overlay.classList.remove('hidden');

        // Apply animation class to panel
        const panel = document.getElementById('menu-panel');
        if (panel) {
            panel.classList.remove('anim-scale-in','anim-slide-in-left','anim-fade-in');
            void panel.offsetWidth;
            const animMap = { slide: 'anim-slide-in-left', fade: 'anim-fade-in', scale: 'anim-scale-in' };
            panel.classList.add(animMap[animation] || 'anim-scale-in');
        }

        switchTab('player');
    }

    function close() {
        document.getElementById('menu-overlay')?.classList.add('hidden');
    }

    // ── Player page ──────────────────────────────────────────────────
    function buildPlayerPage(p) {
        const grid = document.getElementById('player-grid');
        if (!grid || !p) return;
        grid.innerHTML = '';

        const cards = [
            { label: 'Server ID',  value: p.id   || '—',         accent: true },
            { label: 'Name',       value: p.name  || '—' },
            { label: 'Job',        value: p.job?.label || 'Unemployed' },
            { label: 'Gang',       value: p.gang  || 'None' },
            { label: 'Cash',       value: '$' + Number(p.cash).toLocaleString() },
            { label: 'Bank',       value: '$' + Number(p.bank).toLocaleString() },
        ];

        for (const c of cards) {
            const card = el('div', 'info-card');
            card.innerHTML = `
                <div class="info-card-label">${sanitize(c.label)}</div>
                <div class="info-card-value${c.accent ? ' accent' : ''}">${sanitize(c.value)}</div>
            `;
            grid.appendChild(card);
        }
    }

    // ── Vehicle page ─────────────────────────────────────────────────
    function buildVehiclePage(v) {
        const content = document.getElementById('vehicle-content');
        const actions = document.getElementById('vehicle-actions');
        if (!content) return;
        content.innerHTML = '';
        if (actions) actions.innerHTML = '';

        if (!v) {
            content.innerHTML = '<div class="vehicle-no-car">Not in a vehicle</div>';
            return;
        }

        // Stats
        const stats = el('div', 'vehicle-stat-row');
        stats.innerHTML = `
            <div class="info-grid" style="margin-bottom:14px">
                <div class="info-card"><div class="info-card-label">Model</div><div class="info-card-value accent">${sanitize(v.model)}</div></div>
                <div class="info-card"><div class="info-card-label">Plate</div><div class="info-card-value">${sanitize(v.plate)}</div></div>
            </div>
        `;

        const makeStat = (label, pct) => {
            const color = damageColor(pct);
            return `<div class="vehicle-stat-item">
                <span class="vehicle-stat-label">${label}</span>
                <div class="vehicle-stat-bar"><div class="vehicle-stat-fill" style="width:${pct}%;background:${color}"></div></div>
            </div>`;
        };

        stats.innerHTML += `
            <div style="display:flex;flex-direction:column;gap:10px">
                ${makeStat('Engine', v.engine ?? 100)}
                ${makeStat('Body',   v.body   ?? 100)}
                ${makeStat('Fuel',   v.fuel   ?? 100)}
            </div>
        `;
        content.appendChild(stats);

        // Action buttons
        if (actions) {
            const btns = [
                { label: '🔑 Engine',  action: 'engine' },
                { label: '🔒 Lock',    action: 'lock'   },
                { label: '💡 Lights',  action: 'lights' },
            ];
            for (const b of btns) {
                const btn = el('button', 'vehicle-action-btn');
                btn.textContent = b.label;
                btn.addEventListener('click', () => {
                    nuiPost('menu/vehicle', { action: b.action });
                });
                actions.appendChild(btn);
            }
        }
    }

    // ── Emotes page ──────────────────────────────────────────────────
    function buildEmotePage(emotes) {
        const grid = document.getElementById('emote-grid');
        if (!grid) return;
        grid.innerHTML = '';
        for (const e of (emotes || [])) {
            const btn = el('button', 'emote-btn');
            btn.textContent = e.label;
            btn.dataset.cmd = e.cmd;
            btn.addEventListener('click', () => {
                nuiPost('menu/emote', { cmd: e.cmd });
            });
            grid.appendChild(btn);
        }
    }

    function filterEmotes(q) {
        document.querySelectorAll('.emote-btn').forEach(b => {
            b.classList.toggle('hidden', q && !b.textContent.toLowerCase().includes(q));
        });
    }

    // ── Settings page ────────────────────────────────────────────────
    function buildSettingsPage(s) {
        Settings.build(s);
    }

    function sanitize(str) {
        const d = document.createElement('div');
        d.textContent = str ?? '';
        return d.innerHTML;
    }

    // Auto-init when DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    return { open, close };
})();
