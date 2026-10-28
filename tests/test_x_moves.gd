extends SceneTree

var fails := 0
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func pair(style: MartialArtStyle, side: int, wall: bool = false) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	var center := 640.0
	if wall:
		center = Fighter.ARENA_MAX_X - 65.0 if side > 0 else Fighter.ARENA_MIN_X + 65.0
	a.position = Vector2(center - side * 40.0, 560.0)
	b.position = Vector2(center + side * 40.0, 560.0)
	a.ground_y = 560.0
	b.ground_y = 560.0
	a.opponent = b
	b.opponent = a
	a.face_opponent()
	b.face_opponent()
	a.set_style(style)
	b.set_style(StyleRegistry.by_id(&"karate"))
	return [a,b]

func press(a: Fighter) -> void:
	var i := CombatData.Intent.new()
	i.slot = &"x_move"
	a.push_intent(i)

func run(a: Fighter, b: Fighter, ticks: int, block: bool = false) -> Array:
	var hits: Array = []
	for t in ticks:
		var i := CombatData.Intent.new()
		i.block = block
		b.push_intent(i)
		a.tick()
		b.tick()
		if a.current_attack != null and a.is_hitbox_active() and not a.swing_has_hit and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
			var result := b.receive_hit(a.current_attack,a,1)
			a.confirm_hit(result)
			hits.append(result)
	return hits

func _initialize() -> void:
	for style in StyleRegistry.all():
		var type := style.resolve(&"x_move",false)
		var attack := CombatData.get_attack(type)
		check(attack.x_move and not attack.signature and attack.cancel_window == 0, "%s X independent committed move" % style.id)
		var total := attack.damage
		for sub in attack.sequence:
			total += CombatData.get_attack(CombatData.type_for_id(sub)).damage
		check(total == 18, "%s total 18 damage" % style.id)
		for side in [1,-1]:
			for wall in [false,true]:
				var p := pair(style,side,wall)
				var a := p[0]
				var b := p[1]
				press(a)
				a.tick()
				check(a.x_cooldown == 600 and a.focus == 0.0, "%s starts full cooldown without Focus" % style.id)
				var hits := run(a,b,110)
				check(b.health == b.max_health - 18, "%s facing %d wall %s hits 18 (%s)" % [style.id,side,wall,hits])
				var cd := a.x_cooldown
				a.stop_combat()
				check(a.x_cooldown == cd, "round stop preserves cooldown")
				press(a)
				a.tick()
				check(a.state != Fighter.State.ATTACK, "cooldown rejects repeat")
				for f in p:
					f.free()
		var p := pair(style,1)
		press(p[0])
		p[0].focus = 73.0
		var blocked := run(p[0],p[1],110,true)
		check(p[0].focus == 73.0, "X never spends Focus")
		check(not blocked.is_empty() and blocked.all(func(r): return r == CombatData.HitResult.BLOCKED), "%s normal block (%s)" % [style.id,blocked])
		check(p[0].x_cooldown > 0, "blocked cooldown persists")
		for f in p:
			f.free()
		p = pair(style,1)
		press(p[0])
		p[0].tick()
		var cd := p[0].x_cooldown
		p[0].receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT),p[1],1)
		check(p[0].state == Fighter.State.HITSTUN and not p[0].is_mid_sequence() and p[0].x_cooldown == cd, "%s no armour; interruption retains cooldown" % style.id)
		for f in p:
			f.free()
		p = pair(style,1)
		var raw := CombatData.Intent.new()
		raw.attack = type
		p[0].push_intent(raw)
		p[0].tick()
		check(p[0].x_cooldown == 600, "%s direct AI attack pays cooldown" % style.id)
		for sub in attack.sequence:
			raw.attack = CombatData.type_for_id(sub)
			p[0].push_intent(raw)
			check(p[0].buffered_attack == CombatData.AttackType.NONE, "sequence child cannot be requested directly")
		for f in p:
			f.free()
		p = pair(style,1)
		press(p[0])
		p[0].tick()
		var strike := p[0].current_attack
		p[1].call("_enter_state",Fighter.State.BLOCK)
		p[1].parry_window = 4
		var parried := p[1].receive_hit(strike,p[0],1)
		check(parried == CombatData.HitResult.PARRIED and p[0].x_cooldown == 600 and not p[0].is_mid_sequence(), "%s parry interrupts with cooldown intact" % style.id)
		for f in p:
			f.free()
		p = pair(style,1)
		press(p[0])
		p[0].tick()
		p[1].call("_enter_state",Fighter.State.DODGE)
		p[1].state_frame = CombatData.DODGE_INVULN_START
		var evaded := p[1].receive_hit(p[0].current_attack,p[0],1)
		check(evaded == CombatData.HitResult.WHIFF and p[1].health == p[1].max_health and p[0].x_cooldown == 600, "%s evade avoids X without refund" % style.id)
		for f in p:
			f.free()
		p = pair(style,1)
		p[1].position.x += 500.0
		press(p[0])
		p[0].tick()
		run(p[0],p[1],599)
		check(p[0].x_cooldown == 1 and p[1].health == p[1].max_health, "%s whiff still waits all 600 ticks" % style.id)
		p[0].tick()
		check(p[0].x_cooldown == 0, "cooldown expires after 600 ticks")
		press(p[0])
		p[0].tick()
		check(p[0].x_cooldown == 600, "ready X starts again")
		for f in p:
			f.free()
		p = pair(style,1)
		check(p[0].x_cooldown == 0, "new match fighter starts ready")
		p[0].call("_enter_state",Fighter.State.JUMP)
		p[0].airborne = true
		p[0].air_attack_used = false
		p[0].position.y -= 40.0
		p[0].velocity_y = -5.0
		press(p[0])
		p[0].tick()
		check(p[0].current_attack == null and p[0].x_cooldown == 0, "airborne X cannot turn into free attack")
		for f in p:
			f.free()
	var custom := StyleRegistry.by_id(&"boxing").duplicate(true) as MartialArtStyle
	custom.input_map[&"power_light"] = &"dempsey_hook_right"
	check(not custom.validate().is_empty(), "custom style rejects X sequence child slot mapping")
	var forged := pair(custom,1)
	var light := CombatData.Intent.new()
	light.slot = &"light"
	forged[0].push_intent(light)
	forged[0].tick()
	var chord := CombatData.Intent.new()
	chord.jump = true
	forged[0].push_intent(chord)
	check(forged[0].current_attack.type == CombatData.AttackType.LIGHT and forged[0].x_cooldown == 0, "power chord cannot inject X child even through forged custom style")
	forged[0].call("_start_attack",CombatData.AttackType.DEMPSEY_HOOK_RIGHT,1,true)
	check(forged[0].current_attack.type == CombatData.AttackType.LIGHT, "central gate rejects unauthorized child start")
	for f in forged:
		f.free()
	var landing := pair(StyleRegistry.by_id(&"bangla_maar"),1)
	press(landing[0])
	for t in 45:
		landing[0].tick()
	check(landing[0].state == Fighter.State.LAND and landing[0].landing_attack_id == &"dropkick", "dropkick retains landing visual during committed recovery")
	for t in 50:
		landing[0].tick()
	check(landing[0].landing_attack_id == &"", "landing visual clears after recovery")
	for f in landing:
		f.free()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player: Fighter = main.get_node("Player")
	var enemy: Fighter = main.get_node("Enemy")
	main.player = player
	main.enemy = enemy
	player.x_cooldown = 321
	enemy.x_cooldown = 456
	main.call("_reset_fighters",0)
	check(player.x_cooldown == 321 and enemy.x_cooldown == 456, "real round reset preserves both X cooldowns")
	main.free()
	print("X moves failures: %d" % fails)
	print("RESULT: PASS" if fails == 0 else "RESULT: FAIL")
	quit(1 if fails else 0)
