@icon("../icons/quest_node.svg")
class_name QuestNode
extends Resource
## A task or stage in a quest.
##
## Nodes form a graph. When a node becomes TRUE, its children become ACTIVE
## (see [member join_mode] for children with several parents). Non-condition
## nodes turn TRUE as soon as they are active; condition nodes wait for their
## [member condition_set].

enum Type { START, SUCCESS, FAILURE, PASSTHROUGH, CONDITION }
enum State { INACTIVE, ACTIVE, TRUE }
## How a node with several parents decides to become active.
## ANY: when any parent becomes TRUE. ALL: when every non-optional parent is
## TRUE. MIN: when at least [member join_min_count] parents are TRUE.
enum JoinMode { ANY, ALL, MIN }

const NUM_STATES := 3

## Emitted when the node changes state.
signal state_changed(node: QuestNode)

## Identifies the node within its quest, for scripts and children.
@export var id := ""
## Name for the designer's reference. Not shown to the player.
@export var internal_name := ""
@export var node_type := Type.START
## Completion of this node is optional.
@export var is_optional := false
## Id of the entity that speaks this node's dialogue. Empty means the quest giver.
@export var speaker := ""
## Ids of the nodes this node leads to.
@export var children: PackedStringArray
## Conditions required for the node to become TRUE.
@export var condition_set := QuestConditionSet.new()
## Actions and content for each [enum State].
@export var state_info_list: Array[QuestStateInfo]:
	get:
		QuestStateInfo.validate_list(state_info_list, NUM_STATES)
		return state_info_list
@export var join_mode := JoinMode.ANY
@export var join_min_count := 1
## Tags defined by this node, such as the ones its content uses.
@export var tag_dictionary := {}
@export var editor_position := Vector2.ZERO

## The quest this node belongs to. Runtime only.
var quest: Quest:
	get:
		return _quest_ref.get_ref() as Quest if _quest_ref != null else null
	set(value):
		_quest_ref = weakref(value) if value != null else null
## Runtime references to the nodes this node leads to and comes from.
## Parents are held weakly so that a node and its children don't keep each other alive.
var child_list: Array = []
var parent_list: Array:
	get:
		return _deref(_parent_refs)
	set(value):
		_parent_refs = _refs(value)
var optional_parent_list: Array:
	get:
		return _deref(_optional_parent_refs)
	set(value):
		_optional_parent_refs = _refs(value)
var nonoptional_parent_list: Array:
	get:
		return _deref(_nonoptional_parent_refs)
	set(value):
		_nonoptional_parent_refs = _refs(value)
## The current state. Runtime only; use [method set_state] to change it.
var state := State.INACTIVE

## True for nodes that can lead to other nodes: everything except SUCCESS and FAILURE.
var is_connection_node_type: bool:
	get:
		return not is_end_node_type
## True for SUCCESS and FAILURE nodes, which end the quest.
var is_end_node_type: bool:
	get:
		return node_type == Type.SUCCESS or node_type == Type.FAILURE

var _quest_ref: WeakRef
var _parent_refs: Array = []
var _optional_parent_refs: Array = []
var _nonoptional_parent_refs: Array = []


static func _refs(nodes: Array) -> Array:
	var result := []
	for node in nodes:
		result.append(weakref(node))
	return result


static func _deref(refs: Array) -> Array:
	var result := []
	for ref: WeakRef in refs:
		var node: Variant = ref.get_ref()
		if node != null:
			result.append(node)
	return result
var _is_checking_conditions := false


static func create(p_id: String, p_internal_name: String, p_type: Type, p_optional := false) -> QuestNode:
	var result := QuestNode.new()
	result.id = p_id
	result.internal_name = p_internal_name
	result.node_type = p_type
	result.is_optional = p_optional
	return result


## A start node for a quest with the given id.
static func create_start_node(quest_id: String) -> QuestNode:
	var result := QuestNode.create(quest_id + ".start", "Start", Type.START)
	result.editor_position = Vector2(200, 20)
	return result


func get_editor_name() -> String:
	if not internal_name.is_empty():
		return internal_name
	if not id.is_empty():
		return id
	return "Node"


#region Runtime references

## Wires the runtime references. Quest.set_runtime_references calls this on
## every node, then [method connect_runtime_node_references], then
## [method set_runtime_node_references].
func initialize_runtime_references(p_quest: Quest) -> void:
	quest = p_quest
	if condition_set != null:
		condition_set.set_runtime_references(p_quest, self)
	child_list = []
	for child_id in children:
		var child := p_quest.get_node(child_id)
		if child != null and child != self and not child_list.has(child):
			child_list.append(child)
	_parent_refs = []
	_optional_parent_refs = []
	_nonoptional_parent_refs = []


func connect_runtime_node_references() -> void:
	for child in child_list:
		child._add_parent(self)


func _add_parent(parent: QuestNode) -> void:
	if parent == null:
		return
	_parent_refs.append(weakref(parent))
	if parent.is_optional:
		_optional_parent_refs.append(weakref(parent))
	else:
		_nonoptional_parent_refs.append(weakref(parent))
	if not parent.state_changed.is_connected(_on_parent_state_changed):
		parent.state_changed.connect(_on_parent_state_changed)


func set_runtime_node_references() -> void:
	for info in state_info_list:
		info.set_runtime_references(quest, self)


## Disconnects this node from its neighbors so the quest can be freed.
func dispose() -> void:
	set_condition_checking(false)
	for parent in parent_list:
		if parent.state_changed.is_connected(_on_parent_state_changed):
			parent.state_changed.disconnect(_on_parent_state_changed)
	child_list = []
	_parent_refs = []
	_optional_parent_refs = []
	_nonoptional_parent_refs = []

#endregion

#region State

func get_state() -> State:
	return state


## Sets the node state and does everything that follows from it: runs the
## state's actions, starts condition checking, informs listeners, turns
## non-condition nodes TRUE, and ends the quest for SUCCESS and FAILURE nodes.
## This may make other nodes advance.
func set_state(new_state: State, inform_listeners := true) -> void:
	if Quests.debug:
		print("Quests: %s.%s.set_state(%s)" % [quest.get_editor_name() if quest != null else "Quest",
				get_editor_name(), State.find_key(new_state)])
	if new_state == State.INACTIVE or (state == State.TRUE and new_state == State.ACTIVE):
		# Reset conditions if the node becomes inactive or reverts from TRUE to ACTIVE.
		reset_conditions()
	state = new_state
	if not inform_listeners:
		# Applying a saved game doesn't run actions, but active nodes must check conditions.
		set_condition_checking(new_state == State.ACTIVE)
		return
	get_state_info(state).execute_actions()
	set_condition_checking(new_state == State.ACTIVE)
	if quest != null:
		QuestMessages.quest_node_state_changed(self, quest.id, id, state)
		var manager := Quests.get_manager()
		if manager != null:
			manager.quest_node_state_changed.emit(quest, self, state)
	state_changed.emit(self)
	match state:
		State.ACTIVE:
			if node_type != Type.CONDITION:
				set_state(State.TRUE)
		State.TRUE:
			match node_type:
				Type.SUCCESS:
					if quest != null:
						quest.set_state(Quest.State.SUCCESSFUL)
				Type.FAILURE:
					if quest != null:
						quest.set_state(Quest.State.FAILED)


## Sets the internal state without any processing.
func set_state_raw(new_state: State) -> void:
	state = new_state


func get_state_info(p_state: State) -> QuestStateInfo:
	return state_info_list[p_state]


## Starts or stops condition checking.
func set_condition_checking(enable: bool) -> void:
	if enable == _is_checking_conditions:
		return
	if not is_connection_node_type or condition_set == null:
		return
	_is_checking_conditions = enable
	if enable:
		condition_set.start_checking(_on_conditions_true)
	else:
		condition_set.stop_checking()


func reset_conditions() -> void:
	if condition_set != null:
		condition_set.reset_conditions()


func _on_conditions_true() -> void:
	set_state(State.TRUE)


## True if this node's parents satisfy its [member join_mode]. With ANY this is
## always true.
func are_join_conditions_met() -> bool:
	match join_mode:
		JoinMode.ALL:
			for parent in nonoptional_parent_list:
				if parent.get_state() != State.TRUE:
					return false
			return true
		JoinMode.MIN:
			var count := 0
			for parent in parent_list:
				if parent.get_state() == State.TRUE:
					count += 1
			return count >= join_min_count
	return true


func _on_parent_state_changed(parent: QuestNode) -> void:
	if parent != null and parent.get_state() == State.TRUE and quest != null \
			and quest.get_state() == Quest.State.ACTIVE and get_state() == State.INACTIVE \
			and are_join_conditions_met():
		set_state(State.ACTIVE)

#endregion

#region UI content

func has_content(category: QuestContent.Category) -> bool:
	if not _is_content_valid_for_current_speaker(category):
		return false
	return get_state_info(state).has_content(category)


func get_content_list(category: QuestContent.Category) -> Array[QuestContent]:
	if not _is_content_valid_for_current_speaker(category):
		var empty: Array[QuestContent] = []
		return empty
	return get_state_info(state).get_content_list(category)


func _is_content_valid_for_current_speaker(category: QuestContent.Category) -> bool:
	if category != QuestContent.Category.DIALOGUE or quest == null:
		return true
	if quest.current_speaker == null:
		return speaker.is_empty() or speaker == quest.quest_giver_id
	return speaker == quest.current_speaker.id

#endregion
