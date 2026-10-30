# Finisher feel pass (FIN-FEEL), 2026-10-30

## What was measured

All 34 style finishers were played headless at a fixed 60 FPS, with a per-tick timeline: beat, pose, playback speed and hitstop.

- **Length:** the knockout lands 0.4–1.3 s in, and a whole finisher runs about 2 s. There are no long idle waits.
- **The knockout itself was already strong.** It has 6 ticks of hitstop at half speed (about 200 ms on the contact pose), 4 ticks at half speed after it, then an eased return to full speed. On top of that come the boom, flash, impact frame, directional camera kick and blood. Frames: `final_bell_ko_frames.png` and `cyclone_360_ko_frames.png`.
- **The gap was before the blow.** The windup right before the knockout played at full speed, with the music at the same duck as the setup hits. Finisher strikes had no swing sound.

## Change (all finishers, no choreography edits)

- **The hush:** the last 8 ticks of the windup before the knockout blow play at 0.55 speed. The music drops from -14 to -30 dB and the camera leans in a further 0.07 zoom.
- **The snap:** the blow then travels in at full speed. Game speed is capped at 1.0 by design, so the jump from 0.55 to 1.0 is the acceleration. The knockout's boom lands on near silence.
- **Swing sounds:** every finisher strike whooshes as its beat starts. Setup hits get a light whoosh (-4 dB) and the knockout blow a heavy one (+1 dB).
- **No hush for chains:** if the beat before the knockout is itself a strike (Falling Cross, Air Breaker, Football Shot, Super Chor), there is no hush, so the chain keeps its momentum.

Playback speed only: the hit events, their order and contact are unchanged, and the finisher contact suite passes. `tests/test_finisher_feel.gd` covers the hush, the duck, the snap and the chain exception.

## Still open

- Per-finisher choreography review (FIN-FEEL-02/03).
- Listening in actual play.
