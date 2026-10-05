@tool
extends HSplitContainer
## Shows the running game's quest lists as a tree: lists, quests, their counters
## and nodes. Select an entry to change its state or value in the running game.
## Filled by the debugger plugin.

## Emitted with a `quests:*` message and its arguments to send to the game.
signal command(message: String, args: Array)

const QUEST_STATE_COLORS: Dictionary[String, Color] = {
	"ACTIVE": Color("f2c14e"),
	"SUCCESSFUL": Color("8fcf6b"),
	"FAILED": Color("e5534b"),
	"ABANDONED": Color("a0a8b8"),
	"DISABLED": Color("707888"),
	"TRUE": Color("8fcf6b"),
}

var _tree := Tree.new()
var _details := VBoxContainer.new()
var _title := Label.new()
var _state_row := HBoxContainer.new()
var _state_options := OptionButton.new()
var _state_button := Button.new()
var _counter_row := HBoxContainer.new()
var _counter_value := SpinBox.new()
var _counter_button := Button.new()
var _info := RichTextLabel.new()
var _state: Dictionary = {}
var _selected_key := ""
var _collapsed: Dictionary = {}


func _init() -> void:
	name = "Quests"
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Quest")
	_tree.set_column_title(1, "State")
	_tree.set_column_title(2, "Info")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 110)
	_tree.hide_root = true
	_tree.custom_minimum_size.x = 420
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_collapsed.connect(func(item: TreeItem) -> void:
		_collapsed[_key_of(item)] = item.collapsed)
	add_child(_tree)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 16)
	_details.add_child(_title)
	_state_row.add_child(_state_options)
	_state_button.pressed.connect(_on_set_state_pressed)
	_state_row.add_child(_state_button)
	_details.add_child(_state_row)
	_counter_value.allow_greater = true
	_counter_value.allow_lesser = true
	_counter_row.add_child(_counter_value)
	_counter_button.text = "Set counter value"
	_counter_button.pressed.connect(_on_set_counter_pressed)
	_counter_row.add_child(_counter_button)
	_details.add_child(_counter_row)
	_info.bbcode_enabled = true
	_info.selection_enabled = true
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(_info)
	add_child(_details)
	clear()


func clear() -> void:
	_state = {}
	_tree.clear()
	_selected_key = ""
	_title.text = "No game running"
	_state_row.hide()
	_counter_row.hide()
	_info.text = "[i]Run the game with a QuestManager to see its quests here.[/i]"


func show_state(state: Dictionary) -> void:
	_state = state
	_tree.clear()
	var root := _tree.create_item()
	var lists: Array = state.get("lists", [])
	for list: Dictionary in lists:
		var list_id: String = list.get("id", "")
		var list_item := _tree.create_item(root)
		list_item.set_text(0, list_id if not list_id.is_empty() else str(list.get("save_key", "(unnamed list)")))
		list_item.set_text(2, "journal" if list.get("is_journal", false) else "list")
		list_item.set_metadata(0, {"kind": "list", "list_id": list_id, "key": "L:" + list_id})
		for quest: Dictionary in list.get("quests", []):
			_add_quest(list_item, list_id, quest)
		_restore(list_item)
	_reselect(root)
	if lists.is_empty():
		_info.text = "[i]The game has no quest lists yet.[/i]"
		_title.text = "Quests"
		_state_row.hide()
		_counter_row.hide()


func _add_quest(parent: TreeItem, list_id: String, quest: Dictionary) -> void:
	var quest_id: String = quest.get("id", "")
	var item := _tree.create_item(parent)
	item.set_text(0, str(quest.get("title", quest_id)) if not str(quest.get("title", "")).is_empty() else quest_id)
	item.set_tooltip_text(0, quest_id)
	_set_state_text(item, _name_of(quest.get("state", ""), Quest.State.keys()))
	item.set_text(2, "tracked" if quest.get("tracking", false) else "")
	item.set_metadata(0, {"kind": "quest", "list_id": list_id, "quest_id": quest_id, "key": "Q:%s/%s" % [list_id, quest_id], "quest": quest})
	var counters: Dictionary = quest.get("counters", {})
	if not counters.is_empty():
		var group := _tree.create_item(item)
		group.set_text(0, "Counters")
		group.set_metadata(0, {"kind": "group", "key": "C:%s/%s" % [list_id, quest_id]})
		for counter_name: String in counters:
			var counter_item := _tree.create_item(group)
			counter_item.set_text(0, counter_name)
			counter_item.set_text(1, str(counters[counter_name]))
			counter_item.set_metadata(0, {"kind": "counter", "list_id": list_id, "quest_id": quest_id, "counter": counter_name,
					"value": counters[counter_name], "key": "c:%s/%s/%s" % [list_id, quest_id, counter_name]})
	var nodes: Array = quest.get("nodes", [])
	if not nodes.is_empty():
		var group := _tree.create_item(item)
		group.set_text(0, "Nodes")
		group.set_metadata(0, {"kind": "group", "key": "N:%s/%s" % [list_id, quest_id]})
		for node: Dictionary in nodes:
			var node_item := _tree.create_item(group)
			var node_name := str(node.get("name", ""))
			node_item.set_text(0, "%s (%s)" % [node_name, node.get("id", "")] if not node_name.is_empty() else str(node.get("id", "")))
			_set_state_text(node_item, _name_of(node.get("state", ""), QuestNode.State.keys()))
			node_item.set_text(2, "%s -> %s" % [_name_of(node.get("type", ""), QuestNode.Type.keys()), ", ".join(PackedStringArray(node.get("children", [])))])
			node_item.set_metadata(0, {"kind": "node", "list_id": list_id, "quest_id": quest_id, "node_id": node.get("id", ""),
					"key": "n:%s/%s/%s" % [list_id, quest_id, node.get("id", "")], "node": node})
	_restore(item)


func _restore(item: TreeItem) -> void:
	for child in item.get_children():
		_restore(child)
	var key := _key_of(item)
	if _collapsed.has(key):
		item.collapsed = _collapsed[key]
	elif item.get_metadata(0) is Dictionary and item.get_metadata(0).kind == "group":
		item.collapsed = true


func _reselect(item: TreeItem) -> void:
	if item.get_metadata(0) is Dictionary and item.get_metadata(0).get("key", "") == _selected_key and not _selected_key.is_empty():
		item.select(0)
		_show_details(item.get_metadata(0))
		return
	for child in item.get_children():
		_reselect(child)


func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null or not item.get_metadata(0) is Dictionary:
		return
	var data: Dictionary = item.get_metadata(0)
	_selected_key = data.get("key", "")
	_show_details(data)


func _show_details(data: Dictionary) -> void:
	_state_row.hide()
	_counter_row.hide()
	match data.kind:
		"quest":
			_title.text = "Quest %s" % data.quest_id
			_fill_state_options(Quest.State.keys(), _name_of(data.quest.get("state", ""), Quest.State.keys()))
			_state_button.text = "Set quest state"
			_state_row.show()
			_info.text = "[b]%s[/b]\n%d nodes, %d counters" % [data.quest.get("title", ""), data.quest.get("nodes", []).size(), data.quest.get("counters", {}).size()]
		"node":
			_title.text = "Node %s" % data.node_id
			_fill_state_options(QuestNode.State.keys(), _name_of(data.node.get("state", ""), QuestNode.State.keys()))
			_state_button.text = "Set node state"
			_state_row.show()
			_info.text = "Type: %s\nChildren: %s" % [_name_of(data.node.get("type", ""), QuestNode.Type.keys()), ", ".join(PackedStringArray(data.node.get("children", [])))]
		"counter":
			_title.text = "Counter %s" % data.counter
			if not _counter_value.has_focus():
				_counter_value.value = int(data.value)
			_counter_row.show()
			_info.text = "Current value: %s" % data.value
		_:
			_title.text = str(data.get("list_id", "Quests"))
			_info.text = ""


func _fill_state_options(state_names: Array, current: String) -> void:
	var selected := _state_options.selected
	_state_options.clear()
	for index in state_names.size():
		_state_options.add_item(state_names[index].capitalize(), index)
		if state_names[index] == current.to_upper():
			selected = index
	_state_options.select(selected if selected >= 0 else 0)


func _on_set_state_pressed() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	var state_id := _state_options.get_selected_id()
	if data.kind == "quest":
		command.emit("quests:set_state", [data.list_id, data.quest_id, state_id])
	elif data.kind == "node":
		command.emit("quests:set_node_state", [data.list_id, data.quest_id, data.node_id, state_id])


func _on_set_counter_pressed() -> void:
	var item := _tree.get_selected()
	if item != null and item.get_metadata(0).kind == "counter":
		var data: Dictionary = item.get_metadata(0)
		command.emit("quests:set_counter", [data.list_id, data.quest_id, data.counter, int(_counter_value.value)])


func _key_of(item: TreeItem) -> String:
	var meta: Variant = item.get_metadata(0)
	return meta.get("key", "") if meta is Dictionary else ""


func _set_state_text(item: TreeItem, state_name: String) -> void:
	var upper := state_name.to_upper()
	item.set_text(1, state_name.capitalize())
	if QUEST_STATE_COLORS.has(upper):
		item.set_custom_color(1, QUEST_STATE_COLORS[upper])


## Names a state that arrives either as an enum value or as text.
func _name_of(value: Variant, keys: Array) -> String:
	if value is int and value >= 0 and value < keys.size():
		return keys[value]
	return str(value)
