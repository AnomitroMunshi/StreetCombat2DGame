# Painted impact decals v1

21 individual transparent PNGs, generated with built-in image_gen and mechanically sliced/resized from retained source atlases. Artwork delivery only: existing procedural crater, game scripts, scenes and VFX behavior are untouched.

## Material sets

| Folder | Floor | Wall |
|---|---|---|
| dojo_wood_v1 | Warm brown broken floorboards, left-right grain | Dark wood pillar dents/splits |
| west_bengal_v1 | Warm grey paving slabs/chips, for both Kolkata variants | Cream plaster/masonry with exposed grey aggregate |
| colosseum_v1 | Displaced golden sand and shallow compression | Cream limestone chips/fractures |

Each folder contains:
- floor_impact_01.png through floor_impact_03.png: 1024 x 256.
- wall_impact_01.png through wall_impact_03.png: 256 x 512.
- floor_scuff_light.png: 512 x 128, no deep hole.

Original generated sheets: _sources/. Exact export regions, image sizes, transparent-area measurements and provisional centered anchors: manifest.json. Full prompts: PROMPTS.md. Open preview.html in a browser for alpha-composited previews against representative stage colors.

## Integration notes for Claude

- Pick a variant once per impact, retain that choice while animating; do not randomize every frame.
- Floor textures are already flattened to a low-angle 4:1 canvas. Begin with a 4:1 display rectangle; avoid accidentally applying a second full perspective squash. Tune only if actual camera view requires it.
- Suggested starting origin is texture center. Align crater center to the impact point, not texture bottom. Wall crushed centers vary, so inspect and adjust anchors for individual art if needed.
- Draw under fighters, using alpha fade and a small growth animation anchored at contact. Scale by impact strength within sensible limits.
- Keep existing dust/debris/splinter effects above decals. These images depict settled damage, not animated particles.
- Route material by actual impacted surface: Kolkata paving is stone, Colosseum arena floor is sand. Wooden gates still use wood damage; limestone columns use limestone. The distant landmarks/crowd are not damage receivers.
- Use the light scuff for minor impacts. Craters remain cosmetic: do not imply walkable collision holes.
- Blend via ordinary alpha, not additive blending. Avoid horizontal mirroring if the resulting reversed baked light is conspicuous.
- Source atlas sizing was not exact from generation; exports have been normalized to the requested sizes and retain generous transparent padding. Rough source aspect differences were fitted to output rectangles.
- Small light scuffs include some underlying material color; compare opacity against actual stage texture before accepting the blend.
- Some raw image viewers expose bright RGB stored in near-transparent edge pixels. A sampled red edge in the wood export had alpha at most 2/255; use an alpha-aware preview. Check Godot texture filtering/mips during integration.

## Validation and limits

All 21 output files exist. Export dimensions and genuine alpha were checked; every output has fully transparent pixels (sampled transparent area 31.69–77.72%). Source sheets and representative exported wood/stone/sand/wall PNGs visually inspected. Transparent borders are explicitly padded during export.

No in-game compositing, movement, floor-angle or performance acceptance performed. Matching colors and damage scale still need a rendered stage check. Existing code-drawn crater should remain until integration is ready.

