# Current master build review - 2026-10-27

Reviewed remote `origin/master` and local HEAD at `dcc55f86da829dc3845f39d861a46c43487c6451`. They matched after fetch. Uncommitted source changes in the live workspace were excluded. All game execution used an isolated Git archive in the system temporary directory. No game code was changed by this review.

## Assessment

A playable prototype with a clear hook, improving animation and a substantial combat foundation. It is ready for a small external playtest; it does not yet look like a finished commercial fighting game. The strongest reasons to try it are the seven different styles, Bangla Maar's identity, and dramatic knockdowns/finishers. Whether players return is unproven. More styles alone will not answer that question.

This assessment combines rendered gameplay captures, automated keyboard-action sequences, source inspection and regression tests. It is not a human controller-in-hand session, an audio listening review, a measured input-latency test, or evidence of market demand. No player interest or retention statistics were collected.

## What is demonstrably better

- All seven style cards are visible in the 4 + 3 grid. Karate and Taekwondo have different collar treatments. The selection panel supports scrollable detail, although it still presents a lot of text. [Selection capture](reviews/2026-10-27-master-dcc55f8/frame_0100.png).
- The sampled result screen places its headline above the winner and keeps both fighters visible. This earlier presentation defect should not be reported as unchanged. [Result capture](reviews/2026-10-27-master-dcc55f8/frame_1400.png).
- Spin settling now wraps angles before returning to neutral, and the planting predicate also uses the wrapped angle. The old raw full-turn lockout is addressed in code.
- Effects now interpolate their stored previous/current positions and age between simulation ticks. The old claim that effects have no interpolation is outdated.
- The jump regression passes in both directions: neutral apex about 100 px, forward travel about 130 px, backward about 93 px. Reversal slows momentum rather than snapping the jump around; the tested jump-in attacks connect. This is improved control logic, not proof that every leap animation is finished.
- Taekwondo L's dedicated regression passes. A separate full-main training integration check at 70, 80, 90, 100 and 110 px, both facings, produced exactly 5 + 9 damage in every fresh stationary-target case. One mixed-showcase whiff observation was not reproduced in that controlled test and is not reported as a confirmed defect.
- Fourteen close-range Karate/Taekwondo animation cases produced no knee-bend samples below the audit's -12 degree threshold. The earlier pronounced grounded reverse-knee problem did not recur in this sample. [Karate kick sequence](reviews/2026-10-27-master-dcc55f8/close_karate_1_high_kick.png).

## Fix priorities

### 1. Give defensive choices a meaningful tradeoff

Confirmed guard-rule concern: `Fighter.receive_hit()` uses `not attack.low or crouch_held`. Crouching guard therefore accepts ordinary low, body, high and downward-labelled attacks; standing guard loses to the low. A direct rule probe confirmed low roundhouse, body roundhouse, high kick, axe kick and flying side kick are all blocked while crouching. Bangla's hammer breaks either guard. The probe isolates guard rules and does not imply every high hitbox intersects a crouching hurtbox in live play.

This creates a plausible dominant defensive habit, not an unbeatable defense: posture pressure, guard breaks and attacks from behind still matter. Decide an explicit guard matrix before adjusting damage. A reasonable direction is low requires low guard; mid blocks either way; selected clearly telegraphed overheads beat low guard; high attacks may be ducked according to their hitboxes. Do not silently make every jumping attack an overhead. Teach the rule and give the AI the same information. Validate each category against standing/crouching guard, parry, cross-ups and posture break.

### 2. Teach the first useful fight, then expose the full moveset

The current opening is a large style-details panel, followed by another start screen and the walk-in/countdown. The control legend is one long, small line. A new player must discover movement, high/low modifiers, guard/parry, double-tap evasion, the Space attack chord and Focus largely from text. Training is useful as a laboratory, but it does not guide a beginner through those mechanics.

Add a short optional guided lesson: move into range, land a simple strike, block an attack, block low, perform a two-move sequence, use Focus. Provide an obvious skip/replay route. Keep detailed frame data in training. Add a selectable beginner AI preset using the existing AI parameters; the stars on style cards describe style difficulty, not opponent difficulty. Add key remapping and controller support before a wider release. Track first-clean-hit time and whether testers can explain why they were hit; do not infer accessibility from test passes.

### 3. Finish physical contact and recovery consistency

The leg work is substantially improved. In the repeated close-range audit, Taekwondo body-punch support-foot motion fell to roughly 0.6 px per sampled 60 FPS frame, versus the earlier approximately 9-12 px report. Karate body-punch support motion remained approximately 3.1 px, and its sampled grounded kicks approximately 2.4-2.6 px. These are maxima under the audit's planted/non-stepping filter, not proof that every pivot should be motionless. [Taekwondo body-punch sequence](reviews/2026-10-27-master-dcc55f8/close_taekwondo_1_body_punch_support.png).

Remaining candidate: Taekwondo high-kick startup has about 7.5 px of segment-length deviation against the nominal 44 px limb segment, about 17%, during pose/plant blending. Sampled Karate grounded kicks show roughly 3.7-4.9 px. Preserve bone lengths through the final blend/IK solve, then tune reachable hip paths and deliberate support steps. Do not restore reversed knees to hide shortening. Review full-speed anticipation, contact and recovery before rejecting intentional stylization.

Close exchanges still merge limbs and torsos into a crowded silhouette. Prioritize spacing, drawing order, hand/foot contact and recoil before increasing effects. [Training contact capture](reviews/2026-10-27-master-dcc55f8/frame_2360.png).

The finisher-contact regression has two failures: left-facing Kickboxing Last Combination and Knockout Rhythm each measure 6.1 px against a 6 px limit. This is a small boundary/alignment failure, not a large visible miss. Fix or explain the geometric tolerance with evidence; do not simply raise it to make the test green. Preserve the considerable improvement in the other style finishers. The existing style-specific air/wall finisher and Karate flying side-kick requests remain pending design work.

### 4. Make the simple art direction intentional and cohesive

The repeated brown/grey wall grid, sparse floor, minimally featured faces and persistent red rival contour remain the largest first-impression limitations. Simplicity can work; a stronger palette, silhouette, lighting hierarchy and coherent costume/face detail matter more than adding texture everywhere. The rim was reduced, but it is still a prominent red contour in action. It should support character readability without competing with hit confirmation.

Polish one dojo stage and one representative matchup first. Use restrained depth/ambient movement, clear feet-to-floor shadows and quieter background detail behind the action. Continue the already documented stage/prop plan after the basic presentation is approved. Keep the Bangla-only West Bengal eligibility rule. More particles or another style will not resolve the current visual identity by themselves.

### 5. Integrate the supplied music and expose essential settings

The MP3 music files exist in master, but `GameAudio` still synthesizes one 140 BPM loop. No code selects the supplied menu/style tracks. The requested enjoyable per-style soundtrack cannot yet be assessed as a feature of this build. Implement the existing music backlog, with distinct menu/style selection, controlled transitions and independent volume settings. Retain original files and use game-ready loops as planned. Countdown/KO voice requests also remain to be integrated.

This review ran with the Dummy audio driver for repeatable automated execution; it does not make a listening-quality claim. Perform a real listening pass once the intended soundtrack is wired up.

### 6. Build reasons to learn and rematch

Master currently offers single-round player-versus-AI matches and training. Best-of-three/timer and selectable AI difficulty are already backlog items. Finish the core polish, then provide a small coherent repeat-play loop: a clear win/loss/rematch flow and a short style ladder or meaningful challenge goals. Pick one modest mode first rather than expanding multiple systems at once. No fresh all-style balance simulation was performed; older win-rate figures in the backlog are historical and must be remeasured against the final tuning.

## Validation and performance

Godot 4.7.2 import succeeded. All 15 checked-in `test_*.gd` scripts ran against the isolated master copy with `--headless --fixed-fps 60`: 14 passed, and `test_finisher_contact.gd` failed the two small left-facing Kickboxing contact checks above. Core, controls, input, movement, jump, stun, styles, Bangla, double kick, training, flow, match, AI defense and AI finisher scripts passed. Passing automated scripts does not establish enjoyable timing or presentation.

A separate rendered training sparring sample at a 60 FPS cap on an AMD Radeon RX 6600 XT collected 779 intervals after warmup: median 16.662 ms, p95 16.998 ms, maximum 19.349 ms, mean approximately 60 FPS, and zero intervals over 33.34 ms. Capture-to-disk was disabled for this sample, the Dummy audio driver was used, and the run was short. This supports good pacing on this desktop in the sampled scenario; it says nothing conclusive about integrated GPUs, mobile, long sessions, final soundtrack cost or input latency.

ObjectDB cleanup warnings remain on some exits. They did not fail the passing test scripts, but repeated rematch/reload resource usage deserves a lifecycle check before shipping. Do not assume the warnings' cause without tracing them.

[Validation output](reviews/2026-10-27-master-dcc55f8/validation.txt) and [leg audit summary](reviews/2026-10-27-master-dcc55f8/leg-summary.json).

## How to answer whether people will play

The game has a concrete curiosity hook; repeat enjoyment needs human evidence. Invite 5-10 people who have not learned the controls from the developer. Observe the first few minutes without coaching, then ask what felt unfair, what move they enjoyed, and whether they voluntarily want another match or style. Measure learning time, actual rematch choices and repeat-play interest. Use the results to prioritize the next pass. Treat positive comments as feedback, not proof of retention or sales.

Recommended next milestone: one polished short demo with readable contact, understandable defense, a beginner route, intended music and stable performance. Keep Capoeira after the existing backlog.
