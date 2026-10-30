extends SceneTree
## -- <out.png> <cols> <scale> <x> <y> <w> <h> <img>...: tiles a crop of each image.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var cols := int(a[1])
	var sc := float(a[2])
	var rect := Rect2i(int(a[3]), int(a[4]), int(a[5]), int(a[6]))
	var files := a.slice(7)
	var cw := int(rect.size.x * sc)
	var ch := int(rect.size.y * sc)
	var rows := ceili(files.size() / float(cols))
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	for i in files.size():
		var img := Image.load_from_file(files[i])
		img.convert(Image.FORMAT_RGBA8)
		var c := img.get_region(rect)
		c.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i((i % cols) * cw, (i / cols) * ch))
	sheet.save_png(a[0])
	quit()
