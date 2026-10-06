@tool
extends Control
## The bar area of one timeline row, or the time ruler when [member ruler] is true.

const ROW_HEIGHT := 22.0

var row: Dictionary = {}
var length: float = 1.0
var color: Color = Color.WHITE
## Seconds of the play head, or a negative number when nothing is playing.
var playhead: float = -1.0
var ruler: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(120.0, ROW_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func update_data(new_row: Dictionary, new_length: float, new_color: Color, new_playhead: float) -> void:
	row = new_row
	length = maxf(new_length, 0.001)
	color = new_color
	playhead = new_playhead
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := maxi(get_theme_default_font_size() - 3, 8)
	var text_color := Color(1, 1, 1, 0.55)
	if ruler:
		_draw_ruler(font, font_size, text_color)
	else:
		_draw_row(font, font_size, text_color)
	if playhead >= 0.0:
		var x := _x(playhead)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.9), 1.0)


func _x(seconds: float) -> float:
	return clampf(seconds / length, 0.0, 1.0) * (size.x - 1.0)


func _draw_ruler(font: Font, font_size: int, text_color: Color) -> void:
	var step := _nice_step(length / 5.0)
	var t := 0.0
	while t <= length + 0.0001:
		var x := _x(t)
		draw_line(Vector2(x, size.y - 5.0), Vector2(x, size.y), text_color, 1.0)
		var text := "%s" % snappedf(t, 0.001)
		draw_string(font, Vector2(minf(x + 2.0, size.x - 28.0), size.y - 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		t += step


func _draw_row(font: Font, font_size: int, text_color: Color) -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 1, 1, 0.04))
	if row.is_empty() or row.skipped:
		return
	var top := 4.0
	var height := size.y - 8.0
	var start: float = row.start
	var delay: float = row.delay
	var duration: float = row.duration
	var mid := size.y * 0.5
	if delay > 0.0:
		draw_line(Vector2(_x(start), mid), Vector2(_x(start + delay), mid), Color(color, 0.6), 1.0)
	var body_start := start + delay
	if row.is_pause:
		_draw_pause(body_start, top, height, font, font_size, text_color)
		return
	var runs: int = row.repeats + 1
	for run in mini(runs, 64):
		var from: float = body_start + float(run) * (duration + row.gap)
		var x0: float = _x(from)
		if duration <= 0.0:
			draw_rect(Rect2(x0 - 1.5, top, 3.0, height), color)
			continue
		var width := maxf(_x(from + duration) - x0, 2.0)
		draw_rect(Rect2(x0, top, width, height), Color(color, 0.85))
		draw_rect(Rect2(x0, top, width, height), color.lightened(0.3), false, 1.0)
		if run + 1 < runs and row.gap > 0.0:
			draw_line(Vector2(x0 + width, mid), Vector2(_x(from + duration + row.gap), mid), Color(color, 0.5), 1.0)
	if row.endless:
		var edge := _x(body_start + duration)
		draw_line(Vector2(edge, mid), Vector2(size.x - 1.0, mid), Color(color, 0.7), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - 1.0, mid), Vector2(size.x - 7.0, mid - 4.0), Vector2(size.x - 7.0, mid + 4.0)]), color)
	if row.looper:
		var x := _x(body_start)
		draw_dashed_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0), Color(0.95, 0.95, 0.4, 0.9), 1.0, 3.0)
		var loops: int = row.loops
		draw_string(font, Vector2(minf(x + 3.0, size.x - 26.0), size.y - 7.0), "loop x%d" % loops if loops > 0 else "loop inf", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.95, 0.4))


func _draw_pause(from: float, top: float, height: float, font: Font, font_size: int, text_color: Color) -> void:
	var x0 := _x(from)
	var infinite: bool = row.pause < 0.0
	var span: float = row.pause if not infinite else 0.0
	var width := maxf(_x(from + span) - x0, 3.0)
	draw_rect(Rect2(x0, top, width, height), Color(color, 0.25))
	draw_rect(Rect2(x0, top, width, height), color, false, 1.0)
	# Two bars as the pause sign at the start.
	draw_rect(Rect2(x0 + 2.0, top + 3.0, 2.0, height - 6.0), color)
	draw_rect(Rect2(x0 + 6.0, top + 3.0, 2.0, height - 6.0), color)
	if infinite:
		draw_string(font, Vector2(x0 + 12.0, size.y - 7.0), "waits for resume()", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


static func _nice_step(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var magnitude := pow(10.0, floorf(log(raw) / log(10.0)))
	var scaled := raw / magnitude
	var nice := 1.0
	if scaled > 5.0:
		nice = 10.0
	elif scaled > 2.0:
		nice = 5.0
	elif scaled > 1.0:
		nice = 2.0
	return nice * magnitude
