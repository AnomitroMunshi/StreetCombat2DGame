# Reference and move-polish verification

Implementation checkpoint: `dd088a0` (before the subsequent agility/balance pass).

All 29 headless suites passed, with focused final reruns where the implementation changed during review. The initial full finisher run caught three Corner Carnival contacts at 7.6px. An ordered regression reproduced the issue in its middle cartwheel beat; the corrected contact window then passed the complete finisher suite at the unchanged 6px tolerance.

Final replacements for the original suite logs:

- `final_finisher_contact.log`: complete finisher suite, all styles, both directions, wall and airborne cases — PASS.
- `final_music.log`: separate looping tracks, player style selection, crossfading and unknown-style fallback — PASS.
- `final_new_styles.log`: legal moves, resources, mirrored sweep geometry, single JKD X and clean-hit/blocked Capoeira launch checks — PASS.
- `final_expansion_visuals.log`: 66 move/facing probes and distinct pose/support semantics — PASS.
- `final_style_expansion.log`, `final_x_impact.log`: selector/training integration and impact behavior — PASS.

Other suites are recorded in their `test_*.log` files: core, knockdown, jump, announcer, input, controls, stun, Bangla, flow, match, AI finisher, double kick, X moves, X UI/AI, X flinch, AI defense, movement, styles, training, rounds, guard, AI signature and stage.

Additional rendered checks:

- `census.json`: 24 X contacts, both directions, close/mid/AI-boundary distances, center and walls — PASS. Capoeira's widest-range drawn contact gap is 8.4px; JKD's is zero in this census. X checks use their existing contact allowance, not the finisher's 6px tolerance.
- `gameplay-*.log`: actual X input, hitstop, audio and knockback — PASS. Capoeira travels about 126px airborne / 179px total; JKD about 98px airborne / 139px total in open space. Both deal 18 damage with 15-second cooldowns.
- `variations-*.log`: actual inputs start all six intended comparison moves — PASS. Airborne comparison footage shows animation on whiffs, not airborne hit verification.
- `reference-intros.log`: both mirrored intro silhouettes, planted hand and return to guard — PASS.
- `verdict-contact.log`: rendered Karate Verdict in both directions, worst gap 1.6px — PASS.
- `one-inch-contact.log`: rendered JKD One-Inch Ending in both directions, worst gap 3.9px — PASS.

Music generation and decoded OGG measurements are in `music-analysis.json` and `music-decoded-analysis.json`. The files have distinct arrangements, finite samples, approximately -17dBFS RMS and peaks below clipping. This is an automated playback/signal check; subjective musical acceptance remains a listening judgment.

Godot reports existing audio/resource cleanup warnings at process exit. Test result lines above determine pass/fail; the original logs retain those warnings.
