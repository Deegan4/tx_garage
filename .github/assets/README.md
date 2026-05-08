# Visual assets for tx_garage

These are the images the README expects. **The README will look broken until you drop these in.** Capture them once you've polished the in-game experience (Week 5 of the ship plan).

## Required files

| File | Size | What to capture |
|---|---|---|
| `banner.png` | 1920 × 480 | Hero banner. tx_garage wordmark, Vice-City pink/teal gradient, optional UI screenshot collage |
| `demo-thumbnail.png` | 1280 × 720 | Thumbnail for the demo video link. Action shot of valet arriving, or auction NUI mid-bid |
| `feature-valet.png` | 1280 × 720 | Valet NUI panel + valet NPC arriving with the vehicle |
| `feature-auction.png` | 1280 × 720 | Auction NUI showing active bid, countdown, leaderboard |
| `feature-nui.png` | 1280 × 720 | Main garage panel with vehicle list + damage indicators |

## Capture tips

- **Use OBS or NVIDIA ShadowPlay** — built-in FiveM screenshot is low quality
- **Hide the HUD** in F8 console: `setr loadscreen:externalShutdown true` and any HUD-toggle command your stack provides
- **Capture at 2560 × 1440** then downscale to 1280 × 720 — sharper than capturing at target size
- **Color grade in Photoshop / Affinity** — bump saturation 10-15%, slight pink tint to match Vice-City brand
- **Compress with TinyPNG before committing** — keeps repo small

## For the demo video

- 90 seconds maximum
- Open with the value prop (text overlay): "FiveM's only garage with valet & auctions"
- Show the 3 unique features in order: valet → auction → polish
- Music: instrumental synthwave (royalty-free, e.g. from YouTube Audio Library)
- End with: Tebex link + Discord QR code
- Upload to YouTube unlisted, paste link into README.md (search for `REPLACE-WITH-DEMO-VIDEO`)

## Banner mockup spec

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   [tx_garage]   ← large wordmark, white or neon-cyan            │
│   Valet · Impound Auctions · Modern UI                          │
│                                                                 │
│           [small UI screenshot]    [small UI screenshot]        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
   ^─ pink → teal gradient background, slight grain texture
```

Tools: Figma (free), Affinity Designer, Photoshop, or Canva.
