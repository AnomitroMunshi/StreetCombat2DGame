# West Bengal v2 — layered artwork handoff

Five PNG deliverables, created with built-in image_gen. Artwork only; game scripts, scenes and integration are untouched. Full prompts: [PROMPTS.md](PROMPTS.md).

| File | Pixels | Contents |
|---|---|---|
| howrah_backdrop.png | 1536 x 1024 | Sky, distant Howrah Bridge/river, plain cream parapet, empty paved street |
| victoria_backdrop.png | 1536 x 1024 | Matching dusk composition with Victoria Memorial/gardens, cream wall and paved street |
| tea_stall.png | 1536 x 1024 | Transparent stall, Bengali sign, bulbs, kettle and counter cups |
| shopfront_rickshaw.png | 1774 x 887 | Transparent sheet: shopfront left, separate cycle rickshaw right |
| breakable_props.png | 1536 x 1024 | Transparent sheet: cups, crate, bench; intact left / broken right |

## Placement and slicing

- Backdrops are exactly 3:2. Scale uniformly by 1.09375 to cover 1680 x 1120 world pixels.
- Measured strongest wall/street edge is y=699 for Howrah (68.26%) and y=698 for Victoria (68.16%). Requested y=696.32 is approximated, not pixel-exact. Both edges are visually level. Set the sprite origin using the measured edge if exact foot alignment is needed.
- With uniform scale 1.09375 and world FLOOR_Y=560, a backdrop top-left y of approximately -204.53 (Howrah) or -203.44 (Victoria) aligns its edge to the feet. Check camera overscan after choosing placement.
- The central body band is plain cream wall, with no railings or props. Streets are empty, with subtle paving seams. Top 12% contains only sky/clouds.
- The two backdrops have matching composition/light/floor alignment but are not pixel-identical lower-half copies; generative edits slightly changed surface texture.
- Stall intended visible object height: about 320 px. Shopfront: about 340 px. Scale by the visible alpha bounds, not full transparent canvas dimensions.
- Shop/rickshaw sheet can be split at x=910; they do not overlap. Scale rickshaw independently to its intended scene size.
- Prop atlas columns split at x=768. Rows: cups y=0..369, crate y=370..674, bench y=675..1023. Use those as initial region bounds, then tighten around alpha. Preserve a shared baseline/scale per pair so breaking does not resize the object.
- Target intact visible heights: cups 60 px, crate 70 px, bench 90 px. These are high-resolution source sprites, not already resized game sprites.
- Keep side pieces outside the central fighting area. Backdrop is one flattened image: independent landmark/sky parallax would require additional separation; the supplied side pieces can already move independently.
- Broken sprites show settled debris. Do not retain the intact sprite beneath them.

## Checks completed

- Viewed all five selected images. Bengali sign visually reads “চায়ের আড্ডা”.
- Both backdrop dimensions and floor-edge rows checked from PNG pixels.
- Alpha checked directly, not inferred from preview: transparent samples are alpha=0. Sampled fully clear pixel proportions: stall 50.11%, shop/rickshaw 44.52%, prop atlas 55.36%. Interior stall opening and central prop gutter also sample alpha=0.
- Cutout previews may show a dark/brown matte in the image viewer; that matte is not an opaque rectangle in the PNG. Alpha edges contain partial transparency; check filtering against the actual backdrop.
- No fighters or foreground obstructions on either street.
- Art review only: no game/editor run, collision changes, prop state implementation or gameplay acceptance performed.

