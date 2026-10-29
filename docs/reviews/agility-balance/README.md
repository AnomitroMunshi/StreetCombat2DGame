# Capoeira / JKD control revision census

This is a combat-only AI comparison, not a human playtest or a claim that the roster is balanced.

## Method

- Godot 4.7.2, 100 HP, 90-second limit, six fixed seeds: 11, 23, 37, 53, 71, 89.
- Each target style faces all eight other styles, with both starting sides: 96 matches per target, 192 per snapshot.
- Both controllers use the same personality: aggression 0.62, block 0.50, six-tick reaction, dodge 0.12, parry 0.15, jump-in 0.15. Style plans and preferred ranges remain active. This deliberately replaces each style's personality tuning to compare its moves and plans under common control.
- Fighter RNG and controller RNG are seeded separately. The same seed set and side swaps are used before and after.
- The harness uses real `Fighter.tick()`, public AI intentions, simultaneous hit gathering, real `receive_hit`/`confirm_hit`, Focus gain, clash/hitstop handling and the game's pushbox rules. It stops at the first KO. It does not simulate rendering, audio, cinematic slowdown, finishers or multi-round meter persistence. Timings are simulated ticks divided by 60, not measured wall time.
- Side swaps produce matching results in these runs; mirrored pairs are correlated, so 96 matches do not represent 96 independent trials. Six seeds per matchup are directional evidence rather than precise win-rate estimates.

The baseline was run in a detached worktree at `dd088a0`, avoiding concurrent gameplay edits. The final run uses the pending control revision over that commit; `final-source-sha256.json` records the gameplay source snapshot. `after.json` is an intermediate tuning pass, retained for traceability.

## Results

| Target | Baseline wins / losses / draws | Final wins / losses / draws | Baseline → final win rate | Mean rival HP remaining, baseline → final |
|---|---:|---:|---:|---:|
| Capoeira | 0 / 96 / 0 | 26 / 70 / 0 | 0% → 27.1% | 70.5 → 43.0 |
| JKD | 64 / 32 / 0 | 70 / 24 / 2 | 66.7% → 72.9% | 13.3 → 12.3 |

No matches timed out. Mean simulated duration changes from 15.3 to 18.1 seconds for Capoeira and 16.4 to 16.2 for JKD.

| Rival | Capoeira final W–L–D | JKD final W–L–D |
|---|---:|---:|
| Boxing | 4–8–0 | 8–4–0 |
| Muay Thai | 6–6–0 | 12–0–0 |
| Karate | 2–10–0 | 4–8–0 |
| Kung Fu | 8–4–0 | 10–2–0 |
| Taekwondo | 0–12–0 | 6–4–2 |
| Kickboxing | 0–12–0 | 8–4–0 |
| Bangla Maar | 6–6–0 | 12–0–0 |
| Capoeira | — | 10–2–0 |
| JKD | 0–12–0 | — |

The Capoeira/JKD rows are not exact inverses because the target-style role gets controller seed `seed*10`, while its rival gets `seed*10+1`. Swapping starting sides holds those controller roles fixed.

## What the measurements support

Capoeira had a clear problem under this controller. In the baseline, 67 of 121 X starts were interrupted during startup; its cartwheel was interrupted 46 times in startup and 22 in recovery across 129 starts, with only 31 clean hits. Its sweep was substantially more reliable: 50 clean hits from 58 starts. This supports control-oriented changes and safer plan selection rather than indiscriminate damage increases.

The final revision restores normal Capoeira damage to the baseline values, gives L 70 ticks of stun, adds knockdown to the sweep, speeds movement and gives the style a rolling cross-over jump. Close plans now favor palm/sweep entries. Clean hits rise from 273 to 558, and the cartwheel lands 46 clean hits from only 64 starts. This is a meaningful improvement, but Capoeira still loses every sampled matchup against JKD, Kickboxing and Taekwondo. It is not at roster parity in this test. X remains risky: 64 of 140 starts are interrupted during startup. A future AI improvement could reserve X for observable recovery or stun instead of changing the player's damage or startup again.

JKD was already successful mechanically in the baseline, despite the user's weak-feeling presentation feedback. Its final J is a 12-damage jab–cross, K is a 14-damage hammerfist, and the high hook is 14 damage with a 14/4/26 startup/active/recovery profile, no cancel, stun on hit and guard break on block. The hook is still punishable: the census records 18 recovery interruptions. The final win rate gives no basis for further general JKD buffs.

The hook's on-block guard break is intentionally strong, but the implementation checks parry first and uses the existing 120-tick posture lock to prevent consecutive guard-break loops. Dizzy recovery also provides the existing 180-tick stun immunity. These mechanics are observed in `Fighter.receive_hit`, `_parry` and `_tick_dizzy`; they do not prove that a human cannot develop a dominant hook strategy. Contact-result counts marked `GUARD_BREAK` are not treated as a clean count of successful offensive guard breaks because the shared result can also represent the attacker's posture breaking during a parry.

## Repeat

From the project root in PowerShell:

```powershell
$env:CENSUS_OUT = 'res://docs/reviews/agility-balance/final.json'
$env:CENSUS_REV = 'your tested commit or patch description'
& 'D:/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s docs/reviews/agility-balance/census.gd
```

The baseline used the same script copied into an isolated `dd088a0` worktree with its global script-class cache. Baseline and final JSON include all 192 match rows, health, duration, move starts, contact results and interrupted move phases.

Recommendation: retain the bounded control revision, avoid additional broad JKD buffs, and human-playtest Capoeira's palm→sweep, cartwheel stun follow-up and rolling cross-over against the three remaining difficult matchups. AI-versus-AI results cannot establish human enjoyment or execution difficulty.
