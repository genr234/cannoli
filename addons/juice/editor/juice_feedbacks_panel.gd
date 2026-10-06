@tool
extends VBoxContainer
## Toolbar and timeline shown above the feedback list of a [JuicePlayer].
##
## One row per feedback: color strip, active checkbox, name, a button to play only that
## feedback, and a bar placed by its start time and length.

const Util := preload("juice_editor_util.gd")
const Actions := preload("juice_list_actions.gd")
const Layout := preload("juice_timeline_layout.gd")
const Bar := preload("juice_timeline_bar.gd")
const Picker := preload("juice_feedback_picker.gd")
const Preview := preload("juice_preview.gd")

enum _ListMenu { COPY_ALL, PASTE_ADD, PASTE_REPLACE, SAVE_PRESET, LOAD_ADD, LOAD_REPLACE, CLEAR }
enum _RowMenu { COPY, DUPLICATE, MOVE_UP, MOVE_DOWN, REMOVE, EDIT }

const POLL_SECONDS := 0.2

var _player: JuicePlayer
var _actions: Actions
var _grid := GridContainer.new()
var _picker: Picker
var _ruler: Bar
var _bars: Array[Bar] = []
var _checks: Array[CheckBox] = []
var _structure_hash := 0
var _list_menu: MenuButton
var _empty_label := Label.new()


func _init(player: JuicePlayer, undo_redo: EditorUndoRedoManager) -> void:
	_player = player
	_actions = Actions.new(player, undo_redo)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var add_button := Button.new()
	add_button.text = "Add Feedback"
	add_button.icon = Util.icon(&"Add")
	add_button.tooltip_text = "Append a new feedback to the list."
	toolbar.add_child(add_button)
	_picker = Picker.new()
	_picker.picked.connect(_on_picked)
	add_child(_picker)
	add_button.pressed.connect(func() -> void: _picker.open_under(add_button))
	_list_menu = MenuButton.new()
	_list_menu.text = "List"
	_list_menu.flat = false
	_list_menu.tooltip_text = "Copy, paste and presets for the whole list. Drop a JuicePreset file here to add it."
	var menu := _list_menu.get_popup()
	menu.add_item("Copy all", _ListMenu.COPY_ALL)
	menu.add_item("Paste (add)", _ListMenu.PASTE_ADD)
	menu.add_item("Paste (replace)", _ListMenu.PASTE_REPLACE)
	menu.add_separator()
	menu.add_item("Save as preset...", _ListMenu.SAVE_PRESET)
	menu.add_item("Load preset (add)...", _ListMenu.LOAD_ADD)
	menu.add_item("Load preset (replace)...", _ListMenu.LOAD_REPLACE)
	menu.add_separator()
	menu.add_item("Clear", _ListMenu.CLEAR)
	menu.id_pressed.connect(_on_list_menu)
	menu.about_to_popup.connect(_update_list_menu)
	toolbar.add_child(_list_menu)
	_empty_label.text = "No feedbacks yet. Add one to start."
	_empty_label.modulate = Color(1, 1, 1, 0.5)
	add_child(_empty_label)
	_grid.columns = 6
	_grid.add_theme_constant_override(&"h_separation", 4)
	_grid.add_theme_constant_override(&"v_separation", 2)
	add_child(_grid)
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)
	_rebuild()
	_poll()


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and _player.is_playing():
		_update_bars()


func _poll() -> void:
	if not is_instance_valid(_player):
		return
	var structure := _structure_signature()
	if structure != _structure_hash:
		_rebuild()
	_update_bars()


func _structure_signature() -> int:
	var parts: Array = []
	for feedback in _player.feedbacks:
		if feedback == null:
			parts.append(0)
		else:
			parts.append([feedback.get_instance_id(), feedback.get_display_label(), feedback.get_color()])
	return hash(parts)


func _rebuild() -> void:
	_structure_hash = _structure_signature()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_bars.clear()
	_checks.clear()
	_empty_label.visible = _player.feedbacks.is_empty()
	_grid.visible = not _player.feedbacks.is_empty()
	if _player.feedbacks.is_empty():
		return
	for i in 4:
		_grid.add_child(Control.new())
	_ruler = Bar.new()
	_ruler.ruler = true
	_ruler.custom_minimum_size.y = 16.0
	_grid.add_child(_ruler)
	_grid.add_child(Control.new())
	for i in _player.feedbacks.size():
		_add_row(i, _player.feedbacks[i])
	_update_bars()


func _add_row(index: int, feedback: JuiceFeedback) -> void:
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(4, Bar.ROW_HEIGHT)
	strip.color = feedback.get_color() if feedback != null else Color.DIM_GRAY
	_grid.add_child(strip)
	var check := CheckBox.new()
	check.tooltip_text = "Active"
	check.button_pressed = feedback != null and feedback.active
	check.disabled = feedback == null
	check.toggled.connect(func(pressed: bool) -> void: _actions.set_active(_feedback_at(index), pressed))
	_grid.add_child(check)
	_checks.append(check)
	var name_label := Label.new()
	name_label.text = feedback.get_display_label() if feedback != null else "(empty)"
	name_label.custom_minimum_size.x = 110.0
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if feedback != null:
		name_label.tooltip_text = "%s (%s)" % [feedback.get_display_label(), feedback.get_category()]
	_grid.add_child(name_label)
	var play := Button.new()
	play.flat = true
	play.tooltip_text = "Preview only this feedback."
	play.disabled = feedback == null
	Util.set_icon(play, Util.icon(&"Play"), ">")
	play.pressed.connect(func() -> void:
		var target := _feedback_at(index)
		if target != null:
			Preview.play_only(_player, target))
	_grid.add_child(play)
	var bar := Bar.new()
	_grid.add_child(bar)
	_bars.append(bar)
	var more := MenuButton.new()
	more.flat = true
	more.icon = Util.icon(&"GuiTabMenuHl")
	if more.icon == null:
		more.text = "..."
	var popup := more.get_popup()
	popup.add_item("Copy", _RowMenu.COPY)
	popup.add_item("Duplicate", _RowMenu.DUPLICATE)
	popup.add_item("Move up", _RowMenu.MOVE_UP)
	popup.add_item("Move down", _RowMenu.MOVE_DOWN)
	popup.add_item("Remove", _RowMenu.REMOVE)
	popup.add_separator()
	popup.add_item("Open in inspector", _RowMenu.EDIT)
	popup.id_pressed.connect(_on_row_menu.bind(index))
	_grid.add_child(more)


func _update_bars() -> void:
	if _bars.is_empty() or not is_instance_valid(_player):
		return
	var layout := Layout.compute(_player)
	var rows: Array = layout.rows
	var length: float = maxf(layout.length, _player.get_total_duration())
	var playhead := _player.get_elapsed_time() if _player.is_playing() else -1.0
	_ruler.update_data({}, length, Color.WHITE, playhead)
	for i in mini(_bars.size(), rows.size()):
		var feedback := _player.feedbacks[i]
		var color := feedback.get_color() if feedback != null else Color.DIM_GRAY
		_bars[i].update_data(rows[i], length, color, playhead)
		_bars[i].tooltip_text = _bar_tooltip(feedback, rows[i])
		_checks[i].set_pressed_no_signal(feedback != null and feedback.active)


func _bar_tooltip(feedback: JuiceFeedback, row: Dictionary) -> String:
	if feedback == null or row.skipped:
		return "Not played (inactive or wrong direction)."
	var text := "Starts at %s\nDuration %s" % [Util.format_time(row.start + row.delay), Util.format_time(row.duration)]
	if row.endless:
		text += "\nRepeats forever"
	elif row.repeats > 0:
		text += "\nRepeats %d times" % row.repeats
	return text


func _feedback_at(index: int) -> JuiceFeedback:
	if index < 0 or index >= _player.feedbacks.size():
		return null
	return _player.feedbacks[index]


func _on_picked(script: Script) -> void:
	_actions.add(script)


func _update_list_menu() -> void:
	var menu := _list_menu.get_popup()
	menu.set_item_disabled(menu.get_item_index(_ListMenu.PASTE_ADD), Actions.clipboard.is_empty())
	menu.set_item_disabled(menu.get_item_index(_ListMenu.PASTE_REPLACE), Actions.clipboard.is_empty())
	menu.set_item_disabled(menu.get_item_index(_ListMenu.COPY_ALL), _player.feedbacks.is_empty())
	menu.set_item_disabled(menu.get_item_index(_ListMenu.CLEAR), _player.feedbacks.is_empty())


func _on_list_menu(id: int) -> void:
	match id:
		_ListMenu.COPY_ALL:
			_actions.copy()
		_ListMenu.PASTE_ADD:
			_actions.paste(false)
		_ListMenu.PASTE_REPLACE:
			_actions.paste(true)
		_ListMenu.SAVE_PRESET:
			_actions.ask_save_preset()
		_ListMenu.LOAD_ADD:
			_actions.ask_load_preset(false)
		_ListMenu.LOAD_REPLACE:
			_actions.ask_load_preset(true)
		_ListMenu.CLEAR:
			_actions.clear()


func _on_row_menu(id: int, index: int) -> void:
	match id:
		_RowMenu.COPY:
			_actions.copy([index])
		_RowMenu.DUPLICATE:
			_actions.duplicate_at(index)
		_RowMenu.MOVE_UP:
			_actions.move(index, -1)
		_RowMenu.MOVE_DOWN:
			_actions.move(index, 1)
		_RowMenu.REMOVE:
			_actions.remove(index)
		_RowMenu.EDIT:
			var feedback := _feedback_at(index)
			if feedback != null:
				EditorInterface.inspect_object(feedback)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _dropped_preset_path(data) != "" or (data is Dictionary and data.get("resource") is JuicePreset)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("resource") is JuicePreset:
		_actions.apply_preset(data["resource"])
		return
	var path := _dropped_preset_path(data)
	if not path.is_empty():
		_actions.load_preset(path)


func _dropped_preset_path(data: Variant) -> String:
	if not data is Dictionary or data.get("type") != "files":
		return ""
	for file: String in data.get("files", []):
		if file.get_extension() in ["tres", "res"] and ResourceLoader.exists(file) and load(file) is JuicePreset:
			return file
	return ""
