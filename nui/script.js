'use strict';

// tx_garage v2.0 — NUI script
// ────────────────────────────────────────────────────────────────────────────
// Vanilla JS, no frameworks. textContent + appendChild only (no innerHTML).
// Single ticking thread updates every visible auction timer per second.

const RESOURCE = 'tx_garage';

// ── State ──────────────────────────────────────────────────────────────────
let currentGarage   = null;
let currentVehicles = [];
let currentAuctions = [];
let auctionConfig   = {};
let plateChangeCfg  = {};
let subOwnerCfg     = {};
let transferCfg     = {};
let currency        = '$';
let activeSubOwnerPlate = null;
let activeBossSociety   = null;
let lastFocused = null;

// Vehicle class → CSS class + glyph (preview placeholder)
const CLASS_GLYPHS = {
    super:      '◆',
    sports:     '▶',
    suv:        '⬢',
    motorcycle: '⚙',
    truck:      '⬛',
    sedan:      '◑',
    compact:    '◉',
};

// ── NUI bridge ─────────────────────────────────────────────────────────────
function nuiPost(action, data) {
    return fetch(`https://${RESOURCE}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    }).then(r => r.json()).catch(() => ({ ok: false }));
}

// ── DOM helpers (no innerHTML — strict CSP) ─────────────────────────────────
function el(tag, cls, attrs)    { const e = document.createElement(tag); if (cls) e.className = cls; if (attrs) for (const k in attrs) e.setAttribute(k, attrs[k]); return e; }
function txt(tag, cls, content) { const e = el(tag, cls); e.textContent = content; return e; }
function btn(label, cls, fn, type = 'button') {
    const b = el('button', 'btn ' + cls);
    b.type = type;
    b.textContent = label;
    b.addEventListener('click', fn);
    return b;
}
function fmt(n)               { return currency + Number(n || 0).toLocaleString(); }
function setText(id, s)       { const e = document.getElementById(id); if (e) e.textContent = s; }

// ── View switching ─────────────────────────────────────────────────────────
function showView(id) {
    document.getElementById('app').classList.remove('hidden');
    document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
    const t = document.getElementById(id);
    if (t) t.classList.remove('hidden');
    // Focus management
    lastFocused = document.activeElement;
    setTimeout(() => {
        const f = t && t.querySelector('input, button');
        if (f) f.focus();
    }, 50);
}

function closeUI() {
    document.getElementById('app').classList.add('hidden');
    document.querySelectorAll('.view, .modal').forEach(v => v.classList.add('hidden'));
    nuiPost('ui/close', {});
    if (lastFocused && lastFocused.blur) lastFocused.blur();
}

// ── Message dispatcher ─────────────────────────────────────────────────────
window.addEventListener('message', (e) => {
    const d = e.data || {};
    switch (d.action) {
        case 'openGarage':    handleOpenGarage(d);    break;
        case 'openAuction':   handleOpenAuction(d);   break;
        case 'auctionUpdate': handleAuctionUpdate(d); break;
        case 'auctionTick':   handleAuctionTick(d);   break;
        case 'closeUI':       closeUI();              break;
    }
});

// ────────────────────────────────────────────────────────────────────────────
// GARAGE VIEW
// ────────────────────────────────────────────────────────────────────────────

function handleOpenGarage(data) {
    currentGarage   = data.garage || null;
    currentVehicles = (data.vehicles || []).slice();
    currency        = data.currency || '$';
    plateChangeCfg  = data.plateChange || {};
    subOwnerCfg     = data.subOwners || {};
    transferCfg     = data.transfer || {};

    setText('garage-label', currentGarage.label || 'Garage');
    setText('garage-type', (currentGarage.type || 'public').toUpperCase());

    // Show valet only if enabled
    document.getElementById('btn-valet').hidden = !(data.valet && data.valet.enabled);

    // Show boss menu only for job garages
    const isJob = currentGarage.type === 'job' && currentGarage.society;
    const bossBtn = document.getElementById('btn-boss');
    bossBtn.hidden = !isJob;
    if (isJob) activeBossSociety = currentGarage.society;

    // Sort by favorite descending
    currentVehicles.sort((a, b) => (b.tx_garage_fav ? 1 : 0) - (a.tx_garage_fav ? 1 : 0));

    showView('garage-view');
    document.getElementById('search-input').value = '';
    renderVehicles(currentVehicles);
}

function renderVehicles(list) {
    const grid  = document.getElementById('vehicle-grid');
    const empty = document.getElementById('empty-state');
    grid.textContent = '';
    if (!list || list.length === 0) {
        empty.classList.remove('hidden');
        return;
    }
    empty.classList.add('hidden');
    for (const v of list) grid.appendChild(buildVehicleCard(v));
}

function buildVehicleCard(v) {
    const card = el('div', 'vehicle-card');
    if (v.tx_garage_fav) card.classList.add('pinned');

    // Preview banner
    const klass = v.modelClass || 'compact';
    const preview = el('div', 'preview ' + klass);
    preview.dataset.glyph = CLASS_GLYPHS[klass] || CLASS_GLYPHS.compact;
    const status = el('div', 'preview-status ' + (v.state || 'stored'));
    status.textContent = (v.state || 'stored').toUpperCase();
    preview.appendChild(status);
    card.appendChild(preview);

    // Body
    const body = el('div', 'card-body');

    // Title row
    const titleRow = el('div', 'card-title-row');
    titleRow.appendChild(txt('div', 'model', v.vehicle || v.model || 'Unknown'));
    const fav = el('button', 'fav-btn' + (v.tx_garage_fav ? ' active' : ''));
    fav.type = 'button';
    fav.textContent = '★';
    fav.title = v.tx_garage_fav ? 'Unpin vehicle' : 'Pin to top';
    fav.setAttribute('aria-label', fav.title);
    fav.addEventListener('click', () => {
        const nowFav = !fav.classList.contains('active');
        fav.classList.toggle('active');
        card.classList.toggle('pinned', nowFav);
        v.tx_garage_fav = nowFav ? 1 : 0;
        nuiPost('garage/favorite', { plate: v.plate, fav: nowFav });
        // Re-sort
        currentVehicles.sort((a, b) => (b.tx_garage_fav ? 1 : 0) - (a.tx_garage_fav ? 1 : 0));
        renderVehicles(currentVehicles);
    });
    titleRow.appendChild(fav);
    body.appendChild(titleRow);

    body.appendChild(txt('div', 'plate', v.plate || ''));

    // Stats
    const stats = el('div', 'stats');
    stats.appendChild(buildStat(Math.round(v.fuel ?? 100), 'Fuel', 'fuel'));
    stats.appendChild(buildStat(Math.round(v.engine ?? 1000), 'Engine', 'engine'));
    stats.appendChild(buildStat(Math.round(v.body ?? 1000), 'Body', 'body'));
    body.appendChild(stats);

    // Mileage
    const mil = el('div', 'mileage');
    mil.appendChild(txt('span', 'label', 'Mileage'));
    mil.appendChild(txt('span', 'value', formatKm(v.mileage)));
    body.appendChild(mil);

    // Actions
    const actions = el('div', 'card-actions');
    actions.appendChild(btn('Retrieve', 'primary', () => onRetrieve(v)));
    actions.appendChild(btn('Key', 'secondary', () => nuiPost('garage/giveKey', { plate: v.plate })));
    actions.appendChild(btn('Transfer', 'ghost', () => {
        if (transferCfg && transferCfg.enabled) nuiPost('garage/transfer', { plate: v.plate });
    }));
    if (plateChangeCfg && plateChangeCfg.enabled) {
        actions.appendChild(btn('Plate', 'ghost', () => nuiPost('garage/changePlate', { plate: v.plate })));
    }
    if (subOwnerCfg && subOwnerCfg.enabled) {
        actions.appendChild(btn('Sub', 'ghost', () => openSubOwnerModal(v.plate)));
    }
    body.appendChild(actions);

    card.appendChild(body);
    return card;
}

function buildStat(raw, label, type) {
    // engine/body 0-1000 → percentage; fuel already 0-100
    const pct = (type === 'fuel') ? raw : Math.round(raw / 10);
    const s = el('div', 'stat');
    const valueEl = txt('div', 'value', pct + '%');
    valueEl.classList.add(pct >= 70 ? 'ok' : pct >= 40 ? 'warn' : 'crit');
    s.appendChild(valueEl);
    s.appendChild(txt('div', 'label', label));
    return s;
}

function formatKm(m) {
    const km = (Number(m) || 0) / 1000;
    if (km < 1) return '<1 km';
    return km.toFixed(1) + ' km';
}

async function onRetrieve(v) {
    const r = await nuiPost('garage/retrieve', { garageName: currentGarage.name, plate: v.plate });
    if (r && r.ok === false) {
        // Server rejected — keep UI open so player can try again
        return;
    }
}

// Search
document.getElementById('search-input').addEventListener('input', (e) => {
    const q = e.target.value.trim().toLowerCase();
    if (!q) { renderVehicles(currentVehicles); return; }
    const filtered = currentVehicles.filter(v =>
        (v.vehicle || '').toLowerCase().includes(q) ||
        (v.plate || '').toLowerCase().includes(q)
    );
    renderVehicles(filtered);
});

// ────────────────────────────────────────────────────────────────────────────
// AUCTION VIEW
// ────────────────────────────────────────────────────────────────────────────

function handleOpenAuction(data) {
    currentAuctions = data.auctions || [];
    auctionConfig   = data.config || {};
    currency        = data.currency || '$';
    showView('auction-view');
    renderAuctions();
}

function renderAuctions() {
    const grid  = document.getElementById('auction-grid');
    const empty = document.getElementById('auction-empty');
    grid.textContent = '';
    if (currentAuctions.length === 0) {
        empty.classList.remove('hidden');
        return;
    }
    empty.classList.add('hidden');
    for (const a of currentAuctions) grid.appendChild(buildAuctionCard(a));
}

function buildAuctionCard(a) {
    const card = el('div', 'auction-card');
    card.dataset.id = a.id;
    card.dataset.endsTs = a.ends_at_ts;
    card.dataset.currentBid = a.current_bid;

    // Preview gradient
    const klass = classifyForCss(a.vehicle_model);
    const preview = el('div', 'preview ' + klass);
    preview.dataset.glyph = CLASS_GLYPHS[klass] || CLASS_GLYPHS.compact;
    card.appendChild(preview);

    // "You're leading" banner
    if (a.is_leader) {
        const banner = txt('div', 'leading-banner', '★ YOU ARE LEADING');
        card.appendChild(banner);
    }

    const body = el('div', 'card-body');

    // Title row
    const titleRow = el('div', 'card-title-row');
    titleRow.appendChild(txt('div', 'model', a.vehicle_model || 'Unknown'));
    const watch = el('button', 'watch-btn' + (a.watching ? ' active' : ''));
    watch.type = 'button';
    watch.textContent = '◉';
    watch.title = a.watching ? 'Stop watching' : 'Watch — get notified before close';
    watch.setAttribute('aria-label', watch.title);
    watch.addEventListener('click', () => {
        const nowWatch = !watch.classList.contains('active');
        watch.classList.toggle('active');
        watch.title = nowWatch ? 'Stop watching' : 'Watch — get notified before close';
        a.watching = nowWatch;
        nuiPost('auction/watch', { auctionId: a.id, watching: nowWatch });
    });
    titleRow.appendChild(watch);
    body.appendChild(titleRow);

    body.appendChild(txt('div', 'plate', a.plate || ''));

    // Price + countdown
    const priceRow = el('div', 'price-row');
    const priceCol = el('div');
    const bidEl = txt('div', 'current-bid', fmt(a.current_bid ?? 0));
    bidEl.dataset.field = 'bid';
    priceCol.appendChild(bidEl);
    priceCol.appendChild(txt('div', 'starting-bid', `Starting: ${fmt(a.starting_bid ?? 0)}`));
    priceRow.appendChild(priceCol);
    const timer = txt('div', 'ends-in', formatTimeLeft(a.ends_at_ts));
    timer.dataset.field = 'timer';
    priceRow.appendChild(timer);
    body.appendChild(priceRow);

    // Bid input
    const bidRow = el('div', 'bid-row');
    const input = document.createElement('input');
    input.type = 'number';
    input.min  = '0';
    input.dataset.field = 'input';
    input.placeholder = 'Min ' + fmt((a.current_bid ?? 0) + (auctionConfig.minBidIncrement ?? 100));
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') doBid(a.id, input); });
    bidRow.appendChild(input);
    bidRow.appendChild(btn('Bid', 'primary', () => doBid(a.id, input)));
    body.appendChild(bidRow);

    card.appendChild(body);
    return card;
}

function classifyForCss(model) {
    // Mirror of Utils.classifyModel — keeps NUI self-sufficient
    const m = (model || '').toLowerCase();
    if (/^(adder|zentorno|t20|osiris|reaper|tezeract|infernus|cheetah|turismo|furiagt|vagner|italigtb|sc1|xa21|prototipe|tyrus|entityxf)/.test(m)) return 'super';
    if (/^(sultan|futo|jester|massacro|rapidgt|elegy|feltzer|9f|banshee|buffalo|carbonizzare)/.test(m)) return 'sports';
    if (/^(baller|radi|seminole|rocoto|dubsta|huntley)/.test(m)) return 'suv';
    if (/^(akuma|bati|double|faggio|hakuchou|vader|pcj|sanchez|daemon)/.test(m)) return 'motorcycle';
    if (/^(bison|bobcatxl|rebel|sandking|blade|dukes)/.test(m)) return 'truck';
    if (/^(asea|asterope|cognoscenti|emperor|fugitive|glendale|intruder|premier|primo|regina|schafter|stratum|stanier|superd|warrener|washington)/.test(m)) return 'sedan';
    return 'compact';
}

function doBid(auctionId, input) {
    const amount = Number(input.value);
    if (!amount || amount <= 0) return;
    nuiPost('auction/bid', { auctionId, amount });
    input.value = '';
}

function handleAuctionUpdate({ auctionId, newBid, endsTs }) {
    const card = document.querySelector(`.auction-card[data-id="${auctionId}"]`);
    if (!card) return;
    card.dataset.currentBid = newBid;
    if (endsTs) card.dataset.endsTs = endsTs;
    const bidEl = card.querySelector('[data-field="bid"]');
    if (bidEl) bidEl.textContent = fmt(newBid);
    const input = card.querySelector('[data-field="input"]');
    if (input) input.placeholder = 'Min ' + fmt(newBid + (auctionConfig.minBidIncrement ?? 100));
}

// Single-pass tick: update every visible auction's timer per second.
function handleAuctionTick({ nowTs }) {
    const cards = document.querySelectorAll('.auction-card');
    for (const card of cards) {
        const ends = Number(card.dataset.endsTs || 0);
        const left = Math.max(0, ends - nowTs);
        const t = card.querySelector('[data-field="timer"]');
        if (t) {
            t.textContent = formatTimeLeftSeconds(left);
            t.classList.toggle('ending-soon', left > 0 && left < (auctionConfig.antiSnipeSeconds || 60));
        }
    }
}

function formatTimeLeft(ts) {
    if (!ts) return '—';
    const s = Math.max(0, ts - Math.floor(Date.now() / 1000));
    return formatTimeLeftSeconds(s);
}
function formatTimeLeftSeconds(s) {
    if (s <= 0) return 'CLOSED';
    if (s < 60) return s + 's';
    if (s < 3600) return Math.floor(s / 60) + 'm ' + (s % 60) + 's';
    return Math.floor(s / 3600) + 'h ' + Math.floor((s % 3600) / 60) + 'm';
}

// ────────────────────────────────────────────────────────────────────────────
// SUB-OWNER MODAL
// ────────────────────────────────────────────────────────────────────────────

async function openSubOwnerModal(plate) {
    activeSubOwnerPlate = plate;
    const modal = document.getElementById('subowner-modal');
    modal.classList.remove('hidden');
    await refreshSubOwnerList();
}

async function refreshSubOwnerList() {
    if (!activeSubOwnerPlate) return;
    const r = await nuiPost('garage/subOwners/list', { plate: activeSubOwnerPlate });
    const ul = document.getElementById('subowner-list');
    ul.textContent = '';
    if (!r || !r.list || r.list.length === 0) {
        const li = el('li');
        li.appendChild(txt('span', 'muted', 'No sub-owners yet.'));
        ul.appendChild(li);
        return;
    }
    for (const so of r.list) {
        const li = el('li');
        li.appendChild(txt('span', '', so.name || so.citizenid));
        const removeBtn = el('button');
        removeBtn.type = 'button';
        removeBtn.textContent = 'Remove';
        removeBtn.addEventListener('click', async () => {
            await nuiPost('garage/subOwners/remove', {
                plate: activeSubOwnerPlate,
                targetCid: so.citizenid,
            });
            setTimeout(refreshSubOwnerList, 400);
        });
        li.appendChild(removeBtn);
        ul.appendChild(li);
    }
}

document.getElementById('btn-add-subowner').addEventListener('click', () => {
    if (!activeSubOwnerPlate) return;
    nuiPost('garage/subOwners/add', { plate: activeSubOwnerPlate });
    document.getElementById('subowner-modal').classList.add('hidden');
});

// ────────────────────────────────────────────────────────────────────────────
// BOSS MENU MODAL
// ────────────────────────────────────────────────────────────────────────────

async function openBossModal() {
    if (!activeBossSociety) return;
    const r = await nuiPost('garage/boss/balance', { society: activeBossSociety });
    setText('boss-balance-value', fmt((r && r.balance) || 0));
    document.getElementById('boss-modal').classList.remove('hidden');
}

document.getElementById('btn-boss-deposit').addEventListener('click', () => {
    nuiPost('garage/boss/deposit');
    document.getElementById('boss-modal').classList.add('hidden');
});
document.getElementById('btn-boss-withdraw').addEventListener('click', () => {
    nuiPost('garage/boss/withdraw');
    document.getElementById('boss-modal').classList.add('hidden');
});

// ────────────────────────────────────────────────────────────────────────────
// Top-level button bindings
// ────────────────────────────────────────────────────────────────────────────

document.getElementById('btn-store').addEventListener('click', () => {
    nuiPost('garage/store', { garageName: currentGarage && currentGarage.name });
});
document.getElementById('btn-valet').addEventListener('click', () => {
    nuiPost('garage/valet', { garageName: currentGarage && currentGarage.name });
});
document.getElementById('btn-boss').addEventListener('click', openBossModal);

document.querySelectorAll('[data-action="close"]').forEach(b =>
    b.addEventListener('click', closeUI));
document.querySelectorAll('[data-action="close-modal"]').forEach(b =>
    b.addEventListener('click', () => {
        document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    }));

// ESC closes UI / modals
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const openModal = document.querySelector('.modal:not(.hidden)');
    if (openModal) {
        openModal.classList.add('hidden');
        return;
    }
    closeUI();
});

// Focus trap inside modals (Tab cycling stays within the open modal)
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Tab') return;
    const openModal = document.querySelector('.modal:not(.hidden) .modal-card');
    if (!openModal) return;
    const focusables = openModal.querySelectorAll('button, input, [tabindex]:not([tabindex="-1"])');
    if (focusables.length === 0) return;
    const first = focusables[0];
    const last  = focusables[focusables.length - 1];
    if (e.shiftKey && document.activeElement === first) { last.focus(); e.preventDefault(); }
    else if (!e.shiftKey && document.activeElement === last) { first.focus(); e.preventDefault(); }
});
