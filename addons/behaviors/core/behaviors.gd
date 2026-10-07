@tool
@icon("res://addons/behaviors/icons/behaviors.svg")
class_name Behaviors
extends Object
## Static helpers shared by every agent: global variables, events, the tick budget
## and noises.
##
## Nothing here needs a node or an autoload. Settings live under
## [code]behaviors/[/code] in the project settings.

## A [BehaviorVariableSet] file with the global variables.
const SETTING_GLOBAL_VARIABLES := "behaviors/variables/global_variables"
## The most time-sliced agents that tick per frame. 0 is unlimited.
const SETTING_MAX_AGENTS_PER_FRAME := "behaviors/runtime/max_agents_per_frame"
## Seconds a noise from [method emit_noise] can be heard.
const SETTING_NOISE_LIFETIME := "behaviors/perception/noise_lifetime"

## How two values are compared by [method compare].
enum Operator {
	EQUAL,
	NOT_EQUAL,
	LESS,
	LESS_OR_EQUAL,
	GREATER,
	GREATER_OR_EQUAL,
	## The left value is not null, false, zero or empty.
	IS_SET,
	## The left value is null, false, zero or empty.
	IS_NOT_SET,
}

const _Debugger := preload("behavior_debugger.gd")

static var _globals: BehaviorBlackboard
static var _agents: Array[BehaviorAgent] = []
static var _agent_index: Dictionary[BehaviorAgent, int] = {}
static var _frame: int = -1
static var _cursor: int = 0
static var _budget: int = 0
static var _noises: Array[Dictionary] = []
static var _guards: Dictionary[StringName, int] = {}


#region Global variables

## The global variables, loaded from [constant SETTING_GLOBAL_VARIABLES] on first use.
## Tasks reach them with the [code]global/[/code] prefix.
static func get_globals() -> BehaviorBlackboard:
	if _globals == null:
		var variables: Array[BehaviorVariable] = []
		var path: String = ProjectSettings.get_setting(SETTING_GLOBAL_VARIABLES, "")
		if not path.is_empty() and ResourceLoader.exists(path):
			var variable_set := load(path) as BehaviorVariableSet
			if variable_set:
				variables = variable_set.variables
		_globals = BehaviorBlackboard.new(variables)
	return _globals


## Reads a global variable.
static func get_global(variable: StringName, default: Variant = null) -> Variant:
	return get_globals().get_value(variable, default)


## Writes a global variable.
static func set_global(variable: StringName, value: Variant) -> void:
	get_globals().set_value(variable, value)


## Drops the global variables, so the next use loads them again from the file.
static func reset_globals() -> void:
	_globals = null

#endregion

#region Comparing

## Compares two values. Numbers of different types compare by value, and values that
## cannot be compared are only equal when they are the same type and value.
static func compare(left: Variant, operator: Operator, right: Variant = null) -> bool:
	match operator:
		Operator.IS_SET:
			return is_set(left)
		Operator.IS_NOT_SET:
			return not is_set(left)
	var left_number := left is int or left is float
	var right_number := right is int or right is float
	if left_number and right_number:
		left = float(left)
		right = float(right)
	elif typeof(left) != typeof(right):
		if operator == Operator.NOT_EQUAL:
			return true
		return false
	match operator:
		Operator.EQUAL:
			return left == right
		Operator.NOT_EQUAL:
			return left != right
	if not (left_number and right_number) and not (left is String or left is StringName):
		return false
	match operator:
		Operator.LESS:
			return left < right
		Operator.LESS_OR_EQUAL:
			return left <= right
		Operator.GREATER:
			return left > right
		Operator.GREATER_OR_EQUAL:
			return left >= right
	return false


## True unless [param value] is null, false, zero, empty, or a freed object.
static func is_set(value: Variant) -> bool:
	if value is Object:
		return is_instance_valid(value)
	if value is bool or value is int or value is float:
		return bool(value)
	return not _is_empty(value)


static func _is_empty(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return true
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return String(value).is_empty()
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return value.is_empty()
	return value == type_convert(null, typeof(value))

#endregion

#region Agents and events

## The agents on [param node]: the node itself when it is an agent, and its child
## agents.
static func get_agents(node: Node) -> Array[BehaviorAgent]:
	var agents: Array[BehaviorAgent] = []
	if node == null:
		return agents
	if node is BehaviorAgent:
		agents.append(node)
	for child in node.get_children():
		if child is BehaviorAgent:
			agents.append(child)
	return agents


## Every agent in the scene tree.
static func get_all_agents() -> Array[BehaviorAgent]:
	return _agents.duplicate()


## Sends an event to the agents on [param node].
static func send_event(node: Node, event: StringName, args: Array = []) -> void:
	for agent in get_agents(node):
		agent.send_event(event, args)


## Sends an event to the agents on every node in [param group].
static func send_event_to_group(group: StringName, event: StringName, args: Array = []) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group(group):
		send_event(node, event, args)


## Sends an event to every agent.
static func send_event_to_all(event: StringName, args: Array = []) -> void:
	for agent in _agents.duplicate():
		agent.send_event(event, args)

#endregion

#region Noises

## Makes a noise that [BehaviorCanHear] conditions within [param radius] of
## [param position] (a Vector2 or Vector3) can hear for a short time.
static func emit_noise(source: Node, position: Variant, radius: float, tag: StringName = &"") -> void:
	_prune_noises()
	_noises.append({
		"source": source,
		"position": position,
		"radius": radius,
		"tag": tag,
		"time": Time.get_ticks_msec() / 1000.0,
	})


## The noises still audible, oldest first. Each is a dictionary with
## [code]source[/code], [code]position[/code], [code]radius[/code], [code]tag[/code]
## and [code]time[/code] (seconds since start).
static func get_noises() -> Array[Dictionary]:
	_prune_noises()
	return _noises.duplicate()


static func _prune_noises() -> void:
	var lifetime: float = ProjectSettings.get_setting(SETTING_NOISE_LIFETIME, 1.0)
	var now := Time.get_ticks_msec() / 1000.0
	while not _noises.is_empty() and now - float(_noises[0].time) > lifetime:
		_noises.pop_front()

#endregion

#region Internals

static func _register(agent: BehaviorAgent) -> void:
	if _agent_index.has(agent):
		return
	_agent_index[agent] = _agents.size()
	_agents.append(agent)
	_Debugger.agents_changed()


static func _unregister(agent: BehaviorAgent) -> void:
	var index: int = _agent_index.get(agent, -1)
	if index < 0:
		return
	_agents.remove_at(index)
	_agent_index.erase(agent)
	for i in range(index, _agents.size()):
		_agent_index[_agents[i]] = i
	_Debugger.agents_changed()


# Each frame a window of [budget] agents may tick, and the window moves on by the
# budget every frame, so every agent gets its turn.
static func _claim_tick(agent: BehaviorAgent) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_budget = ProjectSettings.get_setting(SETTING_MAX_AGENTS_PER_FRAME, 0)
		if _budget > 0 and not _agents.is_empty():
			_cursor = (_cursor + _budget) % _agents.size()
	var count := _agents.size()
	if _budget <= 0 or count <= _budget:
		return true
	var index: int = _agent_index.get(agent, -1)
	return index < 0 or posmod(index - _cursor, count) < _budget


# Semaphores for [BehaviorTaskGuard] shared by every agent.
static func _acquire_guard(guards: Dictionary[StringName, int], key: StringName, max_count: int) -> bool:
	var count: int = guards.get(key, 0)
	if count >= max_count:
		return false
	guards[key] = count + 1
	return true


static func _release_guard(guards: Dictionary[StringName, int], key: StringName) -> void:
	var count: int = guards.get(key, 0) - 1
	if count <= 0:
		guards.erase(key)
	else:
		guards[key] = count

#endregion
