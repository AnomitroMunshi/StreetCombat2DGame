extends SceneTree
## Visible X head flinches: immediate during hitstop, ordinary timed recovery,
## mirrored grounded anatomy, and head/shoulder clearance at both pillars.
var failures: int = 0
var probes: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	for id: StringName in [&"scorpion_kick", &"step_back_spinning_backfist"]:
		for side in [1, -1]:
			for wall in [false, true]:
				probe(id, side, wall)
	check(probes == 8, "all facing/wall probes completed")
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " X flinch: ", failures, " failures")
	quit(0 if failures == 0 else 1)

func probe(id: StringName, side: int, wall: bool) -> void:
	var scene := load("res://scenes/fighter.tscn") as PackedScene
	var a := scene.instantiate() as Fighter
	var b := scene.instantiate() as Fighter
	b.position = Vector2((Fighter.ARENA_MAX_X - 5.0 if side == 1 else Fighter.ARENA_MIN_X + 5.0) if wall else 640.0, 560.0)
	a.position = b.position - Vector2(side * 90.0, 0.0)
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.ground_y = 560.0
	b.ground_y = 560.0
	a.face_opponent()
	b.face_opponent()
	b.set_style(StyleRegistry.by_id(&"karate"))
	var v := b.get_node("Visual") as FighterVisual
	v._sync_stance()
	v._pose_ready = true
	v._pose = v._guard.duplicate()
	var guard_joints := v._solve_joints(v._guard)
	var root_before := b.position
	var attack := CombatData.get_attack(CombatData.type_for_id(id))
	var result := b.receive_hit(attack, a, 1)
	b.hitstop_frames = attack.hitstop
	v._process(1.0 / 60.0)
	var prefix := "%s side%s wall%s " % [id, side, wall]
	check(result == CombatData.HitResult.HIT and v._has_x_flinch(), prefix + "clean grounded hit selects flinch")
	check(v._pose[FighterVisual.TORSO] < 0.0 and v._pose[FighterVisual.HEAD] < 0.0, prefix + "snap visible during frozen contact")
	var j := v._solve_joints(v._pose)
	var away := (j[FighterVisual.J_HEAD].x - guard_joints[FighterVisual.J_HEAD].x) * b.facing * side
	check(away > (15.0 if wall else 35.0), prefix + "head snaps away in world facing (%.2fpx)" % away)
	check(b.position == root_before and b.state == Fighter.State.HITSTUN and not b.airborne, prefix + "no root teleport or new control state")
	check(v._pose[FighterVisual.SH_F] < v._pose[FighterVisual.TH_F], prefix + "knees soften under recoil")
	check(absf(j[FighterVisual.J_HIP].distance_to(j[FighterVisual.J_NECK]) - FighterVisual.TORSO_LEN) < 2.0, prefix + "torso length preserved")
	check(absf(j[FighterVisual.J_ELBOW_F].distance_to(j[FighterVisual.J_HAND_F]) - FighterVisual.FOREARM) < 0.01, prefix + "forearm length preserved")
	check(j[FighterVisual.J_HEAD].y + FighterVisual.HEAD_R < 0.0 and maxf(j[FighterVisual.J_FOOT_F].y, j[FighterVisual.J_FOOT_B].y) < 6.0, prefix + "grounded joints stay within planted-foot correction")
	check(v._x_flinch_fits(v._pose), prefix + "head and shoulders clear both wall faces")
	var early := v._x_flinch_pose(3.0)
	var held := v._x_flinch_pose(5.0)
	check(early == held, prefix + "holds first six ticks")
	var recovered := v._x_flinch_pose(float(b.stun_frames))
	check(recovered == v._guard, prefix + "guard restored within existing hitstun")
	b.state = Fighter.State.BLOCKSTUN
	check(not v._has_x_flinch(), prefix + "stale context does not alter block reaction")
	b.state = Fighter.State.PARRY
	check(not v._has_x_flinch(), prefix + "stale context does not alter parry")
	b.state = Fighter.State.HITSTUN
	b.last_hit_attack_id = &"jab"
	check(not v._has_x_flinch(), prefix + "ordinary hit keeps ordinary reaction")
	a.free()
	b.free()
	probes += 1
