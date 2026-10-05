@icon("../icons/quest.svg")
class_name Quest
extends Resource
## A quest.
##
## A quest saved in a [QuestDatabase] is an asset. Adding it to a [QuestList]
## makes a runtime instance with [method clone]. The instance holds the
## runtime state: its state, node states, counter values and listeners.
## Exported properties are the authored data; runtime state is in variables
## that aren't exported, so cloning starts fresh.

enum State { WAITING_TO_START, ACTIVE, SUCCESSFUL, FAILED, ABANDONED, DISABLED }
enum IndicatorState { NONE, OFFER_DISABLED, TALK_DISABLED, INTERACT_DISABLED, OFFER, TALK, INTERACT,
	CUSTOM_0, CUSTOM_1, CUSTOM_2, CUSTOM_3, CUSTOM_4, CUSTOM_5, CUSTOM_6, CUSTOM_7, CUSTOM_8, CUSTOM_9 }

const NUM_STATES := 6

## Emitted when the quest has become offerable.
signal offerable(quest: Quest)
## Emitted when the quest's state has changed.
signal state_changed(quest: Quest)
## Emitted when one of the quest's counters changed.
signal counter_changed(quest: Quest, counter: QuestCounter)

@export var id := ""
@export var title := ""
@export var icon: Texture2D
## Optional group under which UIs list the quest.
@export var group := ""
## Optional labels for sorting and filtering.
@export var labels: PackedStringArray
## Id of the quest giver that offered the quest. Set on the quester's instance
## when the quest is accepted.
@export var quest_giver_id := ""
## Allow the player to toggle tracking on and off.
@export var is_trackable := true
## Show in the quest HUD.
@export var show_in_track_hud := true:
	set(value):
		show_in_track_hud = value
		if is_instance:
			QuestMessages.quest_track_toggle_changed(self, id, value)
@export var is_abandonable := false
## Keep the quest in the journal if abandoned.
@export var remember_if_abandoned := false
## Delete when completed even if the journal remembers completed quests.
@export var delete_when_complete := false
## Conditions that start the quest when they become true.
@export var autostart_condition_set := QuestConditionSet.new()
## Conditions that must be true before the quest can be offered.
@export var offer_condition_set := QuestConditionSet.new()
## Dialogue to show when the offer conditions are unmet.
@export var offer_conditions_unmet_content_list: Array[QuestContent]
## Dialogue to show when offering the quest.
@export var offer_content_list: Array[QuestContent]
@export var infinitely_repeatable := false
## Max number of times the quest can be accepted.
@export var max_times := 1
## Seconds that must pass after acceptance before the quest is offered again.
@export var cooldown_seconds := 0.0
## Do not offer again if the quester already completed the quest successfully.
@export var no_repeat_if_successful := false
## Save counters, node states and indicator states even while waiting to start.
@export var save_all_if_waiting_to_start := false
## Info for each [enum State], indexed by state. Always has 6 entries.
@export var state_info_list: Array[QuestStateInfo]:
	get:
		QuestStateInfo.validate_list(state_info_list, NUM_STATES)
		return state_info_list
@export var counter_list: Array[QuestCounter]
## All nodes. The first one is the start node.
@export var node_list: Array[QuestNode]
## Tags and their values. Filled by the quest's text and by the generator.
@export var tag_dictionary := {}
@export var goal_entity_type_name := ""
@export var is_procedurally_generated := false
@export_storage var next_content_id := 0
## Ids of quests that must be successful before this quest can be offered.
@export var requires_quests: PackedStringArray
## If above zero, the quest fails when this many seconds pass while it's active.
@export var time_limit := 0.0
## Derive "name 3/5" objective lines from counters with a display name.
@export var auto_objectives := true

## True for runtime instances, false for assets.
var is_instance := false
## The asset this instance was cloned from, or null if it was generated.
var original_asset: Quest
var times_accepted := 0
var cooldown_seconds_remaining := 0.0
## Seconds left before the time limit runs out.
var time_remaining := 0.0
## The current speaker, if different from the quest giver. Null means the quest giver.
var current_speaker: QuestParticipant
## Entity id -> [enum IndicatorState].
var indicator_states := {}
## Ids of everyone who speaks in the quest or its nodes.
var speakers := PackedStringArray()

var state := State.WAITING_TO_START
var _time_cooldown_last_checked := 0.0
var _time_limit_last_checked := 0.0
var _content_by_id := {}

## The quester's id, from the tag dictionary.
var quester_id: String:
	get:
		return str(tag_dictionary.get(QuestTags.QUESTERID, ""))
## The id of the quester who is greeting the giver. For quests that one
## quester accepts and another turns in, this is the second quester.
var greeter_id: String:
	get:
		return str(tag_dictionary.get(QuestTags.GREETERID, ""))
	set(value):
		tag_dictionary[QuestTags.GREETERID] = value
var greeter: String:
	get:
		return str(tag_dictionary.get(QuestTags.GREETER, ""))
	set(value):
		tag_dictionary[QuestTags.GREETER] = value

var has_autostart_conditions: bool:
	get:
		return QuestConditionSet.condition_count(autostart_condition_set) > 0
var has_offer_conditions: bool:
	get:
		return QuestConditionSet.condition_count(offer_condition_set) > 0
## True while waiting to start and every requirement for offering is met.
var is_offerable: bool:
	get:
		return state == State.WAITING_TO_START and can_be_offered()


## Creates an empty quest with a start node and empty state info.
static func create(p_id: String, p_title := "") -> Quest:
	var quest := Quest.new()
	quest.id = p_id
	quest.title = p_title if not p_title.is_empty() else p_id
	quest.node_list.append(QuestNode.create_start_node(p_id))
	return quest


func get_editor_name() -> String:
	if not title.is_empty():
		return title
	if not id.is_empty():
		return id
	return "Unnamed Quest"


func get_start_node() -> QuestNode:
	return node_list[0] if node_list.size() > 0 else null


#region Initialization

## Returns a new runtime instance with its own copy of every subasset.
func clone() -> Quest:
	# Internal subresources are copied. Textures and sounds that live in their own
	# files stay shared, so they keep their paths; subassets that live in their
	# own files are copied by _copy_external_subassets.
	var copy: Quest = duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	_copy_external_subassets(copy, {})
	copy.is_instance = true
	copy.original_asset = original_asset if is_instance else self
	copy.cooldown_seconds_remaining = 0.0
	copy.initialize()
	return copy


# Replaces subassets that were saved as separate files by copies, so each
# instance has its own runtime state.
static func _copy_external_subassets(owner: Object, visited: Dictionary) -> void:
	if visited.has(owner.get_instance_id()):
		return
	visited[owner.get_instance_id()] = true
	for info in owner.get_property_list():
		var usage: int = info.usage
		if not (usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = owner.get(info.name)
		if value is Resource:
			var replacement := _unique_subasset(value, visited)
			if replacement != value:
				owner.set(info.name, replacement)
		elif value is Array:
			for i in value.size():
				if value[i] is Resource:
					value[i] = _unique_subasset(value[i], visited)


static func _unique_subasset(resource: Resource, visited: Dictionary) -> Resource:
	if resource.get_script() == null:
		return resource
	var result := resource
	if not resource.resource_path.is_empty() and not resource.resource_path.contains("::"):
		result = resource.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	_copy_external_subassets(result, visited)
	return result


## Wires the runtime references of the quest and everything in it, and sets
## counters to their initial values.
func initialize() -> void:
	for counter in counter_list:
		if counter != null:
			counter.reset()
	set_runtime_references()


## Wires the runtime references: quest, nodes, subassets and tags. Doesn't
## change counter values.
func set_runtime_references() -> void:
	_time_cooldown_last_checked = QuestsTime.now()
	_time_limit_last_checked = QuestsTime.now()
	if autostart_condition_set == null:
		autostart_condition_set = QuestConditionSet.new()
	if offer_condition_set == null:
		offer_condition_set = QuestConditionSet.new()
	autostart_condition_set.set_runtime_references(self, null)
	offer_condition_set.set_runtime_references(self, null)
	QuestContent.set_runtime_references_in(offer_conditions_unmet_content_list, self, null)
	QuestContent.set_runtime_references_in(offer_content_list, self, null)
	for counter in counter_list:
		if counter != null:
			counter.set_runtime_references(self)
	for info in state_info_list:
		info.set_runtime_references(self, null)
	# Remove empty entries so the rest of the code can rely on real nodes.
	for i in range(node_list.size() - 1, -1, -1):
		if node_list[i] == null:
			node_list.remove_at(i)
	for node in node_list:
		node.initialize_runtime_references(self)
	for node in node_list:
		node.connect_runtime_node_references()
	for node in node_list:
		node.set_runtime_node_references()
	_record_speakers()
	QuestTags.add_tags_to_dictionary(tag_dictionary, title)
	QuestTags.add_tags_to_dictionary(tag_dictionary, group)
	if not quest_giver_id.is_empty():
		tag_dictionary[QuestTags.QUESTGIVERID] = quest_giver_id


func _record_speakers() -> void:
	speakers = PackedStringArray()
	if not quest_giver_id.is_empty():
		speakers.append(quest_giver_id)
	for node in node_list:
		if not node.speaker.is_empty() and not speakers.has(node.speaker):
			speakers.append(node.speaker)


func assign_quest_giver(info: QuestParticipant) -> void:
	if info == null:
		return
	quest_giver_id = info.id
	if not info.id.is_empty() and not speakers.has(info.id):
		speakers.append(info.id)
	tag_dictionary[QuestTags.QUESTGIVERID] = info.id
	tag_dictionary[QuestTags.QUESTGIVER] = info.display_name


func assign_quester(info: QuestParticipant) -> void:
	if info == null or info.id.is_empty():
		return
	tag_dictionary[QuestTags.QUESTERID] = info.id
	tag_dictionary[QuestTags.QUESTER] = info.display_name


## Stops everything the instance is doing so it can be freed: sets the state
## to DISABLED, stops listening for messages, and unregisters it. Pass
## [param silent] to skip state actions and messages.
func dispose(silent := false) -> void:
	if not is_instance:
		return
	Quests.unregister_quest_instance(self)
	if state != State.DISABLED:
		set_state(State.DISABLED, not silent)
	autostart_condition_set.stop_checking()
	offer_condition_set.stop_checking()
	_set_counter_listeners(false)
	for node in node_list:
		node.dispose()
	QuestMessages.remove_listener(self)


## Disposes of a runtime instance. Does nothing for assets.
static func destroy_instance(quest: Quest) -> void:
	if quest != null and quest.is_instance:
		quest.dispose()

#endregion

#region Startup

## Performs the runtime startup: puts the quest in its current state.
## Loading a saved game doesn't run state actions.
func runtime_startup() -> void:
	set_state(state, not Quests.is_loading_game)


## Begins or ends checking autostart and offer conditions.
func set_start_checking(enable: bool) -> void:
	if not is_instance:
		return
	if enable:
		_set_random_counter_values()
		if has_autostart_conditions:
			autostart_condition_set.start_checking(_autostart)
		if state == State.WAITING_TO_START: # Autostart might have made the quest active.
			if has_offer_conditions:
				offer_condition_set.start_checking(_on_offer_conditions_true)
			elif are_requirements_met():
				become_offerable()
	else:
		if has_autostart_conditions:
			autostart_condition_set.stop_checking()
		if has_offer_conditions:
			offer_condition_set.stop_checking()


func reset_start_conditions() -> void:
	if autostart_condition_set != null:
		autostart_condition_set.reset_conditions()
	if offer_condition_set != null:
		offer_condition_set.reset_conditions()


func _autostart() -> void:
	set_state(State.ACTIVE)


func _on_offer_conditions_true() -> void:
	if are_requirements_met():
		become_offerable()


## Makes the quest offerable: puts it in WAITING_TO_START, emits
## [signal offerable] and sets the giver's indicator to OFFER.
func become_offerable() -> void:
	if state != State.WAITING_TO_START:
		set_state(State.WAITING_TO_START)
	offerable.emit(self)
	var manager := Quests.get_manager()
	if manager != null:
		manager.quest_offerable.emit(self)
	set_indicator_state(quest_giver_id, IndicatorState.OFFER)


func become_unofferable() -> void:
	if state != State.DISABLED:
		set_state(State.DISABLED)
	set_indicator_state(quest_giver_id, IndicatorState.NONE)


## Starts the cooldown period.
func start_cooldown() -> void:
	if cooldown_seconds <= 0.0:
		return
	cooldown_seconds_remaining = cooldown_seconds
	_time_cooldown_last_checked = QuestsTime.now()


## Updates the cooldown from the current time. The quest becomes offerable
## when the cooldown ends.
func update_cooldown() -> void:
	if cooldown_seconds_remaining <= 0.0:
		return
	var current := QuestsTime.now()
	var elapsed := current - _time_cooldown_last_checked
	_time_cooldown_last_checked = current
	cooldown_seconds_remaining = maxf(0.0, cooldown_seconds_remaining - elapsed)
	if cooldown_seconds_remaining <= 0.0:
		become_offerable()


## The most times the quest can be accepted.
func get_max_times() -> int:
	return 0x7FFFFFFF if infinitely_repeatable else max_times


## True if every quest in [member requires_quests] is successful.
func are_requirements_met() -> bool:
	for required_id in requires_quests:
		if Quests.get_quest_state(required_id, quester_id) != State.SUCCESSFUL and not Quests.was_completed(required_id):
			return false
	return true


## True if a giver may offer the quest: the offer conditions are met, the
## required quests are done, it wasn't accepted too many times, and the
## cooldown is over.
func can_be_offered() -> bool:
	return (not has_offer_conditions or offer_condition_set.are_conditions_met) \
			and times_accepted < get_max_times() and cooldown_seconds_remaining <= 0.0 \
			and are_requirements_met()


## Checks the time limit against the current time. Fails the quest if it ran out.
func update_time_limit() -> void:
	if state != State.ACTIVE or time_limit <= 0.0 or time_remaining <= 0.0:
		return
	var current := QuestsTime.now()
	var elapsed := current - _time_limit_last_checked
	_time_limit_last_checked = current
	time_remaining = maxf(0.0, time_remaining - elapsed)
	if time_remaining <= 0.0:
		if Quests.debug:
			print("Quests: %s ran out of time." % get_editor_name())
		set_state(State.FAILED)

#endregion

#region State

func get_state() -> State:
	return state


## Sets the quest state. This may also change node states.
func set_state(new_state: State, inform_listeners := true) -> void:
	if Quests.debug:
		print("Quests: %s.set_state(%s, inform_listeners=%s)" % [get_editor_name(), State.find_key(new_state), inform_listeners])
	var old_state := state
	state = new_state
	if state == State.WAITING_TO_START:
		reset_start_conditions()
	set_start_checking(state == State.WAITING_TO_START)
	_set_counter_listeners(state == State.ACTIVE or (state == State.WAITING_TO_START \
			and (has_autostart_conditions or has_offer_conditions)))
	if state != State.ACTIVE:
		_stop_node_listeners()
	if not inform_listeners:
		if state == State.ACTIVE:
			_time_limit_last_checked = QuestsTime.now()
		return
	if state == State.ACTIVE:
		time_remaining = time_limit
		_time_limit_last_checked = QuestsTime.now()
	execute_state_actions(state)
	QuestMessages.quest_state_changed(self, id, state)
	state_changed.emit(self)
	var manager := Quests.get_manager()
	if manager != null:
		manager.quest_state_changed.emit(self, old_state, new_state)
	if state == State.ACTIVE and get_start_node() != null:
		get_start_node().set_state(QuestNode.State.ACTIVE)
	if state != State.ACTIVE:
		clear_indicator_states()
	if state == State.SUCCESSFUL or state == State.FAILED or state == State.ABANDONED:
		for node in node_list:
			if node.get_state() == QuestNode.State.ACTIVE:
				node.set_state(QuestNode.State.INACTIVE)
		if manager != null and manager.untrack_completed_quests:
			show_in_track_hud = false
	if new_state == State.SUCCESSFUL:
		Quests.notify_quest_succeeded(self)


## Sets the internal state without any processing.
func set_state_raw(new_state: State) -> void:
	state = new_state


func get_state_info(p_state: State) -> QuestStateInfo:
	return state_info_list[p_state]


func execute_state_actions(p_state: State) -> void:
	get_state_info(p_state).execute_actions()


func _stop_node_listeners() -> void:
	for node in node_list:
		node.set_condition_checking(false)

#endregion

#region Counters

func _set_random_counter_values() -> void:
	for counter in counter_list:
		if counter != null and counter.randomize_initial_value:
			counter.set_random_value()


func _set_counter_listeners(enable: bool) -> void:
	for counter in counter_list:
		if counter != null:
			counter.set_listeners(enable)


## Returns the counter with the given name, or null.
func get_counter(counter_name: String) -> QuestCounter:
	for counter in counter_list:
		if counter != null and counter.name == counter_name:
			return counter
	return null


## Objectives derived from counters that have a display name, such as
## "Wolves 3/5". Each entry is {text, current, goal, done, counter_name}.
## Empty if [member auto_objectives] is off.
func get_objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not auto_objectives:
		return result
	for counter in counter_list:
		if counter == null or counter.display_name.is_empty():
			continue
		var goal := counter.get_goal(self)
		var current := counter.current_value
		result.append({
			"text": "%s %d/%d" % [QuestTags.replace_tags(counter.display_name, self), current, goal],
			"current": current,
			"goal": goal,
			"done": current >= goal,
			"counter_name": counter.name,
		})
	return result

#endregion

#region Nodes

## Looks up a node by id.
func get_node(node_id: String) -> QuestNode:
	if node_id.is_empty():
		return null
	for node in node_list:
		if node != null and node.id == node_id:
			return node
	return null

#endregion

#region UI content

func is_speaker_quest_giver(speaker: QuestParticipant) -> bool:
	return speaker == null or speaker.id == quest_giver_id


## True if [method get_content_list] would return anything.
func has_content(category: QuestContent.Category, speaker: QuestParticipant = null) -> bool:
	var speaker_is_giver := is_speaker_quest_giver(speaker)
	current_speaker = null if speaker_is_giver else speaker
	if speaker_is_giver and get_state_info(state).has_content(category):
		return true
	for node in node_list:
		if node.has_content(category):
			return true
	return false


## The UI content for [param category], from the quest's current state and all
## of its nodes' current states. Links are replaced by the content they link to.
func get_content_list(category: QuestContent.Category, speaker: QuestParticipant = null) -> Array[QuestContent]:
	var result: Array[QuestContent] = []
	current_speaker = null if is_speaker_quest_giver(speaker) else speaker
	_add_to_content_list(result, get_state_info(state).get_content_list(category))
	for node in node_list:
		_add_to_content_list(result, node.get_content_list(category))
	return result


func _add_to_content_list(result: Array[QuestContent], to_add: Array[QuestContent]) -> void:
	for content in to_add:
		if content == null:
			continue
		if _is_link(content):
			var linked := get_content_by_id(int(content.get("linked_content_id")))
			if linked != null:
				result.append(linked)
		else:
			result.append(content)


# Link content belongs to the content classes, so look for it by name.
func _is_link(content: QuestContent) -> bool:
	return content.get_type_name() == "QuestLinkContent" and content.get("linked_content_id") != null


func assign_content_id(content: QuestContent) -> void:
	if content == null:
		return
	content.content_id = next_content_id
	next_content_id += 1


func get_content_by_id(content_id: int) -> QuestContent:
	if not _content_by_id.has(content_id):
		var found := _find_content_by_id(content_id)
		if found != null:
			_content_by_id[content_id] = found
		return found
	return _content_by_id[content_id]


func _find_content_by_id(content_id: int) -> QuestContent:
	var found := _find_in_list(content_id, offer_content_list)
	if found == null:
		found = _find_in_list(content_id, offer_conditions_unmet_content_list)
	if found == null:
		for i in NUM_STATES - 1:
			found = _find_in_state_info(content_id, get_state_info(i as State))
			if found != null:
				return found
		for node in node_list:
			for i in QuestNode.NUM_STATES:
				found = _find_in_state_info(content_id, node.get_state_info(i as QuestNode.State))
				if found != null:
					return found
	return found


func _find_in_list(content_id: int, content_list: Array[QuestContent]) -> QuestContent:
	for content in content_list:
		if content != null and content.content_id == content_id:
			return content
	return null


func _find_in_state_info(content_id: int, info: QuestStateInfo) -> QuestContent:
	if info == null:
		return null
	for category in [QuestContent.Category.DIALOGUE, QuestContent.Category.JOURNAL, QuestContent.Category.HUD]:
		var found := _find_in_list(content_id, info.get_content_list(category))
		if found != null:
			return found
	return null

#endregion

#region Indicator states

func set_indicator_state(entity_id: String, indicator_state: IndicatorState) -> void:
	if entity_id.is_empty():
		return
	indicator_states[entity_id] = indicator_state
	QuestMessages.set_indicator_state(self, entity_id, id, indicator_state)


func get_indicator_state(entity_id: String) -> IndicatorState:
	if entity_id.is_empty() or not indicator_states.has(entity_id):
		return IndicatorState.NONE
	return indicator_states[entity_id]


func clear_indicator_states() -> void:
	for entity_id: String in indicator_states:
		QuestMessages.set_indicator_state(self, entity_id, id, IndicatorState.NONE)
	indicator_states.clear()
	QuestMessages.refresh_indicator(self, quest_giver_id)

#endregion

#region Compress generated content

## If the quest was generated and is completed, removes the conditions and
## content that UIs no longer need.
func compress_generated_content() -> void:
	if not is_procedurally_generated or not (state == State.SUCCESSFUL or state == State.FAILED):
		return
	_clear_condition_set(autostart_condition_set)
	_clear_condition_set(offer_condition_set)
	offer_conditions_unmet_content_list.clear()
	offer_content_list.clear()
	for i in NUM_STATES:
		if i != State.SUCCESSFUL and i != State.FAILED:
			_clear_state_info(get_state_info(i as State))
	for node in node_list:
		_clear_condition_set(node.condition_set)
		for i in QuestNode.NUM_STATES:
			if i != QuestNode.State.TRUE:
				_clear_state_info(node.get_state_info(i as QuestNode.State))


func _clear_condition_set(condition_set: QuestConditionSet) -> void:
	if condition_set != null:
		condition_set.stop_checking()
		condition_set.condition_list.clear()


func _clear_state_info(info: QuestStateInfo) -> void:
	info.action_list.clear()
	info.dialogue_content.clear()
	info.journal_content.clear()
	info.hud_content.clear()

#endregion
