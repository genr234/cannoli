@tool
@icon("res://addons/behaviors/icons/sync.svg")
class_name BehaviorVariableSync
extends Node
## Keeps agent variables and node properties equal.
##
## Every entry links a variable of a [BehaviorAgent] with a property of a node, such as
## a health variable and a progress bar's value. Values are checked every frame and
## copied when they differ. Use it when you would rather not write the glue code, or to
## show state in the scene without a task.

## The links to keep in sync.
@export var entries: Array[BehaviorSyncEntry] = []
## Syncs in the physics frame instead of the process frame.
@export var physics: bool = false

# One dictionary per entry: the last values seen on each side.
var _states: Array[Dictionary] = []


func _ready() -> void:
	set_process(not Engine.is_editor_hint() and not physics)
	set_physics_process(not Engine.is_editor_hint() and physics)


func _process(_delta: float) -> void:
	sync()


func _physics_process(_delta: float) -> void:
	sync()


## Copies every entry once.
func sync() -> void:
	while _states.size() < entries.size():
		_states.append({})
	for index in entries.size():
		var entry := entries[index]
		if entry:
			_sync_entry(entry, _states[index])


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if entries.is_empty():
		warnings.append("Add entries to sync.")
	for index in entries.size():
		var entry := entries[index]
		if entry == null:
			warnings.append("Entry %d is empty." % index)
			continue
		if String(entry.variable).is_empty():
			warnings.append("Entry %d has no variable." % index)
		if entry.property.is_empty():
			warnings.append("Entry %d has no property." % index)
		if _find_agent(entry) == null:
			warnings.append("Entry %d finds no agent." % index)
		if get_node_or_null(entry.node_path) == null:
			warnings.append("Entry %d finds no node." % index)
	return warnings


func _sync_entry(entry: BehaviorSyncEntry, state: Dictionary) -> void:
	if String(entry.variable).is_empty() or entry.property.is_empty():
		return
	var agent := _find_agent(entry)
	var node := get_node_or_null(entry.node_path)
	if agent == null or node == null:
		return
	if entry.direction != BehaviorSyncEntry.Direction.NODE_TO_AGENT and not agent.has_variable(entry.variable):
		return
	var agent_value: Variant = agent.get_variable(entry.variable)
	var node_value: Variant = node.get_indexed(entry.property)
	var first: bool = not state.has("agent")
	match entry.direction:
		BehaviorSyncEntry.Direction.AGENT_TO_NODE:
			if not _same(agent_value, node_value):
				node.set_indexed(entry.property, agent_value)
				node_value = node.get_indexed(entry.property)
		BehaviorSyncEntry.Direction.NODE_TO_AGENT:
			if not _same(agent_value, node_value):
				agent.set_variable(entry.variable, node_value)
				agent_value = node_value
		BehaviorSyncEntry.Direction.BOTH:
			var node_changed := not first and not _same(node_value, state.node)
			if node_changed and not _same(agent_value, node_value):
				agent.set_variable(entry.variable, node_value)
				agent_value = node_value
			elif not _same(agent_value, node_value):
				node.set_indexed(entry.property, agent_value)
				node_value = node.get_indexed(entry.property)
	state.agent = agent_value
	state.node = node_value


func _find_agent(entry: BehaviorSyncEntry) -> BehaviorAgent:
	if not entry.agent_path.is_empty():
		return get_node_or_null(entry.agent_path) as BehaviorAgent
	var parent := get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling is BehaviorAgent:
				return sibling
	for child in get_children():
		if child is BehaviorAgent:
			return child
	return null


func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b
