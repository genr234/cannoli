@tool
extends VBoxContainer
## The Behaviors tab of the debugger. The plugin feeds it the messages of one game
## session. It owns the watched agent, the state history and the live overlay.

## Asks the plugin to send a [code]behaviors:*[/code] message to the game.
signal message_requested(message: String, args: Array)
## Emitted when this tab starts watching an agent.
signal watching

const STATE_NAMES: PackedStringArray = ["Stopped", "Running", "Paused"]
const DEFAULT_HISTORY := 300

## Returns the Behaviors main screen control. Set by the plugin.
var get_behavior_editor: Callable

var _history := History.new(DEFAULT_HISTORY)
var _watched_id: int = 0
var _watched_tree_path: String = ""
## Index into the history of the shown snapshot, -1 when there is none.
var _index: int = -1
var _live: bool = true
var _stale: bool = false
var _overlay_drawn: bool = false
var _rebuilding: bool = false

var _hint := Label.new()
var _agents := Tree.new()
var _variables := Tree.new()
var _variable_items: Dictionary[String, TreeItem] = {}
var _refresh := Button.new()
var _show_tree := Button.new()
var _pause := Button.new()
var _resume := Button.new()
var _restart := Button.new()
var _stop := Button.new()
var _live_toggle := CheckButton.new()
var _step_back := Button.new()
var _step_forward := Button.new()
var _slider := HSlider.new()
var _capacity := SpinBox.new()
var _position_label := Label.new()


## UI-free helpers. Everything the tab decides about messages and history lives here.
class History extends RefCounted:
	var capacity: int
	var snapshots: Array[Dictionary] = []

	func _init(max_size: int) -> void:
		capacity = maxi(1, max_size)

	## Adds a snapshot and returns how many old ones were dropped.
	func push(snapshot: Dictionary) -> int:
		snapshots.append(snapshot)
		return _trim()

	func set_capacity(max_size: int) -> int:
		capacity = maxi(1, max_size)
		return _trim()

	func clear() -> void:
		snapshots.clear()

	func size() -> int:
		return snapshots.size()

	func get_snapshot(index: int) -> Dictionary:
		if index < 0 or index >= snapshots.size():
			return {}
		return snapshots[index]

	func _trim() -> int:
		var extra := snapshots.size() - capacity
		if extra <= 0:
			return 0
		snapshots = snapshots.slice(extra)
		return extra


## Converts the game's [code][status, running, reevaluated][/code] arrays to the form
## [code]set_runtime_state[/code] takes.
static func to_runtime_states(states: Dictionary) -> Dictionary:
	var result := {}
	for id in states:
		var entry: Variant = states[id]
		if entry is Array and entry.size() >= 3:
			result[int(id)] = {
				"status": int(entry[0]),
				"running": bool(entry[1]),
				"reevaluating": bool(entry[2]),
			}
	return result


## Builds a snapshot from the arguments of a [code]behaviors:state[/code] message,
## or an empty dictionary when they are malformed.
static func make_snapshot(data: Array) -> Dictionary:
	if data.size() < 5 or not data[3] is Dictionary or not data[4] is Dictionary:
		return {}
	return {
		"agent": int(data[0]),
		"frame": int(data[1]),
		"time": float(data[2]),
		"states": to_runtime_states(data[3]),
		"variables": data[4],
	}


## Formats the label that names a snapshot.
static func describe_snapshot(snapshot: Dictionary, live: bool) -> String:
	if snapshot.is_empty():
		return "No data yet."
	var text := "frame %d · t=%.2f s" % [snapshot.frame, snapshot.time]
	return ("Live · " + text) if live else text


func _init() -> void:
	name = "Behaviors"
	_build()
	_update_controls()


#region Messages from the game

func show_agents(list: Array) -> void:
	_stale = false
	_rebuilding = true
	_agents.clear()
	var root := _agents.create_item()
	var found := false
	for entry: Dictionary in list:
		var item := _agents.create_item(root)
		var id := int(entry.get("id", 0))
		item.set_metadata(0, entry)
		item.set_text(0, String(entry.get("actor", "")))
		item.set_tooltip_text(0, String(entry.get("path", "")))
		item.set_text(1, String(entry.get("path", "")))
		item.set_text(2, String(entry.get("tree", "")).get_file())
		item.set_tooltip_text(2, String(entry.get("tree", "")))
		var state := int(entry.get("state", 0))
		item.set_text(3, STATE_NAMES[state] if state >= 0 and state < STATE_NAMES.size() else "?")
		if id == _watched_id:
			item.select(0)
			found = true
	_rebuilding = false
	_hint.visible = list.is_empty()
	_hint.text = "No agents are running. Start the game, then press Refresh."
	if _watched_id != 0 and not found:
		_hint.visible = true
		_hint.text = "The watched agent is gone. Showing its last recorded state."
	_update_controls()


func receive_state(data: Array) -> void:
	var snapshot := make_snapshot(data)
	if snapshot.is_empty() or snapshot.agent != _watched_id:
		return
	var dropped := _history.push(snapshot)
	if _live:
		_index = _history.size() - 1
	else:
		_index = maxi(0, _index - dropped)
	_show_current()

#endregion


#region Session

## Called by the plugin when the game session ended.
func session_stopped() -> void:
	release()
	_stale = true
	_agents.clear()
	_hint.visible = true
	_hint.text = "The game is not running."
	_update_controls()


func set_stale(stale: bool) -> void:
	_stale = stale
	_agents.modulate = Color(1, 1, 1, 0.5) if stale else Color.WHITE


## Stops watching, forgets the history and clears the overlay.
func release() -> void:
	if _watched_id != 0:
		message_requested.emit("behaviors:watch", [0])
	_watched_id = 0
	_watched_tree_path = ""
	_history.clear()
	_index = -1
	_live = true
	_live_toggle.set_pressed_no_signal(true)
	_clear_overlay()
	_variables.clear()
	_variable_items.clear()
	_rebuilding = true
	_agents.deselect_all()
	_rebuilding = false
	_update_slider()
	_update_controls()


## Redraws the overlay for the shown snapshot. Clears it when the Behaviors screen
## shows another tree.
func refresh_overlay() -> void:
	if _watched_id == 0:
		return
	_apply_overlay(_history.get_snapshot(_index))

#endregion


#region Watching

func _on_agent_selected() -> void:
	if _rebuilding:
		return
	var item := _agents.get_selected()
	if item == null:
		return
	var entry: Dictionary = item.get_metadata(0)
	var id := int(entry.get("id", 0))
	if id == 0 or id == _watched_id:
		return
	watching.emit()
	if _watched_id != 0:
		_clear_overlay()
	_watched_id = id
	_watched_tree_path = String(entry.get("tree", ""))
	_history.clear()
	_index = -1
	_variables.clear()
	_variable_items.clear()
	_update_slider()
	message_requested.emit("behaviors:watch", [id])
	_open_watched_tree(false)
	_update_controls()


func _on_agent_nothing_selected() -> void:
	if _rebuilding or _watched_id == 0:
		return
	release()


func _open_watched_tree(switch_screen: bool) -> void:
	if _watched_tree_path.is_empty() or not ResourceLoader.exists(_watched_tree_path):
		return
	var editor := _get_editor()
	if editor == null:
		return
	var tree := load(_watched_tree_path) as BehaviorTree
	if tree == null:
		return
	if switch_screen:
		EditorInterface.set_main_screen_editor("Behaviors")
	if editor.get_edited_tree() != tree:
		editor.open_tree(tree)
	refresh_overlay()

#endregion


#region Shown snapshot

func _show_current() -> void:
	var snapshot := _history.get_snapshot(_index)
	_update_slider()
	_position_label.text = describe_snapshot(snapshot, _live)
	if snapshot.is_empty():
		return
	_apply_overlay(snapshot)
	_fill_variables(snapshot.variables)


func _apply_overlay(snapshot: Dictionary) -> void:
	var editor := _get_editor()
	if editor == null:
		return
	var edited: BehaviorTree = editor.get_edited_tree()
	var matches := edited != null and not _watched_tree_path.is_empty() \
			and edited.resource_path == _watched_tree_path
	if matches and not snapshot.is_empty():
		editor.set_runtime_state(snapshot.states)
		_overlay_drawn = true
	elif _overlay_drawn:
		_clear_overlay()


func _clear_overlay() -> void:
	if not _overlay_drawn:
		return
	_overlay_drawn = false
	var editor := _get_editor()
	if editor != null:
		editor.clear_runtime_state()


func _get_editor() -> Control:
	return get_behavior_editor.call() if get_behavior_editor.is_valid() else null


func _fill_variables(values: Dictionary) -> void:
	# Updating a cell while it is being edited would throw the user's text away.
	if _variables.get_edited() != null:
		return
	var root := _variables.get_root()
	if root == null:
		root = _variables.create_item()
	for variable_name: String in _variable_items.keys():
		if not values.has(variable_name):
			var stale: TreeItem = _variable_items[variable_name]
			stale.free()
			_variable_items.erase(variable_name)
	var names := values.keys()
	names.sort()
	for variable_name: String in names:
		var item: TreeItem = _variable_items.get(variable_name)
		if item == null:
			item = _variables.create_item(root)
			item.set_text(0, variable_name)
			_variable_items[variable_name] = item
		item.set_text(1, String(values[variable_name]))
		item.set_tooltip_text(1, String(values[variable_name]))
	# Keep rows in name order after new names appeared.
	var previous: TreeItem = null
	for variable_name: String in names:
		var item: TreeItem = _variable_items[variable_name]
		if previous != null and item.get_prev() != previous:
			item.move_after(previous)
		elif previous == null and item.get_prev() != null:
			item.move_before(root.get_first_child())
		previous = item


func _on_variable_activated() -> void:
	var item := _variables.get_selected()
	if item == null or _variables.get_selected_column() != 1:
		return
	if not _live or _watched_id == 0:
		return
	item.set_editable(1, true)
	_variables.edit_selected()


func _on_variable_edited() -> void:
	var item := _variables.get_edited()
	if item == null:
		return
	item.set_editable(1, false)
	if _watched_id != 0:
		message_requested.emit("behaviors:set_variable", [_watched_id, item.get_text(0), item.get_text(1)])

#endregion


#region History controls

func _update_slider() -> void:
	_slider.editable = _history.size() > 1
	_slider.max_value = maxi(0, _history.size() - 1)
	_slider.set_value_no_signal(maxi(0, _index))
	_step_back.disabled = _history.size() < 2
	_step_forward.disabled = _history.size() < 2


func _on_slider_changed(value: float) -> void:
	_freeze_at(int(value))


func _on_live_toggled(pressed: bool) -> void:
	_live = pressed
	if _live:
		_index = _history.size() - 1
	_show_current()


func _on_step(direction: int) -> void:
	if _history.size() == 0:
		return
	_freeze_at(clampi(_index + direction, 0, _history.size() - 1))


func _freeze_at(index: int) -> void:
	_live = false
	_live_toggle.set_pressed_no_signal(false)
	_index = clampi(index, 0, maxi(0, _history.size() - 1))
	_show_current()


func _on_capacity_changed(value: float) -> void:
	var dropped := _history.set_capacity(int(value))
	_index = maxi(0, _index - dropped) if _index >= 0 else -1
	if _live:
		_index = _history.size() - 1
	_show_current()

#endregion


func _send_control(command: String) -> void:
	if _watched_id != 0:
		message_requested.emit("behaviors:control", [_watched_id, command])


func _update_controls() -> void:
	var has_agent := _watched_id != 0
	for button: Button in [_pause, _resume, _restart, _stop, _show_tree]:
		button.disabled = not has_agent
	_live_toggle.disabled = not has_agent
	if not has_agent:
		_position_label.text = "Select an agent to watch it."


func _build() -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	split.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	_refresh.text = "Refresh"
	_refresh.pressed.connect(message_requested.emit.bind("behaviors:request_agents", []))
	top.add_child(_refresh)
	_show_tree.text = "Show tree"
	_show_tree.tooltip_text = "Open the watched agent's tree in the Behaviors screen."
	_show_tree.pressed.connect(_open_watched_tree.bind(true))
	top.add_child(_show_tree)
	top.add_child(VSeparator.new())
	for entry: Array in [[_pause, "Pause", "pause"], [_resume, "Resume", "resume"],
			[_restart, "Restart", "restart"], [_stop, "Stop", "stop"]]:
		var button: Button = entry[0]
		button.text = entry[1]
		button.pressed.connect(_send_control.bind(entry[2]))
		top.add_child(button)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.6)
	_hint.text = "The game is not running."
	left.add_child(_hint)
	_agents.columns = 4
	_agents.column_titles_visible = true
	for i in 4:
		_agents.set_column_title(i, ["Actor", "Agent path", "Tree", "State"][i])
	_agents.set_column_expand_ratio(0, 2)
	_agents.set_column_expand_ratio(1, 4)
	_agents.set_column_expand_ratio(2, 2)
	_agents.set_column_expand(3, false)
	_agents.set_column_custom_minimum_width(3, 70)
	_agents.hide_root = true
	_agents.allow_reselect = false
	_agents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_agents.item_selected.connect(_on_agent_selected)
	_agents.nothing_selected.connect(_on_agent_nothing_selected)
	left.add_child(_agents)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_variables.columns = 2
	_variables.column_titles_visible = true
	_variables.set_column_title(0, "Variable")
	_variables.set_column_title(1, "Value (double-click to edit)")
	_variables.set_column_expand_ratio(0, 2)
	_variables.set_column_expand_ratio(1, 3)
	_variables.hide_root = true
	_variables.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_variables.item_activated.connect(_on_variable_activated)
	_variables.item_edited.connect(_on_variable_edited)
	right.add_child(_variables)

	var bar := HBoxContainer.new()
	add_child(bar)
	_live_toggle.text = "Live"
	_live_toggle.button_pressed = true
	_live_toggle.toggled.connect(_on_live_toggled)
	bar.add_child(_live_toggle)
	_step_back.text = "◀"
	_step_back.tooltip_text = "Previous snapshot"
	_step_back.pressed.connect(_on_step.bind(-1))
	bar.add_child(_step_back)
	_slider.step = 1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.scrollable = true
	_slider.value_changed.connect(_on_slider_changed)
	bar.add_child(_slider)
	_step_forward.text = "▶"
	_step_forward.tooltip_text = "Next snapshot"
	_step_forward.pressed.connect(_on_step.bind(1))
	bar.add_child(_step_forward)
	_position_label.custom_minimum_size.x = 190
	bar.add_child(_position_label)
	var capacity_label := Label.new()
	capacity_label.text = "History"
	bar.add_child(capacity_label)
	_capacity.min_value = 2
	_capacity.max_value = 100000
	_capacity.step = 1
	_capacity.value = DEFAULT_HISTORY
	_capacity.tooltip_text = "How many state snapshots to keep."
	_capacity.value_changed.connect(_on_capacity_changed)
	bar.add_child(_capacity)
	_update_slider()
