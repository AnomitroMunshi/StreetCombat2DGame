# Balance pass 1: 2026-10-30

An AI-vs-AI census across all nine styles. This compares how the styles do when the AI plays them; it is not a measure
of human win rates.

## Method

- `tools/balance/run_census.sh` runs one headless Godot process per style, all in parallel (about 90 s in total).
- Each style plays every other style over 96 seeds, from both starting sides, at 200 HP: 1,536 matches per style.
- A match is one round, played to the first K.O. Combat runs in full (real `Fighter.tick()`, AI intents, pushboxes,
  hits, Focus and hitstop). Rendering, audio and finishers are not simulated.
- Each style's own AI tuning is used, as in the game (`CENSUS_AI=common` gives every style one shared personality).
- 24 seeds proved too few: two seed sets differed by up to 10 points for the same style. With 96 seeds, repeated
  runs agree.
- Tables: [before.md](before.md) (master `6ca5beb`) and [after.md](after.md).

## Result

| Style | Before | After | Change |
|---|---:|---:|---|
| Taekwondo | 62% | 56% | AI aggression 0.76 → 0.66 |
| Karate | 64% | 54% | Reverse punch damage 12 → 10; AI aggression 0.66 → 0.56 |
| Kung Fu | 59% | 53% | none; it moved because the others changed |
| Jeet Kune Do | 56% | 50% | none |
| Muay Thai | 55% | 49% | none |
| Kickboxing | 41% | 47% | AI: default block and punish (were 0.40 and 0.55), aggression 0.56 → 0.62, range 120 → 135 |
| Capoeira | 39% | 46% | AI aggression 0.55 → 0.70, range 78 → 110 |
| Bangla Maar | 25% | 45% | Damage up (below); AI range 95 → 135 |
| Boxing | 52% | 45% | none |

The spread is now 45–56%, compared with 25–64% before.

Bangla Maar damage changes:

| Move | Before | After |
|---|---:|---:|
| Street punch | 6 | 8 |
| Stomach shot | 8 | 10 |
| Head elbow | 11 | 13 |
| Leg kick | 9 | 10 |
| Thrust kick | 10 | 12 |
| Jor Dhakka | 11 | 13 |
| Hammer | 15 | 17 |

Timings and reach are unchanged, so Bangla Maar stays fast and short-ranged.

## Findings

- **Bangla Maar's moves were weak.** It lost whichever AI personality played it. It threw fewer attacks than the
  other styles (21 a match, against 27–29) and did about 6 damage per throw. Karate's reverse punch alone does about
  9 per throw.
- **Kickboxing and Capoeira were held back by their AI tuning, not by their moves.** Kickboxing's low block and
  punish chances, and Capoeira's low aggression at point-blank range, cost each of them about 15 points.
- **This AI rewards staying further back.** Waiting outside the opponent's reach and punishing as they come in wins
  more often. The two strongest styles were the two with the longest preferred ranges (Taekwondo 135, Karate 130).
  Ranges were therefore tuned with each style's identity in mind, not simply maximised: Capoeira stays at 110
  although 135 measured a little better. A future AI change could make waiting less dominant for every style.
- A longer reverse punch recovery (17 → 20) made Karate stronger, not weaker, so it was reverted. In this census,
  frame changes can work in the opposite direction to what you'd expect; only measured changes were kept.

## Remaining lopsided pairs

These are all within 70/30, and none was targeted in this pass:

- Taekwondo over Capoeira: 70%
- Boxing over Kung Fu: 34% (Kung Fu wins)
- Boxing over Capoeira: 28% (Capoeira wins)
- Kickboxing over Taekwondo: 26% (Taekwondo wins)
- Capoeira over Kickboxing: 24% (Kickboxing wins)
