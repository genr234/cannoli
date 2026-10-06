@tool
extends VBoxContainer
## Lists the running players of the game. Filled by the debugger plugin.

var _tree := Tree.new()
var _hint := Label.new()


func _init() -> void:
	name = "Juice"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate = Color(1, 1, 1, 0.6)
	add_child(_hint)
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Player")
	_tree.set_column_title(1, "Time")
	_tree.set_column_title(2, "Plays")
	_tree.set_column_title(3, "Active feedbacks")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand_ratio(0, 3)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 140)
	_tree.set_column_expand(2, false)
	_tree.set_column_custom_minimum_width(2, 60)
	_tree.set_column_expand_ratio(3, 4)
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tree)
	clear()


func clear() -> void:
	_tree.clear()
	_hint.text = "No data. Run the game with JuicePlayer nodes that report to the debugger."
	_hint.visible = true


func show_state(state: Array) -> void:
	_tree.clear()
	var root := _tree.create_item()
	_hint.text = "No player is playing right now."
	_hint.visible = state.is_empty()
	for entry: Dictionary in state:
		var item := _tree.create_item(root)
		item.set_text(0, entry.name)
		item.set_tooltip_text(0, entry.path)
		var total := "∞" if entry.endless else "%.2f" % entry.total
		item.set_text(1, "%.2f / %s s%s" % [entry.elapsed, total, "  (paused)" if entry.paused else ""])
		item.set_text(2, str(entry.plays))
		item.set_text(3, ", ".join(PackedStringArray(entry.active)))
