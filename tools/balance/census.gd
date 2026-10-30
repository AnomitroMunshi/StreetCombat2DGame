extends SceneTree
## Headless AI-vs-AI style census: one style against every other style, both
## starting sides, a fixed seed set. One "match" is one round at real match
## health (200 HP) to the first K.O. Combat only: real Fighter.tick(), AI
## intents, pushboxes, simultaneous hit gathering, receive_hit / confirm_hit,
## Focus and hitstop as in main.gd; no rendering, audio or finishers.
## Run through tools/balance/run_census.sh (one process per style, parallel).
##
## Environment:
##   CENSUS_STYLE   the style measured in this process (required)
##   CENSUS_SEEDS   comma-separated seeds (default below)
##   CENSUS_OUT     output JSON path
##   CENSUS_AI      "shipped" (each style's own AI tuning, as the game plays;
##                  default) or "common" (one shared personality for both)
##   CENSUS_DIFF    difficulty of the measured style's AI   (default normal)
##   CENSUS_RDIFF   difficulty of the rival's AI            (default normal)
##   CENSUS_RIVALS  comma-separated rival ids (default: every other style)
const SEEDS := [11, 23, 37, 53, 71, 89, 101, 131]
const LIMIT := 7200
const HEALTH := 200


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


func _count(d: Dictionary, key: String) -> void:
	d[key] = d.get(key, 0) + 1


func match_one(style: StringName, rival: StringName, side: int, seed_value: int, common: bool, diffs: Array) -> Dictionary:
	var fs: Array[Fighter] = [Fighter.new(), Fighter.new()]
	var ais: Array[EnemyAI] = [EnemyAI.new(), EnemyAI.new()]
	var starts := [{}, {}]
	for n in 2:
		var f := fs[n]
		root.add_child(f)
		root.add_child(ais[n])
		f.set_style(StyleRegistry.by_id(style if n == 0 else rival))
		f.max_health = HEALTH
		f.health = HEALTH
		f.position = Vector2(640 + side * (-140 if n == 0 else 140), 560)
		f.ground_y = 560
		f.opponent = fs[1 - n]
		(f.get("_rng") as RandomNumberGenerator).seed = seed_value * 100 + n
		f.attack_started.connect(func(_f: Fighter, attack: CombatData.Attack): _count(starts[n], String(attack.id)))
	for n in 2:
		fs[n].face_opponent()
		ais[n].rng_seed = seed_value * 10 + n
		ais[n].difficulty = diffs[n]
		ais[n].setup(fs[n], fs[1 - n])
		if common:
			ais[n].aggression = 0.62
			ais[n].block_chance = 0.5
			ais[n].dodge_chance = 0.12
			ais[n].parry_chance = 0.15
			ais[n].jump_in_chance = 0.15
	var ticks := 0
	var stop := 0
	var contacts := [{}, {}]
	var damage_by_move := [{}, {}]
	for tick in LIMIT:
		ticks = tick + 1
		if stop > 0:
			stop -= 1
			continue
		# Simultaneous intentions and hit gathering: no side gets priority.
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
			var hp_before := d.health
			var result := d.receive_hit(attack, a, step)
			_count(contacts[n], CombatData.HitResult.keys()[result])
			var dealt := hp_before - d.health
			if dealt > 0:
				damage_by_move[n][String(attack.id)] = damage_by_move[n].get(String(attack.id), 0) + dealt
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
	var row := {"style": style, "rival": rival, "side": side, "seed": seed_value, "outcome": outcome, "ticks": ticks,
		"health": [fs[0].health, fs[1].health], "starts": starts, "contacts": contacts, "damage": damage_by_move}
	for f in fs: f.free()
	for ai in ais: ai.free()
	return row


func _env_list(name: String, fallback: Array) -> Array:
	var text := OS.get_environment(name)
	if text == "":
		return fallback
	var out := []
	for v in text.split(","):
		if v.strip_edges() != "":
			out.append(v.strip_edges())
	return out


func run() -> void:
	var style := StringName(OS.get_environment("CENSUS_STYLE"))
	if StyleRegistry.by_id(style) == null:
		push_error("CENSUS_STYLE must name a style")
		quit(1)
		return
	var seeds: Array[int] = []
	for v in _env_list("CENSUS_SEEDS", SEEDS):
		seeds.append(int(v))
	var rivals: Array = []
	for v in _env_list("CENSUS_RIVALS", []):
		rivals.append(StringName(v))
	if rivals.is_empty():
		for other in StyleRegistry.all():
			if other.id != style:
				rivals.append(other.id)
	var common := OS.get_environment("CENSUS_AI") == "common"
	var diffs := [OS.get_environment("CENSUS_DIFF"), OS.get_environment("CENSUS_RDIFF")]
	for i in 2:
		diffs[i] = StringName(diffs[i] if diffs[i] != "" else "normal")
	var rows: Array = []
	for rival: StringName in rivals:
		for side in [1, -1]:
			for seed_value in seeds:
				rows.append(match_one(style, rival, side, seed_value, common, diffs))
	var out := OS.get_environment("CENSUS_OUT")
	if out == "":
		out = "user://census_%s.json" % style
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"style": style, "ai": "common" if common else "shipped", "difficulty": diffs,
		"seeds": seeds, "health": HEALTH, "tick_limit": LIMIT, "rows": rows}))
	file.close()
	print("RESULT: census %s: %d matches -> %s" % [style, rows.size(), out])
	quit()
