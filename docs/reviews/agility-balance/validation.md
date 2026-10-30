# Final gameplay verification

The final Capoeira tuning is documented in [target-50-60/README.md](target-50-60/README.md): 52.08% tuning wins, 56.25% fresh validation wins, 54.17% combined across 384 matches. These are controlled AI measurements, not human win-rate guarantees or equal-matchup claims.

All 31 registered suites passed, using the complete suite run plus final reruns for changed behavior. Final replacement results are in `final_*.log`; unchanged suites retain their `test_*.log` results. The full finisher suite passed both directions, airborne and wall cases. Earlier failed logs remain for traceability: old JKD key mappings, the old exclusive Bangla guard-break count, the old four-overhead count and the old neutral Capoeira X expectation were updated to the explicitly requested behavior, then rerun successfully.

The final focused rerun includes core, controls, stun, movement, new styles, agile styles, Capoeira AI, style expansion, expansion visuals, AI defense, AI signatures, X UI/AI, training, guard and Bangla. It covers automatic jab-cross legality and interruption, power-chord conversion, knockdown/low guard, stun recovery and immunity, guard-break/parry rules, crossover clearance and vulnerable landing, and AI use of visible X openings.

Rendered evidence:

- `normal-contacts.json` / `normal-contacts.log`: 40 revised-normal contacts, mirrored, center and near walls, two distances. Each jab and cross lands once. The reviewed matrix's maximum drawn gap is under 4.1px; the existing 12px allowance was not increased.
- `gameplay-right.log` / `gameplay-left.log`: all seven input-driven scenarios pass. Crossover lands beyond the opponent; L stuns; sweep knocks down; J produces two hits; hammerfist produces one; hook stuns on hit and breaks guard on block.
- [Right-facing gameplay](clips/gameplay_right.mp4) and [left-facing gameplay](clips/gameplay_left.mp4) include the final animation and dedicated style music.
- `visual-capture.log`: 68 pose/facing probes plus somersault, jab-cross and hammerfist semantics pass. PNG sheets show the current contact silhouettes.

The fast JKD punch contact review initially found a 21px visual gap. The animation now reaches extension before the first interpolated active frame; the jab-cross drawn gap is zero in the reviewed cases.

Existing Godot ObjectDB/resource cleanup warnings are retained in the logs; RESULT lines and script errors determine test outcomes. No manual human-versus-AI win-rate claim is made.
