class_name GameAudio
extends Node
## Procedural sound effects (synthesized in _ready) and the music. Music: the
## menu theme and each style's own track are files (MUSIC_FILES); a style with
## no track yet plays the procedural loop, rendered on a worker thread. Tracks
## crossfade on a dedicated Music bus; the same track is never restarted.

const MIX_RATE: int = 22050
const VOICES: int = 14
const BGM_VOLUME_DB: float = -12.0
const BGM_BPM: float = 140.0
const BGM_BARS: int = 16
## Headroom for stacked impacts; a hard limiter on the master bus catches the rest.
const SFX_VOLUME_DB: float = -5.0
const LIMITER_CEILING_DB: float = -1.0

var _sfx: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Music id -> [file, gain dB]. Gains match each track's measured loudness to
## the procedural loop's (about -22 dBFS mean as heard). Add a style's track
## here when it exists; until then that style plays the procedural loop.
const MUSIC_FILES: Dictionary = {
	&"menu": ["res://assets/audio/music/originals/menu_theme.mp3", -4.5],
	&"boxing": ["res://assets/audio/music/originals/boxing_theme.mp3", -5.8],
	&"muay_thai": ["res://assets/audio/music/originals/muay_thai_theme.mp3", -4.2],
	&"kung_fu": ["res://assets/audio/music/originals/kung_fu_theme.mp3", -3.9],
	&"bangla_maar": ["res://assets/audio/music/originals/bangla_maar_theme.mp3", -4.4],
}
const MUSIC_BUS: StringName = &"Music"
const MUSIC_FADE_TIME: float = 0.8
const SILENT_DB: float = -60.0

## The playing music player (and the one fading out under it).
var _bgm: AudioStreamPlayer = null
var _bgm_out: AudioStreamPlayer = null
var _bgm_gain: float = BGM_VOLUME_DB
var _music_id: StringName = &""
var _fade: float = 1.0
var _procedural: AudioStreamWAV = null
var _streams: Dictionary = {}
var _bgm_thread: Thread = null
var _bgm_duck_db: float = 0.0
var _duck_now: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	_install_limiter()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_install_music_bus()
	for k in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		add_child(player)
		if k == 0:
			_bgm = player
		else:
			_bgm_out = player
	_build_sfx()
	_bgm_thread = Thread.new()
	_bgm_thread.start(_render_bgm)


func _process(delta: float) -> void:
	if _bgm_thread != null and not _bgm_thread.is_alive():
		_procedural = _bgm_thread.wait_to_finish()
		_bgm_thread = null
		if not MUSIC_FILES.has(_music_id):
			_switch_to(_procedural, BGM_VOLUME_DB)  # the loop was waited for
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_fade = minf(_fade + real_delta / MUSIC_FADE_TIME, 1.0)
	_duck_now = lerpf(_duck_now, _bgm_duck_db, 1.0 - exp(-3.0 * real_delta))
	# Crossfade in the linear domain (no dip in loudness halfway).
	_bgm.volume_db = linear_to_db(maxf(db_to_linear(_bgm_gain + _duck_now) * _fade, 0.000001))
	if _bgm_out.playing:
		_bgm_out.volume_db = linear_to_db(maxf(db_to_linear(_bgm_out.get_meta("from_db", SILENT_DB)) * (1.0 - _fade), 0.000001))
		if _fade >= 1.0:
			_bgm_out.stop()
			_bgm_out.stream = null


func _exit_tree() -> void:
	if _bgm_thread != null:
		_bgm_thread.wait_to_finish()
		_bgm_thread = null
	# Release streams so nothing is still playing when the audio server shuts down.
	for voice: AudioStreamPlayer in _voices + [_bgm, _bgm_out]:
		voice.stop()
		voice.stream = null


# --- Public API -----------------------------------------------------------------

func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var stream: AudioStreamWAV = _sfx.get(sound)
	if stream == null:
		push_warning("Unknown sound: %s" % sound)
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = SFX_VOLUME_DB + volume_db
	voice.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	voice.play()


## Plays the music for `id` (&"menu" or a style id): its own track, or the
## procedural loop when it has none yet. Crossfades from what is playing;
## asking for the music already playing changes nothing (no restart).
func set_music(id: StringName) -> void:
	_music_id = id
	if MUSIC_FILES.has(id):
		var entry: Array = MUSIC_FILES[id]
		if not _streams.has(id):
			var stream: AudioStream = load(entry[0])
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			_streams[id] = stream
		_switch_to(_streams[id], entry[1])
	elif _procedural != null:
		_switch_to(_procedural, BGM_VOLUME_DB)
	# else: the procedural loop starts as soon as it has rendered.


## The music id last asked for.
func get_music_id() -> StringName:
	return _music_id


## The stream playing (or fading in) now, or null.
func get_music_stream() -> AudioStream:
	return _bgm.stream if _bgm != null else null


func _switch_to(stream: AudioStream, gain_db: float) -> void:
	if stream == null or (_bgm.stream == stream and _bgm.playing):
		_bgm_gain = gain_db
		return
	# The playing track becomes the one fading out; the free player takes the new one.
	var old := _bgm
	_bgm = _bgm_out
	_bgm_out = old
	_bgm_out.set_meta("from_db", _bgm_out.volume_db)
	_bgm.stream = stream
	_bgm.volume_db = SILENT_DB
	_bgm_gain = gain_db
	_fade = 0.0 if _bgm_out.playing else 1.0
	_bgm.play()


## Music has its own bus (under Master), so its level can be set apart from SFX.
func _install_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, &"Master")


## Lowers the music by `db` (0 = normal). Eases over ~0.3 s.
func duck_bgm(db: float) -> void:
	_bgm_duck_db = db


func has_sound(sound: StringName) -> bool:
	return _sfx.has(sound)


func is_bgm_playing() -> bool:
	return _bgm != null and _bgm.stream != null and _bgm.playing


## Length of the procedural loop (s), 0 before it has rendered.
func get_bgm_length() -> float:
	return _procedural.get_length() if _procedural != null else 0.0


## Big finishers stack many loud sounds; limit the master bus instead of clipping.
func _install_limiter() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(0, limiter)


# --- Sound effects --------------------------------------------------------------

func _build_sfx() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var b: PackedFloat32Array

	b = _buffer(0.18)
	_whoosh(b, 0.0, 0.16, 0.04, 0.35, 0.55, rng)
	_sfx[&"whoosh_light"] = _finish(b)

	b = _buffer(0.32)
	_whoosh(b, 0.0, 0.28, 0.02, 0.22, 0.8, rng)
	_thump(b, 0.0, 0.2, 90.0, 60.0, 0.08, 0.15)
	_sfx[&"whoosh_heavy"] = _finish(b)

	b = _buffer(0.16)
	_whoosh(b, 0.0, 0.14, 0.05, 0.3, 0.35, rng)
	_sfx[&"jump"] = _finish(b, 0.6)

	b = _buffer(0.16)
	_thump(b, 0.0, 0.12, 240.0, 95.0, 0.03, 0.9)
	_noise(b, 0.0, 0.05, 0.012, 0.7, 0.6, rng)
	_soft_clip(b, 1.5)
	_sfx[&"hit_light"] = _finish(b)

	# Jab: short, crisp glove snap.
	b = _buffer(0.14)
	_noise(b, 0.0, 0.04, 0.007, 0.92, 0.85, rng)
	_thump(b, 0.0, 0.09, 330.0, 150.0, 0.02, 0.6)
	_soft_clip(b, 1.4)
	_sfx[&"hit_snap"] = _finish(b, 0.8)

	# Hook: a rounder, swinging thump with a slap on the front.
	b = _buffer(0.3)
	_whoosh(b, 0.0, 0.07, 0.15, 0.5, 0.25, rng)
	_thump(b, 0.03, 0.24, 175.0, 62.0, 0.055, 1.0)
	_noise(b, 0.03, 0.06, 0.012, 0.78, 0.6, rng)
	_soft_clip(b, 1.8)
	_sfx[&"hit_hook"] = _finish(b)

	# Uppercut: a deep thump with a sharp upper click (the jaw snapping shut).
	b = _buffer(0.3)
	_thump(b, 0.0, 0.26, 140.0, 48.0, 0.06, 1.0)
	_noise(b, 0.0, 0.05, 0.01, 0.85, 0.6, rng)
	_noise(b, 0.012, 0.02, 0.003, 0.98, 0.5, rng)
	_soft_clip(b, 1.9)
	_sfx[&"hit_upper"] = _finish(b)

	# Body thud: low, dull and short (no bright slap on top).
	b = _buffer(0.26)
	_thump(b, 0.0, 0.22, 115.0, 52.0, 0.05, 1.0)
	_noise(b, 0.0, 0.07, 0.02, 0.22, 0.45, rng)
	_soft_clip(b, 1.8)
	_sfx[&"hit_body"] = _finish(b)

	# Crack layered on heavy blows: a very short bright snap.
	b = _buffer(0.12)
	_noise(b, 0.0, 0.03, 0.004, 0.98, 0.9, rng)
	_thump(b, 0.0, 0.06, 1500.0, 650.0, 0.01, 0.35)
	_soft_clip(b, 1.5)
	_sfx[&"hit_crack"] = _finish(b, 0.8)

	b = _buffer(0.4)
	_thump(b, 0.0, 0.32, 150.0, 42.0, 0.08, 1.0)
	_noise(b, 0.0, 0.12, 0.03, 0.45, 0.7, rng)
	_noise(b, 0.0, 0.03, 0.005, 0.95, 0.5, rng)
	_soft_clip(b, 2.0)
	_sfx[&"hit_heavy"] = _finish(b)

	b = _buffer(0.14)
	_thump(b, 0.0, 0.08, 820.0, 520.0, 0.02, 0.45)
	_noise(b, 0.0, 0.07, 0.015, 0.85, 0.45, rng)
	_thump(b, 0.0, 0.1, 300.0, 240.0, 0.03, 0.3)
	_sfx[&"block"] = _finish(b, 0.75)

	b = _buffer(0.2)
	_thump(b, 0.0, 0.16, 110.0, 55.0, 0.04, 0.55)
	_noise(b, 0.0, 0.08, 0.02, 0.15, 0.25, rng)
	_sfx[&"land"] = _finish(b, 0.6)

	b = _buffer(0.55)
	_thump(b, 0.0, 0.45, 95.0, 38.0, 0.12, 1.0)
	_noise(b, 0.0, 0.4, 0.09, 0.12, 0.6, rng)
	_soft_clip(b, 1.6)
	_sfx[&"body_fall"] = _finish(b)

	b = _buffer(0.55)
	_thump(b, 0.0, 0.45, 120.0, 40.0, 0.1, 1.0)
	_noise(b, 0.0, 0.18, 0.03, 0.9, 0.8, rng)
	_noise(b, 0.0, 0.35, 0.08, 0.2, 0.5, rng)
	_soft_clip(b, 2.2)
	_sfx[&"wall_hit"] = _finish(b)

	b = _buffer(0.7)
	for k in 3:
		_thump(b, k * 0.15, 0.14, 85.0, 50.0, 0.04, 0.5)
	_noise(b, 0.0, 0.6, 0.25, 0.08, 0.3, rng)
	_sfx[&"roll"] = _finish(b, 0.7)

	b = _buffer(1.8)
	_thump(b, 0.0, 1.3, 85.0, 26.0, 0.4, 1.0)
	_noise(b, 0.0, 1.1, 0.3, 0.06, 0.7, rng)
	_noise(b, 0.0, 0.06, 0.01, 0.9, 0.6, rng)
	_echo(b, 0.13, 0.35)
	_soft_clip(b, 1.8)
	_sfx[&"ko_boom"] = _finish(b)

	b = _buffer(2.6)
	_whoosh(b, 0.0, 0.45, 0.01, 0.5, 0.6, rng)
	_gong(b, 0.35, 2.1, 147.0, 0.7)
	_thump(b, 0.35, 0.6, 70.0, 40.0, 0.2, 0.7)
	_echo(b, 0.18, 0.3)
	_sfx[&"finisher_sting"] = _finish(b)

	# Parry: bright metallic ting (inharmonic ring) over a sharp click.
	b = _buffer(0.7)
	_noise(b, 0.0, 0.02, 0.004, 0.95, 0.8, rng)
	_gong(b, 0.0, 0.65, 1180.0, 0.55)
	_thump(b, 0.0, 0.08, 900.0, 600.0, 0.02, 0.4)
	_sfx[&"parry"] = _finish(b, 0.75)

	# Guard break: low crunch, a cracking noise burst and a falling metallic ring.
	b = _buffer(0.9)
	_thump(b, 0.0, 0.5, 160.0, 40.0, 0.14, 1.0)
	_noise(b, 0.0, 0.25, 0.06, 0.8, 0.9, rng)
	_noise(b, 0.04, 0.2, 0.05, 0.95, 0.5, rng)
	_gong(b, 0.0, 0.8, 520.0, 0.3)
	_soft_clip(b, 1.8)
	_sfx[&"guard_break"] = _finish(b)

	# Finisher music layer: a taiko roll that accelerates for ~2 s under the
	# choreography (the fight track is ducked), with a rising noise swell.
	b = _buffer(2.4)
	var hit_t := 0.0
	var gap := 0.28
	while hit_t < 2.1:
		var louder := 0.45 + 0.55 * hit_t / 2.1
		_thump(b, hit_t, 0.35, 95.0, 48.0, 0.12, louder)
		_noise(b, hit_t, 0.02, 0.005, 0.5, 0.25 * louder, rng)
		hit_t += gap
		gap = maxf(gap * 0.86, 0.07)
	for i in int(2.1 * MIX_RATE):
		var u := float(i) / (2.1 * MIX_RATE)
		b[i] += rng.randf_range(-1.0, 1.0) * 0.08 * u * u
	_soft_clip(b, 1.4)
	_sfx[&"finisher_drums"] = _finish(b, 0.8)

	# Victory: a deep gong under a bright open chord (A minor -> A major lift).
	b = _buffer(3.0)
	_gong(b, 0.0, 2.9, 110.0, 0.8)
	for f in [440.0, 554.37, 659.25]:
		_pluck(b, 0.05, f, 2.0, 0.18, rng)
		_square(b, 0.1, f * 0.5, 1.6, 0.06, 0.15)
	_echo(b, 0.21, 0.3)
	_sfx[&"victory"] = _finish(b, 0.8)

	# Counter hit: a sharp high crack on top of a punchy thud.
	b = _buffer(0.35)
	_noise(b, 0.0, 0.03, 0.006, 0.98, 0.9, rng)
	_thump(b, 0.0, 0.25, 320.0, 90.0, 0.05, 0.9)
	_gong(b, 0.0, 0.3, 880.0, 0.12)
	_soft_clip(b, 1.8)
	_sfx[&"counter"] = _finish(b, 0.8)

	# Clash: two strikes meeting - a dry clap with a short bright ring.
	b = _buffer(0.3)
	_noise(b, 0.0, 0.05, 0.01, 0.9, 1.0, rng)
	_thump(b, 0.0, 0.08, 600.0, 400.0, 0.02, 0.5)
	_gong(b, 0.0, 0.25, 1500.0, 0.15)
	_sfx[&"clash"] = _finish(b, 0.7)

	# Signature: a sharp intake (short rising whoosh) into a deep body thump.
	b = _buffer(0.6)
	_whoosh(b, 0.0, 0.25, 0.02, 0.5, 0.7, rng)
	_thump(b, 0.18, 0.4, 110.0, 45.0, 0.12, 0.9)
	_noise(b, 0.18, 0.05, 0.01, 0.8, 0.4, rng)
	_soft_clip(b, 1.5)
	_sfx[&"signature"] = _finish(b, 0.8)

	# Countdown: a dry taiko beat with a short high ping (3, 2, 1).
	b = _buffer(0.6)
	_thump(b, 0.0, 0.4, 120.0, 62.0, 0.09, 1.0)
	_noise(b, 0.0, 0.03, 0.006, 0.6, 0.35, rng)
	_gong(b, 0.0, 0.5, 392.0, 0.18)
	_sfx[&"count_tick"] = _finish(b, 0.7)

	# FIGHT!: double taiko hit, bright crash and a low gong swell.
	b = _buffer(1.6)
	_thump(b, 0.0, 0.5, 140.0, 45.0, 0.14, 1.0)
	_thump(b, 0.09, 0.6, 110.0, 38.0, 0.18, 0.9)
	_noise(b, 0.0, 1.0, 0.3, 0.85, 0.5, rng)
	_gong(b, 0.05, 1.5, 196.0, 0.45)
	_echo(b, 0.11, 0.25)
	_soft_clip(b, 1.5)
	_sfx[&"fight_call"] = _finish(b)

	# Dizzy: a bright bell ring, a falling dazed "bwoing", and birdsong.
	b = _buffer(1.3)
	_gong(b, 0.0, 0.9, 1320.0, 0.28)
	_thump(b, 0.02, 0.7, 720.0, 170.0, 0.3, 0.35)
	for i in 5:
		var at := 0.25 + i * 0.17
		_pluck(b, at, 2500.0 + (i % 2) * 450.0, 0.08, 0.12, rng)
		_pluck(b, at + 0.05, 3100.0 + (i % 2) * 300.0, 0.07, 0.09, rng)
	_echo(b, 0.12, 0.25)
	_sfx[&"dizzy"] = _finish(b, 0.75)

	# Birdsong loop while still dizzy.
	b = _buffer(0.5)
	for i in 3:
		_pluck(b, i * 0.13, 2600.0 + (i % 2) * 500.0, 0.07, 0.11, rng)
		_pluck(b, i * 0.13 + 0.045, 3200.0, 0.06, 0.08, rng)
	_sfx[&"dizzy_chirp"] = _finish(b, 0.6)

	# Open-palm slap: a very bright, dry crack of skin on skin with a short
	# room tail (no thump: a slap is all top end).
	b = _buffer(0.45)
	_noise(b, 0.0, 0.05, 0.006, 0.99, 1.0, rng)
	_thump(b, 0.0, 0.07, 1500.0, 520.0, 0.012, 0.55)
	_noise(b, 0.006, 0.3, 0.07, 0.8, 0.22, rng)
	_echo(b, 0.06, 0.25)
	_soft_clip(b, 1.6)
	_sfx[&"slap"] = _finish(b, 0.95)

	# Football punt: a hollow boot thud.
	b = _buffer(0.5)
	_thump(b, 0.0, 0.3, 190.0, 55.0, 0.07, 1.0)
	_noise(b, 0.0, 0.03, 0.008, 0.55, 0.6, rng)
	_thump(b, 0.02, 0.2, 420.0, 160.0, 0.04, 0.35)
	_soft_clip(b, 1.5)
	_sfx[&"punt"] = _finish(b, 0.9)

	# A body sliding along the floorboards: a long gritty scrape dying away.
	b = _buffer(1.2)
	_noise(b, 0.0, 1.1, 0.45, 0.32, 0.5, rng)
	_noise(b, 0.0, 0.9, 0.3, 0.6, 0.18, rng)
	_sfx[&"body_slide"] = _finish(b, 0.7)

	# Shaking it off: two quick head-shake whooshes.
	b = _buffer(0.35)
	_whoosh(b, 0.0, 0.12, 0.05, 0.45, 0.4, rng)
	_whoosh(b, 0.13, 0.12, 0.05, 0.45, 0.35, rng)
	_sfx[&"shake_off"] = _finish(b, 0.6)


# --- Background music (worker thread) -------------------------------------------

func _render_bgm() -> AudioStreamWAV:
	# Driving fight track, 140 BPM in A minor: punchy kick and snare, 16th hats,
	# distorted saw bass, taiko accents, a stabbing lead riff (bars 0-7) that
	# opens into a melody (bars 8-15), crashes and drum fills. Loops seamlessly.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var beat := 60.0 / BGM_BPM
	var step := beat / 4.0  # 16th note
	var bar_len := beat * 4.0
	var buf := _buffer(bar_len * BGM_BARS)
	var roots: Array[float] = [55.0, 55.0, 43.65, 49.0, 55.0, 55.0, 43.65, 41.2,
		43.65, 49.0, 55.0, 55.0, 43.65, 49.0, 41.2, 41.2]
	for bar in BGM_BARS:
		var t0 := bar * bar_len
		var fill := bar % 8 == 7
		# Crash + taiko boom at the top of each 8-bar section.
		if bar % 8 == 0:
			_noise(buf, t0, 1.6, 0.55, 0.9, 0.35, rng, true)
			_thump(buf, t0, 0.8, 70.0, 38.0, 0.3, 0.9, true)
		# Kick: driving, syncopated.
		for k in ([0, 3, 8, 10] if bar % 2 == 0 else [0, 6, 8, 11, 14]):
			_thump(buf, t0 + k * step, 0.28, 130.0, 42.0, 0.08, 1.0, true)
			_noise(buf, t0 + k * step, 0.012, 0.004, 0.9, 0.35, rng, true)
		# Snare on 2 and 4 (16th roll on the last beat of a fill bar).
		var snares := [4, 12] if not fill else [4, 12, 13, 14, 15]
		for sn in snares:
			var vel: float = 0.75 if sn == 4 or sn == 12 else 0.45 + (sn - 12) * 0.1
			_noise(buf, t0 + sn * step, 0.2, 0.06, 0.72, vel, rng, true)
			_thump(buf, t0 + sn * step, 0.1, 230.0, 170.0, 0.035, vel * 0.5, true)
		# Hats: closed 8ths with ghosted 16ths, open hat before the bar turns.
		for h in 16:
			if h == 14:
				_noise(buf, t0 + h * step, 0.12, 0.05, 0.97, 0.16, rng, true)
			elif h % 2 == 0:
				_noise(buf, t0 + h * step, 0.04, 0.01, 0.98, 0.14, rng, true)
			else:
				_noise(buf, t0 + h * step, 0.03, 0.007, 0.98, 0.06, rng, true)
		# Taiko accent on beat 3 for the martial-arts flavour.
		_thump(buf, t0 + 8 * step, 0.4, 85.0, 50.0, 0.12, 0.45, true)
		# Distorted bass: driving 8ths with octave jumps.
		var root := roots[bar]
		var bass_pattern: Array[float] = [1.0, 1.0, 2.0, 1.0, 1.0, 1.5, 2.0, 1.0]
		for e in 8:
			var f := root * bass_pattern[e]
			_saw(buf, t0 + e * step * 2.0, f, step * 1.8, 0.42, 0.14)
			_bass(buf, t0 + e * step * 2.0, f, step * 1.6, 0.3)
	# Lead: A minor pentatonic. Riff (stabs) for bars 0-7, melody for 8-15.
	var note := {"G4": 392.0, "A4": 440.0, "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.0}
	var riff: Array = [[0, "A4"], [3, "A4"], [6, "C5"], [8, "A4"], [11, "D5"], [14, "C5"],
		[16, "A4"], [19, "A4"], [22, "E5"], [24, "D5"], [27, "C5"], [30, "G4"]]
	var melody: Array = [[0, "E5", 4], [4, "G5", 4], [8, "A5", 4], [12, "G5", 2], [14, "E5", 2],
		[16, "D5", 4], [20, "E5", 4], [24, "C5", 4], [28, "D5", 2], [30, "E5", 2]]
	for phrase in 4:
		var p0 := phrase * 2 * bar_len
		for n in riff:
			_square(buf, p0 + n[0] * step, note[n[1]], step * 1.3, 0.2, 0.3)
	for phrase in range(4, 8):
		var p0 := phrase * 2 * bar_len
		for n in melody:
			_square(buf, p0 + n[0] * step, note[n[1]], step * n[2] * 0.95, 0.22, 0.22)
			_pluck(buf, p0 + n[0] * step, note[n[1]] * 0.5, 0.5, 0.12, rng)
	_soft_clip(buf, 1.6)
	_normalize(buf, 0.85)
	var wav := _to_wav(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = buf.size()
	return wav


# --- Synthesis helpers (static: safe to use from the worker thread) -------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	b.fill(0.0)
	return b


## Adds `value` at sample index `idx`; wraps around the buffer end for loops.
static func _put(buf: PackedFloat32Array, idx: int, value: float, wrap: bool) -> bool:
	if idx >= buf.size():
		if not wrap:
			return false
		idx -= buf.size()
	buf[idx] += value
	return true


## Pitched sine with an exponential pitch drop: kicks, thuds, impacts.
static func _thump(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		decay: float, amp: float, wrap: bool = false) -> void:
	var n := int(dur * MIX_RATE)
	var off := int(start * MIX_RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * f0 * pow(f1 / f0, t / dur) / MIX_RATE
		if not _put(buf, off + i, sin(phase) * exp(-t / decay) * amp, wrap):
			break


## Low-passed noise burst (cutoff 0..1 = dark..bright).
static func _noise(buf: PackedFloat32Array, start: float, dur: float, decay: float, cutoff: float,
		amp: float, rng: RandomNumberGenerator, wrap: bool = false) -> void:
	var n := int(dur * MIX_RATE)
	var off := int(start * MIX_RATE)
	var y := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		y += cutoff * (rng.randf_range(-1.0, 1.0) - y)
		if not _put(buf, off + i, y * exp(-t / decay) * amp, wrap):
			break


## Air whoosh: noise with a sweeping filter and a swelling envelope.
static func _whoosh(buf: PackedFloat32Array, start: float, dur: float, c0: float, c1: float,
		amp: float, rng: RandomNumberGenerator) -> void:
	var n := int(dur * MIX_RATE)
	var off := int(start * MIX_RATE)
	var y := 0.0
	var slow := 0.0
	for i in n:
		var u := float(i) / n
		var cutoff := lerpf(c0, c1, sin(PI * u))
		y += cutoff * (rng.randf_range(-1.0, 1.0) - y)
		slow += 0.02 * (y - slow)
		var env := pow(sin(PI * u), 2.0)
		if not _put(buf, off + i, (y - slow) * env * amp * 2.0, false):
			break


## Karplus-Strong plucked string (koto / shamisen flavour).
static func _pluck(buf: PackedFloat32Array, start: float, freq: float, dur: float, amp: float,
		rng: RandomNumberGenerator) -> void:
	var period := maxi(int(MIX_RATE / freq), 2)
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = rng.randf_range(-1.0, 1.0)
	var off := int(start * MIX_RATE)
	var idx := 0
	for i in int(dur * MIX_RATE):
		var nxt := (idx + 1) % period
		var out := line[idx]
		line[idx] = 0.5 * (line[idx] + line[nxt]) * 0.996
		idx = nxt
		_put(buf, off + i, out * amp, true)


## Filtered sawtooth with a plucky envelope (aggressive bass / lead body).
static func _saw(buf: PackedFloat32Array, start: float, freq: float, dur: float, amp: float, cutoff: float) -> void:
	var off := int(start * MIX_RATE)
	var phase := 0.0
	var y := 0.0
	for i in int(dur * MIX_RATE):
		var t := float(i) / MIX_RATE
		phase = fmod(phase + freq / MIX_RATE, 1.0)
		y += cutoff * ((phase * 2.0 - 1.0) - y)
		var env := minf(t / 0.004, 1.0) * exp(-t / (dur * 0.5))
		_put(buf, off + i, tanh(y * 2.2) * env * amp, true)


## Filtered square wave with slight vibrato (lead synth).
static func _square(buf: PackedFloat32Array, start: float, freq: float, dur: float, amp: float, cutoff: float) -> void:
	var off := int(start * MIX_RATE)
	var phase := 0.0
	var y := 0.0
	for i in int(dur * MIX_RATE):
		var t := float(i) / MIX_RATE
		var f := freq * (1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(t / 0.15, 1.0))
		phase = fmod(phase + f / MIX_RATE, 1.0)
		y += cutoff * ((1.0 if phase < 0.5 else -1.0) - y)
		var env := minf(t / 0.005, 1.0) * (1.0 - 0.35 * minf(t / dur, 1.0)) * minf((dur - t) / 0.02, 1.0)
		_put(buf, off + i, y * env * amp, true)


static func _bass(buf: PackedFloat32Array, start: float, freq: float, dur: float, amp: float) -> void:
	var off := int(start * MIX_RATE)
	for i in int(dur * MIX_RATE):
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.01, 1.0) * exp(-t / 0.3)
		var v := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) + 0.15 * sin(TAU * freq * 3.0 * t)
		_put(buf, off + i, v * env * amp, true)


## Inharmonic partials with long decays: a temple gong.
static func _gong(buf: PackedFloat32Array, start: float, dur: float, base: float, amp: float) -> void:
	var ratios: Array[float] = [1.0, 1.59, 2.14, 2.92, 3.76, 4.4]
	var off := int(start * MIX_RATE)
	for i in int(dur * MIX_RATE):
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in ratios.size():
			v += sin(TAU * base * ratios[k] * t) * exp(-t / (1.2 / (1.0 + k * 0.5))) / (1.0 + k * 0.6)
		if not _put(buf, off + i, v * amp * minf(t / 0.005, 1.0), false):
			break


static func _echo(buf: PackedFloat32Array, delay: float, gain: float) -> void:
	var d := int(delay * MIX_RATE)
	for i in range(d, buf.size()):
		buf[i] += buf[i - d] * gain


static func _soft_clip(buf: PackedFloat32Array, drive: float) -> void:
	for i in buf.size():
		buf[i] = tanh(buf[i] * drive)


static func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	if m > 0.0:
		var k := peak / m
		for i in buf.size():
			buf[i] *= k


static func _finish(buf: PackedFloat32Array, peak: float = 0.9) -> AudioStreamWAV:
	_normalize(buf, peak)
	return _to_wav(buf)


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
