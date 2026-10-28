# X moves acceptance - 2026-10-28

Implemented on `moves/x-moves`. Seven mapped X moves deal 18 total damage, cost no Focus, and start a 600-simulation-tick cooldown on entry. Cooldown survives interruption, whiff, block and round reset; new matches start ready. X cannot cancel its recovery, start airborne, or inject sequence children through raw/custom-style inputs. Existing block/parry/evade rules apply; no armour was added.

## Checks

- Godot 4.7.2 editor import: no script parse/load errors.
- Full regression suite: **24/24 passed**, run headless with dummy audio and `--fixed-fps 60`; see the per-suite summary.
- New combat tests cover mappings, total damage, both facings and walls, block/parry/evade, whiff/expiry, interruption, raw-input/sequence-child gates, Focus and actual round-reset persistence.
- New integration tests cover physical X, held-input behavior, AI readiness/range, and training guidance.
- Rendered contact census: **84 cases, zero failures**. Seven styles x two facings x centre/target-near-wall x 70 px, 90 px and calculated AI-range boundary. This is a diagnostic fighter scene with manual simulation/contact resolution, not a human playtest.
- Each contact samples the rendered striking joint against the defender hurtbox before applying damage. Limit: 12 px for joint centre versus body box (allows the drawn hand/foot thickness); worst observed below. This metric does not certify every surface of the rendered body.
- Big Foot supplemental physics measurement: about 49.7 px backward travel, 10 airborne ticks, 16 px rise. Dropkick visibly lands horizontally and holds seated recovery before rising.

## Census

All cases deal 18 damage. Tick values exclude gameplay hitstop. The boundary uses conservative AI range including step, lunge, retreat and leap travel; it is not an exhaustive sweep of every possible manual entry distance.

| Style | Contact ticks | Back to actionable | Worst joint gap |
|---|---|---|---|
| Boxing | 24, 39 | 73 | 7.10 px |
| Muay Thai | 26 | 63 | 0.00 px |
| Karate | 28 | 65 | 0.00 px |
| Kung Fu | 24 | 64 | 0.00 px |
| Taekwondo | 22, 34, 47 | 83 | 5.82 px |
| Kickboxing | 24 | 63 | 9.07 px |
| Bangla Maar | 24 | 70 | 0.00 px |

HUD example: [cooldown and ready indicators](hud.png).

## Clips

Silent diagnostic captures at 60 simulation ticks/second, with both facings; half-speed reels use the same frames. These isolate choreography/contact and do not contain match audio, HUD, stage effects or hitstop.

- [All seven facing right](clips/all_right.mp4) ? [half speed](clips/all_right_half_speed.mp4)
- [All seven facing left](clips/all_left.mp4) ? [half speed](clips/all_left_half_speed.mp4)

Individual style/facing clips are also in `clips/`. Machine-readable contact/timing data: [census.json](census.json). Full suite outcomes: [suite-summary.txt](suite-summary.txt). Per-suite logs and the import log are retained here. Existing scene-based suites can emit ObjectDB/resource cleanup warnings on exit; pass/fail is determined from assertions, exit status and script errors.

Reproduce: run `tests/x_move_review.gd` with the normal renderer, dummy audio and fixed FPS 60. It regenerates source PNGs and census data. Run `tests/run_all.sh` with `GODOT` set to the Godot executable for the full suite.

No matchup balance or listening claim follows from these checks; damage/cooldown remain the requested initial tuning.
