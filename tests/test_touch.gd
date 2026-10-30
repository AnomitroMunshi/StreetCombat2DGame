extends SceneTree
## Touch controls, driven with real screen touch / drag events (Boxing):
## hidden on menus, shown in the fight; the clock joystick's zones; 12 flick
## jumps; 12 hold + J is W+J; beyond 12 + J is Space+J; 3 walks; double flick
## 3 dashes; 2 jumps right; 6 crouches; 6 + K is S+K; 6 -> 4 flick rolls;
## J / K / L / BLOCK press their actions; F only at full Focus.

var main: Node
var tc: TouchControls
var p: Fighter
var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	GameSettings.file = "user://test_touch_tmp.cfg"  # never the player's file
	GameSettings.touch_controls = true
	call_deferred("run")


func ticks(n: int) -> void:
	for i in n:
		await physics_frame


## Window coordinates of a canvas point (the headless window is not 1280 x 720).
func screen(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


func touch(index: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = down
	ev.position = screen(pos)
	root.push_input(ev)


func drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = screen(pos)
	root.push_input(ev)


## Thumb down on the stick, pushed to `offset` (clock direction), held.
func stick(offset: Vector2) -> void:
	touch(0, TouchControls.STICK_CENTRE, true)
	drag(0, TouchControls.STICK_CENTRE + offset)


func stick_to(offset: Vector2) -> void:
	drag(0, TouchControls.STICK_CENTRE + offset)


func stick_off() -> void:
	touch(0, TouchControls.STICK_CENTRE, false)


func button(id: StringName, down: bool) -> void:
	for b in TouchControls.BUTTONS:
		if b[0] == id:
			touch(1, b[2], down)


## Back to neutral, standing apart, able to act.
func reset() -> void:
	stick_off()
	for id in [&"j", &"k", &"l", &"block"]:
		button(id, false)
	await ticks(2)
	main.call("_reset_fighters", 0)
	await ticks(30)


func attack_id() -> String:
	return String(p.current_attack.id) if p.current_attack != null else "nothing"


func move_id(slot: StringName) -> String:
	return String(CombatData.get_attack(p.style.resolve(slot, false)).id)


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await ticks(2)
	tc = main.get("touch")
	p = main.get_node("Player")
	main.call("select_style", &"boxing")
	main.call("confirm_style")
	await ticks(2)
	print("[visibility]")
	check(not tc.is_shown(), "hidden on the pre-match screen")
	main.call("start_match", true)
	main.get_node("EnemyAI").setup(null, null)
	await ticks(4)
	check(tc.is_shown(), "shown in the fight (TOUCH CONTROLS on)")
	var R := TouchControls.STICK_RADIUS
	var Z := TouchControls.Zone
	print("[zones]")
	check(TouchControls.zone_for(Vector2(0, -R)) == Z.N and TouchControls.zone_for(Vector2(0, -R * 1.5)) == Z.BEYOND_N
		and TouchControls.zone_for(Vector2(R, 0)) == Z.E and TouchControls.zone_for(Vector2(R, R)) == Z.SE
		and TouchControls.zone_for(Vector2(-R, -R)) == Z.NW and TouchControls.zone_for(Vector2(5, 5)) == Z.NONE,
		"eight clock zones, beyond-12 and a neutral dead zone")

	print("[joystick]")
	await reset()
	stick(Vector2(0, -R))
	await ticks(4)
	stick_to(Vector2.ZERO)
	await ticks(12)  # the jump's crouch comes first
	check(p.airborne, "12 flick jumps")
	await reset()
	stick(Vector2(0, -R))
	await ticks(3)
	button(&"j", true)
	await ticks(3)
	check(attack_id() == move_id(&"up_light"), "12 hold + J is W+J (%s)" % attack_id())
	button(&"j", false)
	await ticks(10)
	check(not p.airborne, "a 12 used for an attack does not also jump")
	await reset()
	stick(Vector2(0, -R * 1.6))
	await ticks(3)
	button(&"j", true)
	await ticks(3)
	check(attack_id() == move_id(&"power_light"), "beyond 12 + J is Space+J (%s)" % attack_id())
	button(&"j", false)
	await reset()
	var x0 := p.position.x
	stick(Vector2(R, 0))
	await ticks(20)
	check(p.position.x > x0 + 10.0, "3 walks right (%.0f px)" % (p.position.x - x0))
	await reset()
	stick(Vector2(R, 0))
	await ticks(3)
	stick_to(Vector2.ZERO)
	await ticks(3)
	stick_to(Vector2(R, 0))
	await ticks(2)
	check(p.state == Fighter.State.DODGE, "double flick 3 dashes (%s)" % Fighter.State.keys()[p.state])
	await reset()
	x0 = p.position.x
	stick(Vector2(R, -R))
	await ticks(12)
	check(p.airborne and p.position.x > x0 + 5.0, "2 jumps right (%.0f px)" % (p.position.x - x0))
	await reset()
	stick(Vector2(0, R))
	await ticks(4)
	check(p.is_crouched(), "6 hold crouches")
	button(&"k", true)
	await ticks(3)
	check(attack_id() == move_id(&"down_heavy"), "6 + K is S+K (%s)" % attack_id())
	button(&"k", false)
	await reset()
	stick(Vector2(0, R))
	await ticks(6)
	stick_to(Vector2(R, R))
	await ticks(3)
	check(p.state == Fighter.State.EVADE_ROLL, "6 -> 4 flick rolls (%s)" % Fighter.State.keys()[p.state])

	print("[buttons]")
	await reset()
	button(&"l", true)
	await ticks(1)
	check(Input.is_action_pressed(&"attack_technique") and tc.is_pressed(&"l"), "L presses technique")
	button(&"l", false)
	await ticks(1)
	check(not Input.is_action_pressed(&"attack_technique"), "lifting the finger releases it")
	await reset()
	button(&"block", true)
	await ticks(8)
	check(p.state == Fighter.State.BLOCK, "the BLOCK pill blocks while held (%s)" % Fighter.State.keys()[p.state])
	button(&"block", false)
	p.focus = 0.0
	await ticks(1)
	check(not tc.f_visible(), "F is hidden below full Focus")
	p.focus = CombatData.FOCUS_MAX
	await ticks(1)
	check(tc.f_visible(), "F appears at full Focus")
	await reset()
	GameSettings.touch_controls = false
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
