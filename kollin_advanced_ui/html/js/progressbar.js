'use strict';
// kollin_advanced_ui — Progress bar module

const ProgressBar = (() => {
    let rafId = null;
    let startTime, endTime;

    function start({ label, duration, canCancel, cancelKey, color }) {
        const overlay = document.getElementById('progress-overlay');
        const fill    = document.getElementById('progress-fill');
        const lbl     = document.getElementById('progress-label');
        const hint    = document.getElementById('progress-hint');
        if (!overlay) return;

        overlay.classList.remove('hidden');
        if (lbl)  lbl.textContent  = label || '';
        if (hint) hint.textContent = canCancel ? `Press ${cancelKey || 'BACKSPACE'} to cancel` : '';
        if (fill) {
            fill.style.background  = color || 'var(--accent)';
            fill.style.width       = '0%';
            fill.style.transition  = 'none';
        }

        startTime = performance.now();
        endTime   = startTime + duration;

        cancelAnimationFrame(rafId);
        rafId = requestAnimationFrame(frame);
    }

    function frame(now) {
        const fill = document.getElementById('progress-fill');
        if (!fill) return;
        const elapsed = now - startTime;
        const total   = endTime - startTime;
        const pct     = clamp((elapsed / total) * 100, 0, 100);
        fill.style.width = pct + '%';
        if (pct < 100) rafId = requestAnimationFrame(frame);
    }

    function stop() {
        cancelAnimationFrame(rafId);
        const overlay = document.getElementById('progress-overlay');
        const fill    = document.getElementById('progress-fill');
        if (fill) fill.style.width = '100%';
        setTimeout(() => {
            if (overlay) overlay.classList.add('hidden');
        }, 150);
    }

    // Cancel button support from NUI side (keyboard handled in Lua)
    document.addEventListener('keydown', e => {
        if (!document.getElementById('progress-overlay')?.classList.contains('hidden')) {
            if (e.key === 'Backspace' || e.code === 'Backspace') {
                nuiPost('progress/cancel', {});
            }
        }
    });

    return { start, stop };
})();
