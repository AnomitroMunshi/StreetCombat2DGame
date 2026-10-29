extends SceneTree
## New styles work through real selector/training UI and legal AI anti-air.
var fails := 0
func check(ok: bool, message: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + message)
	if not ok:
		fails += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var screen := Rect2(0, 0, 1280, 720)
	for sid in [&"capoeira", &"jeet_kune_do"]:
		StyleRegistry.skip_selection = false
		var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		await process_frame
		main.call("select_style", sid)
		await process_frame
		await process_frame
		var hud: Hud = main.get_node("HUD")
		var cards: GridContainer = hud.get("_cards")
		var confirm: Button = hud.get("_confirm")
		check(cards.get_child_count() == 9 and cards.columns == 3, "nine cards in a 3 by 3 selector")
		var visible_cards := true
		var names_fit := true
		for card: Button in cards.get_children():
			visible_cards = visible_cards and screen.encloses(card.get_global_rect())
			var title := card.text.split("\n")[0]
			var font := card.get_theme_font("font")
			names_fit = names_fit and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, card.get_theme_font_size("font_size")).x <= card.size.x - 20.0
		check(visible_cards and screen.encloses(confirm.get_global_rect()), "%s: every card and confirm stay onscreen" % sid)
		check(names_fit, "full style names fit each card")
		var player: Fighter = main.get_node("Player")
		var enemy: Fighter = main.get_node("Enemy")
		check(player.style.id == sid and enemy.style.id != sid, "%s selectable and rival differs" % sid)
		check(confirm.text.contains(player.style.display_name.to_upper()), "confirm includes complete style name")
		main.call("confirm_style")
		main.call("start_training")
		var tr: TrainingMode = main.get("training")
		check(tr != null and tr.player.style.id == sid and tr.info_text().contains("no Focus"), "%s enters training with X information" % sid)
		var seen := {}
		for i in 9:
			main.call("training_action", &"dummy_style")
			seen[enemy.style.id] = true
		check(seen.size() == 9 and seen.has(&"capoeira") and seen.has(&"jeet_kune_do"), "training dummy cycles through all nine styles")
		main.queue_free()
		await process_frame
		# Fresh AI at zero Focus/cooldown, target visibly descending.
		var me := Fighter.new()
		var target := Fighter.new()
		root.add_child(me)
		root.add_child(target)
		me.set_style(StyleRegistry.by_id(sid))
		me.position = Vector2(550, 560)
		target.position = Vector2(630, 520)
		me.opponent = target
		target.opponent = me
		me.face_opponent()
		target.face_opponent()
		target.airborne = true
		target.velocity_y = 2.0
		var ai := EnemyAI.new()
		root.add_child(ai)
		ai.setup(me, target)
		ai.anti_air_chance = 1.0
		var intent := ai.compute_intent()
		check(intent.attack == CombatData.AttackType.RISING_ELBOW and me.style.allows(intent.attack), "%s: AI selects legal rising anti-air" % sid)
		me.push_intent(intent)
		me.tick()
		check(me.current_attack != null and me.current_attack.type == intent.attack and me.rejected_attacks == 0, "new-style anti-air starts without illegal fallback")
		ai.free()
		me.free()
		target.free()
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
