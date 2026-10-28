extends SceneTree
## Actual simulation outcomes: launch travel, fast strikes and committed root motion.
var fails := 0
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func pair(style: StringName, side: int) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(640.0-side*40.0,560.0)
	b.position = Vector2(640.0+side*40.0,560.0)
	a.ground_y=560.0
	b.ground_y=560.0
	a.opponent=b
	b.opponent=a
	a.face_opponent()
	b.face_opponent()
	a.set_style(StyleRegistry.by_id(style))
	b.set_style(StyleRegistry.by_id(&"karate"))
	return [a,b]

func simulate(style: StringName, side: int, blocking: bool = false, move: CombatData.AttackType = CombatData.AttackType.NONE) -> Dictionary:
	var p := pair(style,side)
	var a := p[0]
	var b := p[1]
	var start := b.position.x
	var air_travel := 0.0
	var peak_height := 0.0
	var attack_airborne := false
	var knocked_down := false
	var travel := 0.0
	var times: Array = []
	var clock := 0
	var health := b.health
	var press := CombatData.Intent.new()
	if move == CombatData.AttackType.NONE:
		press.slot=&"x_move"
	else:
		press.attack=move
	a.push_intent(press)
	for tick in 150:
		var hold := CombatData.Intent.new()
		hold.block = blocking
		b.push_intent(hold)
		a.tick()
		b.tick()
		clock += 1
		if a.current_attack != null and a.is_hitbox_active() and not a.swing_has_hit and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
			var attack := a.current_attack
			attack_airborne = attack_airborne or a.airborne
			var result := b.receive_hit(attack,a,1)
			a.confirm_hit(result)
			times.append(clock)
			if result == CombatData.HitResult.HIT:
				clock += attack.hitstop # match freezes both fighters during hitstop
		knocked_down = knocked_down or b.state == Fighter.State.KNOCKDOWN
		travel = maxf(travel,(b.position.x-start)*side)
		peak_height=maxf(peak_height,b.ground_y-b.position.y)
		if b.airborne:
			air_travel=maxf(air_travel,(b.position.x-start)*side)
	var out := {"travel":travel,"air_travel":air_travel,"peak_height":peak_height,"times":times,"damage":health-b.health,"cooldown":a.x_cooldown,"attack_airborne":attack_airborne,"knocked_down":knocked_down}
	for f in p:
		f.free()
	return out

func check_flinch_context(style: StringName, side: int) -> void:
	for defense in [&"clean",&"block",&"parry"]:
		var p := pair(style,side)
		var a := p[0]
		var b := p[1]
		var intent := CombatData.Intent.new()
		intent.slot = &"x_move"
		a.push_intent(intent)
		a.tick()
		var attack := a.current_attack
		if defense != &"clean":
			b.call("_enter_state",Fighter.State.BLOCK)
			b.state_frame = CombatData.BLOCK_STARTUP_FRAMES
			b.block_held = true
			if defense == &"parry":
				b.parry_window = 4
		var result := b.receive_hit(attack,a,1)
		if defense == &"clean":
			check(result == CombatData.HitResult.HIT and b.last_hit_attack_id == attack.id and b.state == Fighter.State.HITSTUN and b.stun_frames == attack.hitstun and not b.airborne,"%s clean hit retains move-specific flinch context with ordinary hitstun facing%d" %[style,side])
			check(b.health == b.max_health - 18 and a.x_cooldown == 600,"flinch keeps normal damage and cooldown")
			b.tick()
			check(b.last_hit_attack_id == attack.id and b.state == Fighter.State.HITSTUN,"flinch context persists during ordinary reaction")
			b.receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT),a,1)
			check(b.last_hit_attack_id == &"jab","next ordinary clean hit replaces special flinch context")
		else:
			var expected := CombatData.HitResult.BLOCKED if defense == &"block" else CombatData.HitResult.PARRIED
			check(result == expected and b.last_hit_attack_id == &"" and b.health == b.max_health and a.x_cooldown == 600,"%s %s does not trigger clean flinch facing%d" %[style,defense,side])
		for f in p:
			f.free()

func _initialize() -> void:
	for side in [1,-1]:
		check_flinch_context(&"kung_fu",side)
		check_flinch_context(&"karate",side)
		var big := simulate(&"kickboxing",side)
		check(big.damage==18 and big.air_travel>=250.0 and big.air_travel<=350.0,"Big Foot airborne travel facing %d: %s" %[side,big])
		check(big.cooldown==900-149,"long launch pays 15-second cooldown")
		var drop := simulate(&"bangla_maar",side)
		check(drop.damage==18 and drop.air_travel>=150.0 and drop.air_travel<=220.0,"Dropkick airborne travel facing %d: %s" %[side,drop])
		check(drop.cooldown==900-149,"dropkick pays 15-second cooldown")
		var thai := simulate(&"muay_thai",side)
		check(thai.cooldown==900-149,"Thai knockdown pays 15-second cooldown")
		var ordinary := simulate(&"muay_thai",side,false,CombatData.AttackType.BODY_ROUNDHOUSE)
		check(thai.damage==18 and thai.travel>80.0 and thai.travel>ordinary.travel*2.0 and thai.air_travel>60.0 and thai.air_travel<150.0 and thai.peak_height<35.0,"Thai Roundhouse heavy lateral recoil facing%d: X %s vs ordinary %s" %[side,thai,ordinary])
		var box := simulate(&"boxing",side)
		check(box.damage==18 and box.times.size()==2 and box.travel>=90.0 and box.travel<=120.0,"Dempsey two hooks forceful final travel facing %d: %s" %[side,box])
		check(box.cooldown==600-149,"Dempsey keeps 10-second cooldown")
		var scorpion := simulate(&"kung_fu",side)
		check(scorpion.damage==18 and scorpion.times==[19] and not scorpion.attack_airborne and not scorpion.knocked_down and scorpion.cooldown==600-149,"Scorpion contacts after fast grounded 18-tick startup, keeps normal hitstun/10s cooldown: %s" %scorpion)
		var tkd := simulate(&"taekwondo",side)
		check(tkd.cooldown==900-149,"fast triple pays 15-second cooldown")
		check(tkd.damage==18 and tkd.times==[13,22,31],"Triple Kick fast contact incl hitstop facing %d: %s" %[side,tkd])
		for style in [&"kickboxing",&"bangla_maar",&"muay_thai"]:
			var blocked := simulate(style,side,true)
			check(blocked.damage==0 and blocked.air_travel==0.0 and blocked.cooldown>0,"block avoids forceful launch %s facing%d" %[style,side])
		var p := pair(&"karate",side)
		p[1].position.x += side * 25.0 # 105px gap: already inside ordinary range + margin
		var a:=p[0]
		var start:=a.position.x
		var press:=CombatData.Intent.new()
		press.slot=&"x_move"
		a.push_intent(press)
		for tick in 6:
			a.tick()
		var back:float=(a.position.x-start)*side
		for tick in 12:
			a.tick()
		var spin_travel:float=(a.position.x-start)*side-back
		check(spin_travel>40.0 and a.state_frame==17 and a.current_attack.startup==18,"Karate travels during faster spin while already in range: %.1f" %spin_travel)
		for tick in 5:
			a.tick()
		check((p[1].position.x-a.position.x)*side>=Fighter.PUSH_HALF_WIDTH*2.0,"travelling Karate respects opposing body")
		for f in p:
			f.free()
	check(StyleRegistry.by_id(&"kung_fu").resolve(&"x_move",false)==CombatData.AttackType.SCORPION_KICK,"Kung Fu maps Scorpion")
	check(StyleRegistry.by_id(&"muay_thai").resolve(&"x_move",false)==CombatData.AttackType.THAI_ROUNDHOUSE,"Muay maps Thai Roundhouse")
	check(CombatData.type_for_id(&"butterfly_kick")==CombatData.AttackType.BUTTERFLY_KICK and CombatData.type_for_id(&"retreating_jump_elbow")==CombatData.AttackType.RETREATING_JUMP_ELBOW,"old permanent IDs retained")
	print("RESULT: PASS" if fails==0 else "RESULT: FAIL (%d)" %fails)
	quit(0 if fails==0 else 1)
