extends SceneTree
## The real AI against a player who keeps throwing readable side kicks (startup
## 9). Seeded, so reproducible. The AI should block most, parry some (never
## all), and punish the stagger after a parry.

class Driver extends Node:
	var tree: SceneTree
	var frame: int = 0
	var fails: int = 0
	var kicks: int = 0
	var parries: int = 0
	var blocks: int = 0
	var punishes: int = 0
	var prev_enemy_state: int = -1

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if frame == 1:
			main.call("select_style", &"taekwondo")  # readable side kicks to parry
			main.call("start_match", true)
			# This test is about defensive choices: a patient rival, so most kicks
			# meet a guard (or a parry) rather than a trade.
			(main.get_node("EnemyAI") as EnemyAI).aggression = 0.2
		for a in ["attack_kick", "move_left", "move_right"]:
			Input.action_release(a)
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		# Keep the player alive and the round going: this test is about defense.
		p.health = maxi(p.health, 60)
		e.health = maxi(e.health, 60)
		var dist := absf(e.position.x - p.position.x)
		if dist > 115.0:
			Input.action_press("move_right" if e.position.x > p.position.x else "move_left")
		elif frame % 45 == 0 and p.can_act():
			Input.action_press("attack_kick")
			kicks += 1
		if e.state != prev_enemy_state:
			if e.state == Fighter.State.PARRY:
				parries += 1
			elif e.state == Fighter.State.BLOCKSTUN:
				blocks += 1
		prev_enemy_state = e.state
		if p.state == Fighter.State.STAGGER and e.state == Fighter.State.ATTACK and e.get_phase() == Fighter.Phase.STARTUP and e.state_frame == 1:
			punishes += 1
		if frame == 3600:
			print("  kicks %d  enemy parries %d  blocks %d  punish attempts %d" % [kicks, parries, blocks, punishes])
			check(parries > 0, "AI parries sometimes")
			check(blocks > parries, "AI blocks more often than it parries")
			check(parries < kicks / 2, "AI does not parry everything")
			check(punishes > 0, "AI counter-attacks a staggered player")
			print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
			tree.quit(fails)


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.process_physics_priority = -100
	root.add_child(d)
