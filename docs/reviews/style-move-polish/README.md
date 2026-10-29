# Capoeira / JKD move revision

This review supersedes the overlapping animations and JKD X sequence in the initial expansion.

- Capoeira L remains a two-hand vertical cartwheel kick. X is now **Handstand Hammer**: a one-hand split kick based on the supplied silhouette, with the free arm folded away from the floor. The permanent `meia_lua_tornado` ID is retained for compatibility. Clean hits launch the opponent backward; blocking prevents the launch. Damage remains 18 and cooldown remains 15 seconds.
- Capoeira wears yellow pants. Its intro uses the supplied one-hand balance with the legs together overhead and the free arm extended, then lands before combat starts. JKD uses the supplied wide, bladed open-hand intro stance.
- Capoeira's sweep uses one bent support leg, one posted hand and a low extended heel, followed by retraction before standing.
- JKD air K is a side-on heel extension. Air L is a front snap kick with its own chamber, torso and leg path.
- JKD X is a single stepping side kick: 18 damage, 15s cooldown, 22-tick startup, 34-tick recovery. The rear foot gathers, the support foot pivots before extension, the shoulder/hip separation reverses through the turn, and the lead arm counterbalances the drive. The leg re-chambers before the body unwinds. It advances even when already in range, stops at the opponent's body and produces airborne recoil on a clean hit. Block/parry/evade and interruption remain available. Right-lead rendering now keeps the support-foot pivot and open hand attached to the correct anatomical limbs.
- One-Inch Ending has dedicated set/load/short-stroke/follow-through poses, a close held setup and a stronger backward launch. Its fist is set near the torso before the impulse; it no longer borrows the general burst-punch pose.
- Karate's One-Inch Verdict uses the supplied wide grounded reverse-punch silhouette: bent lead knee, long rear leg, off-hand chambered and extended rear fist. The victim launches backward without an extra somersault.
- Dedicated original music: Capoeira is a 112 BPM percussion/struck-string arrangement (68.6s); JKD is a 118 BPM bass/drums arrangement (65.1s). Both use 32-bar arrangements with section changes, wrapped tails and -17 dBFS RMS before the game's -5 dB gain. The instrument timbres are synthesized approximations, not sampled recordings. See `music-analysis.json` and `tools/music/gen_expansion_music.py`.

The one-inch presentation is a cinematic game adaptation. The artistic emphasis on coordinated hip/body drive follows the description in [Bruce Lee's Fighting Method](https://dojo.press/pdf/Bruce-Lees-Fighting-Method-The-Complete-Edition.pdf); animation timing, distance and launch are game choices.

## Evidence

The folder contains current move sheets, actual-input comparison clips, both mirrored punch finishers, intro/landing footage, X contact census and regression logs. Airborne comparison footage demonstrates motion on whiffs; it is not proof of airborne hit contact. X contacts are checked separately in both directions, at close/max range and walls. Finisher contact keeps the existing 6px drawn-body tolerance.

The first 29-suite pass found three Corner Carnival contact failures (7.6px). Isolated tests hid the issue; logging each strike in an ordered Kickboxing/Capoeira run identified the middle cartwheel contact. That beat now has a longer contact window and waits for the inverted heel to settle rather than resolving on its first receding frame. The ordered wall regression passes at a maximum 4.4px without increasing tolerance. `final_finisher_contact.log` records the complete finisher rerun. `final_new_styles.log` includes clean-hit launch and blocked-no-launch checks for Capoeira in both directions. `final_music.log` checks dedicated tracks, looping, player-style selection, crossfading and fallback behavior.

Clips: [X impacts](clips/gameplay_right.mp4), [mirrored X impacts](clips/gameplay_left.mp4), [move comparisons](clips/variations_right.mp4), [mirrored comparisons](clips/variations_left.mp4), [intro transitions](clips/reference_intros.mp4), [JKD One-Inch Ending](clips/one_inch_ending.mp4), [Karate Verdict](clips/one_inch_verdict.mp4).

Raw AVI and PNG sequences are retained locally and ignored. Encode AVI captures using `python tests/encode_style_expansion_review.py docs/reviews/style-move-polish`.
