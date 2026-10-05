@tool
extends RefCounted
## What the editor currently knows about: the quest open in the Quest Editor,
## the quests in its source list, and quests and identities found in the project.
## Property pickers use it to offer counters, node ids and quest ids.

signal current_quest_changed

var current_quest: Quest:
	set(value):
		if current_quest != value:
			current_quest = value
			current_quest_changed.emit()
## Quests listed by the source (database or quest list) open in the editor.
var source_quests: Array[Quest] = []

var _project_quests: Array[Quest] = []
var _project_dirty := true


func _init() -> void:
	if Engine.is_editor_hint():
		var filesystem := EditorInterface.get_resource_filesystem()
		if filesystem != null:
			filesystem.filesystem_changed.connect(mark_dirty)


func mark_dirty() -> void:
	_project_dirty = true


## Counter names of the quest being edited.
func get_counter_names(quest: Quest = null) -> PackedStringArray:
	var names := PackedStringArray()
	var target := quest if quest != null else current_quest
	if target != null:
		for counter in target.counter_list:
			if counter != null and not counter.name.is_empty():
				names.append(counter.name)
	return names


## Node ids of `quest`, or of the quest being edited.
func get_node_ids(quest: Quest = null) -> PackedStringArray:
	var ids := PackedStringArray()
	var target := quest if quest != null else current_quest
	if target != null:
		for node in target.node_list:
			if node != null and not node.id.is_empty():
				ids.append(node.id)
	return ids


func get_all_quests() -> Array[Quest]:
	var all: Array[Quest] = []
	for quest in source_quests:
		if quest != null and not all.has(quest):
			all.append(quest)
	if current_quest != null and not all.has(current_quest):
		all.append(current_quest)
	if _project_dirty:
		_scan_project()
	for quest in _project_quests:
		if not all.has(quest):
			all.append(quest)
	return all


func get_quest_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for quest in get_all_quests():
		if not quest.id.is_empty() and not ids.has(quest.id):
			ids.append(quest.id)
	return ids


func find_quest(quest_id: String) -> Quest:
	for quest in get_all_quests():
		if quest.id == quest_id:
			return quest
	return null


## Ids of QuestIdentity and QuestList nodes in the scene being edited.
func get_participant_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if not Engine.is_editor_hint():
		return ids
	var root := EditorInterface.get_edited_scene_root()
	if root != null:
		_collect_participants(root, ids)
	return ids


func _collect_participants(node: Node, ids: PackedStringArray) -> void:
	var id := ""
	if node is QuestIdentity or node is QuestList:
		id = node.get("id")
	if not id.is_empty() and not ids.has(id):
		ids.append(id)
	for child in node.get_children():
		_collect_participants(child, ids)


func _scan_project() -> void:
	_project_dirty = false
	_project_quests.clear()
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem == null or filesystem.get_filesystem() == null:
		return
	_scan_directory(filesystem.get_filesystem())


func _scan_directory(directory: EditorFileSystemDirectory) -> void:
	for index in directory.get_file_count():
		var script_class := directory.get_file_script_class_name(index)
		if script_class != "Quest" and script_class != "QuestDatabase":
			continue
		var resource := load(directory.get_file_path(index))
		if resource is Quest:
			_project_quests.append(resource)
		elif resource is QuestDatabase:
			for quest in resource.quest_assets:
				if quest != null:
					_project_quests.append(quest)
	for index in directory.get_subdir_count():
		_scan_directory(directory.get_subdir(index))
