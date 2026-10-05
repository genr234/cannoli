@icon("../icons/quest_list.svg")
class_name QuestList
extends Node
## A list of quest instances. [QuestJournal] and [QuestGiver] are quest lists.
##
## The quests you assign in [member quests] are assets. When the node is ready,
## it makes an instance of each and starts it. Quests added later with
## [method add_quest] are cloned the same way.

## Emitted when a quest instance is added, if [member forward_events_to_listeners] is on.
signal quest_added(quest: Quest)
## Emitted when a quest instance is removed, if [member forward_events_to_listeners] is on.
signal quest_removed(quest_id: String)
## Emitted when one of the list's quests becomes offerable.
signal quest_offerable(quest: Quest)
## Emitted when the state of one of the list's quests changes.
signal quest_state_changed(quest: Quest)
## Emitted when the state of a node of one of the list's quests changes.
signal quest_node_state_changed(node: QuestNode)

## Identifies the list. If blank, the id of a [QuestIdentity] on the same
## entity is used, or else the parent's name.
@export var id := ""
@export var display_name := ""
## Quest assets to add when the list is ready.
@export var quests: Array[Quest]
## Emit the quest signals. Journals and givers always need this.
@export var forward_events_to_listeners := false
@export var include_in_saved_game_data := true
## When loading a saved game, add quests from [member quests] that weren't in the save.
@export var add_new_quests_since_saved_game := false
## Key under which the list's data is saved. If blank, the node's path.
@export var save_key := ""

## The runtime quest instances.
var quest_list: Array[Quest] = []
## Ids of quest assets that were removed from this list, so they aren't added again.
var deleted_static_quests: Array[String] = []

var _startup_queue: Array[Quest] = []
var _startup_scheduled := false


func _enter_tree() -> void:
	var identity := QuestIdentity.find_for(self)
	if id.is_empty():
		id = identity.id if identity != null and not identity.id.is_empty() else QuestIdentity.fallback_name(self)
	if display_name.is_empty() and identity != null:
		display_name = identity.display_name
	Quests.register_quest_list(self)


func _exit_tree() -> void:
	Quests.unregister_quest_list(self)


func _ready() -> void:
	_instantiate_quest_assets()
	var manager := Quests.get_manager()
	if manager != null:
		manager.apply_pending_data(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_dispose_quest_instances()


func _instantiate_quest_assets() -> void:
	add_quests(quests, true)


func _dispose_quest_instances() -> void:
	for quest in quest_list:
		if quest != null:
			quest.dispose(true)
	quest_list.clear()


#region Adding and removing quests

## Adds quests like [method add_quest].
func add_quests(list: Array[Quest], delay_startup := false) -> void:
	for quest in list:
		add_quest(quest, delay_startup)


## Adds a quest. Assets are cloned; instances are added as they are. If
## [param delay_startup] is true, the quest starts at the end of the frame.
## Returns the instance, or null if the quest was deleted from this list before.
func add_quest(quest: Quest, delay_startup := false) -> Quest:
	if quest == null:
		return null
	if deleted_static_quests.has(quest.id):
		return null
	var instance := quest if quest.is_instance else quest.clone()
	quest_list.append(instance)
	Quests.register_quest_instance(instance)
	register_for_quest_events(instance)
	if delay_startup:
		_startup_queue.append(instance)
		if not _startup_scheduled:
			_startup_scheduled = true
			_run_startup_queue.call_deferred(Quests.is_loading_game)
	else:
		instance.runtime_startup()
	return instance


func _run_startup_queue(loading_game: bool) -> void:
	var previous := Quests.is_loading_game
	Quests.is_loading_game = loading_game
	var queue := _startup_queue.duplicate()
	_startup_queue.clear()
	_startup_scheduled = false
	for quest in queue:
		if quest_list.has(quest):
			quest.runtime_startup()
	Quests.is_loading_game = previous


func find_quest(quest_id: String) -> Quest:
	if quest_id.is_empty():
		return null
	for quest in quest_list:
		if quest != null and quest.id == quest_id:
			return quest
	return null


func contains_quest(quest_id: String) -> bool:
	return find_quest(quest_id) != null


## Removes a quest, given as an instance or an id, and disposes of it. Quest
## assets that were removed aren't added again unless they were generated.
func delete_quest(quest_or_id: Variant) -> void:
	var quest: Quest = quest_or_id if quest_or_id is Quest else find_quest(str(quest_or_id))
	if quest == null:
		return
	quest_list.erase(quest)
	if not quest.is_procedurally_generated and not deleted_static_quests.has(quest.id):
		deleted_static_quests.append(quest.id)
	unregister_for_quest_events(quest)
	Quests.unregister_quest_instance(quest)
	Quest.destroy_instance(quest)


## Deletes every quest instance and starts again from [member quests].
func reset_to_original_state() -> void:
	delete_all_quest_instances()
	deleted_static_quests.clear()
	_instantiate_quest_assets()


func delete_all_quest_instances() -> void:
	for i in range(quest_list.size() - 1, -1, -1):
		delete_quest(quest_list[i])

#endregion

#region Events

func register_for_quest_events(quest: Quest) -> void:
	if quest == null:
		return
	if quest.has_offer_conditions and quest.get_state() != Quest.State.ACTIVE:
		QuestMessages.add_listener(self, QuestMessages.CHECK_OFFER_CONDITIONS, quest.id, _on_check_offer_conditions)
	if not forward_events_to_listeners:
		return
	quest_added.emit(quest)
	quest.offerable.connect(_on_quest_offerable)
	quest.state_changed.connect(_on_quest_state_changed)
	for node in quest.node_list:
		node.state_changed.connect(_on_quest_node_state_changed)


func unregister_for_quest_events(quest: Quest) -> void:
	if quest == null:
		return
	if quest.has_offer_conditions:
		QuestMessages.remove_listener(self, QuestMessages.CHECK_OFFER_CONDITIONS, quest.id)
	if not forward_events_to_listeners:
		return
	quest_removed.emit(quest.id)
	if quest.offerable.is_connected(_on_quest_offerable):
		quest.offerable.disconnect(_on_quest_offerable)
	if quest.state_changed.is_connected(_on_quest_state_changed):
		quest.state_changed.disconnect(_on_quest_state_changed)
	for node in quest.node_list:
		if node.state_changed.is_connected(_on_quest_node_state_changed):
			node.state_changed.disconnect(_on_quest_node_state_changed)


func _on_check_offer_conditions(args: QuestMessageArgs) -> void:
	var quest := find_quest(args.parameter)
	if quest == null or not quest.has_offer_conditions:
		return
	if quest.state == Quest.State.WAITING_TO_START or quest.state == Quest.State.DISABLED:
		quest.offer_condition_set.stop_checking()
		quest.offer_condition_set.start_checking(quest.become_offerable)
		if not quest.offer_condition_set.are_conditions_met:
			quest.become_unofferable()


func _on_quest_offerable(quest: Quest) -> void:
	quest_offerable.emit(quest)


func _on_quest_state_changed(quest: Quest) -> void:
	quest_state_changed.emit(quest)


func _on_quest_node_state_changed(node: QuestNode) -> void:
	quest_node_state_changed.emit(node)

#endregion

#region Saving

func get_save_key() -> String:
	if not save_key.is_empty():
		return save_key
	return str(get_path()) if is_inside_tree() else String(name)


## Records the list in a dictionary with only JSON-compatible values. Quests
## that are also assets store just their state; generated quests store everything.
func record_data() -> Dictionary:
	if not include_in_saved_game_data:
		return {}
	var entries: Array[Dictionary] = []
	for quest in quest_list:
		if quest == null:
			continue
		if quest.is_procedurally_generated:
			entries.append({"id": quest.id, "static": false, "state": QuestSerializer.quest_to_dict(quest)})
		else:
			entries.append({"id": quest.id, "static": true, "state": QuestSerializer.state_to_dict(quest)})
	return {"id": id, "quests": entries, "deleted_static": deleted_static_quests.duplicate()}


## Restores data from [method record_data]. Quests start at the end of the
## frame without running their state actions.
func apply_data(data: Dictionary) -> void:
	if not include_in_saved_game_data or data.is_empty():
		return
	Quests.is_loading_game = true
	QuestMessages.allow_receive_same_frame_added = false
	# Adds them to the deleted list, but that is restored below.
	delete_all_quest_instances()
	var entries: Array = data.get("quests", [])
	for entry: Dictionary in entries:
		if not entry.get("static", true):
			var generated := QuestSerializer.dict_to_quest(entry.get("state", {}))
			if generated != null:
				add_quest(generated, true)
	deleted_static_quests.clear()
	for deleted_id in data.get("deleted_static", []):
		deleted_static_quests.append(str(deleted_id))
	# Add all quests first, in case one quest refers to another.
	for entry: Dictionary in entries:
		var quest_id := str(entry.get("id", ""))
		if not entry.get("static", true) or quest_id.is_empty() or deleted_static_quests.has(quest_id):
			continue
		var asset := _find_asset(quest_id)
		if asset == null:
			push_error("Quests: %s can't find quest '%s'. Is it registered in a database?" % [name, quest_id])
			continue
		add_quest(asset.clone(), true)
	for entry: Dictionary in entries:
		var quest_id := str(entry.get("id", ""))
		if not entry.get("static", true) or deleted_static_quests.has(quest_id):
			continue
		var quest := find_quest(quest_id)
		if quest != null:
			QuestSerializer.apply_state(quest, entry.get("state", {}))
	if add_new_quests_since_saved_game:
		for asset in quests:
			if asset != null and find_quest(asset.id) == null:
				add_quest(asset.clone(), true)
	QuestMessages.refresh_indicator(self, id)
	_finish_loading()


func _find_asset(quest_id: String) -> Quest:
	var asset := Quests.get_quest_asset(quest_id)
	if asset != null:
		return asset
	for candidate in quests:
		if candidate != null and candidate.id == quest_id:
			return candidate
	return null


# Delayed startups wait one frame; wait another so they finish before loading ends.
func _finish_loading() -> void:
	if not is_inside_tree():
		Quests.is_loading_game = false
		QuestMessages.allow_receive_same_frame_added = true
		return
	var tree := get_tree()
	await tree.process_frame
	QuestMessages.allow_receive_same_frame_added = true
	await tree.process_frame
	Quests.is_loading_game = false

#endregion


## The display name, or the id if there is none.
func get_display_name() -> String:
	return display_name if not display_name.is_empty() else id


## Information about the entity that owns the list.
func get_participant() -> QuestParticipant:
	var identity := QuestIdentity.find_for(self)
	var participant := QuestParticipant.new(id, get_display_name())
	if identity != null:
		participant.image = identity.image
	return participant
