# NetUtil App Icon — Design Brief (Liquid Glass, macOS 26)

Approved direction: **Concept A** (evolve the existing node-graph mark), brand **system blue**. Needs layered source assets; no assets changed yet.

## Goal

A layered icon following Apple's new icon system: solid, geometric, overlapping shapes; the system handles masking, blur, refraction, and highlights. Must read from 16 px to 1024 px and work across appearances (light / dark / clear / tinted).

## Layers (full-bleed square; never bake the mask)

1. **Background** — solid blue base (gradient allowed).
2. **Middle** — connective lines hub→nodes, white ~70–85% opacity, optional glow.
3. **Foreground** — hub + three nodes as solid white shapes, overlapping.

Rule: each layer is a solid filled shape that overlaps; avoid thin 1 px strokes (the system blurs them away). At 1024 px, connection lines should be ~24–32 px thick.

## Geometry

- Canvas: 1024×1024 per layer, transparent PNG.
- Keep key art within the central ~80% (≈10% margins) so the macOS squircle mask never clips it.
- Concentric with the hardware curvature; keep elements centered.
- Node outer rings → solid discs (or thick rings), hub slightly larger as the focal point.

## Palette

- Default: gradient `#0A84FF → #0066E0`, elements white.
- Dark: richer/darker blue (`#0A6FE0 → #053C8A`), white elements.
- Clear: transparent background, white elements must stay legible.
- Tinted: must work in grayscale — form, not color, defines the silhouette.
- Contrast: white-on-blue ≥ 3:1; verify with Increased Contrast.

## Export / handoff

- 3 PNG layers @1024: `NetUtil-Icon-Background@1024.png`, `-Middle@1024.png`, `-Foreground@1024.png`.
- Compose and preview in **Icon Composer**; export light/dark/clear/tinted sets into `Assets.xcassets/AppIcon`.
- Also keep vector sources (Figma/SVG) and the `.icon` project for revisions.
- Sizes: 16/32/64/128/256/512/1024 (1x/2x).

## Do / Don't

- Do: solid filled shapes, overlapping layers, separate layers, full-bleed, let the system apply effects.
- Don't: thin strokes, text, baked shadows/reflections, baked mask/rounded corners, elements near the edges, details smaller than ~8 px at 1024.

## Test matrix

| Test | Pass criteria |
|---|---|
| 16×16 | motif still readable, lines don't vanish |
| 32/64 | overlaps clear |
| 128/512 | no clipping in the mask |
| Light/Dark | adequate contrast, distinct feel |
| Clear/Tinted | silhouette clear without color |
| Increased Contrast | doesn't break up |
| Dock & About | consistent |
