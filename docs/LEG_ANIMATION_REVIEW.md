# Front/rear leg animation audit ? 27 October 2026

Reviewed snapshot: HEAD 62b0daf plus the pre-existing finisher.gd working change; manifest.json records all copied files. Animation source was not edited. Standard motion/contact cases were rendered at a fixed 60 FPS for frame-by-frame inspection, not as a performance benchmark.

## Coverage

146 initial cases: all seven styles, both facing directions, forward/back walking, neutral/forward/back jumps, each mapped leg-led attack and leg-led signature, and each style's down-light/body-punch support-leg action. Boxing has no mapped kicks; its movement/jump/body-hook support was inspected. Six chronological sample images and per-rendered-frame joint data were captured per case (21,900 leg observations). A further 16 close-range cases covered Taekwondo and Karate's grounded kick/technique and body-punch support legs, both directions, at 70 px initial root gap. An independent spin probe tested idle/walk/training-reset after one spinning hook kick. Fresh-start Kickboxing/Bangla checks were added because the spin probe exposed persistent state that contaminated later cases in the original sequential sweep.

This does not certify every authored finisher pose, ragdoll, cross-up, every frame rate or every collision distance. Air-only attack cases were placed in flight to inspect their poses; their first frames include a diagnostic setup transition and are not evidence by themselves of a normal-input jump transition defect. Numeric bend/length outliers are investigation aids, not blanket failures for intentional spin foreshortening or tightly chambered airborne legs.

## Confirmed high-priority bug ? full-turn angle permanently disables planting

Files: scripts/fighter_visual.gd (_update_spin, _is_back_kick/_back_turn, _wants_plant, reset handling).

Focused reproduction on a fresh Taekwondo training scene:
- Before move: IDLE, _spin_angle=0, _plant=1, _wants_plant=true.
- Execute Jumping Spinning Hook Kick and wait until recovery completes: IDLE, _spin_angle=6.28318530717959, _plant=0, _wants_plant=false.
- Walk: WALK, same angle, _plant=0, _wants_plant=false.
- Reset training positions, then wait: IDLE, same angle, _plant=0, _wants_plant=false.

A full turn is visually equivalent to zero. lerp_angle settles to that equivalent representation near TAU; the raw abs(_spin_angle)>0.01 test then treats the fighter as still turning forever. This explains why later movement can lose the carefully implemented foot planting even though the fighter looks normally oriented. The original sequential sweep retained this state after Taekwondo; do not mislabel all subsequent observations as independent style-specific defects.

Fix: use a wrapped/normalized angular difference for orientation gates, and normalize or reset equivalent full turns safely when a turn ends. Do not snap halfway through an intentional spin or erase authored multi-turn motion. Review all raw-angle gates, including _wants_plant. Add an automated regression that a completed spin restores foot planting in idle/walk, after interruption and after training reset, in both directions. Test other spinning attacks and transitions as well.

## Confirmed ? rear foot drags/pops during body punches

The close-range Taekwondo S+J case reproduces the user's elongated rear-leg pose. At a 70 px initial gap, the rear ankle moves approximately 12.01 px in one rendered frame while planting blend is full and that leg is not stepping in either adjacent sample. Mirrored case: approximately 9.20 px. Close-range Karate body punch has approximately 10.48/9.95 px rear-ankle motion. In open-space probes, Karate/Muay Thai body punches produced larger approximately 25/16.6 px candidates.

This is actual joint displacement, not just an afterimage. Inspect foot reach clamping: _ik_leg pulls unreachable feet toward the hip; _plant_feet writes the solved X back into the stored planted-foot position ('a dragged foot stays dragged'). Strong hip/torso changes can therefore move the supposedly planted foot. Also review timed step targets, hip settling and _limit_reach for close attacks. Fix through reachable hip placement, coordinated stepping and smooth weight transfer; do not simply stretch bone lengths or freeze feet beyond their reach.

Evidence: close_taekwondo_1_body_punch_support.png, close_karate_-1_body_punch_support.png, close-leg-samples.json. An ankle may legitimately move slightly during a heel lift; the measured abrupt multi-pixel drift here must be evaluated with toe/forefoot anchoring rather than insisting every shoe pixel be motionless.

## Confirmed geometry concern ? support knee reverses during kick recovery

Grounded Karate High Kick and Low Side Kick recovery show a rear/support knee bend of approximately -28 degrees in the sagittal joint test, with the same result mirrored. These frames occur after the strike, without spin/body rotation or airborne ambiguity. Knee direction needs constrained recovery targets and valid IK handling, not just a more attractive strike pose. Smaller negative-angle candidates also occur in some Kung Fu/Muay Thai recoveries and need visual review.

Do not apply a naive raw angle clamp to every leg animation: fully chambered aerial poses and spinning projections can cross angle-wrap boundaries. Preserve authored kick extension/recoil and use a consistent anatomical/bend convention when choosing targets and solving support legs. Check the chronological Karate high-kick/low-side-kick sheets and the per-frame data, especially recovery ticks around 23?26.

## Foot presentation concern ? shoe rotation is not a stable ground pivot

Shoes are generally constructed perpendicular to the shin and the rear foot's toe direction is selected from a rotating pivot vector. This creates strongly tipped shoes in extended rear-leg poses; the visual contact point can move even when the ankle is constrained. Airborne feet should point according to the technique, while a loaded support foot needs a credible forefoot/toe anchor and heel movement. Separate these cases. Flat soles are not required throughout every heel pivot, but a toe anchor must remain believable and feet must not hover or cut through the floor unintentionally.

## Jump/movement assessment

Normal jumps have coherent rising/apex/falling pose phases, and standard walking alternates feet. They are not universally broken. Neutral and directional jumps share most leg posing, with direction mainly changing torso lean; forward/back travel would benefit from clearer leg/landing choreography as requested in the jump movement task. Some walk frames approach near-straight knees and IK fallbacks permit foot drift. Recheck this only after repairing the persistent-spin gate, so retained state does not hide or exaggerate the underlying quality.

## Required acceptance

1. Repair persistent spin/plant state first, then rerun fresh-scene and post-spin cases separately.
2. For every style and both directions, inspect front and rear legs during forward/back walking, stop/start/reversal, neutral/forward/back jump, takeoff, apex, landing, grounded kicks, jumping kicks and recovery.
3. For support legs, verify knee bend, reachable fixed bone lengths, planted toe/forefoot contact, smooth heel pivot, and an intentional step before changing support. Record leg/side and exact phase for failures.
4. Repeat the Taekwondo S+J/Karate close-range scenario from the user's screenshot and near both walls. Ensure the repair does not break attack range, existing frame data or pushbox separation.
5. Check actual player-triggered air attacks and landing transitions; do not promote diagnostic midair setup artifacts into product bugs.
6. Verify at 30/60/120 rendered FPS and 25/50/100% training speed. The broad audit here used 60 FPS; the other conditions remain acceptance work for the fix.
7. Preserve intentionally airborne kicks, spins and existing style identity. Boxing must remain kick-free; the newly requested Taekwondo alternating-leg L technique is not yet present in this snapshot and requires its own validation when implemented.
8. Run existing movement/control/core suites and add targeted rendered-state regressions for planted-foot restoration after spins and for support-leg continuity. Headless combat success alone does not establish correct legs.

Evidence lives beside this report: leg_review.gd, spin_probe.gd, close_leg_review.gd, chronological PNG sheets, leg-summary.json, leg-samples.json, close-leg-summary.json and close-leg-samples.json. The full raw first sweep contains the persistent-spin state; use the fresh rerun for independent Kickboxing/Bangla observations.

## Fresh-start cross-check completed

An additional 42 rendered scenarios (22 Kickboxing, 20 Bangla Maar) were completed without preceding Taekwondo spins. All 6,300 leg observations had no full-turn orientation exclusion. Kickboxing still shows reversed-bend candidates during grounded low/body roundhouse extension (approximately -20 to -24 degrees in sampled strike frames), so this is not solely inherited spin state. Bangla Maar had no grounded bends below the -12 degree diagnostic threshold in this fresh sample, but its stomach-shot rear foot still moved approximately 9.1 px in one frame while classified as planted. This is evidence of the shared planting/reach problem, not a verdict that every Bangla animation is wrong.

Recommended fix order: full-turn orientation/plant restoration; planted-foot reach/drag; grounded knee direction and recovery targets; support-foot rendering/pivots; then jump-direction and landing polish. Re-run with a fresh scene for each style and in a post-spin sequence to distinguish authored-pose problems from retained visual state.
