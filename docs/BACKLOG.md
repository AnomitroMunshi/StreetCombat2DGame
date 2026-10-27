# Backlog

Findings from the playtest captures reviewed on 2026-10-26 (7 matches, one per style).
Timestamps are `clip @ seconds`.

## High priority: readability and bugs

- [x] **HUD callouts overlap.** *Fixed in polish batch 1: fixed rows per side (style/HP, READY, combo, 3 callout slots); training lanes move inward.* COUNTER, N HITS, DIZZY!, move names, SIGNATURE READY and "... READY" all draw in the same slot under each health bar (Bangla vs Muay Thai @31.5, Kickbox vs Karate @22–24, Muay Thai vs TKD @21–29). The combo text also covers the style name. Stack them in rows or queue them, and give READY a fixed row.
- [ ] **Fighters overlap at close range.** *Still open (handoff item 3, staging half): leg stretch fixed in batch 1, silhouette overlap at 60 px spacing not yet addressed.* Bodies interpenetrate by half a torso or more in most exchanges (Boxing vs Bangla @11.5, 14.5, 20–23.5). Widen the push-box and separate the fighters on hit.
- [x] **Speech bubbles don't follow the speaker.** *Fixed in polish batch 2: anchored to the drawn head.* The bubble stays where it was spoken when the fighter is knocked down (Bangla vs Muay Thai @17, 29.5; the knocked-out line in Karate vs Bangla @28.5–30).
- [x] **Style select shows only 5 of 7 tabs.** *Fixed in polish batch 2: 4 + 3 grid, all visible.* Kickboxing and Bangla Maar are hidden behind a horizontal scroll. Fit all 7 (two rows or narrower tabs).
- [x] **Winner off-screen after a finisher.** *Fixed in polish batch 1: explicit result camera; checked centre and both walls.* In Karate vs Bangla @30.5–32.5 the winner is cut off at the right edge, so the celebration isn't seen. Frame both fighters on the result screen.
- [x] **The win title covers the winner.** *Fixed in polish batch 1: headline in the upper third; no READY/hint prompts after K.O.* "PLAYER/RIVAL WINS" sits over the winner's body (Muay Thai vs TKD @35.5, TKD vs Kickbox @22).

## Medium priority: visuals

- [x] **Rival Karate and Taekwondo are too dark.** *Polish batch 3: dark gi/dobok is slate (0.27 luminance), belt and folds read against the wall.* Black gi/dobok with dark skin on a dark background, so they're only readable by the outline.
- [x] **Rival rim glow is always on** *Polish batch 3: thinner (5/2.6 px), ~1/3 strength at rest, 0.7 in action.* (`rim_glow`, fighter_visual.gd). It hides costume detail and competes with hit flashes. Dim it at idle, make it thinner, or use a floor marker instead.
- [x] **Taekwondo and Karate look the same** *Polish batch 3: dobok V-neck ending mid-chest plus a collar band visible side-on above the guard; karate keeps crossed lapels.* (white uniform with a black belt). Give the dobok its V-neck trim or a different colour.
- [ ] **The dojo banner shows through the empty part of the health bar.** Make the bar background opaque.
- [ ] **Fighters are small on screen** (about a third of the window height). Zoom the camera in more during neutral play.

## Gameplay feel

- [ ] **Knockdowns are too frequent.** There were 3 in 15 s in TKD vs Kickbox, and that match ended in 23 s. Raise the threshold or require a combo.
- [~] **Speech lines repeat** *Polish batch 2: per-line 5 s cooldown for everyday lines; quotes may be a list of variants (rotated). Variant lines still to be written.* within seconds (শালা শুয়োর!, উফ্!). Add a cooldown per line and rotate through several lines.
- [ ] **Bangla Maar's win quote** is a censored swear on every win. Consider a cleaner line or a rotation.
- [x] **The SIGNATURE READY prompt is easy to miss.** *Already pulses (handoff review); now on its own row.* Pulse it or show a key icon by the Focus bar.

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

- [x] **LEG-01 / High: full-turn rotation leaves foot planting disabled.** *Fixed in polish batch 1: the spin settles from a wrapped angle; planting returns idle/walk, both directions.* A fresh Taekwondo Jumping Spinning Hook Kick ends with `_spin_angle = TAU`, `_plant = 0`, and `_wants_plant() = false`. This persists during idle, walking and training-position reset. `_update_spin()` uses `lerp_angle`, while `_wants_plant()` checks the raw absolute angle. Use a wrapped angular difference or safe end-of-turn normalization; preserve intentional multi-turn motion. Acceptance: planting returns after completed/interrupted spins, during idle/walk and after training reset, facing either direction. Fix this before evaluating subsequent poses because the retained state contaminates later movement.

- [~] **LEG-02 / High: supposedly planted rear feet move abruptly during body punches.** *Improved in polish batch 1: travel is read from the fighter root (hip drive no longer triggers walking steps), strikes sink the hips up to 18 px, and a foot out of reach takes one minimal follow-up step. TKD S+J: 0 locked frames (master 18). Rear-hand crosses 3-4 frames and Karate reverse punch 7-9 frames (master 15) still reach full extension briefly. Re-verify against the 12 px single-frame ankle motion measure.* Close-range Taekwondo S+J reproduces roughly 12 px rear-ankle motion in one 60 FPS rendered frame (about 9 px mirrored); Karate also reproduces roughly 10 px. The foot is classified as planted and not stepping in both adjacent samples. Inspect `_ik_leg()` reach clamping, `_plant_feet()` writing clamped X back into the anchor, hip settling and contact-aware pose shortening. Acceptance: use reachable hip placement or deliberate stepping; preserve forefoot contact without stretching bones, foot snapping or changing attack damage/range unintentionally. Recheck the supplied Taekwondo-versus-Karate screenshot scenario, both directions and both walls.

- [x] **LEG-03 / High: grounded kick poses can reverse the knee bend.** *Polish batch 3: grounded knees clamped to at most 4 deg backward in FK (airborne, tucked and down bodies untouched). Karate high/low side kick 18/28 deg -> 4, Kickboxing roundhouses 24 -> 4, both directions.* Karate High Kick and Low Side Kick recovery show approximately 28 degrees of reversed rear/support-knee bend in both directions. Fresh-start Kickboxing low/body roundhouse strike samples also flag reversed bends; this persists independently of LEG-01. Correct phase-specific pose targets and support-leg IK conventions. Acceptance: valid knee direction through chamber, extension, recoil and return to guard. Distinguish real grounded hyperextension from intentional airborne folding, angle wrapping and spin foreshortening; do not apply a blanket raw-angle clamp.

- [ ] **LEG-04 / Medium: support-foot rendering lacks a reliable ground pivot.** Feet are largely oriented perpendicular to the shin, so long rear-leg poses can tip the whole shoe instead of showing a believable heel lift over a planted forefoot. Coordinate toe/forefoot anchors, heel movement and support-leg weight transfer; keep airborne foot pointing separate. Acceptance: no unintended hovering, floor penetration or abrupt shoe rotation during walking, punches and grounded kicks, while preserving natural pivots.

- [ ] **LEG-05 / Verification: rerun fresh-scene and post-spin leg checks separately.** The audit covered 146 broad cases, 16 close-range cases and 42 fresh-start repeats across all seven styles/both directions. Most walking and jump phases work; not every pose is defective. After LEG-01 through LEG-04, compare both legs during forward/back walking, neutral/forward/back jumps, kick recovery and landing at 30/60/120 render FPS and 25/50/100% training speed. Include actual input-driven air attacks and the new Taekwondo L double kick once implemented. Do not treat diagnostic midair setup transitions or headless combat passes as proof of animation quality.


## Backgrounds and breakable props - design review 2026-10-27

This section contains stage proposals and implementation requirements, not claims that the proposed features already exist. Current-source observations: the arena is a single procedural training hall in `main.gd._draw()`, with repeated wall/window grids, a central banner, plank floor and fixed edge pillars. `FxLayer` already supplies cracks, floor damage, dust, splinters, capped debris and pillar jolts. The pillars are still drawn intact beneath damage decals; there is no dedicated independently breakable prop/state system. Current destruction is presentation-only and does not change floor/wall collision. Preserve that readable, predictable fighting space for the first prop pass.

### Recommended stage concepts

| Concept | Visual direction | Breakable/reactive props | Material response |
|---|---|---|---|
| Training dojo - improve first | Warm side lighting, softer rear-wall detail, clear centre fighting strip; restrained courtyard view beyond windows | Board stack, clay practice pot, wooden bench, paper screen; hanging bag sways | Boards split into slats; pottery cracks/shards; bench buckles; paper tears; bag swings without exploding |
| Para tea-stall courtyard - distinctive second stage | Faded cream/teal plaster, dusk light, overhead wires and distant homes; keep signs behind the fighters | Earthen cups, wooden produce crates, lightweight stool, small signboard, sheet-metal panel | Clay chips; crates collapse; stool tips/breaks; sign falls; metal dents/rattles instead of stone-like shattering |
| Rainy rooftop | Muted blue-grey skyline, warm distant windows, rain concentrated behind the fighting plane | Water jars, timber crates, dish bracket, clothesline clips and parapet facing | Water splash plus pottery; wood splinters; bracket bends; fabric flutters; parapet chips while structural bounds remain |
| Old warehouse/loading yard | Desaturated brick, high window shafts and distant machinery silhouettes | Pallets, packing crates, ceramic insulators, loose sheet metal; hanging lamp sways | Splintered timber, brick chips and metallic vibration; avoid explosive barrels as the default mechanic |
| Bamboo courtyard | Layered bamboo silhouettes, pale stone floor, restrained leaf motion and open sky | Bamboo fence panels, practice-board rack, clay lantern housing, hanging fabric | Fibres/slivers, clay shards and drifting leaves; dense dust only on major impacts |

Stages are available independently of martial-art selection; do not lock an art to a stereotyped location. The tea-stall courtyard is an original stage identity suggestion, not a requirement to alter Bangla Maar gameplay.

### Tasks and acceptance

- [ ] **BG-01 / High design priority: improve arena readability and depth before adding clutter.** The current repetitive rear-wall grid and dark lower wall give limited depth and compete with some costumes. Separate distant background, rear-wall/midground props, fighting floor and restrained corner foreground. Lower contrast/detail immediately behind head/torso height; reserve strongest silhouettes and saturation for fighters/contact. Use the camera's full existing zoom/shake/result extents when sizing layers so edges never reveal empty space. Acceptance: all seven styles, both costume roles and both corners remain readable; foreground elements never hide feet or attack contact. Subtle parallax must not move the actual floor line or cause perceived foot sliding.

- [ ] **BG-02 / First implementation batch: pilot three prop types in the existing dojo.** Start with one clay pot, one board/crate stack and one wooden bench or paper screen. Put them at deliberate stage-edge/rear-plane anchors; keep the main fighting lane clear. Make the bag/banner reactive with sway rather than treating everything as shatterable. Acceptance: the three prop types each have a distinct intact/damaged/broken look and material response; evaluate actual captures before multiplying stages. Do not build all five proposed stages in the first batch.

- [ ] **BG-03 / High: implement independent prop state, not just impact decals.** A small prop receiver needs a stable ID, placement/depth, material, intact/damaged/broken state, damage threshold/health as needed, and appropriate VFX/audio profile. Destroy or replace visible geometry when broken; do not keep the complete object under a crack overlay. Keep settled broken geometry independent of transient effect/decal FIFO eviction so a broken bench does not visually repair itself when the effect cap is reached. Acceptance: repeat impacts cannot re-break/reward/replay the same destroyed prop, and it stays consistently broken until the defined match/training reset.

- [ ] **BG-04 / High: wire breakage to real local impacts with once-per-hit registration.** Drive stage-edge props from actual body-wall impacts or explicitly authored finisher events with direction, impact position and strength. If normal attacks can damage props, validate the prop's interaction plane/range and a unique swing/sub-hit token so three active frames do not break it three times. Do not break distant background props because an unrelated hit occurred elsewhere. Light hits may wobble/chip; strong impacts may fracture/break. Acceptance: one valid event causes one state transition/emission; blocked/whiffed fighter attacks and multi-hit sequences follow an explicit consistent rule; left/right behavior mirrors.

- [ ] **BG-05 / High: preserve fair collision and existing finishers in the first pass.** Keep arena bounds, floor height, pushboxes, jump/roll routes and AI navigation unchanged. Detached fragments are cosmetic and cannot snag or damage fighters. A breakable railing/panel must leave a credible permanent boundary/post; a decorative floor crater should not imply an open pit that fighters inexplicably stand over. Existing Air Smash/Wall Crush must work at both edges. True holes, falling off rooftops, projectile debris or prop damage to fighters are separate gameplay features requiring design/balance work, not implicit parts of this request.

- [ ] **BG-06 / Medium: make destruction material-aware.** Extend/reuse the existing capped effects: wood gives long slivers, clay gives short angular shards, metal dents/bends and rings, paper tears/flutters, water splashes. Floor marks must match the selected floor (wood splits with grain; concrete chips rather than exposing planks). Give secondary prop debris a lower brightness/priority than the fighter impact and stagger dust after contact. Acceptance: material is recognizable with no HUD label; broken objects, particles, floor marks and sound agree; no generic bright explosion on every prop.

- [ ] **BG-07 / Medium: stage data and lifecycle.** After the dojo pilot is approved, move stage identity/palette/layers/material profiles/prop anchors behind a small stage definition and renderer/controller, reusing the project's data-driven approach. Avoid expanding a giant switch in `main.gd` for every stage. Expose stage preview/selection separately from style, lock it during the match, and keep the dojo as a stable training default. Acceptance: match restart and training reset restore all prop state, particles and ambient motion without stale callbacks or duplicate event connections. Define whether training R resets props; make the behavior clear in the UI/docs.

- [ ] **BG-08 / Medium: bound ambience, debris and sounds.** Reuse existing `MAX_EFFECTS`, `MAX_DEBRIS` and decal budgets; set explicit per-prop fragment limits and keep primary hit feedback higher priority than leaves/rain/dust. Sleep/retire settled transient fragments; draw persistent broken silhouettes cheaply. Add low-motion/reduced-effects behavior for rain, sway and parallax. Acceptance: repeatedly breaking/resetting props does not grow allocations, audio voices, signal connections or stored decals; benchmark worst-case destruction in normal and slow motion. Interpolate moving VFX as required by the existing smoothness task.

- [ ] **BG-09 / Verification: stage compatibility matrix.** For each implemented stage, check every style, light/dark rivals, jumps/kicks/rolls, both walls, every environmental finisher, result framing and supported window sizes. Capture intact, damaged and broken states. Test one-time breakage, capped repeated hits, multi-hit registration, pause/resume, training reset and rematch. Validate the exported build as well as the editor. Require actual visual review; headless logic tests alone cannot certify depth, lighting or occlusion.

Implementation order: current-dojo composition -> three material/prop pilots -> reset/event/collision verification -> one new stage (recommended tea-stall courtyard) -> expand only after readability and performance hold. This is a new environment-art/features backlog; do not interrupt the currently assigned combat/leg fixes to implement every proposal at once.


## User-requested West Bengal stage - Bangla Maar only

This explicit request overrides the earlier suggestion that every proposed stage be independent of martial-art selection, specifically for these West Bengal variants. Other stages can retain their existing selection rules. This is a requested feature, not implemented behavior.

- [ ] **WB-01 / Requested: Bangla Maar-exclusive Kolkata street stage.** Offer a West Bengal street setting only when the PLAYER selects Bangla Maar. A Bangla Maar rival alone does not unlock or force it. Choose one landmark backdrop initially: Howrah Bridge OR Victoria Memorial. Keep the fight on a street/courtyard in the foreground, with the landmark recognizably in the distance; do not place the combat on the bridge deck or inside the memorial. An optional second backdrop variant can follow after the first is reviewed.

- [ ] **WB-02 / Visual direction: recognizable local street character.** Use a Bengali tea-stall frontage, hand-painted Bengali shop boards, earthen tea cups, wooden produce crates, a shuttered storefront, hanging wires, a cycle/rickshaw silhouette or parked street vehicle, and distant pedestrian silhouettes. Keep foreground dressing selective and the central fighting strip clear. Howrah variant: a stylized truss silhouette beyond a river/ghat-side street, with restrained haze and warm evening light. Victoria variant: a stylized white domed silhouette beyond trees and a boundary/approach road, with warm late-afternoon or dusk lighting. These are creative compositions, not surveyed reconstructions; review landmark proportion/reference before final art. Match the existing procedural graphic style and preserve contrast for both fighters.

- [ ] **WB-03 / Props: break local street dressing, retain landmark scenery.** Reuse the small prop system from BG-02 through BG-06: clay cups/pots shatter, wooden crates split, a lightweight stool tips/breaks, a shop sign drops, and a small metal panel dents/rattles. A hanging cloth or awning can flutter. Keep Howrah Bridge/Victoria Memorial as distant scenery with no breakable receivers, and keep crowd/traffic outside the fighting plane. No new traffic hazards, falling-off-stage rules or destructible landmark system is implied. Material response, one-time breakage and match/training resets follow the shared prop rules.

- [ ] **WB-04 / Eligibility and selection lifecycle.** When the player's style is Bangla Maar, expose the West Bengal street option (Howrah/Victoria variant if both exist), or use a clearly indicated Bangla Maar default if that is the chosen UI. When switching away from Bangla Maar before the match, remove/disable the exclusive option and fall back to a valid ordinary stage; do not leave a stale selected stage. Lock the chosen stage at match start; rematch preserves the eligible choice, while CHANGE STYLE revalidates it. Never change stages mid-fight. Preserve a neutral dojo training option; if the exclusive street is available in training, apply the same player-style eligibility rule.

- [ ] **WB-05 / Acceptance and scope.** Confirm player Bangla Maar unlocks the street, other player styles cannot choose it, rival-only Bangla Maar does not unlock it, and style switching/rematch/reload cannot bypass eligibility. Check legibility of Bengali signs using the bundled-font task, both rivals, both corners, camera zoom/shake and result framing. Props must not block feet, low kicks or the visible landmark silhouette. Validate wall/floor finishers against material-appropriate stage anchors with the same collision bounds. Build and review one landmark variant first; keep this separate from the in-progress combat fixes.
