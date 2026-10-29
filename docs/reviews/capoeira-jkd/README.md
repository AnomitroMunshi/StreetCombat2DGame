# Capoeira and Jeet Kune Do expansion

Adds playable styles 8 and 9, with complete ground/air controls, distinct stances and outfits, AI plans, signatures, X moves and four finishers each. The selector fits all nine cards and the Start button; training and move lists include both styles.

| Style | Identity | F signature | X |
|---|---|---|---|
| Capoeira | Ginga, circular heel kicks, sweeps and hand-supported attacks | Roda Storm: 24 damage | Meia-Lua Tornado: 18 damage, 15s cooldown |
| Jeet Kune Do | Bruce Lee-inspired bladed readiness, direct lead strikes, stop kicks and side kicks | Intercepting Fury: 24 damage | Dragon's Burst: stop kick 6 + side kick 12, 15s cooldown |

X costs no Focus, charges cooldown at the beginning, and follows ordinary block/parry/evade/interruption rules. Capoeira's low/inverted attack and recovery hurtboxes follow its changing posture. Signature parents and children cannot bypass Focus through raw attack requests.

Finishers: Capoeira has Roda's End, Handstand Havoc, Sky Wheel and Corner Carnival. JKD has One-Inch Ending, No Second Chance, Dragon Intercept and End of the Line. JKD's compact punch finisher remains separate from its revised kick-only X.

## Review artifacts

- Actual-scene X clips with HUD, effects and sound: [right](clips/gameplay_right.mp4), [left](clips/gameplay_left.mp4).
- Move pose sheets: [Capoeira](capoeira_moves.png), [JKD](jeet_kune_do_moves.png).
- [Rendered X contact census](census.json): 24 cases, both directions, centre/wall and close/max range; all deal 18 total damage. Worst sampled strike-joint gap is under 1px against the hurtbox. This is not an every-frame body-contour measurement.
- Actual-scene hit records: [right](gameplay_right.json), [left](gameplay_left.json). JKD contacts deal 6 then 12 damage; both cooldowns are 15s.
- [Finisher contact log](finisher-contact.log) uses the existing 6px drawn-body tolerance across all nine styles.
- `test_expansion_visuals` covers 68 move/facing geometry, registration and hand-support probes. Other focused tests cover controls, legal AI plans, real damage, interruption, cooldown bypass, recovery vulnerability and all nine visible roster cards.

The two new styles currently use the existing procedural music fallback. Dedicated tracks, human feel/balance approval, a large matchup win-rate census and exported-platform checks remain follow-up work. Scene tests retain the existing cleanup warnings at exit.

## Reproduction

Run `tests/run_all.sh` with `GODOT` pointing to the engine. Captures used Godot 4.7.2 at fixed 60 FPS. For new-style X captures, set `REVIEW_STYLES=capoeira,jeet_kune_do`, `REVIEW_OUT=res://docs/reviews/capoeira-jkd`, and `REVIEW_SIDE=1` or `-1`, then run `tests/x_impact_gameplay_review.gd` with `--write-movie`. Encode the two generated AVI files with `python tests/encode_style_expansion_review.py` (requires imageio-ffmpeg). Raw AVI/PNG sequences remain local and ignored.
