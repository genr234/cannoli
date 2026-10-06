@tool
extends Tree
## The outline beside the graph: the open quest's info, counters, conditions and
## states, plus the selected node. Selecting an entry edits its resource; the
## right-click menu adds and removes counters and conditions.

const QuestActionMenu := preload("quest_action_menu.gd")

## Asks the editor to run `mutate` on the quest as an undoable action.
signal commit_requested(action_name: String, mutate: Callable)
## Asks the editor to repaint after a change made directly on the quest.
signal refresh_requested

var _quest: Quest
var _menu := QuestActionMenu.new()


func _init() -> void:
	custom_minimum_size.x = 260
	hide_root = true
	item_selected.connect(_on_item_selected)
	item_mouse_selected.connect(_on_mouse_selected)


func _ready() -> void:
	add_child(_menu)


## Rebuilds the tree for `quest` (may be null), expanding the node when exactly
## one id is in `selected_ids`.
func rebuild(quest: Quest, selected_ids: Array[String]) -> void:
	if not is_node_ready():
		return
	_quest = quest
	clear()
	var root := create_item()
	if _quest == null:
		return
	var info := _section(root, "Quest Info", _quest)
	for line in [
		["ID", _quest.id], ["Title", _quest.title], ["Group", _quest.group],
		["Quest Giver", _quest.quest_giver_id],
		["Trackable", str(_quest.is_trackable)], ["Abandonable", str(_quest.is_abandonable)],
		["Max times", "unlimited" if _quest.infinitely_repeatable else str(_quest.max_times)],
		["Cooldown", "%d s" % int(_quest.cooldown_seconds)],
		["Time limit", "%d s" % int(_quest.time_limit) if _quest.time_limit > 0.0 else "none"],
		["Requires", ", ".join(_quest.requires_quests) if not _quest.requires_quests.is_empty() else "none"]]:
		_leaf(info, "%s: %s" % line, _quest)
	info.collapsed = true
	var counters := _section(root, "Counters (%d)" % _quest.counter_list.size(), _quest, "counters")
	for counter in _quest.counter_list:
		if counter != null:
			_leaf(counters, "%s  [%d..%d]" % [counter.name, counter.min_value, counter.max_value], counter, "counter")
	_condition_section(root, "Autostart Conditions", _quest.autostart_condition_set, "autostart")
	var offer := _condition_section(root, "Offer Conditions", _quest.offer_condition_set, "offer")
	var offer_content := _section(offer, "Offer Content (%d)" % _quest.offer_content_list.size(), _quest)
	for content in _quest.offer_content_list:
		if content != null:
			_leaf(offer_content, content.get_editor_name(), content)
	var unmet := _section(offer, "Unmet Content (%d)" % _quest.offer_conditions_unmet_content_list.size(), _quest)
	for content in _quest.offer_conditions_unmet_content_list:
		if content != null:
			_leaf(unmet, content.get_editor_name(), content)
	var states := _section(root, "States", _quest)
	for state in Quest.State.size():
		_state_item(states, Quest.State.keys()[state].capitalize(), _quest.state_info_list[state])
	if selected_ids.size() == 1:
		var node := QuestGraphOps.find_node(_quest, selected_ids[0])
		if node != null:
			var node_item := _section(root, "Node: %s" % (node.internal_name if not node.internal_name.is_empty() else node.id), node)
			if node.condition_set != null:
				var conditions := _section(node_item, "Conditions (%d)" % node.condition_set.condition_list.size(), node.condition_set)
				for condition in node.condition_set.condition_list:
					if condition != null:
						_leaf(conditions, condition.get_editor_name(), condition)
			for state in QuestNode.State.size():
				_state_item(node_item, QuestNode.State.keys()[state].capitalize(), node.state_info_list[state])


func _section(parent: TreeItem, text: String, resource: Variant, kind := "") -> TreeItem:
	var item := create_item(parent)
	item.set_text(0, text)
	item.set_metadata(0, {"resource": resource, "kind": kind})
	item.set_custom_bg_color(0, Color(1, 1, 1, 0.06))
	return item


func _leaf(parent: TreeItem, text: String, resource: Variant, kind := "") -> TreeItem:
	var item := create_item(parent)
	item.set_text(0, text)
	item.set_metadata(0, {"resource": resource, "kind": kind})
	return item


func _condition_section(parent: TreeItem, title: String, condition_set: QuestConditionSet, kind: String) -> TreeItem:
	var count := condition_set.condition_list.size() if condition_set != null else 0
	var item := _section(parent, "%s (%d)" % [title, count], condition_set if condition_set != null else _quest, kind)
	if condition_set != null:
		for condition in condition_set.condition_list:
			if condition != null:
				_leaf(item, condition.get_editor_name(), condition, "condition")
	return item


func _state_item(parent: TreeItem, title: String, info: QuestStateInfo) -> void:
	if info == null:
		return
	var item := _section(parent, title, info)
	for action in info.action_list:
		if action != null:
			_leaf(item, "Action: " + action.get_editor_name(), action)
	for category in [["Dialogue", info.dialogue_content], ["Journal", info.journal_content], ["HUD", info.hud_content]]:
		for content in category[1]:
			if content != null:
				_leaf(item, "%s: %s" % [category[0], content.get_editor_name()], content)
	item.collapsed = item.get_child_count() == 0 or title != "Active"


func _on_item_selected() -> void:
	var item := get_selected()
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	var resource: Variant = data.resource
	if resource is Resource:
		EditorInterface.edit_resource(resource)
	elif resource == null and data.kind in ["autostart", "offer"]:
		_create_condition_set(data.kind)


func _create_condition_set(kind: String) -> void:
	if kind == "autostart":
		_quest.autostart_condition_set = QuestConditionSet.new()
	else:
		_quest.offer_condition_set = QuestConditionSet.new()
	refresh_requested.emit()


func _on_mouse_selected(_position: Vector2, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_RIGHT:
		return
	var item := get_selected()
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	_menu.reset()
	match data.kind:
		"counters":
			_menu.add_action("Add Counter", func() -> void:
				commit_requested.emit("Add Quest Counter", func() -> void:
					QuestGraphOps.add_counter(_quest, _unique_counter_name())))
		"counter":
			var counter: QuestCounter = data.resource
			_menu.add_action("Remove Counter", func() -> void:
				commit_requested.emit("Remove Quest Counter", func() -> void: QuestGraphOps.remove_counter(_quest, counter.name)))
		"autostart", "offer":
			for script_class in _subclasses_of("QuestCondition"):
				_menu.add_action("Add " + script_class.trim_prefix("Quest").trim_suffix("Condition") + " Condition", func() -> void:
					_add_condition(data.kind, script_class))
		"condition":
			var condition: Resource = data.resource
			_menu.add_action("Remove Condition", func() -> void: _remove_condition(condition))
	if _menu.item_count > 0:
		_menu.popup_at_mouse()


func _unique_counter_name() -> String:
	var index := 1
	while _counter_exists("counter%d" % index):
		index += 1
	return "counter%d" % index


func _counter_exists(counter_name: String) -> bool:
	for counter in _quest.counter_list:
		if counter != null and counter.name == counter_name:
			return true
	return false


func _add_condition(kind: String, script_class: String) -> void:
	var condition: QuestCondition = _instantiate(script_class)
	if condition == null:
		return
	var condition_set := _quest.autostart_condition_set if kind == "autostart" else _quest.offer_condition_set
	if condition_set == null:
		condition_set = QuestConditionSet.new()
		if kind == "autostart":
			_quest.autostart_condition_set = condition_set
		else:
			_quest.offer_condition_set = condition_set
	condition_set.condition_list.append(condition)
	refresh_requested.emit()
	EditorInterface.edit_resource(condition)


func _remove_condition(condition: Resource) -> void:
	for condition_set in [_quest.autostart_condition_set, _quest.offer_condition_set]:
		if condition_set != null and condition_set.condition_list.has(condition):
			condition_set.condition_list.erase(condition)
	for node in _quest.node_list:
		if node != null and node.condition_set != null:
			node.condition_set.condition_list.erase(condition)
	refresh_requested.emit()


## Names of the global classes that inherit `base`, sorted.
static func _subclasses_of(base: String) -> PackedStringArray:
	var parents := {}
	for entry in ProjectSettings.get_global_class_list():
		parents[entry["class"]] = entry["base"]
	var result := PackedStringArray()
	for class_name_text: String in parents:
		var current: String = parents[class_name_text]
		while not current.is_empty():
			if current == base:
				result.append(class_name_text)
				break
			current = parents.get(current, "")
	result.sort()
	return result


static func _instantiate(script_class: String) -> Resource:
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == script_class:
			return load(entry["path"]).new()
	return null
