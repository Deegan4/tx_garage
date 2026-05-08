'use strict';
// kollin_advanced_ui — Notification system

const Notif = (() => {
    const ICONS = {
        success:  '✓',
        error:    '✕',
        warning:  '⚠',
        info:     'ℹ',
        announce: '📢',
    };
    const MAX = 5;
    let queue = [];

    function show({ msg, type = 'info', duration = 5000 }) {
        if (queue.length >= MAX) {
            const oldest = queue.shift();
            oldest?.remove();
        }

        const container = document.getElementById('notif-container');
        if (!container) return;

        const toast = el('div', `notif-toast ${type} anim-slide-in-right`);
        toast.setAttribute('role', 'alert');

        const icon  = ICONS[type] || ICONS.info;
        const label = type.charAt(0).toUpperCase() + type.slice(1);

        toast.innerHTML = `
            <div class="notif-header">
                <span class="notif-type-icon">${icon}</span>
                <span class="notif-type-label">${label}</span>
            </div>
            <div class="notif-msg">${sanitize(msg)}</div>
            <div class="notif-timer" style="width:100%;transition:width ${duration}ms linear"></div>
        `;

        // Dismiss on click
        toast.addEventListener('click', () => dismiss(toast));
        container.appendChild(toast);
        queue.push(toast);

        // Start timer bar
        requestAnimationFrame(() => {
            const timer = toast.querySelector('.notif-timer');
            if (timer) {
                timer.style.color = toastAccentColor(type);
                requestAnimationFrame(() => { timer.style.width = '0%'; });
            }
        });

        // Auto-dismiss
        const tid = setTimeout(() => dismiss(toast), duration);
        toast._tid = tid;

        // Play sound via web audio
        if (App.settings.sounds !== false) playTone(type);

        return toast;
    }

    function dismiss(toast) {
        if (!toast || toast._dismissed) return;
        toast._dismissed = true;
        clearTimeout(toast._tid);
        queue = queue.filter(t => t !== toast);
        toast.classList.remove('anim-slide-in-right');
        toast.classList.add('anim-slide-out-right');
        toast.addEventListener('animationend', () => toast.remove(), { once: true });
        nuiPost('notify/dismissed', {});
    }

    function toastAccentColor(type) {
        return { success: '#27ae60', error: '#e74c3c', warning: '#f39c12',
                 info: '#3498db', announce: 'var(--accent)' }[type] || 'var(--accent)';
    }

    function sanitize(str) {
        const d = document.createElement('div');
        d.textContent = str;
        return d.innerHTML;
    }

    // Simple web audio tones (no external files needed)
    let _ctx = null;
    function getAudioCtx() {
        if (!_ctx) _ctx = new (window.AudioContext || window.webkitAudioContext)();
        return _ctx;
    }
    function playTone(type) {
        try {
            const ctx  = getAudioCtx();
            const osc  = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.connect(gain);
            gain.connect(ctx.destination);
            gain.gain.setValueAtTime(0.06, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);
            const freqs = { success: 880, error: 220, warning: 440, info: 660, announce: 740 };
            osc.frequency.setValueAtTime(freqs[type] || 660, ctx.currentTime);
            osc.type = type === 'error' ? 'sawtooth' : 'sine';
            osc.start();
            osc.stop(ctx.currentTime + 0.3);
        } catch (_) { /* audio blocked — silently skip */ }
    }

    return { show, dismiss };
})();
