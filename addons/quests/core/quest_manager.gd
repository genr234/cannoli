@icon("../icons/quest_manager.svg")
class_name QuestManager
extends Node
## Configures the quest system for a scene. Add one to your game.
##
## The manager registers the quests of its databases, sets the default UIs,
## advances [QuestsTime], ticks timers, cooldowns and time limits once per
## second, collects the data to save, and talks to the editor's debugger tab.
## It also re-emits what happens to every quest as typed signals.

enum CompletedQuestDialogueMode { SHOW_COMPLETED_QUEST, SHOW_NO_QUESTS }

## Emitted when any quest instance changes state.
signal quest_state_changed(quest: Quest, old_state: Quest.State, new_state: Quest.State)
## Emitted when any quest node changes state.
signal quest_node_state_changed(quest: Quest, node: QuestNode, new_state: QuestNode.State)
## Emitted when any quest counter changes.
signal quest_counter_changed(quest: Quest, counter: QuestCounter)
## Emitted when any quest becomes offerable.
signal quest_offerable(quest: Quest)
## Emitted when an alert should be shown.
signal quest_alert(quest_id: String, contents: Array[QuestContent])
## Emitted for every message sent through [QuestMessages].
signal message_sent(args: QuestMessageArgs)

@export var quest_databases: Array[QuestDatabase]
@export var dialogue_ui: QuestDialogueUI
@export var journal_ui: QuestJournalUI
@export var alert_ui: QuestAlertUI
@export var hud: QuestHUD
@export var completed_quest_dialogue_mode := CompletedQuestDialogueMode.SHOW_COMPLETED_QUEST
## If another manager already exists when this one enters the tree, this one frees itself.
@export var allow_only_one_instance := true
@export var hide_dialogue_ui_on_start := true
@export var hide_journal_ui_on_start := true
## Stop tracking quests in the HUD when they complete.
@export var untrack_completed_quests := true
## Store the manager's data with the Save addon, if it is installed.
@export var use_save_addon := true
@export_group("Generator")
@export var max_simultaneous_planners := 5
@export var max_goal_action_checks_per_frame := 100
@export var max_steps_per_frame := 100
## The domain type of the player, used when generating quests.
@export var default_player_domain_type: QuestDomainType
## How goal facts are chosen from the most urgent ones.
@export var goal_selection_mode: QuestUrgentFactSelectionMode
@export_group("Debug")
@export var debug := false
@export var debug_generator := false

## The active manager.
static var instance: QuestManager

# Set by the editor's Quests debugger tab while it's visible.
static var _debugger_watching := false

var _tick_time := 0.0
var _debugger_timer := 0.0
# Saved list data waiting for lists that haven't registered yet, by save key.
var _pending_list_data := {}
# Saved spawner and indicator data waiting for nodes that haven't entered the tree yet.
var _pending_node_data := {"spawners": {}, "indicators": {}}


func _enter_tree() -> void:
	if allow_only_one_instance and is_instance_valid(instance) and instance != self:
		if debug:
			print("Quests: A QuestManager already exists. Freeing %s." % get_path())
		queue_free()
		return
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if EngineDebugger.is_active() and not EngineDebugger.has_capture("quests"):
		EngineDebugger.register_message_capture("quests", _on_debugger_message)
	Quests.debug = debug and OS.is_debug_build()
	register_databases()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if instance != self:
		return
	if hide_dialogue_ui_on_start and dialogue_ui != null:
		dialogue_ui.hide()
	if hide_journal_ui_on_start and journal_ui != null:
		journal_ui.hide()
	if use_save_addon:
		Quests.register_with_save()


func _process(delta: float) -> void:
	if instance != self:
		return
	QuestsTime.advance(delta, get_tree().paused)
	if not QuestsTime.is_paused():
		_tick_time += QuestsTime.delta()
		while _tick_time >= 1.0:
			_tick_time -= 1.0
			tick()
	if _debugger_watching and EngineDebugger.is_active():
		_debugger_timer += delta
		if _debugger_timer >= 0.25:
			_debugger_timer = 0.0
			_send_debugger_state()


## Registers the quests and images of every database.
func register_databases() -> void:
	for database in quest_databases:
		if database != null:
			database.register()


## Runs the once-per-second work: sends the "Timer Tick" message, ticks the
## registered timers, updates cooldowns and checks time limits.
## Called automatically; call it yourself when using manual [QuestsTime].
func tick() -> void:
	QuestMessages.send(self, null, QuestMessages.TIMER_TICK)
	Quests.tick_timers()
	for list: Array in Quests.get_all_quest_instances().values().duplicate():
		for quest: Quest in list.duplicate():
			if quest.state == Quest.State.WAITING_TO_START:
				quest.update_cooldown()
			elif quest.state == Quest.State.ACTIVE:
				quest.update_time_limit()


## The default UIs and settings that quest lists fall back on.
func get_completed_quest_dialogue_mode() -> CompletedQuestDialogueMode:
	return completed_quest_dialogue_mode


## Deletes every quest from every list and reloads the lists' starting quests.
func reset_all() -> void:
	_pending_list_data.clear()
	_pending_node_data = {"spawners": {}, "indicators": {}}
	for list in Quests.get_all_quest_lists().values().duplicate():
		if is_instance_valid(list):
			list.reset_to_original_state()


#region Saving

## Records every registered quest list, in a JSON-compatible dictionary.
func record_data() -> Dictionary:
	var lists := _pending_list_data.duplicate()
	for list: QuestList in Quests.get_all_quest_lists().values():
		if is_instance_valid(list) and list.include_in_saved_game_data:
			lists[list.get_save_key()] = list.record_data()
	var data := {"version": 1, "lists": lists, "generator": {}, "completed": Array(Quests.get_completed_quest_ids()),
			"spawners": _record_nodes(&"quest_spawners", "spawner_name", "record_data"),
			"indicators": _record_nodes(&"quest_indicator_managers", "", "record_data")}
	if Quests.generator_record_callback.is_valid():
		data["generator"] = Quests.generator_record_callback.call()
	return data


## Restores data from [method record_data]. Lists that aren't registered yet
## get their data when they register.
func apply_data(data: Dictionary) -> void:
	if data.has("generator") and Quests.generator_apply_callback.is_valid():
		Quests.generator_apply_callback.call(data.generator)
	if data.has("completed"):
		Quests.set_completed_quest_ids(data.completed)
	_pending_list_data.clear()
	_apply_nodes(&"quest_spawners", "spawners", data.get("spawners", {}))
	_apply_nodes(&"quest_indicator_managers", "indicators", data.get("indicators", {}))
	var by_key := {}
	for list: QuestList in Quests.get_all_quest_lists().values():
		if is_instance_valid(list):
			by_key[list.get_save_key()] = list
	var lists: Dictionary = data.get("lists", {})
	for key: String in lists:
		if by_key.has(key):
			by_key[key].apply_data(lists[key])
		else:
			_pending_list_data[key] = lists[key]


# Saves the spawners or indicator managers in the tree, keyed by spawner name or entity id.
func _record_nodes(group: StringName, name_property: String, method: String) -> Dictionary:
	var result := {}
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group(group):
		var key := str(node.get(name_property)) if not name_property.is_empty() else str(node.call(&"get_entity_id"))
		if not key.is_empty():
			result[key] = node.call(method)
	return result


func _apply_nodes(group: StringName, kind: String, saved: Dictionary) -> void:
	var found := {}
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(group):
			var key := str(node.get(&"spawner_name")) if kind == "spawners" else str(node.call(&"get_entity_id"))
			found[key] = node
	_pending_node_data[kind] = {}
	for key: String in saved:
		if found.has(key):
			found[key].call(&"apply_data", saved[key])
		else:
			_pending_node_data[kind][key] = saved[key]


## Spawners and indicator managers call this when they are ready, to receive saved data
## that was applied before they existed. You don't need to call it.
func apply_pending_node_data(kind: String, key: String, node: Node) -> void:
	if _pending_node_data[kind].has(key):
		var data: Dictionary = _pending_node_data[kind][key]
		_pending_node_data[kind].erase(key)
		node.call(&"apply_data", data)


## Lists call this when they register. You don't need to call it.
func apply_pending_data(list: QuestList) -> void:
	var key := list.get_save_key()
	if _pending_list_data.has(key):
		var data: Dictionary = _pending_list_data[key]
		_pending_list_data.erase(key)
		list.apply_data(data)

#endregion

#region Debugger

static func _on_debugger_message(message: String, data: Array) -> bool:
	match message:
		"watch":
			_debugger_watching = bool(data[0]) if not data.is_empty() else false
			return true
		"set_state":
			var quest := _find_debugger_quest(data)
			if quest != null and data.size() >= 3:
				quest.set_state(int(data[2]) as Quest.State)
			return true
		"set_node_state":
			var quest := _find_debugger_quest(data)
			if quest != null and data.size() >= 4:
				var node := quest.get_node(str(data[2]))
				if node != null:
					node.set_state(int(data[3]) as QuestNode.State)
			return true
		"set_counter":
			var quest := _find_debugger_quest(data)
			if quest != null and data.size() >= 4:
				var counter := quest.get_counter(str(data[2]))
				if counter != null:
					counter.set_value(int(data[3]))
			return true
	return false


static func _find_debugger_quest(data: Array) -> Quest:
	if data.size() < 2:
		return null
	var list := Quests.get_quest_list(str(data[0]))
	if list == null:
		for candidate: QuestList in Quests.get_all_quest_lists().values():
			if is_instance_valid(candidate) and candidate.get_save_key() == str(data[0]):
				list = candidate
	return list.find_quest(str(data[1])) if list != null else null


func _send_debugger_state() -> void:
	if not EngineDebugger.is_active():
		return
	var lists := []
	for list: QuestList in Quests.get_all_quest_lists().values():
		if not is_instance_valid(list):
			continue
		var quests := []
		for quest in list.quest_list:
			var counters := {}
			for counter in quest.counter_list:
				if counter != null:
					counters[counter.name] = counter.current_value
			var nodes := []
			for node in quest.node_list:
				nodes.append({
					"id": node.id,
					"name": node.get_editor_name(),
					"type": int(node.node_type),
					"state": int(node.get_state()),
					"children": Array(node.children),
				})
			quests.append({
				"id": quest.id,
				"title": quest.title,
				"state": int(quest.get_state()),
				"tracking": quest.show_in_track_hud,
				"counters": counters,
				"nodes": nodes,
			})
		lists.append({
			"id": list.id,
			"save_key": list.get_save_key(),
			"is_journal": list is QuestJournal,
			"quests": quests,
		})
	EngineDebugger.send_message("quests:state", [{"lists": lists}])

#endregion
