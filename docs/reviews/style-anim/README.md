# Style animation prototypes (STYLE-ANIM-08): 2026-10-30

These are the four representative moves the backlog asks to see before any rollout. All are still frames from
real input in a windowed run at 60 FPS, captured with `tools/review/pose_strip.gd` and laid out with
`tools/review/tile.gd`. No move data changed: timing, reach, damage and hitboxes are all as before. All 40 test
suites pass.

| Move | Image | What changed |
|---|---|---|
| Boxing cross | `boxing_cross_before_after.png` (top row before, bottom row after) | **Fixed the near-kneeling lunge.** Boxing has its own cross pose: hips over the stance, short rear-leg drive, chin behind the lead glove. Its strikes now sink at most 6 px (the default is 18), so the rear foot drags in behind the punch instead of the hips collapsing. |
| Boxing, other punches | `boxing_hand_strikes_after.png` | Rows: body hook, jab, overhand, slip counter, uppercut. All stay compact with no foot crossing. The overhand keeps its deliberate deep lunge. |
| Karate reverse punch | `karate_reverse_punch_before_after.png`, `karate_guard_before_after.png` | Upright torso and square hip drive. The lead fist pulls back to the hip (hikite) as the rear fist extends. Strikes sink at most 10 px, so the long front stance is kept. In guard, the lead elbow now bends so the punch has visible room to extend. The finisher poses are untouched. |
| Taekwondo side kick | `taekwondo_side_kick_muay_thai_roundhouse_current.png` (top row) | **Not changed.** Chamber, extension with a counter-lean, and re-chamber already read clearly. |
| Muay Thai body roundhouse | same image (bottom row) | **Not changed.** It turns over with the lead arm swinging down for counterbalance. |
| Muay Thai jab and elbow | `muay_thai_jab_elbow_before_after.png` (rows: jab before, jab after, elbow before, elbow after) | Same 6 px sink limit as Boxing, which removes the long low lunges noted in the backlog. |

## Waiting on you

Please play these at normal speed and say whether they feel right, especially:
- Boxing's step-drag
- Karate's hikite

Rollout to the rest of each moveset, plus STYLE-ANIM-06/07 and the Kung Fu items, waits on that review, as
STYLE-ANIM-08 asks.
