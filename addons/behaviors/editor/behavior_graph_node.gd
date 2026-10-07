@tool
extends GraphNode
## One task on the canvas: icon, name, short text, comment, badges, and the live state
## drawn on top while a game runs. Also used for the entry node.

## The node was double-clicked.
signal activated(node: GraphNode)
## The node was right-clicked.
signal context_requested(node: GraphNode)

const KIND_COLORS := {
	"composite": Color("4b7bd1"),
	"decorator": Color("8d63c9"),
	"action": Color("3f9a5f"),
	"condition": Color("c9a227"),
	"subtree": Color("2aa6a6"),
	"entry": Color("7d8494"),
}
const ABORT_TEXT: Array[String] = ["", "◀ self", "▶ lower", "◆ both"]
const RUNNING_COLOR := Color("5fe08a")
const SUCCESS_COLOR := Color("8fcf6b")
const FAILURE_COLOR := Color("e06666")
const REEVALUATING_COLOR := Color("f2c14e")
const NODE_WIDTH := 190.0

var task: BehaviorTask
var kind := "entry"

var _linked := false
var _selected_link := false
var _icon := TextureRect.new()
var _abort := Label.new()
var _reevaluate := Label.new()
var _result := Label.new()
var _warning := TextureRect.new()
var _breakpoint := Label.new()
var _body := VBoxContainer.new()
var _text := Label.new()
var _comment := Label.new()
var _fold := Label.new()
var _runtime: Dictionary = {}


func _init() -> void:
	resizable = false
	custom_minimum_size.x = NODE_WIDTH
	gui_input.connect(_on_gui_input)


## Draws the entry: a title and one output port.
func setup_entry() -> void:
	kind = "entry"
	title = "Entry"
	var label := Label.new()
	label.text = "Start"
	label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	add_child(label)
	set_slot(0, false, 0, Color.WHITE, true, 0, KIND_COLORS["entry"])
	custom_minimum_size.x = 110.0
	_apply_style()


## Draws [param source]. [param has_output] is false for tasks that take no children,
## [param folded] counts hidden descendants (0 when not collapsed), and
## [param tooltip] is the text shown on hover.
func setup(source: BehaviorTask, has_output: bool, folded: int, tooltip: String) -> void:
	task = source
	kind = BehaviorTaskCatalog.get_kind(source.get_script())
	title = source.get_display_name()
	tooltip_text = tooltip
	var titlebar := get_titlebar_hbox()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.texture = _find_icon(source)
	titlebar.add_child(_icon)
	titlebar.move_child(_icon, 0)
	for label: Label in [_abort, _reevaluate, _result, _breakpoint]:
		label.add_theme_font_size_override("font_size", 11)
		label.visible = false
		titlebar.add_child(label)
	_breakpoint.text = "●"
	_breakpoint.add_theme_color_override("font_color", Color("e05555"))
	_breakpoint.visible = source.breakpoint_enabled
	_reevaluate.text = "↻"
	_reevaluate.add_theme_color_override("font_color", REEVALUATING_COLOR)
	_warning.custom_minimum_size = Vector2(16, 16)
	_warning.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_warning.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_warning.visible = false
	titlebar.add_child(_warning)
	if source is BehaviorComposite:
		var abort_type: int = (source as BehaviorComposite).abort_type
		_abort.text = ABORT_TEXT[abort_type]
		_abort.visible = abort_type > 0
		_abort.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_body.add_theme_constant_override("separation", 2)
	add_child(_body)
	_text.add_theme_font_size_override("font_size", 12)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = NODE_WIDTH - 24.0
	_body.add_child(_text)
	_comment.add_theme_font_size_override("font_size", 11)
	_comment.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comment.custom_minimum_size.x = NODE_WIDTH - 24.0
	_body.add_child(_comment)
	_fold.add_theme_font_size_override("font_size", 11)
	_fold.add_theme_color_override("font_color", Color("f2c14e"))
	_body.add_child(_fold)
	refresh_content(folded)
	var color: Color = KIND_COLORS[kind]
	set_slot(0, true, 0, color, has_output, 0, color)
	self_modulate = Color(1, 1, 1, 0.5) if source.disabled else Color.WHITE
	_apply_style()


## Updates the texts and badges from the task.
func refresh_content(folded := 0) -> void:
	if task == null:
		return
	var graph_text := task._get_graph_text()
	_text.text = graph_text
	_text.visible = not graph_text.is_empty()
	_comment.text = task.comment
	_comment.visible = not task.comment.is_empty()
	_fold.text = "▸ %d hidden" % folded
	_fold.visible = folded > 0
	var warnings := task.get_warnings()
	_warning.visible = not warnings.is_empty()
	if _warning.visible:
		_warning.texture = _theme_icon("StatusWarning")
		_warning.tooltip_text = "\n".join(warnings)
		_warning.mouse_filter = Control.MOUSE_FILTER_PASS


## Shows or hides the dashed outline of a task that the selected task points at.
func set_linked(value: bool) -> void:
	_linked = value
	queue_redraw()


## Draws the live state: [code]status[/code] ([enum BehaviorTask.Status]),
## [code]running[/code] and [code]reevaluating[/code]. An empty dictionary clears it.
func set_runtime(state: Dictionary) -> void:
	_runtime = state
	var status: int = state.get("status", BehaviorTask.Status.INACTIVE)
	var running: bool = state.get("running", false)
	_result.visible = false
	if not running and status == BehaviorTask.Status.SUCCESS:
		_result.text = "✓"
		_result.add_theme_color_override("font_color", SUCCESS_COLOR)
		_result.visible = true
	elif not running and status == BehaviorTask.Status.FAILURE:
		_result.text = "✗"
		_result.add_theme_color_override("font_color", FAILURE_COLOR)
		_result.visible = true
	_reevaluate.visible = state.get("reevaluating", false)
	_apply_style()


func _draw() -> void:
	if not _linked:
		return
	var rect := Rect2(Vector2(-3, -3), size + Vector2(6, 6))
	var color := Color("f2c14e")
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, 2.0, 6.0)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, 2.0, 6.0)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, 2.0, 6.0)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, 2.0, 6.0)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		context_requested.emit(self)
	elif button.button_index == MOUSE_BUTTON_LEFT and button.double_click:
		accept_event()
		activated.emit(self)


func _apply_style() -> void:
	var color: Color = KIND_COLORS[kind]
	var running: bool = _runtime.get("running", false)
	for entry in [["titlebar", color], ["titlebar_selected", color.lightened(0.25)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = entry[1]
		style.set_corner_radius_all(3)
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		add_theme_stylebox_override(entry[0], style)
	for entry in [["panel", false], ["panel_selected", true]]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.13, 0.14, 0.17, 0.96)
		panel.set_corner_radius_all(3)
		panel.corner_radius_top_left = 0
		panel.corner_radius_top_right = 0
		panel.set_border_width_all(3 if running else (2 if entry[1] else 1))
		if running:
			panel.border_color = RUNNING_COLOR
			panel.bg_color = Color(0.13, 0.2, 0.16, 0.96)
		else:
			panel.border_color = color.lightened(0.4) if entry[1] else color.darkened(0.2)
		panel.content_margin_left = 10
		panel.content_margin_right = 10
		panel.content_margin_top = 6
		panel.content_margin_bottom = 6
		add_theme_stylebox_override(entry[0], panel)


func _find_icon(source: BehaviorTask) -> Texture2D:
	var texture := BehaviorTaskCatalog.get_icon(source.get_script())
	if texture:
		return texture
	var names := {
		"composite": "GraphNode", "decorator": "Filter", "action": "Play",
		"condition": "Help", "subtree": "PackedScene",
	}
	return _theme_icon(names.get(kind, "Object"))


func _theme_icon(icon_name: String) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_icon(icon_name, "EditorIcons"):
		return theme.get_icon(icon_name, "EditorIcons")
	return theme.get_icon("Object", "EditorIcons") if theme else null
