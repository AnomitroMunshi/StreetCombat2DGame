extends SceneTree
## -- <style> <action> <mods|-> <gap> <ticks,...> <out_prefix> [rival] [block]
## One move, pressed at tick 40 against a standing (or blocking) rival; saves
## the window at each listed tick after the press (out_prefix_<tick>.png).
var main: Node
var n := 0
var a: PackedStringArray
var ticks: Array = []
func _initialize() -> void:
	a = OS.get_cmdline_user_args()
	for t in a[4].split(","): ticks.append(int(t))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	n += 1
	var p: Fighter = main.get_node("Player")
	var e: Fighter = main.get_node("Enemy")
	main.hud.visible = false
	if n == 2:
		main.call("select_style", StringName(a[0]))
		e.set_style(StyleRegistry.by_id(StringName(a[6]) if a.size() > 6 else &"karate"))
		main.call("start_match", true)
		(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
	if n == 30:
		e.position.x = 640.0 + float(a[3]) * 0.5
		p.position.x = 640.0 - float(a[3]) * 0.5
		p.face_opponent(); e.face_opponent()
		p.reset_physics_interpolation(); e.reset_physics_interpolation()
	if a.size() > 7 and n > 20:
		var it := CombatData.Intent.new(); it.block = true; e.push_intent(it)
	if n == 40:
		if a[2] != "-": for m in a[2].split("+"): Input.action_press(m)
		Input.action_press(a[1])
	if n == 42: Input.action_release(a[1])
	if n == 70 and a[2] != "-": for m in a[2].split("+"): Input.action_release(m)
	var k := n - 40
	if k in ticks:
		root.get_texture().get_image().save_png("%s_%03d.png" % [a[5], k])
	if k > ticks.max() + 1: quit()
	return false
