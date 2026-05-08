---
name: tebex-listing-writer
description: Generates a Tebex store listing (title, blurb, feature list, install steps, FAQ, dependency block) for a tx_* FiveM resource in this repo. Invoke when the user is preparing to publish or refresh a Tebex product page. Pulls real version, dependencies, and escrow_ignore from fxmanifest.lua so the listing never drifts from the shipping artifact.
disable-model-invocation: true
---

# tebex-listing-writer

Generates a Tebex listing for a tx_* FiveM resource published from this repo.

## When to use
- User says "write the Tebex listing", "draft the store page", "generate listing copy"
- User is shipping a new version and wants the listing refreshed
- Pre-listing checklist before running `/agents fivem-script-reviewer`

## Workflow

### 1. Gather facts from the artifact (do not invent)
Read these files to source ground truth:
- `fxmanifest.lua` — `version`, `description`, `dependencies`, `escrow_ignore`
- `README.md` — feature narrative
- `INSTALL.sql` — schema delta (if present)
- `config.lua` — feature toggles a buyer can flip without touching escrowed code

### 2. Cross-check against repo conventions (`/Volumes/SAMSUNG 1TB/fx/CLAUDE.md`)
- Price anchors: simple jobs ~$14.99, feature-rich systems ~$24.99–$34.99
- Frameworks supported: QBCore / QBox / ESX (must be stated explicitly)
- Original work only — no Rockstar IP, no trademarked vehicle names
- Server-side security: `?` placeholders, source validation, ownership checks, rate limits

### 3. Use the template
Open `template.md` in this skill directory. It ships pre-filled with a current tx_garage v1.0.0 listing as the working baseline.

For a refresh (same product, new version): copy `template.md` to the output path, then update the version line, swap any feature changes into the appropriate sections, and re-confirm the price tier.

For a new product (e.g., tx_bikecourier): copy `template.md`, replace the entire body section-by-section using the same structure. The structural choices — title format, "Why" framing, FAQ shape, escrow callout — are deliberate and proven; only the content should change.

### 4. Output structure (Tebex-friendly markdown)
1. **Title** — under 60 chars, includes `tx_<name>` and primary feature
2. **One-line blurb** — what it does + who it's for, in one sentence
3. **Feature bullets** — 5–8 bullets, each starting with a verb
4. **Differentiators** — what no other script in this category does (this is the conversion driver)
5. **Compatibility** — frameworks, dependencies (from fxmanifest), tested versions
6. **Install** — 3–5 numbered steps, including `INSTALL.sql` if present
7. **Configuration** — note that `config.lua` and `locales/*.lua` are escrow-ignored (buyer-editable)
8. **FAQ** — 3–5 anticipated buyer questions
9. **Support** — discord/email; refund policy line

### 5. Final verification before handing back
- [ ] Version in listing matches `fxmanifest.lua` version
- [ ] All `dependencies {}` from fxmanifest are mentioned in Compatibility
- [ ] No Rockstar trademarks (Adder, Zentorno, Comet, Sultan, etc.) in copy
- [ ] No competitor script names referenced
- [ ] Price tier chosen using CLAUDE.md anchors and stated rationale (1 sentence)
- [ ] Buyer-editable surface (config.lua, locales) is called out
- [ ] Listing length: 250–500 words. Tebex listings shorter than 200 words underperform; longer than 600 words bury the buy button.

## Output destination
Write to `tebex/listing.md` (create if missing). Do NOT write into the resource itself — `tebex/` is outside `fxmanifest.lua` files{} and won't ship.
