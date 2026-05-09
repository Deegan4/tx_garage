'use strict';

// State
let currentGarage = null;
let currentVehicles = [];
let currentAuctions = [];
let auctionConfig = {};
let currency = "$";

// NUI bridge
function nuiPost(action, data) {
    return fetch(`https://tx_garage/${action}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data ?? {}),
    });
}

// Message dispatcher
window.addEventListener("message", (e) => {
    const { action } = e.data;
    if (action === "openGarage")    handleOpenGarage(e.data);
    if (action === "openAuction")   handleOpenAuction(e.data);
    if (action === "auctionUpdate") handleAuctionUpdate(e.data);
});

function handleOpenGarage({ garage, vehicles, valet }) {
    currentGarage = garage;
    currentVehicles = (vehicles || []).sort((a, b) => (b.tx_garage_fav ? 1 : 0) - (a.tx_garage_fav ? 1 : 0));
    show("garage-view");
    setText("garage-label", garage.label || "Garage");
    setText("garage-type", (garage.type || "public").toUpperCase());
    document.getElementById("btn-valet").style.display = (valet && valet.enabled) ? "" : "none";
    renderVehicles();
}

function renderVehicles() {
    const grid  = document.getElementById("vehicle-grid");
    const empty = document.getElementById("empty-state");
    grid.textContent = "";
    if (currentVehicles.length === 0) { empty.classList.remove("hidden"); return; }
    empty.classList.add("hidden");
    for (const v of currentVehicles) grid.appendChild(buildVehicleCard(v));
}

function buildVehicleCard(v) {
    const card = el("div", "vehicle-card");
    if (v.tx_garage_fav) card.classList.add("pinned");

    const titleRow = el("div", "card-title-row");
    titleRow.appendChild(txt("div", "model", v.model || "Unknown"));
    const favBtn = el("button", "fav-btn" + (v.tx_garage_fav ? " active" : ""));
    favBtn.textContent = "★";
    favBtn.title = v.tx_garage_fav ? "Unpin vehicle" : "Pin to top";
    favBtn.addEventListener("click", () => {
        const nowFav = !favBtn.classList.contains("active");
        favBtn.classList.toggle("active");
        card.classList.toggle("pinned", nowFav);
        nuiPost("garage/favorite", { plate: v.plate, fav: nowFav });
        v.tx_garage_fav = nowFav;
        // re-sort: pinned cards bubble to front
        currentVehicles.sort((a, b) => (b.tx_garage_fav ? 1 : 0) - (a.tx_garage_fav ? 1 : 0));
        renderVehicles();
    });
    titleRow.appendChild(favBtn);
    card.appendChild(titleRow);

    card.appendChild(txt("div", "plate", v.plate || ""));
    const stats = el("div", "stats");
    stats.appendChild(buildStat(Math.round(v.fuel   ?? 100), "Fuel",   "fuel"));
    stats.appendChild(buildStat(Math.round(v.engine ?? 100), "Engine", "engine"));
    stats.appendChild(buildStat(Math.round(v.body   ?? 100), "Body",   "body"));
    card.appendChild(stats);
    const actions = el("div", "card-actions");
    actions.appendChild(btn("Retrieve", "primary", () => {
        nuiPost("garage/retrieve", { garageName: currentGarage.name, plate: v.plate });
        closeUI();
    }));
    actions.appendChild(btn("Give Key", "secondary", () => {
        const id = prompt("Enter target player server ID:");
        if (!id || isNaN(Number(id))) return;
        nuiPost("garage/giveKey", { plate: v.plate, targetId: Number(id) });
    }));
    actions.appendChild(btn("Transfer", "secondary", () => {
        const id = prompt("Enter target player server ID:");
        if (!id || isNaN(Number(id))) return;
        nuiPost("garage/transfer", { plate: v.plate, targetId: Number(id) });
    }));
    card.appendChild(actions);
    return card;
}

// pct is 0–1000 for engine/body (FiveM scale), or 0–100 for fuel
function buildStat(raw, label, type) {
    // Normalise to 0–100 percentage
    const pct = (type === "fuel") ? raw : Math.round(raw / 10);
    const s = el("div", "stat");
    const valueEl = txt("div", "value", pct + "%");
    // colour-code: ≥70 green, ≥40 yellow, <40 red
    valueEl.classList.add(pct >= 70 ? "ok" : pct >= 40 ? "warn" : "crit");
    s.appendChild(valueEl);
    s.appendChild(txt("div", "label", label));
    return s;
}


function handleOpenAuction({ auctions, config }) {
    currentAuctions = auctions || [];
    auctionConfig   = config   || {};
    show("auction-view");
    renderAuctions();
}

function renderAuctions() {
    const grid  = document.getElementById("auction-grid");
    const empty = document.getElementById("auction-empty");
    grid.textContent = "";
    if (currentAuctions.length === 0) { empty.classList.remove("hidden"); return; }
    empty.classList.add("hidden");
    for (const a of currentAuctions) grid.appendChild(buildAuctionCard(a));
}

function buildAuctionCard(a) {
    const card = el("div", "auction-card");
    card.dataset.id = a.id;

    const titleRow = el("div", "card-title-row");
    titleRow.appendChild(txt("div", "model", a.model || "Unknown"));
    const watchBtn = el("button", "watch-btn" + (a.watching ? " active" : ""));
    watchBtn.textContent = "👁";
    watchBtn.title = a.watching ? "Stop watching" : "Watch — get notified 5 min before close";
    watchBtn.addEventListener("click", () => {
        const nowWatch = !watchBtn.classList.contains("active");
        watchBtn.classList.toggle("active");
        watchBtn.title = nowWatch ? "Stop watching" : "Watch — get notified 5 min before close";
        a.watching = nowWatch;
        nuiPost("auction/watch", { auctionId: a.id, watching: nowWatch });
    });
    titleRow.appendChild(watchBtn);
    card.appendChild(titleRow);

    card.appendChild(txt("div", "plate", a.plate  || ""));
    const priceRow = el("div", "price-row");
    const bidEl = txt("div", "current-bid", fmt(a.currentBid ?? 0));
    bidEl.dataset.field = "bid";
    priceRow.appendChild(bidEl);
    const timer = txt("div", "ends-in", formatTimeLeft(a.endsAt));
    timer.dataset.field = "timer";
    priceRow.appendChild(timer);
    card.appendChild(priceRow);
    const bidRow = el("div", "bid-row");
    const input = document.createElement("input");
    input.type = "number";
    input.placeholder = "Min " + fmt((a.currentBid ?? 0) + (auctionConfig.minBidIncrement ?? 100));
    bidRow.appendChild(input);
    bidRow.appendChild(btn("Bid", "primary", () => {
        const amount = Number(input.value);
        if (!amount || amount <= 0) return;
        nuiPost("auction/bid", { auctionId: a.id, amount });
        input.value = "";
    }));
    card.appendChild(bidRow);
    return card;
}

function handleAuctionUpdate({ auctionId, newBid }) {
    const card = document.querySelector(".auction-card[data-id=\""+auctionId+"\"]");
    if (!card) return;
    const bidEl = card.querySelector("[data-field=\"bid\"]");
    if (bidEl) bidEl.textContent = fmt(newBid);
    const input = card.querySelector("input");
    if (input) input.placeholder = "Min " + fmt(newBid + (auctionConfig.minBidIncrement ?? 100));
}

document.getElementById("btn-store").addEventListener("click", () => {
    nuiPost("garage/store", { garageName: currentGarage && currentGarage.name });
    closeUI();
});
document.getElementById("btn-valet").addEventListener("click", () => {
    nuiPost("garage/valet", { garageName: currentGarage && currentGarage.name });
    closeUI();
});
document.querySelectorAll("[data-action=\"close\"]").forEach(b => b.addEventListener("click", closeUI));
document.addEventListener("keydown", e => { if (e.key === "Escape") closeUI(); });

function closeUI() {
    document.getElementById("app").classList.add("hidden");
    document.querySelectorAll(".view").forEach(v => v.classList.add("hidden"));
    nuiPost("ui/close", {});
}

function el(tag, cls)         { const e = document.createElement(tag); if (cls) e.className = cls; return e; }
function txt(tag, cls, content) { const e = el(tag, cls); e.textContent = content; return e; }
function btn(label, cls, fn)  { const b = el("button", "btn " + cls); b.textContent = label; b.addEventListener("click", fn); return b; }
function show(id)             { document.getElementById("app").classList.remove("hidden"); document.querySelectorAll(".view").forEach(v => v.classList.add("hidden")); const t = document.getElementById(id); if (t) t.classList.remove("hidden"); }
function setText(id, text)    { const e = document.getElementById(id); if (e) e.textContent = text; }
function fmt(n)               { return currency + Number(n).toLocaleString(); }
function formatTimeLeft(ts)   { if (!ts) return "Unknown"; const s = Math.max(0, ts - Math.floor(Date.now()/1000)); if (s < 60) return s+"s"; if (s < 3600) return Math.floor(s/60)+"m"; return Math.floor(s/3600)+"h "+Math.floor((s%3600)/60)+"m"; }
