# X move impact and cooldown revision - 2026-10-28

Implemented on `moves/x-impact` after the first X-move review. All moves still deal 18 total damage, cost no Focus and retain normal block/parry/evade rules.

## What changed

- Boxing: stronger weight transfer, heavy hook audio/impact feedback and a forceful second hook (~106px displacement).
- Muay Thai: **Thai Roundhouse Kick (Tae Chiang)** replaces Retreating Jump Elbow. Held rearward hip/leg load, five-tick shin whip, full pivot/follow-through and deliberate recoil/plant; a clean hit causes a short knockdown (~140px total travel).
- Karate: startup reduced from 28 to 18 ticks; spin footwork actually travels even when already in range (~48px forward during the spin in the close-range test), respects body separation and has stronger knockback. A clean hit now snaps the opponent's head/torso back immediately in hitstop, then reels and recovers their guard.
- Kung Fu: **Scorpion Kick** replaces Butterfly Kick. Hand-supported dip and rear heel curling over the back; startup shortened from 26 to 18 ticks and recovery from 34 to 30. Its clean-hit head/torso flinch is visible during hitstop; it adds no damage, stun or cooldown change.
- Taekwondo: three kicks arrive at measured clock ticks 13/22/31 including impact pauses, versus the original much slower burst. Same raised leg, body/body/head; early hitstop 2/2 and final 6.
- Kickboxing: Big Foot causes ~301px airborne travel, ~369px including the skid.
- Bangla Maar: Dropkick causes ~154px airborne travel, ~197px total. The attacker now falls fully onto the floor, pauses, rolls/braces on a hand, rises through one knee and stands. Its 70-tick landing/get-up is vulnerable and cannot be cancelled; floor clearance was visually and geometrically checked.

## Cooldown decision

**Big Foot, Dropkick, Tae Chiang and Triple Kick use 15 seconds (900 simulation ticks).** Boxing, Karate and Scorpion Kick retain 10 seconds (600 ticks). The first three guarantee knockdown/space reset on a clean hit; Triple Kick has 12-tick startup, tightly spaced contacts and 48 total posture damage on guard. This is a conservative frequency adjustment based on measured move properties, not a claim of proven dominant matchup win rates. All are still punishable on a whiff/block or interruptible. Roster, training and both HUD indicators use the correct per-move duration.

## Measured census

Contact tick values below are zero-based simulation indices excluding hitstop. Travel comes from the actual training-scene replay with input, pushboxes, hitstop and effects.

| Style | Cooldown | Contact ticks | Actionable tick | Target airborne / total travel |
|---|---|---|---|---|
| Boxing | 10s | 24, 39 | 73 | 0.0 / 105.5px |
| Muay Thai | 15s | 20 | 55 | 61.7 / 139.7px |
| Karate | 10s | 18 | 55 | 0.0 / 87.2px |
| Kung Fu | 10s | 18 | 53 | 0.0 / 37.2px |
| Taekwondo | 15s | 12, 19, 26 | 54 | 0.0 / 47.9px |
| Kickboxing | 15s | 24 | 63 | 300.5 / 368.7px |
| Bangla Maar | 15s | 24 | 100 | 153.7 / 196.8px |

## Verification

- **26/26 test suites pass** (movement held-guard scenario rerun after fixture isolation), including all existing suites and new displacement, speed, per-move cooldown, landing vulnerability and input-cancel checks. [Suite summary](suite-summary.txt).
- **84 rendered contact cases pass**: seven styles, both facings, centre/near target wall, 70px/90px close distances and calculated AI range boundary. Every case deals 18 total damage. Worst sampled striking-joint gap is below 12px; this includes drawn hand/foot thickness, and is not a claim about every body-surface contour. [Census](census.json).
- New flinch regression: eight move/facing/wall probes and 113 assertions pass, including immediate frozen-frame recoil, wall clearance, anatomy, floor clearance and guard recovery within the existing hitstun.
- **14 actual-scene movie cases pass**, seven styles in both facings, with real X input, hitstop, pushboxes, audio/effects and measured flight. Each gets 18 total damage; centre Scorpion/backfist captures also assert visible head recoil during hitstop; Big Foot/Dropkick meet their airborne travel checks. [Right data](gameplay_right.json), [left data](gameplay_left.json).
- Godot 4.7.2 editor import has no script parse/load errors.
- Fixed the existing defense test to pin its rival style before seeded AI setup. Its previously random rival could yield no parry opportunities; thresholds and production AI were preserved. Final defense test passes with the pinned moveset.
- An initial movement-test run let a ready AI X interrupt its deliberately held guard. That one fixture now puts X on cooldown; the cross-up assertion and production AI were preserved, and the rerun passes.
- Scene-based tests still emit the known ObjectDB/resource-cleanup warnings at exit. No claim of human listening, player enjoyment, platform export coverage or matchup balance certification.

## Clips

Actual gameplay captures include sound, hitstop, HUD and effects:

- [All seven facing right](clips/gameplay_right.mp4) / [facing left](clips/gameplay_left.mp4)
- **Scorpion flinch:** [right](clips/scorpion_flinch_gameplay_right.mp4) / [left](clips/scorpion_flinch_gameplay_left.mp4)
- **Karate backfist flinch:** [right](clips/karate_flinch_gameplay_right.mp4) / [left](clips/karate_flinch_gameplay_left.mp4)
- **Tae Chiang:** [right](clips/muay_thai_gameplay_right.mp4) / [left](clips/muay_thai_gameplay_left.mp4)
- **Dropkick fall and get-up:** [right](clips/dropkick_gameplay_right.mp4) / [left](clips/dropkick_gameplay_left.mp4)

Diagnostic captures isolate choreography without audio or gameplay hitstop: [right](clips/all_right.mp4), [left](clips/all_left.mp4), [right half speed](clips/all_right_half_speed.mp4), [left half speed](clips/all_left_half_speed.mp4). Individual style clips are also in `clips/`.

Dropkick stills: [floor](dropkick_floor.png), [kneeling](dropkick_kneel.png), [standing](dropkick_stand.png).

## Reproduction

Run `tests/run_all.sh` with `GODOT` pointing to the engine for all 26 suites. The recorded suite run used headless mode, dummy audio and `--fixed-fps 60`. Run `tests/x_move_review.gd` rendered at fixed FPS 60 for the contact census and source PNGs. `tests/x_impact_gameplay_review.gd` plus `--write-movie <output.avi>` records the real scene; `REVIEW_SIDE=-1` mirrors it. Source PNGs/AVI intermediates are omitted from the commit.
