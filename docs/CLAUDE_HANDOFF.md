# Claude handoff ? Street Combat professional polish

Reviewed build: clean commit 66ffbd7, Godot 4.7.2, 27 October 2026. No source changes were made by this review. Evidence and diagnostic scripts are beside this file. Reproduce against the current branch before editing; preserve unrelated work if the branch has moved.

## Verified baseline

- Import succeeds. All 12 existing headless suites pass, with zero reported failures or script/parse errors.
- A scripted-input Kung Fu vs Boxing match reaches KO and RESULT.
- All 14 style finishers complete in both directions: 28 rendered cases. Shared/legacy finishers are covered by existing headless tests, not all by this rendered sweep.
- 36 launch/wall/roll probes settle with no gameplay-root floor or arena-bound violations. This is not a guarantee that every rendered limb avoids clipping.
- Transient and decal caps hold at 260 and 140 in a synthetic stress probe.
- Fresh short real-time benchmark: 2,017 measured frames across seven styles and Hundred Palms; approximately 16.67 ms average frame interval, 18.433 ms maximum, zero frames above 25 ms. Conditions: 1280x720, GL Compatibility, RX 6600 XT, 60 FPS cap, VSync disabled, Dummy audio. This is not a long soak or low-end hardware guarantee; no new audio listening/mix measurement was performed. See performance.json.
- Preserve the recent improvements: authored KO flight before ragdoll, real spinning back-kick presentation, less aggressive finisher camera/slow motion, contact-aware finisher logic, and thin directional impact effects instead of opaque white discs.
- Signature readiness already pulses. Dynamic combat framing, a master hard limiter, costumes, training, style legality checks, and low blocking already exist; do not reimplement them based on old backlog text.

## Phase 1 ? Reproduced defects and high-priority readability

### 1. Finishers still permit premature contact [high, measured]
Files: scripts/finisher.gd, scripts/fighter_visual.gd.
Reproduction: run finisher_review.gd from this review folder against the snapshot. It starts each finisher from a 120 px root gap, at centre stage, in both directions. Heaven's Heel first strike resolves with approximately 66.61 px separation facing right and 52.61 px facing left according to the director's own contact estimator, despite CONTACT_SLOP=6. Eight-Count facing right and Last Combination facing left have smaller approximately 10.54/10.83 px misses. All finishers complete; completion alone is insufficient.
Inspect _try_land, beat transitions and the forced fallback _land calls. The eight-tick spinning hook beat cannot simply time out and register a hit before the limb reaches the target. Adjust approach, spin/pose timing or waiting rules while guaranteeing progress. Do not hide the problem by increasing CONTACT_SLOP.
Also author the intended contact joint per beat: _strike_gap currently accepts either hand/elbow or either foot/knee, so an unrelated limb can satisfy contact.
Acceptance: intended limb reaches the intended head/body/leg region before reaction, spark, sound and KO; satisfy a documented contact tolerance; each beat emits once; all 14 style finishers pass both directions at close/mid range and near walls; verify at 30/60/120 render FPS. Handle headless fallback explicitly rather than claiming it validates drawn contact.
Evidence: rendered-finishers.json and rendered-finishers.log.

### 2. Separate HUD message lanes [high, rendered]
File: scripts/hud.gd.
Normal combat reproduces COUNTER overlapping SIGNATURE READY, and combo text overlapping the style label. Multiple popups use the same coordinates. Training controls also compete with callouts.
Give style/HP, combo, signature readiness and temporary callouts reserved space; stack or queue messages with bounded lifetimes. Wrap long signature names.
Acceptance: simultaneous counter+combo+ready+dizzy messages remain readable for both sides, including longest style/signature strings, training panels and supported window scales.
Evidence: match-400.png, match-1000.png, 03-hud-stress.png.

### 3. Improve close-range staging without breaking combat [high, rendered]
Files: scripts/main.gd, scripts/fighter.gd, scripts/fighter_visual.gd, scripts/combat_data.gd as needed.
Fighters still visually overlap substantially during exchanges. Reach limiting also compresses extended techniques into hard-to-read bent poses. Gameplay pushboxes passing tests does not establish visual separation.
Review push width, torso lean, step-in, contact depth and authored close-range variants together. Do not just widen pushboxes: that can make short-range attacks unusable. Preserve legitimate overlap during cross-ups, pass-through rolls and authored finishers.
Acceptance: silhouettes remain readable during neutral exchanges; short-range attacks still connect; no wall pinning or one-sided reach advantage; existing movement/control suites pass; capture all seven styles at minimum spacing and in both directions.
Evidence: match-400.png.

### 4. Result UI must leave the winner visible [high, rendered]
Files: scripts/main.gd, scripts/hud.gd.
The current Karate result capture places PLAYER WINS over the winner's head/upper body. Both fighters were inside frame in the sampled results; a winner disappearing off screen was not reproduced.
Use an explicit RESULT camera/layout, remove gameplay combat prompts and place the win title/buttons away from the celebration. Currently a non-null finished director can retain finisher camera behavior; test it rather than assuming failure in every match.
Acceptance: every style's winner and celebration remain unobscured at either wall; defeated fighters never display signature-ready prompts; controls are visible; no stale cinematic tilt/bars.
Evidence: 05-result.png and match-1599.png.

### 5. Smooth VFX during slow motion [medium-high, measured]
File: scripts/effects.gd.
At 25% speed a sampled particle changes position 15 times in 60 rendered frames, holding for up to three frames. It changes 60 times at normal speed. Custom draw coordinates are not automatically interpolated by Godot node transform interpolation.
Store previous/current particle and debris positions and interpolate only in drawing. Handle spawn, reset, teleport and expiration cleanly. Keep age, physics and caps tick-driven.
Acceptance: visible motion remains continuous at 100/50/25% speed, normal hitstop and reduced render rates; particle lifetimes, hit timing and budgets are unchanged.
Evidence: vfx-timing.json and vfx_timing.gd.

### 6. Fit the full style roster [medium, rendered]
File: scripts/hud.gd.
Seven minimum-width 118 px cards plus spacing require at least 874 px inside a panel approximately 640 px wide. Kickboxing and Bangla Maar begin outside the visible row; the default selected Kickboxing card is not visible.
Use a compact grid/two rows or another layout that exposes all seven. Keep keyboard selection visibly indicated and move-list text readable.
Acceptance: all seven choices and selected highlight visible at the supported minimum window size, with no accidental clipping.
Evidence: 01-style-select.png.

### 7. Attach speech to the animated head [medium, code-confirmed]
Files: scripts/hud.gd, scripts/fighter_visual.gd, scripts/main.gd.
Speech follows root position plus a fixed (0,-200) offset, not the drawn head. It therefore floats above empty space during falls/rolls. There is a global speech cooldown, but no per-line rotation.
Expose a safe rendered head anchor with a standing fallback; apply camera transforms once. Preserve priorities and avoid UI/other-bubble overlap. Recheck screen clamps after moving the second bubble. Add per-line cooldown or variants for frequently repeated lines.
Acceptance: correct anchor through jump, knockdown, roll and KO, both speakers and camera zoom; no off-screen bubbles or repeated per-frame speech.

## Phase 2 ? Physics, VFX and character polish

### 8. Tune low-energy falls [medium, measured]
Files: scripts/fighter.gd, scripts/combat_data.gd.
A 1 px drop rebounds to approximately 4.8 px; 5 px and 20 px drops receive the same minimum -3.5 px/tick rebound. The min() expression injects bounce into gentle contact.
Introduce a low-impact no-bounce threshold and impact-scaled restitution; reserve dramatic bounce for suitable launches. Recheck sliding inward near walls and the transition from authored flight to ragdoll/rest.
Acceptance: gentle drops settle; heavy launches retain deliberate arcade weight; no infinite bounce/roll or premature RESULT; repeat the 36 probe scenarios.
Evidence: physics.json.

### 9. Improve character value contrast and silhouette [medium, visual judgment/code]
File: scripts/fighter_visual.gd and style data.
Dark Karate/Taekwondo costumes obscure internal detail against the dojo; red rim glow carries too much of their readability. Both uniforms already have some collar distinction, so refine it rather than assuming none exists.
Lighten/select alternate rival costume values, reduce idle glow width, strengthen dobok V-neck/jacket shape, and differentiate selected hair/profile/costume silhouettes. Add restrained expressions for pain, anticipation and victory within the existing art style.
Acceptance: all seven styles and both roles read against the actual background with glow reduced, including grayscale screenshots and combat zoom. Keep visual size compatible with collision expectations.

### 10. Reduce visual clutter and strengthen motion weight [medium, art direction]
Files: scripts/fighter_visual.gd, scripts/effects.gd, scripts/main.gd.
Full-body afterimages still produce competing silhouettes on ordinary attacks. Some jumping attacks share similar crouched landings/recovery. Secondary pillar explosions can compete with the primary body impact.
Reduce ordinary trail count/opacity/duration, keep stronger trails for special moves, differentiate key recovery/landing poses, and stage secondary dust/debris after the primary hit. Review foot planting, support knee, hip/shoulder transfer and return to guard using sequential frames, not only still poses. Consider signed ragdoll knee/elbow limits after reproducing problematic poses; current length/minimum-distance constraints do not guarantee natural bend directions.
Acceptance: current pose dominates; contact stays visible; feet do not visibly slide/pop in calm movement; style identity survives with effects off. Avoid changing the shared skeleton merely for novelty.

## Phase 3 ? Small-game release requirements, not a feature rewrite

### 11. Player settings and input completeness [feature gap]
Files: project.godot, HUD/menu/input/audio code, a small settings resource/service as appropriate.
Add persistent key remapping, controller bindings/menu navigation, master/music/SFX volume, window/fullscreen options, and adjustable shake/flash/trails/blood. Blood is currently a source constant. Keep defaults close to the current game; avoid losing Space-to-jump when buttons have focus. Pause and release held inputs on focus loss; test reconnection and pause/restart from each match state.
Acceptance: settings survive restart; valid bindings always allow menu access; keyboard and controller can complete select/start/pause/rematch/training without mouse; focus changes never leave stuck movement/guard.

### 12. Portable text and packaging [release gap]
Bundle an openly licensed Bengali font and its license; do not rely on Windows system fonts. Add reproducible target-platform export presets/build instructions and a version identifier. Test an exported build on a clean machine with no Godot editor or Bengali font installed, and at supported window sizes. No bundled font/export preset/CI files were found in this review.
Acceptance: Bengali speech/comic text shapes correctly in the exported build; assets/resources resolve; startup, quit and rematch work; no private paths or credentials shipped.

### 13. Balance and difficulty need measurements [validation/product work]
Expose a small set of difficulty presets using existing AI tuning and reaction_frames; make their behavior distinct and fair. Run seeded style matchups with both sides and report seed/sample counts, win rates, match duration, knockdowns and move usage. Validate with human playtests. Old 21%/67% backlog figures are not fresh measurements; do not blindly tune to them.
Acceptance: no dominant repeatable AI exploit, unusable style or difficulty with untelegraphed reactions; actionable player feedback supports changes. A round timer/best-of-three is a design decision, not a confirmed defect. Do not add multiplayer/grappling/new styles as part of this polish pass unless separately requested.

### 14. Release QA and audio verification [validation/infrastructure]
Files: tests/run_all.sh, tests, audio cleanup and build tooling.
Make the runner fail on runtime SCRIPT ERROR/Parse Error/Failed to load even when the engine exits 0 and a RESULT: PASS line exists. Check import exit code and timeouts robustly. Add a native Windows runner or documented equivalent and CI for import plus the existing suites. Add rendered contact/layout evidence checks: headless tests cannot catch Heaven's Heel's visible miss.
Some captures still emit ObjectDB leak warnings (including six in the latest performance run). Identify their owners and verify repeated scene reload/quit rather than declaring all warnings harmless.
The master hard limiter already exists at -1 dB; verify actual captured audio instead of adding a duplicate limiter. Check mix headroom, repeated/stacked impacts, voice stealing, mute/pause/focus changes and device behavior. No new audio waveform or listening analysis was done in this pass.
Run longer hardware/performance checks, resource/memory soak tests across repeated rematches/training changes, and 30/60/120 FPS visual checks. Do not call a fixed-FPS accelerated render a performance benchmark.
Acceptance: no script errors, unexplained leaks, hangs, audio clipping or stale state; short automated checks plus a documented human release checklist pass on exported builds.

## Implementation order and constraints

Work in small reviewable batches: 1?4, then 5?8, then 9?10, then release settings/packaging/QA. Preserve the 60 Hz combat model, input buffers, legal movesets, parry rules, trade/double-KO handling and existing style identities. Add focused regression tests for behavior changes; do not replace visual evaluation with tests that merely echo implementation. After each batch, report changed behavior, checks and screenshots/clips. Update docs/BACKLOG.md to separate fixed items, reproduced defects and unverified ideas. Do not claim a visual fix from headless test success alone.

## Additional check ? low-strike coverage

Runtime enumeration of the live style resources and CombatData.Attack.low finds true low attacks in five of seven styles. Muay Thai: Low Kick (S+K); Karate: Low Side Kick (S+K); Kung Fu: Sweep (S+K); Kickboxing: Low Kick (S+K); Bangla Maar: Leg Kick (S+K). Boxing and Taekwondo have none. Boxing explicitly lists "No low attacks" as a weakness. Taekwondo maps S+K to Axe Kick, whose low flag is false. Kung Fu Low Palm, Boxing Body Hook, and other body punches are also not mechanically low: standing guard can block them. The down input modifier or a low-sounding name is not evidence of low-guard behavior.

This is a balance/design decision, not automatically a defect. If the intended requirement is one low-guard attack per style, implement a style-appropriate low option for Boxing and Taekwondo, with consistent input, animation, hitbox, low flag, AI plans, move-list text and tests. Preserve Boxing's no-kicks identity. Do not label a head-height Axe Kick as low merely to satisfy a coverage check. Acceptance: the chosen move beats standing guard, is stopped by low guard/parry under the existing rules, works in both directions and remains style-legal.

## Additional high-priority fix ? rear-leg/support-leg mechanics (user screenshot)

Reference supplied by the user: training, Taekwondo versus Karate, last move Body Punch (S+J), HIT, near the right pillar. The white attacker leans deeply forward with the rear leg nearly straight and stretched far behind; the rear foot is sharply tipped, and the support/contact of the feet is difficult to read. The dark defender's rear leg/foot also needs inspection through the hit reaction. A still image establishes the awkward pose, but does not by itself prove sliding, popping or an incorrect IK branch; reproduce the full sequence before assigning the cause.

Treat this as part of the high-priority close-range staging fix, not merely a cosmetic shoe change. Inspect both fighters and both facing directions.

Likely code areas: scripts/fighter_visual.gd (_plant_feet, _ik_leg, _solve_joints, _mechanics, _short_punch/_limit_reach, foot orientation and heel/toe drawing), scripts/stances.gd and Body Punch pose keys; check step-in/pushbox interaction in scripts/fighter.gd and scripts/main.gd where necessary. These are investigation points, not a confirmed root cause.

Required behavior:
- Keep the rear/support knee softly bent in grounded punches and guards. Avoid an overextended/locked or backward-bending knee and an implausibly long split stance.
- Drive the punch with coordinated hips, torso and rear heel pivot. A lifted heel must preserve believable forefoot/toe contact; do not rotate the entire foot upright or make it hover unintentionally.
- Keep each planted foot stable until an intentional step/pivot begins. When the stance exceeds leg reach, reposition the foot or adjust body weight smoothly instead of stretching the leg, snapping the knee or dragging the foot.
- Ensure front/rear IK bend directions and foot orientation mirror correctly when facing left; do not fix one facing direction at the expense of the other.
- Blend startup, contact, recovery and hit reactions without foot teleportation, knee flips or body-height pops. Preserve intentional aerial poses, spins, evasive rolls and ragdolls.
- Review the defender's weight-bearing leg during recoil so it does not buckle in an anatomically implausible direction or penetrate the floor/pillar.

Acceptance: reproduce the supplied Taekwondo S+J into Karate scenario at close range and near both walls; capture startup/contact/recovery in both directions. Compare ordinary punches across all seven styles, then verify walking, crouch, kicks, landing and get-up. Inspect with trails/glow temporarily disabled so the actual legs remain visible. Render at 30/60/120 FPS and training 25/50/100% speed to reveal frame-dependent slipping or pops. Bone lengths remain consistent; knee bend and foot contact remain plausible; existing combat/movement/control tests still pass; hit range, damage and timing are preserved unless a separately justified balance change is necessary.

## Explicit user-requested implementation ? Taekwondo L alternating-leg double kick

This is a narrowly scoped move replacement requested by the user, separate from general polish suggestions. Apply it to the existing Godot 4 project; do not rename or recreate the project. Replace ONLY Taekwondo's currently mapped L technique (Lead-Leg Feint) with an automatic two-hit alternating-leg double kick. Preserve its other mapped moves, controls, signature, finishers and the other six styles. Minimal data/animation/legality integration is in scope; unrelated AI behavior, posture rules and state-machine redesign are not.

### Input

One fresh L press commits to the complete move. No follow-up input or S+K -> K chord is required. Holding L must not repeatedly restart the move. After completion, another fresh press can start a new move under the normal action rules.

### Required choreography

1. Start from Taekwondo guard and shift weight onto the support leg.
2. Chamber the rear knee and pivot the supporting foot.
3. Throw a LOW rear-leg roundhouse at the opponent's lead thigh: 5 damage.
4. Recoil that leg and plant its foot forward naturally.
5. Transfer body weight onto the newly planted foot.
6. Chamber the opposite knee.
7. Throw a MID-height roundhouse at the opponent's ribs: 9 damage.
8. Retract and plant the second leg, then return smoothly to Taekwondo guard.

Use opposite legs for the two strikes, not the same kick replayed or an existing generic combo with unchanged leg poses. The first foot must visibly plant before becoming the support for the second kick. Apply the rear-leg/support-leg requirements in the preceding screenshot task. Keep the fighter root stable relative to the intended grounded action; use local weight shifts and intentional footwork rather than teleporting or sliding toward the target. Preserve normal defensive knockback, collision separation and arena limits.

### Combat contract

- One committed two-hit move with two distinct, non-overlapping active windows and a visible recoil/plant/weight-transfer transition between them.
- First startup initially 9 simulation frames; first active window 3 frames; second active window 3 frames; final recovery 20 frames. Inspect and tune the intervening transition frames; do not remove the transition or invent an unreviewed zero-frame link. Record the selected transition timing in the move data/docs.
- Each kick has its own hitbox, contact event and once-per-target registration. Reset contact eligibility only for the second strike; never re-hit every active tick.
- First kick uses existing low-guard rules. Second kick uses existing mid/body guard rules; do not invent a new overhead rule. A down modifier or descriptive name alone is insufficient: set the actual low flag/hitbox correctly for the first strike.
- The second kick executes even if the first whiffs or is blocked, provided the attacker is still able to continue. Do not gate the second strike on first-hit contact or a manual combo-cancel input.
- Existing defender block, parry, evade, stun, interrupt and KO behavior remains authoritative. An attacker interruption discards the remaining strike, and no pending hit or callback may fire later. Recovery remains committed according to the existing gameplay rules.
- Verify left/right mirroring and foot-role reversal, near walls and at minimum pushbox spacing; no teleport-to-target logic.
- Do not change shared low_roundhouse/body_roundhouse damage globally to get 5 and 9. Use Taekwondo-specific move definitions or a safely scoped existing mechanism so Muay Thai/Kickboxing and other styles remain unchanged.

### Integration boundaries

Inspect CombatData.Attack.sequence, Fighter._tick_attack/_clear_sequence and FighterVisual timelines before choosing the smallest implementation. Reuse the existing sequence/state machinery if it can meet this contract. Keep one player-visible L technique; internal strikes may use separately scoped IDs.

Update styles/taekwondo.tres, required move/frame data and visuals, move-list names, training display and README. Update style legality and AI plan references only as necessary so Taekwondo can legally select and complete the replacement, with no dangling Lead-Leg Feint references. Internal sequence strikes must be legal for this sequence without exposing unrelated moves or changing other styles' legality. Do not retune AI aggression, defense or unrelated combo behavior.

The request to preserve all other moves takes precedence over the general low-coverage suggestion: this new L technique supplies Taekwondo's low attack. Leave S+K Axe Kick unchanged and do not add another Taekwondo low as part of the earlier general suggestion. Boxing's low-coverage decision remains separate. Keep existing signatures and their sequences unchanged.

Ensure move lists/training present this as ONE automatic two-hit technique, with first/second damage 5+9 and meaningful startup/transition/active/recovery information. Do not display only the first internal move as though the second does not exist. Explicitly decide how it interacts with the existing received-combo/knockdown count, preserving the game's rules rather than bypassing them to force a second hit on an invulnerable knocked-down target.

### Required validation and acceptance

1. On a fresh stationary full-health target in range, one L press produces exactly two separate three-frame active windows and two contact events, dealing exactly 5 then 9 damage (14 total), with no unintended damage scaling. Validate startup 9 and final recovery 20, and document transition frames.
2. Hold L through the move and recovery: no restart or extra hits. Release and press again: a new move is allowed normally. No second button is necessary.
3. First-hit whiff: second strike still plays on schedule. First-hit block: second strike still plays. Each window can hit at most once per target.
4. First strike defeats ordinary standing guard and is stopped by low guard under existing rules. The second is blocked by the existing applicable mid/body guard behavior. Validate parry/evade behavior separately for each window.
5. Interrupt during startup, first active window, leg transfer and second startup: no remaining strike, stale hitbox, delayed damage or orphaned visual callback. KO stops the sequence safely.
6. Test both facing directions, minimum/normal range, both walls, a moving/evading opponent, and interactions with existing combo knockdown rules. Positions, hitboxes and damage mirror correctly.
7. Verify root stability, support-foot contact/pivot, genuine alternating legs, visible transfer and smooth guard recovery using sequential frames at normal/slow training speeds. Rendered checks supplement headless tests.
8. Assert that other Taekwondo mappings, signature, finishers and other styles' move definitions/damage/AI legality remain unchanged. Run Godot import/parse validation and all 12 existing suites plus focused new behavioral tests.
9. Provide exact playtest instructions: select Taekwondo, enter training, test stand/block/evade or fight-back modes, press/hold/release L, slow/step the move, repeat facing left and near walls, and compare the training damage/frame readout with the documented sequence. Supply before/after captures and the final frame timing.

## Additional requested movement pass ? normal and directional jumps

User reference: a weighty, readable martial-arts jump feel inspired by Shadow Fight. Treat this as an aesthetic/gameplay-feel direction, not an assertion of that game's exact physics, frame data or control scheme. Do not copy proprietary assets or recreate the game. Exact reference footage would help later; it is not supplied in this request.

Current code observations: normal and directional jumps share JUMP_VELOCITY=-15, rise/fall gravity 0.95/1.35 and AIR_SPEED=4.5 px/tick. Direction is sampled at takeoff; held direction can subsequently steer jump_vx toward AIR_SPEED with AIR_CONTROL=0.3. With no direction held, horizontal speed persists. Thus the arc already uses different ascent/descent gravity; do not describe it as constant-gravity or missing all air control. Shared squat/rise poses and this travel model need a coordinated feel pass, not just more jump height.

Desired behavior:
- Neutral Space: a grounded, readable compression and push-off, compact airborne guard, clear apex, controlled descent, then knee/hip compression and balanced return to guard. Avoid a rigid standing pose translated up and down.
- Forward/back + Space: distinct readable launch and travel poses. Coordinate torso lean, knee chamber, arms and support-foot push-off with travel direction. Land under the centre of mass without foot sliding or a sudden stance-width change. Backward travel should read differently from a forward jump; do not add automatic flips simply for spectacle.
- Tune launch velocity, travel distance, rise/fall timing and limited air steering together. Assess whether direction release/reversal is too slippery or too controllable; document a deliberate momentum rule instead of assuming either full steering or no steering is correct. Preserve left/right symmetry and cross-up opportunities.
- Keep the ground shadow anchored to the floor and matched to height, with restrained takeoff/landing dust and believable foot contact. Camera tracking must not make the arc appear to jerk.
- Review normal landing versus air-attack landing: preserve deliberate punish/recovery windows and the one-air-attack-per-jump restriction; no landing-cancel exploit or free midair turn that invalidates cross-ups.
- Preserve the existing Space+J/K power-move chord in either order. Normal jump takeoff currently waits through the six-tick chord window. Do not remove that delay and silently break power input. Make the anticipation read immediately while input is being disambiguated; any changed input rule must be explicitly justified and approved as a separate control change.
- Keep changes grounded in the fixed-tick simulation and interpolate presentation. Do not replace collision or gameplay movement with render-delta motion/tweens. Preserve dodge/roll, hit reactions, signatures and finisher-authored leaps; avoid global gravity changes that accidentally alter every cinematic/power move.

Acceptance: compare neutral, forward and backward jumps in both facing directions, from stand/walk/crouch, at centre and both walls, at normal/50%/25% training speed and 30/60/120 render FPS. Check jump apex/time of flight/travel distance against chosen documented targets. Include late direction press, release and reversal, jump attacks, cross-up/facing, defensive interaction, landing recovery, buffered inputs, holding Space without repeated jumps, and Space+J/K in both orders. Record before/after sequential captures or clips and human playtest feedback; do not claim a Shadow Fight-like feel from headless tests alone. Existing movement/input/control suites must pass, with focused tests for any intentional new momentum behavior.

Coordinate this shared movement pass after the narrowly scoped Taekwondo L replacement; the latter's instruction to change only its move does not authorize unrelated jump changes in that same batch. Keep the movement work a separate reviewable batch.
