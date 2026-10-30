# Street Combat workspace instructions

## Arena art and decals

- Inspect the actual rendered floor and its material, grain direction, perspective and palette **before** generating replacement decals. Check `scripts/dojo_stage.gd` for the native dojo and the selected painted backdrop for other arenas.
- Follow the layered `assets/art/backgrounds/west_bengal_v2` approach: background, independent transparent side cutouts, separate intact/broken prop pairs, and damage decals. Do not bake foreground equipment into the only background image when it needs independent placement or state changes.
- Keep the middle fighting lane readable. Floor contact stays at world Y=560; collision bounds stay X=90..1190. Measure generated floor-edge rows and record them in layout metadata; do not trust a prompt's requested row. Check full camera overscan.
- Inspect real PNG alpha, including interior gaps. A preview's dark matte does not establish transparency. Preserve scale and baseline between intact and broken props, and check source row/column cuts before slicing.
- Decals must match the selected surface. Wooden dents are shallow grain damage, rubber shows abrasion/compression, and stone/concrete have restrained material-appropriate fractures. Floor damage must remain on the floor; wall damage clips to the actual boundary surface.
- After activating a replacement, remove superseded version directories only after checking runtime references. A `_v1` suffix alone does not mean unused: West Bengal's active decals and newly used material sets remain valid. Do not keep silent fallbacks to obsolete art.
- Preserve source prompts, source atlases and mechanical export metadata for active assets. Do not regenerate or replace unrelated artwork.

## Shared workspace

- Another assistant may use the same checkout. Check the current branch before commits. If it changes unexpectedly, move this task into an isolated worktree and preserve other work; do not merge unrelated branch changes into the task.
- Preserve unrelated dirty files and untracked art. Cleanup requires checking exact resolved paths and actual references, even when the user requests old-version removal.
- Validate stage selection, player/rival independence, training behavior, materials, wall/floor alignment, prop state changes and rendered camera coverage after arena changes.
