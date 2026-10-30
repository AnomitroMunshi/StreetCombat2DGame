extends SceneTree
## Two new styles: legal data, committed resources and real contacts.
var fails := 0
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func pair(style_id: StringName, side: int) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(640-side*40,560)
	b.position = Vector2(640+side*40,560)
	a.ground_y=560
	b.ground_y=560
	a.opponent=b
	b.opponent=a
	a.face_opponent()
	b.face_opponent()
	a.set_style(StyleRegistry.by_id(style_id))
	b.set_style(StyleRegistry.by_id(&"kickboxing"))
	return [a,b]

func play(a: Fighter, b: Fighter, ticks: int, block: bool = false) -> Array:
	var hits: Array=[]
	for tick in ticks:
		var intent:=CombatData.Intent.new()
		intent.block=block
		intent.crouch=a.current_attack!=null and a.current_attack.low
		b.push_intent(intent)
		a.tick()
		b.tick()
		if a.current_attack!=null and a.is_hitbox_active() and not a.swing_has_hit and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
			var attack:=a.current_attack
			var result:=b.receive_hit(attack,a,1)
			a.confirm_hit(result)
			hits.append([attack.id,result])
	return hits

func free_pair(p: Array[Fighter]) -> void:
	for f in p:
		f.free()

func total_damage(attack: CombatData.Attack) -> int:
	var out:=attack.damage
	for child in attack.sequence:
		out+=CombatData.get_attack(CombatData.type_for_id(child)).damage
	return out

func jkd_x_regression(side: int) -> void:
	var p:=pair(&"jeet_kune_do",side)
	var intent:=CombatData.Intent.new()
	intent.slot=&"x_move"
	p[0].push_intent(intent)
	var start_target:=p[1].position.x
	var hits: Array=[]
	var air_travel:=0.0
	var total_travel:=0.0
	var first_contact:=-1
	for tick in 150:
		var contact:=play(p[0],p[1],1)
		if not contact.is_empty():
			hits.append_array(contact)
			if first_contact<0:
				first_contact=tick+1
		var travel:float=(p[1].position.x-start_target)*side
		total_travel=maxf(total_travel,travel)
		if p[1].airborne:
			air_travel=maxf(air_travel,travel)
	check(hits.size()==1 and hits[0][0]==&"dragons_burst" and p[1].health==p[1].max_health-18 and first_contact==23,"JKD X is one stepping side kick after readable22-tick startup")
	check(p[0].x_cooldown==751 and p[0].focus==0,"single side-kick X charges one900-tick cooldown without Focus")
	check(air_travel>60.0 and air_travel<160.0 and total_travel>120.0 and total_travel<230.0,"side-kick clean hit produces strong short airborne recoil: air%.1f total%.1f" %[air_travel,total_travel])
	free_pair(p)
	p=pair(&"jeet_kune_do",side)
	p[1].position.x+=side*20.0 # 100px is already within the ordinary range margin.
	var start:float=p[0].position.x
	p[0].push_intent(intent)
	for tick in 23:
		p[0].tick()
	var stepped:float=(p[0].position.x-start)*side
	check(stepped>=35.0 and stepped<=40.1 and (p[1].position.x-p[0].position.x)*side>=Fighter.PUSH_HALF_WIDTH*2.0,"X takes a real bounded step even already in range (%.1fpx)" %stepped)
	free_pair(p)
	p=pair(&"jeet_kune_do",side)
	p[0].push_intent(intent)
	play(p[0],p[1],10)
	check(p[1].health==p[1].max_health,"committed stepping anticipation cannot hit early")
	var cd:=p[0].x_cooldown
	p[0].receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT),p[1],1)
	play(p[0],p[1],100)
	check(p[1].health==p[1].max_health and p[0].x_cooldown==cd-100,"side-kick startup is interruptible without cooldown refund")
	free_pair(p)
	p=pair(&"jeet_kune_do",side)
	p[1].position.x+=side*400.0
	start=p[0].position.x
	var started: Array=[]
	p[0].attack_started.connect(func(_f: Fighter, attack: CombatData.Attack): started.append(attack.id))
	p[0].push_intent(intent)
	play(p[0],p[1],80)
	stepped=(p[0].position.x-start)*side
	check(started==[&"dragons_burst"] and p[1].health==p[1].max_health and p[0].x_cooldown==821 and stepped>55.0 and stepped<70.0,"whiff stays one kick with bounded travel and full cooldown")
	free_pair(p)
	p=pair(&"jeet_kune_do",side)
	for child in [CombatData.AttackType.JKD_X_STOP,CombatData.AttackType.JKD_X_SIDE]:
		var raw:=CombatData.Intent.new()
		raw.attack=child
		p[0].push_intent(raw)
		p[0].tick()
		check(p[0].state==Fighter.State.IDLE and p[0].x_cooldown==0,"old permanent X children stay unmapped and cannot bypass the parent")
	free_pair(p)

func cap_x_launch_regression(side: int) -> void:
	for block in [false, true]:
		var p := pair(&"capoeira", side)
		var intent := CombatData.Intent.new()
		intent.slot = &"x_move"
		p[0].push_intent(intent)
		var start := p[1].position.x
		var air_travel := 0.0
		for tick in 150:
			play(p[0], p[1], 1, block)
			if p[1].airborne:
				air_travel = maxf(air_travel, (p[1].position.x - start) * side)
		if block:
			check(air_travel == 0 and p[1].health == p[1].max_health, "blocked Capoeira X does not launch or damage")
		else:
			check(air_travel > 110 and air_travel < 180 and p[1].health == p[1].max_health - 18, "Capoeira X launches strongly without increasing damage: %.1fpx airborne" % air_travel)
		check(p[0].x_cooldown == 751, "Capoeira impact retains full 15s cooldown")
		free_pair(p)

func recovery_hurtbox_regression(side: int) -> void:
	for test in [[CombatData.AttackType.CAP_CARTWHEEL,28,29,35,36],[CombatData.AttackType.MEIA_LUA_TORNADO,39,40,57,58]]:
		var p:=pair(&"capoeira",side)
		var a:=p[0]
		a.call("_start_attack",test[0],1,true)
		a.state_frame=test[1]
		var inverted:=a.get_hurtbox_world()
		a.state_frame=test[2]
		var crouched:=a.get_hurtbox_world()
		check(inverted.size.y>crouched.size.y and crouched.size.y==125.0 and crouched.size.x>=96.0,"supported body transitions to broad low recovery hurtbox")
		for frame in range(test[2],test[3]+1):
			a.state_frame=frame
			check(a.get_hurtbox_world().size==crouched.size and a.can_be_hit(),"low recovery stays vulnerable throughout authored phase")
		var ghost_head:=Rect2(a.position+Vector2(-10,-164),Vector2(20,18))
		var body_strike:=Rect2(a.position+Vector2(-10,-100),Vector2(20,25))
		check(not crouched.intersects(ghost_head) and crouched.intersects(body_strike),"high strike above crouched body whiffs while body strike still contacts")
		a.state_frame=test[4]
		check(a.get_hurtbox_world().size==Fighter.HURTBOX.size,"upright hurtbox returns at authored guard recovery")
		free_pair(p)

func sweep_geometry_regression(side: int) -> void:
	for signature in [false,true]:
		var p:=pair(&"capoeira",side)
		var intent:=CombatData.Intent.new()
		if signature:
			p[0].focus=CombatData.FOCUS_MAX
			intent.signature=true
		else:
			intent.slot=&"down_heavy"
		p[0].push_intent(intent)
		p[0].tick()
		var attack:=p[0].current_attack
		p[0].state_frame=attack.startup
		var head_world:=p[0].position+Vector2(-50*side,-86)
		var heel_world:=p[0].position+Vector2(85*side,-11)
		check(p[0].get_hurtbox_world().has_point(head_world) and p[0].can_be_hit(),"low sweep counterleaning head remains in vulnerable mirrored hurtbox")
		check(attack.low and p[0].get_hitbox_world().has_point(heel_world),"low sweep hitbox follows the floor-level heel while requiring low guard")
		free_pair(p)

func _initialize() -> void:
	check(StyleRegistry.count()==9 and StyleRegistry.rejected().is_empty(),"nine registered styles without rejected data")
	for sid in [&"capoeira",&"jeet_kune_do"]:
		var style:=StyleRegistry.by_id(sid)
		check(style!=null and style.validate().is_empty(),"%s validates" %sid)
		if style==null:
			continue
		check(style.stance>=11 and Stances.pose(style.stance).size()==14,"new append-only stance has all pose channels")
		for slot in MartialArtStyle.SLOTS:
			check(style.resolve(slot,false)!=CombatData.AttackType.NONE,"%s maps %s" %[sid,slot])
		var signature:=CombatData.get_attack(CombatData.type_for_id(style.signature))
		var total:=0
		for child in signature.sequence:
			var attack:=CombatData.get_attack(CombatData.type_for_id(child))
			total+=attack.damage
			check(attack.x_strike and style.allows(attack.type),"signature child is internal and style-legal")
		check(signature.signature and total==24,"%s signature sums exactly24" %sid)
		for meter in [0.0,50.0,100.0]:
			var p:=pair(sid,1)
			p[0].focus=meter
			var raw_f:=CombatData.Intent.new()
			raw_f.attack=signature.type
			p[0].push_intent(raw_f)
			p[0].tick()
			check(p[0].state==Fighter.State.IDLE and p[0].focus==meter and p[0].rejected_attacks==1,"raw signature wrapper cannot bypass F/Focus at meter%.0f" %meter)
			p[0].call("_start_attack",signature.type,1,true)
			check(p[0].state==Fighter.State.IDLE and p[0].focus==meter,"central signature start requires authorized Focus path")
			p[0].focus=CombatData.FOCUS_MAX
			var proper_f:=CombatData.Intent.new()
			proper_f.signature=true
			p[0].push_intent(proper_f)
			var legal_hits:=play(p[0],p[1],150)
			check(legal_hits.size()==signature.sequence.size() and p[1].health==p[1].max_health-24 and p[0].focus==0.0,"normal F still pays Focus and completes all authorized child continuations")
			free_pair(p)
		var x:=CombatData.get_attack(style.resolve(&"x_move",false))
		check(total_damage(x)==18 and x.x_cooldown_frames==900 and not x.signature,"%s X18 damage,15 seconds,no Focus" %sid)
		for side in [1,-1]:
			var p:=pair(sid,side)
			p[0].focus=CombatData.FOCUS_MAX
			var intent:=CombatData.Intent.new()
			intent.signature=true
			p[0].push_intent(intent)
			var hits:=play(p[0],p[1],150)
			check(p[1].health==p[1].max_health-24 and hits.size()==signature.sequence.size(),"%s F all strikes24 damage facing%d (%s)" %[sid,side,hits])
			check(p[0].focus==0 and p[0].x_cooldown==0,"F spends Focus exactly once and leaves X ready")
			free_pair(p)
			p=pair(sid,side)
			intent=CombatData.Intent.new()
			intent.slot=&"x_move"
			p[0].push_intent(intent)
			hits=play(p[0],p[1],100)
			check(p[1].health==p[1].max_health-18 and hits.size()==maxi(1,x.sequence.size()) and p[0].x_cooldown==801,"%s X authored contacts and committed cooldown facing%d" %[sid,side])
			free_pair(p)
			p=pair(sid,side)
			p[0].push_intent(intent)
			hits=play(p[0],p[1],100,true)
			check(p[1].health==p[1].max_health and hits.size()==maxi(1,x.sequence.size()) and hits.all(func(hit): return hit[1]==CombatData.HitResult.BLOCKED),"%s X normal block facing%d" %[sid,side])
			free_pair(p)
			p=pair(sid,side)
			p[0].push_intent(intent)
			p[0].tick()
			p[1].call("_enter_state",Fighter.State.BLOCK)
			p[1].parry_window=4
			check(p[1].receive_hit(p[0].current_attack,p[0],1)==CombatData.HitResult.PARRIED and p[0].x_cooldown==900,"%s X parry without cooldown refund" %sid)
			free_pair(p)
			p=pair(sid,side)
			p[0].focus=CombatData.FOCUS_MAX
			intent=CombatData.Intent.new()
			intent.signature=true
			p[0].push_intent(intent)
			p[0].tick()
			p[0].receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT),p[1],1)
			check(p[0].state==Fighter.State.HITSTUN and not p[0].is_mid_sequence(),"%s signature interrupt drops remaining strikes" %sid)
			intent=CombatData.Intent.new()
			intent.attack=CombatData.type_for_id(signature.sequence[0])
			p[0].push_intent(intent)
			check(p[0].buffered_attack==CombatData.AttackType.NONE,"signature children cannot be directly injected")
			free_pair(p)
		for side in [1,-1]:
			for slot in MartialArtStyle.SLOTS:
				var p:=pair(sid,side)
				var intent:=CombatData.Intent.new()
				intent.slot=slot
				p[0].push_intent(intent)
				var mapped:=CombatData.get_attack(style.resolve(slot,false))
				var contacts:=play(p[0],p[1],100)
				check(p[1].health==p[1].max_health-total_damage(mapped) and contacts.size()==maxi(1,mapped.sequence.size()),"%s %s actual authored contacts match damage facing%d" %[sid,slot,side])
				free_pair(p)
		# Another martial art cannot inject any of this style's exclusive X/F moves.
		var wrong:=pair(&"boxing",1)
		var raw:=CombatData.Intent.new()
		raw.attack=x.type
		wrong[0].push_intent(raw)
		check(wrong[0].buffered_attack==CombatData.AttackType.NONE and wrong[0].rejected_attacks==1,"foreign style rejects %s X" %sid)
		free_pair(wrong)
	for side in [1,-1]:
		jkd_x_regression(side)
		cap_x_launch_regression(side)
		recovery_hurtbox_regression(side)
		sweep_geometry_regression(side)
		var p:=pair(&"capoeira",side)
		var intent:=CombatData.Intent.new()
		intent.slot=&"technique"
		p[0].push_intent(intent)
		p[0].tick()
		var standing:=p[0].get_hurtbox_world()
		for tick in 9:
			p[0].tick()
		var support:=p[0].get_hurtbox_world()
		check(support.size.x>standing.size.x and support.size.y<standing.size.y and p[0].can_be_hit(),"hand-supported Capoeira uses wider authored hurtbox without invulnerability")
		p[0].call("_enter_state",Fighter.State.IDLE)
		check(p[0].get_hurtbox_world().size==standing.size,"support hurtbox clears outside authored attack")
		free_pair(p)
	for kick in [CombatData.AttackType.CAP_SPIN_HEEL,CombatData.AttackType.CAP_CARTWHEEL,CombatData.AttackType.CAP_CRESCENT,CombatData.AttackType.CAP_LOW_SWEEP,CombatData.AttackType.JKD_HIGH_HOOK]:
		check(CombatData.focus_for_hit(CombatData.get_attack(kick),false)==CombatData.FOCUS_KICK,"new kicks use the existing kick Focus gain")
	print("RESULT: PASS" if fails==0 else "RESULT: FAIL (%d)" %fails)
	quit(0 if fails==0 else 1)
