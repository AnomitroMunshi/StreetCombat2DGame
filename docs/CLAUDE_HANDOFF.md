# Street Combat handoff

Updated 2026-10-30. Read this before changing the current gameplay.

The older professional-polish review is preserved in [the 27 October handoff](archive/CLAUDE_HANDOFF_2026-10-27.md). Its findings describe an earlier build; reproduce them before treating them as current defects.

## User direction

- Capoeira and Jeet Kune Do are the two new styles. There are nine styles total.
- Capoeira should be agile and control opponents through stun and knockdown. Target roughly 50–60% wins in the documented AI census; distinguish that measurement from human win rates.
- JKD is Bruce Lee inspired: very fast J jab-cross, heavy overhead K hammerfist, existing W+K high hook with stun on hit **and guard break on block**. The user explicitly restored guard break after an earlier clarification.
- Capoeira uses yellow pants, a one-hand balance intro, a one-hand split-handstand X, L cartwheel stun, S+K knockdown sweep, and a directional A/D+Space rolling crossover jump.
- JKD X is one advancing side kick with support-foot pivot, hip/shoulder turn and strong recoil. It is not the earlier stop-kick sequence or a punch.
- Karate's One-Inch Verdict uses the supplied wide grounded reverse punch and backward airborne victim reaction. JKD One-Inch Ending uses compact dedicated poses and whole-body impulse.
- Both new styles have separate original synthesized looping music tracks. Do not restore their old shared procedural fallback.
- User authorized animation/move refinements, agents, testing, merge and push to master. Preserve unrelated workspace changes.

## Important behavior

- X moves cost no Focus; cooldown starts on entry, survives interruption/whiff/block, carries across rounds, resets for matches. Capoeira/JKD X are 18 damage with 15-second cooldowns.
- Capoeira rolling jump remains vulnerable, locks facing during the somersault, crosses only above the opponent and lands into recovery. It is not an invulnerable evade roll.
- Stun uses existing hit-drain, mash recovery and immunity. Hook guard break preserves parry, evade and the shared posture lock.
- JKD's automatic jab/cross child IDs reject direct input. Only the parent can start the sequence; interruption drops the remaining cross.
- Appended attack IDs must remain stable. The old `meia_lua_tornado` ID now displays **Handstand Hammer**. Legacy unmapped JKD X child IDs remain for compatibility.

## Final balance snapshot

Capoeira: **100/192 wins (52.08%)** in the tuning set, **108/192 (56.25%)** in a fresh 12-seed validation set; **208/384 (54.17%) combined**, no draws. These use the documented common AI personality, mirrored sides and all eight opponents. They are not human win-rate guarantees. Earlier tuning snapshots and failed validations remain recorded.

Final Capoeira normals, startup/active/recovery in ticks:

| Move | Timing | Damage | Control |
|---|---|---:|---|
| J Quick Palm | 4/3/9 | 11 | Fast entry |
| K Spinning Heel | 11/4/17 | 16 | 40-tick stun |
| L Cartwheel | 14/5/20 | 13 | 80-tick stun |
| W+K Crescent | 10/4/18 | 12 | 35-tick stun |
| S+K Sweep | 10/4/24 | 8 | Knockdown, low-blockable |

Walking is 30% faster than the shared base; voluntary jump travel is scaled 1.5. The final palm/heel damage increases followed the user's later broad authorization after recovery/stun-only changes did not meet the target. Do not describe the final revision as having completely unchanged base damage.

JKD remains the restrained earlier revision: J starts with a 3-tick jab and delivers 12 total damage across two punches; K is 14 damage; W+K is 14 damage, 14/4/26 timing, 50-tick stun or guard break. No further JKD buffs were made during the Capoeira target pass.

## Code and evidence

- Data: `scripts/combat_data.gd`, `styles/capoeira.tres`, `styles/jeet_kune_do.tres`.
- Movement/status/input gating: `scripts/fighter.gd`, `scripts/martial_art_style.gd`.
- Animation: `scripts/fighter_visual.gd`. Right-lead rendering must keep pivot/open-hand roles attached to anatomical limbs after drawing-order swaps.
- Capoeira AI waits for observable recovery/stun openings before X: `scripts/enemy_ai.gd`. It does not read future input.
- Intro/finisher guidance: `scripts/main.gd`, `scripts/finisher.gd`, `scripts/training.gd`.
- Music: `scripts/audio.gd`, `tools/music/gen_expansion_music.py`, generated OGGs under `assets/audio/music/generated/`.
- `docs/reviews/style-move-polish/`: frozen earlier reference/music checkpoint, clips, full 29-suite evidence and corrected ordered wall-finisher contact.
- `docs/reviews/agility-balance/`: current agility clips, rendered normal contacts, initial/updated census and final regression logs.
- `docs/reviews/agility-balance/target-50-60/`: subsequent tuning trials, validation seeds and source hashes. Read its final report before quoting a win rate.

## Validation commands

Godot console executable on this machine:
`D:/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`

`tests/run_all.sh` lists 31 suites. On Windows, the suites can be run individually with `--headless --path . --fixed-fps 60 -s tests/test_NAME.gd`.

Key additions: `test_agile_styles.gd`, `test_capoeira_ai.gd`, `test_expansion_visuals.gd`. Actual-input review: `tests/agility_gameplay_review.gd` with `REVIEW_SIDE=1/-1`. Rendered contact matrix: `tests/agility_contact_review.gd` without headless. The matrix measures the drawn striking limb at first real contact; do not loosen its tolerance to hide a mistimed pose.

The 3-tick JKD punches need an early authored extension: the first active rendered frame samples startup minus one. A generic 90%-startup key caused 21px phantom hits; dedicated early keys fixed them to zero in the reviewed matrix.

`test_finisher_contact.gd` supports comma-separated `ONLY` finisher IDs and `ONLY_STYLE` IDs. Corner Carnival's middle cartwheel uses a bounded settling contact window because isolated tests previously hid failures that appeared after earlier styles. Keep the 6px finisher tolerance.

## Workspace cautions

There are preexisting dirty audio `.import` files, `docs/BACKLOG.md`, old review `.png.import` files and many untracked art/concept directories. These are outside this task. Do not blanket restore, clean, delete or stage them. Godot editor import may also touch unrelated art imports; restore only the exact newly generated metadata when verified.

Godot's existing ObjectDB/resource cleanup warnings appear in some passing test logs. Check the explicit RESULT and script-error lines; retain failure history and final replacement logs honestly.
