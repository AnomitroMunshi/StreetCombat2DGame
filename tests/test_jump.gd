extends SceneTree
## Voluntary jump arc and momentum (CombatData.JUMP_*), and that knockbacks
## keep the shared physics. Both facing directions.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


## Jumps with `hold` (relative to facing) held from takeoff; `flip_at` (air
## tick) reverses it, `release_at` lets go. Returns [apex, air ticks, distance].
func _jump(side: int, hold: int, flip_at: int = -1, release_at: int = -1) -> Array:
	var f := Fighter.new()
	root.add_child(f)
	f.position = Vector2(640.0, 560.0)
	f.ground_y = 560.0
	f.facing = side
	var start := f.position.x
	var apex := 0.0
	var air := 0
	for t in 120:
		var i := CombatData.Intent.new()
		var h := hold
		if flip_at >= 0 and air >= flip_at:
			h = -hold
		if release_at >= 0 and air >= release_at:
			h = 0
		i.move = h * side
		i.jump = t == 0
		f.push_intent(i)
		f.tick()
		if f.airborne:
			air += 1
			apex = maxf(apex, 560.0 - f.position.y)
		elif air > 0:
			break
	var dist := (f.position.x - start) * side
	f.queue_free()
	return [apex, air, dist]


func _initialize() -> void:
	for side in [1, -1]:
		print("[facing %s]" % ("right" if side == 1 else "left"))
		var n := _jump(side, 0)
		_check(n[0] > 118.0 and n[0] < 138.0, "neutral apex ~128 px (%.0f)" % n[0])
		_check(n[1] >= 32 and n[1] <= 38, "about 35 ticks in the air (%d)" % n[1])
		_check(absf(n[2]) < 0.5, "neutral jump stays put (%.1f)" % n[2])
		var fwd := _jump(side, 1)
		var back := _jump(side, -1)
		_check(fwd[2] > 140.0 and fwd[2] < 170.0, "forward jump ~155 px (%.0f)" % fwd[2])
		_check(back[2] < -95.0 and back[2] > -125.0, "back jump ~110 px, shorter (%.0f)" % back[2])
		var rev := _jump(side, 1, 17)
		_check(rev[2] > 60.0 and rev[2] < fwd[2] - 15.0, "reversing at the apex slows the jump, never snaps round (%.0f)" % rev[2])
		var rel := _jump(side, 1, -1, 17)
		_check(rel[2] > rev[2] and rel[2] < fwd[2], "releasing keeps most of the momentum (%.0f)" % rel[2])

	print("[knockbacks keep the shared physics]")
	var v := Fighter.new()
	root.add_child(v)
	v.position = Vector2(640.0, 560.0)
	v.ground_y = 560.0
	v.call("_enter_state", Fighter.State.KNOCKDOWN)
	v.blowback(1, 0.0, -10.0, 0, false)
	var peak := 0.0
	for t in 60:
		v.tick()
		peak = maxf(peak, 560.0 - v.position.y)
	# -10 at GRAVITY_RISE 0.95: about 10 * 10.5 / 2 = 53 px (not the jump arc).
	_check(peak > 45.0 and peak < 60.0 and not v.jump_arc, "a -10 launch peaks ~53 px under the shared gravity (%.0f)" % peak)
	v.queue_free()

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
