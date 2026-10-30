extends SceneTree
## Deterministic combat-only AI census. No visual/audio/finisher simulation.
## Main-equivalent simultaneous hit gather, Focus, pushboxes and hitstop.
const SEEDS := [11, 23, 37, 53, 71, 89]
const LIMIT := 5400
var rows: Array = []
var usages := [{}, {}]

func _initialize() -> void:
	call_deferred("run")

func pushboxes(a: Fighter, b: Fighter) -> void:
	var min_dist := Fighter.PUSH_HALF_WIDTH * 2.0
	var dx := b.position.x - a.position.x
	if absf(dx) >= min_dist or absf(b.position.y - a.position.y) > CombatData.CROSSUP_CLEARANCE or a.is_down() or b.is_down() or a.is_passing_through() or b.is_passing_through(): return
	if a.is_crossing() != b.is_crossing():
		var mover := a if a.is_crossing() else b
		var other := b if a.is_crossing() else a
		var side := signf(mover.position.x - other.position.x)
		if side == 0: side = float(mover.dodge_world_dir if mover.state in [Fighter.State.EVADE_ROLL, Fighter.State.DODGE] else -mover.facing)
		var step := minf(min_dist - absf(mover.position.x - other.position.x), CombatData.CROSS_RESOLVE_STEP)
		var before := mover.position.x
		mover.position.x += side * step
		mover.clamp_to_arena()
		var short := step - absf(mover.position.x - before)
		if short > 0.01:
			other.position.x -= side * short
			other.clamp_to_arena()
		return
	var dir := signf(dx) if dx != 0 else float(a.facing)
	var overlap := min_dist - absf(dx)
	a.position.x -= dir * overlap * 0.5
	b.position.x += dir * overlap * 0.5
	a.clamp_to_arena()
	b.clamp_to_arena()
	dx = b.position.x - a.position.x
	if absf(dx) < min_dist:
		var rest := min_dist - absf(dx)
		if is_equal_approx(a.position.x, Fighter.ARENA_MIN_X) or is_equal_approx(a.position.x, Fighter.ARENA_MAX_X): b.position.x += dir * rest
		else: a.position.x -= dir * rest
		a.clamp_to_arena()
		b.clamp_to_arena()

func match_one(style: StringName, rival: StringName, side: int, seed_value: int) -> Dictionary:
	var fs: Array[Fighter] = [Fighter.new(), Fighter.new()]
	var ais: Array[EnemyAI] = [EnemyAI.new(), EnemyAI.new()]
	usages = [{}, {}]
	for n in 2:
		var f := fs[n]
		root.add_child(f)
		root.add_child(ais[n])
		f.set_style(StyleRegistry.by_id(style if n == 0 else rival))
		f.position = Vector2(640 + side * (-140 if n == 0 else 140), 560)
		f.ground_y = 560
		f.opponent = fs[1 - n]
		(f.get("_rng") as RandomNumberGenerator).seed = seed_value * 100 + n
		f.attack_started.connect(func(_f: Fighter, attack: CombatData.Attack): usages[n][String(attack.id)] = usages[n].get(String(attack.id), 0) + 1)
	for n in 2:
		fs[n].face_opponent()
		ais[n].rng_seed = seed_value * 10 + n
		ais[n].setup(fs[n], fs[1 - n])
		# Same difficulty/personality for both styles; style move plans/range remain.
		ais[n].aggression = 0.62
		ais[n].block_chance = 0.5
		ais[n].reaction_frames = 6
		ais[n].dodge_chance = 0.12
		ais[n].parry_chance = 0.15
		ais[n].jump_in_chance = 0.15
	var ticks := 0
	var stop := 0
	var results := [{}, {}]
	var move_contacts := [{}, {}]
	var interrupted := [{}, {}]
	for tick in LIMIT:
		ticks = tick + 1
		if stop > 0:
			stop -= 1
			continue
		# Simultaneous intentions and hit gathering avoid player-side priority.
		var intents := [ais[0].compute_intent(), ais[1].compute_intent()]
		for n in 2: fs[n].push_intent(intents[n])
		for f in fs: f.tick()
		pushboxes(fs[0], fs[1])
		var pending: Array = []
		for n in 2:
			var a := fs[n]
			var d := fs[1 - n]
			if not a.is_hitbox_active() or not a.get_hitbox_world().intersects(d.get_hurtbox_world()): continue
			if d.is_evading():
				d.perfect_evade()
				continue
			if d.can_be_hit(): pending.append([n, a.current_attack, a.combo_step])
		if Fighter.hitboxes_clash(fs[0], fs[1]): stop = 4
		for hit in pending:
			var n: int = hit[0]
			var a := fs[n]
			var d := fs[1 - n]
			var attack: CombatData.Attack = hit[1]
			var step: int = hit[2]
			var interrupted_id := String(d.current_attack.id) if d.current_attack != null else ""
			var interrupted_phase := int(d.get_phase())
			var result := d.receive_hit(attack, a, step)
			var key: String = CombatData.HitResult.keys()[result]
			results[n][key] = results[n].get(key, 0) + 1
			var move_key := String(attack.id) + ":" + key
			move_contacts[n][move_key] = move_contacts[n].get(move_key, 0) + 1
			if not interrupted_id.is_empty() and result in [CombatData.HitResult.HIT, CombatData.HitResult.KO]:
				var interrupt_key: String = interrupted_id + ":" + Fighter.Phase.keys()[interrupted_phase]
				interrupted[1 - n][interrupt_key] = interrupted[1 - n].get(interrupt_key, 0) + 1
			match result:
				CombatData.HitResult.HIT:
					if not a.in_signature: a.add_focus(CombatData.focus_for_hit(attack, d.last_hit_counter))
					d.add_hurt_focus(CombatData.focus_for_hurt(attack.damage))
					stop = maxi(stop, attack.hitstop + (3 if step >= CombatData.MAX_COMBO_CHAIN else 0) + (CombatData.COUNTER_HITSTOP_BONUS if d.last_hit_counter else 0))
				CombatData.HitResult.BLOCKED:
					d.add_block_focus()
					stop = maxi(stop, CombatData.BLOCK_HITSTOP_FRAMES)
				CombatData.HitResult.PARRIED: stop = maxi(stop, CombatData.PARRY_HITSTOP_FRAMES)
				CombatData.HitResult.GUARD_BREAK: stop = maxi(stop, CombatData.GUARD_BREAK_HITSTOP_FRAMES)
			a.confirm_hit(result)
		if fs[0].health <= 0 or fs[1].health <= 0: break
	var outcome := "draw"
	if fs[0].health <= 0 and fs[1].health > 0: outcome = "loss"
	elif fs[1].health <= 0 and fs[0].health > 0: outcome = "win"
	elif ticks == LIMIT: outcome = "timeout"
	var row := {"style": style, "rival": rival, "side": side, "seed": seed_value, "outcome": outcome, "ticks": ticks, "health": [fs[0].health, fs[1].health], "move_starts": usages.duplicate(true), "contacts": results, "move_contacts": move_contacts, "interrupted": interrupted}
	for f in fs: f.free()
	for ai in ais: ai.free()
	return row

func run() -> void:
	var seeds: Array[int] = []
	var seed_text := OS.get_environment("CENSUS_SEEDS")
	if seed_text == "":
		for value in SEEDS: seeds.append(value)
	else:
		for value in seed_text.split(","):
			if value.strip_edges().is_valid_int(): seeds.append(int(value.strip_edges()))
	var targets: Array[StringName] = []
	var target_text := OS.get_environment("CENSUS_STYLES")
	if target_text == "": target_text = "capoeira,jeet_kune_do"
	for value in target_text.split(","):
		var id := StringName(value.strip_edges())
		if StyleRegistry.by_id(id) != null: targets.append(id)
	if seeds.is_empty() or targets.is_empty():
		push_error("Census requires valid target styles and seeds")
		quit(1)
		return
	for style: StringName in targets:
		for other in StyleRegistry.all():
			if other.id == style: continue
			for side in [1, -1]:
				for seed_value in seeds: rows.append(match_one(style, other.id, side, seed_value))
	var out := OS.get_environment("CENSUS_OUT")
	if out == "": out = "res://docs/reviews/agility-balance/latest.json"
	var file := FileAccess.open(out, FileAccess.WRITE)
	var revision := OS.get_environment("CENSUS_REV")
	if revision == "": revision = "working tree; see source_sha256"
	var source_hashes := {}
	for path in ["scripts/combat_data.gd", "scripts/fighter.gd", "scripts/enemy_ai.gd", "scripts/martial_art_style.gd", "styles/capoeira.tres", "styles/jeet_kune_do.tres"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	file.store_string(JSON.stringify({"revision": revision, "source_sha256": source_hashes, "settings": {"target_styles": targets, "seed_set": seeds, "tick_limit": LIMIT, "health": 100, "ai_personality": "common defaults; style plans and preferred range retained", "scope": "combat-only; no rendering, audio, cinematic slowdown or finishers"}, "rows": rows}, "\t"))
	print("RESULT: census complete ", rows.size(), " matches -> ", out)
	quit()
