# West Bengal audience animation v2 — use this revision

Replaces the overly subtle animation_v1 first pass after feedback that mainly the woman moved.

Three crowds, four keyframes each:
- maar_sala: both outer men pump fists, holder raises/tilts sign, woman claps.
- jio_pagla: yellow-shirt man pumps fist, holder raises/tilts sign, man claps, sari-clad caller switches from calling to raised-arm cheering.
- khela_hobe: outer men pump fists, holder raises/tilts sign, woman claps.

Exact slogans visually checked in all generated frames: “maar sala”, “Jio pagla”, “khela hobe!”.

## Files and playback

- Open preview.html for actual looping playback, pause, frame stepping and speed control.
- *_animated.png: true transparent animated PNG (APNG), four frames, infinite loop. For viewing in an APNG-capable browser; Godot may import only its first frame.
- *_sheet.png: ordinary transparent 2048 x 512 PNG, four 512 x 512 frames left-to-right.
- Each group folder contains frame_00.png through frame_03.png.
- manifest.json gives order, timing, dimensions and anchor. Play 0,1,2,3 then repeat. Loop lengths are 880, 940 and 1000 ms to avoid synchronized groups.
- Foot anchor: (256,480) in a 512 x 512 frame. Sprite2D hframes=4, vframes=1 if using sheets. Do not animate by sliding the entire crowd.
- _sources/ retains the full generated 2x2 artwork. export_frames.ps1 slices and registers it with one fixed scale per group, centering from the foot region and aligning the collective baseline. pack_apng.cjs packages the exported PNG streams into animated PNGs without repainting them.
- Built-in image_gen produced all artwork; full prompts in PROMPTS.md.

## Placement and limits

Use on rear planes / sides of the West Bengal stage, behind fighters. Keep signs and bodies out of the central contact/readability band. Start around 100–150 px total group height including placards and inspect sign legibility. Preserve aspect ratio.

This is four-frame painted sprite animation, not a skeletal rig or smoothly interpolated animation. Collective floor baseline is normalized; individual foot placement, faces and clothing retain some generation drift. Do not claim perfectly planted individual feet. Review small-size playback in-game before acceptance. All people have deliberately changed upper-body poses in v2.

No game scripts, scenes, crowd behavior or stage routing changed.

