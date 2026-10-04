@tool
extends HSplitContainer
## Shows the running game's faction members. Filled by the debugger plugin.

var _tree := Tree.new()
var _details := RichTextLabel.new()
var _state: Array = []
var _selected_path := ""


func _init() -> void:
	name = "Relationships"
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Member")
	_tree.set_column_title(1, "Faction")
	_tree.set_column_title(2, "Temperament")
	_tree.hide_root = true
	_tree.custom_minimum_size.x = 360
	_tree.item_selected.connect(func() -> void:
		_selected_path = _tree.get_selected().get_metadata(0)
		_show_details())
	add_child(_tree)
	_details.bbcode_enabled = true
	_details.selection_enabled = true
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_details)
	clear()


func clear() -> void:
	_state = []
	_tree.clear()
	_details.text = "[i]Run the game with a FactionManager to see its members here.[/i]"


func show_state(state: Array) -> void:
	_state = state
	_tree.clear()
	var root := _tree.create_item()
	for member: Dictionary in state:
		var item := _tree.create_item(root)
		item.set_text(0, str(member.path).get_base_dir().get_file() if str(member.path).ends_with("/FactionMember") else str(member.path).get_file())
		item.set_tooltip_text(0, member.path)
		item.set_metadata(0, member.path)
		item.set_text(1, member.faction)
		item.set_text(2, str(member.temperament).capitalize())
		if member.path == _selected_path:
			item.select(0)
	_show_details()


func _show_details() -> void:
	var member: Dictionary = {}
	for entry: Dictionary in _state:
		if entry.path == _selected_path:
			member = entry
	if member.is_empty():
		_details.text = "[i]Select a member.[/i]"
		return
	var text := "[b]%s[/b]  ·  %s\n\n" % [member.path, member.faction]
	var pad: Array = member.pad
	text += "[b]PAD[/b]  pleasure %d · arousal %d · dominance %d · happiness %d  (%s)\n\n" % [
			pad[1], pad[2], pad[3], pad[0], str(member.temperament).capitalize()]
	text += "[b]Affinities[/b]\n[table=4]"
	for affinity: Array in member.affinities:
		var color := "#8fcf6b" if affinity[1] > 0 else ("#e5534b" if affinity[1] < 0 else "#a0a8b8")
		text += "[cell]%s  [/cell][cell][color=%s]%d[/color]  [/cell][cell]%s  [/cell][cell]%s[/cell]" % [
				affinity[0], color, roundi(affinity[1]), affinity[2], "personal" if affinity[3] else "[i]inherited[/i]"]
	text += "[/table]\n\n[b]Memories[/b] (%d)\n" % member.memories.size()
	for memory: Array in member.memories:
		text += "• %s [i]%s[/i] %s — pleasure %d, ×%d, %s\n" % [memory[0], memory[1], memory[2], roundi(memory[3]), memory[4],
				"witnessed" if memory[5] == 0 else "heard (%d hops)" % memory[5]]
	_details.text = text
