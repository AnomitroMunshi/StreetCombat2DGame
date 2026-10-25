# Adding a martial art

Styles are data. The match code never checks a style's name.

1. **Moves.** Reuse rows from `CombatData.ATTACK_TABLE` where you can. For a new move:
   1. Append a value to `AttackType`. Never reorder this enum.
   2. Add a table row with a permanent `id` and its frame data, hitbox, damage, posture and cancel window. Set `air: true` for jump-only moves and `spin: true` for moves that turn the back.
   3. Add keyframe poses and a timeline in `FighterVisual._moves`, plus the striking joint in `_attack_joint`.
2. **Stance.** Reuse a `Stances.Kind`, or append a new one with its guard pose and active idle. Never reorder this enum either.
3. **Style file.** Copy `styles/boxing.tres` to `styles/<id>.tres` and set:
   - `id`: permanent; saves refer to it.
   - `order`, `display_name`, `description`, `category`, `difficulty`, `strengths`, `weaknesses`, `stance`.
   - `input_map` and `air_map`: slot → move id. The slots are listed in `MartialArtStyle`.
   - `chains`: move id → the move ids it may cancel into on contact.
   - `ai_close_plans`, `ai_far_plans`, `ai_preferred_range`.
4. **Validate.** Run `tests/run_all.sh`. `StyleRegistry` refuses a malformed file and names every problem in `StyleRegistry.rejected()`, for example:
   - an unknown move,
   - a chain that leaves the moveset,
   - an AI plan that isn't a legal chain,
   - an air-only move mapped to a ground slot.

The new style then appears in the selection roster. The card row scrolls, so the roster can grow. Both the player and the AI rival can use it, and the `Fighter` gate keeps every fighter inside its own moveset.

**Not covered by data alone.** Throws, grips, clinches and ground positions (Judo, Wrestling, BJJ, Sambo, Hapkido locks) need a synchronized two-fighter interaction subsystem. See `docs/M6.5_ARCHITECTURE.md` §4.
