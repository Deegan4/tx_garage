---
name: fivem-resource-audit
description: Walks every server-side entry point (RegisterNetEvent, lib.callback.register) in a tx_* FiveM resource and verifies the 4-point security checklist from CLAUDE.md — source validation, ownership verification, rate limiting, server-side money. Invoke before listing on Tebex, after refactoring server code, or when the user asks "audit this resource" or "check security."
---

# fivem-resource-audit

Audit every client-reachable server entry point in a FiveM resource against the security checklist in `/Volumes/SAMSUNG 1TB/fx/CLAUDE.md`.

## When to use
- Pre-Tebex-listing security pass
- After adding/modifying any `RegisterNetEvent` or `lib.callback.register`
- User asks to "audit", "review for security", "check exploits"
- Mentioned anywhere as a prerequisite for `/agents fivem-script-reviewer`

## The 4-point checklist (from CLAUDE.md)
For EVERY net event and callback, verify:

1. **Source validation** — `source` is captured at top of handler and used (not trusted as a parameter)
2. **Ownership verification** — vehicle/item/money ops check the player owns the target before acting
3. **Rate limiting** — per-player cooldown tracked between calls (e.g., the `cooldowns[src]` pattern in `sv_garage.lua`)
4. **Server-side money** — money amounts are computed on server, never accepted from client args. Client args like `amount` are verified against server-side state before charging.

## Workflow

### Step 1 — Enumerate entry points
Run from project root:
```bash
grep -rn "RegisterNetEvent\|lib\.callback\.register" server/
```
Build a table: `{ file, line, event_name, handler_signature }`.

### Step 2 — For each entry, check the 4 points
Read each handler. For each checklist item, mark one of:
- ✅ Pass
- ⚠️ Partial (e.g., source captured but not validated; ownership check exists but bypassable)
- ❌ Fail (missing entirely)
- N/A (e.g., point #4 doesn't apply if no money is involved)

### Step 3 — Cross-cut audits
Beyond per-handler checks, scan for:
- **Client-trusted IDs** — any `targetServerId` or `plate` parameter where the handler doesn't re-resolve from server-authoritative state
- **State enum drift** — `tx_garage_state` values used in queries vs. INSTALL.sql schema (must match exactly: `stored`, `impound`, `auction`)
- **Missing playerDropped cleanup** — long-lived per-source tables (cooldowns, sessions) that don't clear on disconnect
- **Free-form SQL** — any `MySQL.query.await` whose first arg isn't a static `[[ ]]` block or local string from a static source. (The `sql-guard.py` PreToolUse hook covers new code, but this catches existing debt.)
- **Bridge.* misuse** — money operations that use `RemoveMoney` (online-only) where the player might be offline. Use `RemoveMoneyOffline` with safe round-trip when in doubt.

### Step 4 — Output
Produce a table sorted by severity:

| Severity | File:Line | Event | Issue | Fix |
|---|---|---|---|---|
| 🔴 Critical | sv_X.lua:42 | event_name | exploit summary | one-line remediation |
| 🟡 Medium | ... | | | |
| 🟢 Pass | (count) handlers fully clear | | | |

### Step 5 — Pass/fail verdict
- 🔴 critical findings → BLOCKS Tebex listing
- 🟡 medium findings → reviewer's call (note in changelog if shipping)
- 🟢 only → safe to proceed to `/agents fivem-script-reviewer` for final review

## Notes
- This skill is the *programmer's* audit. The `fivem-script-reviewer` agent is the *reviewer's* audit (broader: escrow correctness, IP, manifest hygiene, dependency policy). Run this skill first; the agent second.
- Cooldown reference pattern (gold standard, copy this style):
  ```lua
  local function isOnCooldown(src, key, seconds)
      local now = os.time()
      cooldowns[src] = cooldowns[src] or {}
      if cooldowns[src][key] and now - cooldowns[src][key] < seconds then return true end
      cooldowns[src][key] = now
      return false
  end
  AddEventHandler('playerDropped', function() cooldowns[source] = nil end)
  ```
