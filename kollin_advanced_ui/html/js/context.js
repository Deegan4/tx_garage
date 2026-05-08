'use strict';
// kollin_advanced_ui — Context menu module

const ContextMenu = (() => {
    let focusIndex = -1;
    let items = [];

    function open({ title, items: newItems }) {
        items = newItems || [];
        const overlay = document.getElementById('context-overlay');
        const box     = document.getElementById('context-box');
        const list    = document.getElementById('context-list');
        const titleEl = document.getElementById('context-title');
        if (!overlay) return;

        if (titleEl) {
            titleEl.textContent  = title || '';
            titleEl.style.display = title ? '' : 'none';
        }

        list.textContent = '';
        for (const item of items) {
            const row = el('div', `context-item${item.disabled ? ' disabled' : ''}`);
            row.dataset.id = item.id;
            row.innerHTML = `
                <span class="context-item-icon">${sanitize(item.icon || '')}</span>
                <div style="flex:1">
                    <div class="context-item-label">${sanitize(item.label)}</div>
                    ${item.description ? `<div class="context-item-desc">${sanitize(item.description)}</div>` : ''}
                </div>
            `;
            if (!item.disabled) {
                row.addEventListener('click', () => {
                    nuiPost('context/select', { id: item.id });
                });
            }
            list.appendChild(row);
        }

        focusIndex = -1;
        overlay.classList.remove('hidden');
        // Re-trigger animation
        box.classList.remove('anim-scale-in');
        void box.offsetWidth;
        box.classList.add('anim-scale-in');
    }

    function close() {
        const overlay = document.getElementById('context-overlay');
        if (overlay) overlay.classList.add('hidden');
        items = [];
        focusIndex = -1;
    }

    // Keyboard navigation
    document.addEventListener('keydown', e => {
        const overlay = document.getElementById('context-overlay');
        if (!overlay || overlay.classList.contains('hidden')) return;

        const rows = qsa('.context-item:not(.disabled)', overlay);
        if (e.key === 'Escape') {
            nuiPost('context/close', {});
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            focusIndex = (focusIndex + 1) % rows.length;
            rows[focusIndex]?.focus();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            focusIndex = (focusIndex - 1 + rows.length) % rows.length;
            rows[focusIndex]?.focus();
        } else if (e.key === 'Enter' && focusIndex >= 0) {
            rows[focusIndex]?.click();
        }
    });

    function sanitize(str) {
        const d = document.createElement('div');
        d.textContent = str;
        return d.innerHTML;
    }

    return { open, close };
})();
