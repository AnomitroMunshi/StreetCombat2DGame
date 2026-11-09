extends SceneTree
## The web build has no system fonts to fall back on: every character in the
## game's text (scripts and style files) must exist in the built-in font, or
## it draws as an empty box in a browser. Bengali speech is the one known
## exception until a Bengali font is bundled (it falls back to a system font
## on desktop).

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	var font: Font = ThemeDB.fallback_font
	var missing := {}
	var files := PackedStringArray()
	for dir in ["res://scripts", "res://styles"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tres"):
				files.append(dir + "/" + f)
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			for ch in line:
				var code := ch.unicode_at(0)
				if code < 0x80 or (code >= 0x980 and code <= 0x9FF):
					continue
				if not font.has_char(code):
					missing["%s U+%04X %s:%d" % [ch, code, path.get_file(), i + 1]] = true
	_check(missing.is_empty(), "every UI character is in the built-in font %s" % [missing.keys()])
	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
