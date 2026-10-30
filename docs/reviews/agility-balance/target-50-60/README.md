# Capoeira target-rate tuning

This follow-up uses the combat-only census and common controller settings described in the parent review. It targets a measured 50–60% Capoeira win rate, not a guarantee about human matches.

**Final candidate 10 meets the target:** 100/192 wins (52.1%) on the known tuning seeds and 108/192 (56.3%) on a fresh, previously unused 12-seed validation set. Both runs use identical gameplay source hashes. Together they give 208/384 wins (54.2%), with no draws or timeouts.

Each original-seed run contains 96 matches: eight opponents, six seeds and both starting sides. Mirrored pairs are correlated. The original seeds are `11,23,37,53,71,89`.

| Snapshot | Wins / matches | Win rate | Change |
|---|---:|---:|---|
| Starting control revision | 26 / 96 | 27.1% | First agility revision |
| Trial 01 | 22 / 96 | 22.9% | Use X only on observable stun/recovery openings |
| Trial 02 | 24 / 96 | 25.0% | L startup 16, recovery 26 |
| Trial 03 | 46 / 96 | 47.9% | Faster palm/kick recovery, short heel/crescent stuns, range 78 |
| Trial 04 | 43 / 96 | 44.8% | Range 74 |
| Trial 05 | 44 / 96 | 45.8% | Fast-entry far plans |
| Trial 06 | 50 / 96 | 52.1% | Restore trial-03 plans; L startup 14 |
| Trial 06 holdout | 36 / 96 | 37.5% | Same source, previously unused seeds |
| Trial 07, combined known seeds | 86 / 192 | 44.8% | L recovery 20/stun 80, heel recovery 17 |
| Trial 08, combined known seeds | 84 / 192 | 43.8% | Heel stun 60, crescent stun 50 |
| Trial 09, combined known seeds | 96 / 192 | 50.0% | Palm damage 10, heel damage 15; kick stuns restored to 40/35 |
| Trial 09 fresh six-seed validation | 42 / 96 | 43.8% | Same source; candidate did not validate |
| **Trial 10, combined known seeds** | **100 / 192** | **52.1%** | **Palm damage 11, heel damage 16** |
| **Trial 10 fresh 12-seed validation** | **108 / 192** | **56.3%** | **Same source, no further tuning** |

Trial 06 reached the requested range on the original seeds but did **not** validate on the reserved seeds `101,127,149,173,197,223`. Its combined result was 86/192 wins, or 44.8%. Trial 07 used both now-observed seed sets as tuning data and produced the same aggregate result. These failures are retained rather than presenting only the favorable original-seed result.

Every JSON records the exact gameplay source hashes, seed set, controller settings, per-match health and outcome, move usage, contact results and interruptions. No outcome weights or opponent-specific advantages are used.

Trial 09 reached 50% on the known seeds but also failed its fresh validation (`307,331,353,379,401,431`). That result is retained. Those validation results were not reused as tuning matches for candidate 10.

## Final control and power changes

The final candidate keeps the agility revision: 30% faster walking, directional rolling crossover jump, knockdown sweep, shorter normal-move recovery, and a committed X used by the AI on observable openings. Capoeira's L now uses 14 startup / 5 active / 20 recovery ticks and 80 ticks of stun. The heel and crescent apply shorter 40- and 35-tick stuns; the shared stun-immunity rules remain active.

Recovery/stun-only candidates remained below the requested range on the larger known seed set. The final power adjustment raises Quick Palm from 8 to 11 damage and Spinning Heel from 14 to 16. L remains 13 damage, the sweep remains 8, and X remains 18 with its 15-second cooldown. There are no opponent-specific advantages or changes to other styles' damage in this follow-up.

The final fresh validation seeds are `503,541,577,613,653,691,733,773,811,853,907,953`. They were first used after candidate 10 reached the target on the 12 known tuning seeds. The resulting validation rate was accepted without another gameplay change. `trial-10-final-power-step.json` and `validation-candidate10.json` contain the matching source hashes and complete match rows.

| Rival | Known seeds W–L | Fresh validation W–L | Combined win rate |
|---|---:|---:|---:|
| Boxing | 22–2 | 18–6 | 83.3% |
| Muay Thai | 12–12 | 18–6 | 62.5% |
| Karate | 18–6 | 10–14 | 58.3% |
| Kung Fu | 6–18 | 10–14 | 33.3% |
| Taekwondo | 16–8 | 8–16 | 50.0% |
| Kickboxing | 2–22 | 10–14 | 25.0% |
| Bangla Maar | 16–8 | 22–2 | 79.2% |
| Jeet Kune Do | 8–16 | 12–12 | 41.7% |

The aggregate target is met, but individual matchups remain uneven; Kickboxing and Kung Fu are difficult for this controller. Mean simulated match duration is 16.6 seconds across the final 384 matches. Paired sides are correlated, AI personality is controlled rather than each style's shipped personality, and these results do not establish human fairness or enjoyment. No further broad buff is recommended from this sample.
