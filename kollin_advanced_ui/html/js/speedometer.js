'use strict';
// kollin_advanced_ui — Speedometer module

const Speedo = (() => {
    let visible = false;
    let animId  = null;
    let current = { speed: 0, rpm: 0 };
    let target  = { speed: 0, rpm: 0 };

    const LERP = 0.22; // smoothing factor (0 = instant, 1 = never moves)

    function lerp(a, b, t) { return a + (b - a) * t; }

    function init() {
        requestAnimationFrame(tick);
    }

    function tick() {
        if (visible) {
            // Smooth speed number
            const prevSpeed = current.speed;
            current.speed = lerp(current.speed, target.speed, 0.28);
            if (Math.abs(current.speed - target.speed) < 0.5) current.speed = target.speed;

            if (Math.abs(current.speed - prevSpeed) > 0.2) {
                const speedEl = document.getElementById('speedo-speed');
                if (speedEl) speedEl.textContent = Math.round(current.speed);
                // Color the speed value when very fast (>100mph or >160kph)
                const isFast = current.speed > 100;
                if (speedEl) speedEl.style.color = isFast ? '#e74c3c' : 'var(--text-primary)';
            }

            // Smooth RPM bar
            current.rpm = lerp(current.rpm, target.rpm, 0.18);
            const rpmEl = document.getElementById('speedo-rpm');
            if (rpmEl) {
                rpmEl.style.width      = clamp(current.rpm * 100, 0, 100) + '%';
                rpmEl.style.background = rpmColor(current.rpm);
                if (current.rpm > 0.9) {
                    rpmEl.style.animation = 'rpmFlash 0.2s ease-in-out infinite';
                } else {
                    rpmEl.style.animation = '';
                }
            }
        }
        animId = requestAnimationFrame(tick);
    }

    function update(d) {
        if (!d) return;
        target.speed = d.speed ?? 0;
        target.rpm   = d.rpm   ?? 0;

        setText('speedo-unit', d.unit || 'MPH');

        // Gear
        const gearEl = document.getElementById('speedo-gear');
        if (gearEl) {
            const g = d.gear ?? 0;
            gearEl.textContent = g === 0 ? 'R' : (g === 1 && d.speed < 2 ? 'N' : g);
        }

        // Fuel
        const fuelFill = document.getElementById('speedo-fuel');
        if (fuelFill) {
            fuelFill.style.width      = clamp(d.fuel ?? 100, 0, 100) + '%';
            fuelFill.style.background = fuelColor(d.fuel ?? 100);
        }

        // Seatbelt
        const beltEl = document.getElementById('speedo-seatbelt');
        if (beltEl) {
            beltEl.textContent = d.seatbelt ? '🔒' : '🔓';
            beltEl.title       = d.seatbelt ? 'Seatbelt on' : 'Seatbelt off';
            beltEl.style.opacity = d.seatbelt ? '1' : '0.4';
        }

        // Engine
        const engEl = document.getElementById('speedo-engine');
        if (engEl) {
            engEl.style.width      = clamp(d.engine ?? 100, 0, 100) + '%';
            engEl.style.background = damageColor(d.engine ?? 100);
        }

        // Body
        const bodyEl = document.getElementById('speedo-body');
        if (bodyEl) {
            bodyEl.style.width      = clamp(d.body ?? 100, 0, 100) + '%';
            bodyEl.style.background = damageColor(d.body ?? 100);
        }
    }

    function show() {
        if (visible) return;
        visible = true;
        const el = document.getElementById('speedometer');
        if (el) {
            el.classList.remove('hidden');
            el.classList.add('anim-slide-in-bottom');
        }
    }

    function hide() {
        if (!visible) return;
        visible = false;
        current = { speed: 0, rpm: 0 };
        target  = { speed: 0, rpm: 0 };
        const el = document.getElementById('speedometer');
        if (el) {
            el.classList.add('hidden');
            el.classList.remove('anim-slide-in-bottom');
        }
    }

    function setSeatbelt(on) {
        const beltEl = document.getElementById('speedo-seatbelt');
        if (beltEl) {
            beltEl.textContent = on ? '🔒' : '🔓';
            beltEl.style.opacity = on ? '1' : '0.4';
        }
    }

    return { init, update, show, hide, setSeatbelt };
})();
