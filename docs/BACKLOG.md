# Backlog

Findings from the playtest captures reviewed on 2026-10-26 (7 matches, one per style).
Timestamps are `clip @ seconds`.

## High priority: readability and bugs

- [ ] **HUD callouts overlap.** COUNTER, N HITS, DIZZY!, move names, SIGNATURE READY and "... READY" all draw in the same slot under each health bar (Bangla vs Muay Thai @31.5, Kickbox vs Karate @22–24, Muay Thai vs TKD @21–29). The combo text also covers the style name. Stack them in rows or queue them, and give READY a fixed row.
- [ ] **Fighters overlap at close range.** Bodies interpenetrate by half a torso or more in most exchanges (Boxing vs Bangla @11.5, 14.5, 20–23.5). Widen the push-box and separate the fighters on hit.
- [ ] **Speech bubbles don't follow the speaker.** The bubble stays where it was spoken when the fighter is knocked down (Bangla vs Muay Thai @17, 29.5; the knocked-out line in Karate vs Bangla @28.5–30).
- [ ] **Style select shows only 5 of 7 tabs.** Kickboxing and Bangla Maar are hidden behind a horizontal scroll. Fit all 7 (two rows or narrower tabs).
- [ ] **Winner off-screen after a finisher.** In Karate vs Bangla @30.5–32.5 the winner is cut off at the right edge, so the celebration isn't seen. Frame both fighters on the result screen.
- [ ] **The win title covers the winner.** "PLAYER/RIVAL WINS" sits over the winner's body (Muay Thai vs TKD @35.5, TKD vs Kickbox @22).

## Medium priority: visuals

- [ ] **Rival Karate and Taekwondo are too dark.** Black gi/dobok with dark skin on a dark background, so they're only readable by the outline.
- [ ] **Rival rim glow is always on** (`rim_glow`, fighter_visual.gd). It hides costume detail and competes with hit flashes. Dim it at idle, make it thinner, or use a floor marker instead.
- [ ] **Taekwondo and Karate look the same** (white uniform with a black belt). Give the dobok its V-neck trim or a different colour.
- [ ] **The dojo banner shows through the empty part of the health bar.** Make the bar background opaque.
- [ ] **Fighters are small on screen** (about a third of the window height). Zoom the camera in more during neutral play.

## Gameplay feel

- [ ] **Knockdowns are too frequent.** There were 3 in 15 s in TKD vs Kickbox, and that match ended in 23 s. Raise the threshold or require a combo.
- [ ] **Speech lines repeat** within seconds (শালা শুয়োর!, উফ্!). Add a cooldown per line and rotate through several lines.
- [ ] **Bangla Maar's win quote** is a censored swear on every win. Consider a cleaner line or a rotation.
- [ ] **The SIGNATURE READY prompt is easy to miss.** Pulse it or show a key icon by the Focus bar.

## Discussed earlier, not yet done

- [ ] **Bangla Maar balance.** It wins about 21% of AI-vs-AI matches because of the spec's lighter damage. Decide whether to buff it.
- [ ] **Overall style balance spread.** From Kung Fu at 67% down to Boxing at 38%; the target is roughly 45–55%.
- [ ] **Bundle a Bengali font.** Speech currently needs Nirmala UI or Vrinda installed. A free, openly licensed font (e.g. Noto Sans Bengali, OFL) would fix this, but it needs your approval before download.
- [ ] **Rounds.** Single round only: no round timer, no best-of-3.
- [ ] **Hurtboxes are fixed rectangles** and don't follow extended limbs.
- [ ] **AI difficulty select.** Difficulty is only adjustable through exported values on `EnemyAI`; there's no menu option.
- [ ] **Throws and grappling.** Design note only (`docs/V0.3_PLAN.md` §4). Parked on purpose; the Bangla Maar spec said no grappling yet.
- [ ] **Boxing quality checklist** (11 items from the Boxing pass) has never been checked off by a human playtest.
- [ ] Harmless "2 ObjectDB instances leaked" warning on exit (looping music held by the audio server).

## Audio and performance

- [ ] **Finisher audio clips.** It peaks at 0 dB in Kung Fu vs Kickbox @25–30 (Hundred Palms) and also in Muay Thai vs TKD. Add a limiter or lower the gain of stacked finisher sounds.
- [ ] **The captures average about 36 fps against a 60 fps timebase.** Check the in-game FPS during finishers to rule out frame drops.


## Follow-up leg audit - 2026-10-27

Newly confirmed findings from the rendered leg audit; details and evidence are in [LEG_ANIMATION_REVIEW.md](LEG_ANIMATION_REVIEW.md). Coordinate with Claude's in-progress handoff work rather than implementing duplicate fixes. Results apply to the audited snapshot (62b0daf plus the then-existing finisher change); reproduce on the working branch before changing code or marking an item resolved. Future review findings go here; leave the active handoff stable.

- [ ] **LEG-01 / High: full-turn rotation leaves foot planting disabled.** A fresh Taekwondo Jumping Spinning Hook Kick ends with `_spin_angle = TAU`, `_plant = 0`, and `_wants_plant() = false`. This persists during idle, walking and training-position reset. `_update_spin()` uses `lerp_angle`, while `_wants_plant()` checks the raw absolute angle. Use a wrapped angular difference or safe end-of-turn normalization; preserve intentional multi-turn motion. Acceptance: planting returns after completed/interrupted spins, during idle/walk and after training reset, facing either direction. Fix this before evaluating subsequent poses because the retained state contaminates later movement.

- [ ] **LEG-02 / High: supposedly planted rear feet move abruptly during body punches.** Close-range Taekwondo S+J reproduces roughly 12 px rear-ankle motion in one 60 FPS rendered frame (about 9 px mirrored); Karate also reproduces roughly 10 px. The foot is classified as planted and not stepping in both adjacent samples. Inspect `_ik_leg()` reach clamping, `_plant_feet()` writing clamped X back into the anchor, hip settling and contact-aware pose shortening. Acceptance: use reachable hip placement or deliberate stepping; preserve forefoot contact without stretching bones, foot snapping or changing attack damage/range unintentionally. Recheck the supplied Taekwondo-versus-Karate screenshot scenario, both directions and both walls.

- [ ] **LEG-03 / High: grounded kick poses can reverse the knee bend.** Karate High Kick and Low Side Kick recovery show approximately 28 degrees of reversed rear/support-knee bend in both directions. Fresh-start Kickboxing low/body roundhouse strike samples also flag reversed bends; this persists independently of LEG-01. Correct phase-specific pose targets and support-leg IK conventions. Acceptance: valid knee direction through chamber, extension, recoil and return to guard. Distinguish real grounded hyperextension from intentional airborne folding, angle wrapping and spin foreshortening; do not apply a blanket raw-angle clamp.

- [ ] **LEG-04 / Medium: support-foot rendering lacks a reliable ground pivot.** Feet are largely oriented perpendicular to the shin, so long rear-leg poses can tip the whole shoe instead of showing a believable heel lift over a planted forefoot. Coordinate toe/forefoot anchors, heel movement and support-leg weight transfer; keep airborne foot pointing separate. Acceptance: no unintended hovering, floor penetration or abrupt shoe rotation during walking, punches and grounded kicks, while preserving natural pivots.

- [ ] **LEG-05 / Verification: rerun fresh-scene and post-spin leg checks separately.** The audit covered 146 broad cases, 16 close-range cases and 42 fresh-start repeats across all seven styles/both directions. Most walking and jump phases work; not every pose is defective. After LEG-01 through LEG-04, compare both legs during forward/back walking, neutral/forward/back jumps, kick recovery and landing at 30/60/120 render FPS and 25/50/100% training speed. Include actual input-driven air attacks and the new Taekwondo L double kick once implemented. Do not treat diagnostic midair setup transitions or headless combat passes as proof of animation quality.
