@tool
@abstract
@icon("res://addons/behaviors/icons/task.svg")
class_name BehaviorTask
extends Resource
## One node of a [BehaviorTree]: an action, a condition, a composite or a decorator.
##
## Tasks are resources, so a whole tree saves as one file. A [BehaviorAgent] never runs
## the tasks you edited. It clones the tree when it starts and runs the copies, so one
## tree file can drive any number of agents.
## [br][br]
## Write new tasks by extending [BehaviorAction] or [BehaviorCondition] and overriding
## the virtual methods named [code]_on_*[/code]. Every task script should start with
## [code]@tool[/code] so the editor can read its defaults.
## [br][br]
## Any exported property can be [b]bound[/b] to a blackboard variable in the editor.
## The agent copies the variable into the property before [method _on_start] and
## [method _on_update], and copies the property back to the variable afterwards if
## the task changed it. Task code reads and writes plain properties.

## The result of running a task.
enum Status {
	## Not started yet, or interrupted.
	INACTIVE,
	## Still working. The agent ticks it again next time.
	RUNNING,
	SUCCESS,
	FAILURE,
}

## A name shown in the graph. Empty uses the name of the task type.
@export var label: String = ""
## A note shown under the task in the graph.
@export_multiline var comment: String = ""
## When true, the next task starts in the same tick after this one ends. When false,
## the tree waits for the next tick, which spreads work over frames.
@export var instant: bool = true
## Disabled tasks never run and count as a success.
@export var disabled: bool = false

@export_group("Utility")
## Used by [BehaviorPrioritySelector] when [method _get_priority] is not overridden.
@export var priority: float = 0.0
## Scores this task for [BehaviorUtilitySelector] without code. The scores multiply.
## Empty uses [method _get_utility].
@export var considerations: Array[BehaviorConsideration] = []

## Property name to variable name. Set by the editor's bind buttons. Names starting
## with [code]global/[/code] read the global variables.
@export_storage var bindings: Dictionary[StringName, String] = {}
## Identifies the task inside its tree. Clones keep it, so the debugger can match a
## running task with the one in the editor.
@export_storage var id: int = 0
## Where the editor draws the task.
@export_storage var graph_position: Vector2 = Vector2.ZERO
## Pauses the game in the debugger when the task starts.
@export_storage var breakpoint_enabled: bool = false

## The agent running this task. Null outside of a run.
var agent: BehaviorAgent
## The node the agent drives, usually the agent's parent.
var actor: Node
## The variables this task reads and writes.
var blackboard: BehaviorBlackboard
## The position of this task among its parent's children, or -1.
var index_in_parent: int = -1
## The status of the last tick.
var status: Status = Status.INACTIVE
## True between the start and the end of a run.
var is_running: bool = false

var _parent_ref: WeakRef
var _pulled: Dictionary[StringName, Variant] = {}
# The status this task ended with, kept for conditional aborts. Parents clear it when
# they start, so a stale result never triggers an abort.
var _observed: Status = Status.INACTIVE
var _start_tick: int = -1


#region Virtual methods

## Called once when the agent builds its tree. Use it like a constructor.
func _on_awake() -> void:
	pass


## Called right before the task runs. Reset anything left from the previous run.
func _on_start() -> void:
	pass


## Does the work. Return [constant Status.RUNNING] to be ticked again.
func _on_update(_delta: float) -> Status:
	return Status.SUCCESS


## Called every physics frame while the task runs. The status still comes from
## [method _on_update].
func _on_physics_update(_delta: float) -> void:
	pass


## Called after the task succeeds, fails or is interrupted.
func _on_end() -> void:
	pass


## Called when the agent is paused or resumed.
func _on_pause(_paused: bool) -> void:
	pass


## Called on every task when the whole tree ends.
func _on_tree_complete(_tree_status: Status) -> void:
	pass


## The priority used by [BehaviorPrioritySelector]. Higher runs first.
func _get_priority() -> float:
	return priority


## The utility used by [BehaviorUtilitySelector]. Higher runs first.
func _get_utility() -> float:
	return 0.0


## Problems shown in the editor, such as a composite without children.
func _get_warnings() -> PackedStringArray:
	return PackedStringArray()


## Extra text drawn on the task in the graph.
func _get_graph_text() -> String:
	return ""


## Tasks held in properties other than [member BehaviorParent.children], such as the
## stack of a [BehaviorStackedAction]. The agent sets them up with this task.
func _get_inline_tasks() -> Array[BehaviorTask]:
	return []

#endregion

#region Public API

## The label, or the name of the task type.
func get_display_name() -> String:
	if not label.is_empty():
		return label
	return get_type_name(get_script())


## The task's parent, or null for the root. Inline tasks return the task holding them.
func get_parent_task() -> BehaviorTask:
	return _parent_ref.get_ref() as BehaviorTask if _parent_ref else null


## The priority of this task. See [method _get_priority].
func get_priority() -> float:
	return _get_priority()


## The utility of this task: the product of its [member considerations], or
## [method _get_utility] when it has none.
func get_utility() -> float:
	if considerations.is_empty():
		return _get_utility()
	var score := 1.0
	for consideration in considerations:
		if consideration:
			score *= consideration.evaluate(self)
	return score


## The warnings for this task, plus binding problems.
func get_warnings() -> PackedStringArray:
	var warnings := _get_warnings()
	for property in bindings:
		if bindings[property].is_empty():
			warnings.append("Property \"%s\" is bound to an empty variable name." % property)
	return warnings


## Reads a variable through this task's blackboard.
func get_var(variable: StringName, default: Variant = null) -> Variant:
	return blackboard.get_value(variable, default) if blackboard else default


## Writes a variable through this task's blackboard.
func set_var(variable: StringName, value: Variant) -> void:
	if blackboard:
		blackboard.set_value(variable, value)


## Resolves a path relative to the actor, falling back to the agent. An empty path
## returns the actor.
func get_node_from_actor(path: NodePath) -> Node:
	if path.is_empty():
		return actor
	var node: Node = actor.get_node_or_null(path) if actor else null
	if not node and agent:
		node = agent.get_node_or_null(path)
	return node


## Ticks the task: starts it if needed, runs it, and ends it when it stops running.
## Parents call this on their children. Returns the new status.
func tick(delta: float) -> Status:
	if not is_running:
		if agent and not agent._claim_start(self):
			return Status.RUNNING
		if disabled:
			status = Status.SUCCESS
			return status
		_start()
	var result := _execute(delta)
	if result == Status.INACTIVE:
		result = Status.SUCCESS
	if result != Status.RUNNING and is_running:
		_finish(result)
	return result


## Stops the task if it is running. Running children stop first, then [method _on_end]
## is called. The status becomes [constant Status.INACTIVE].
func abort() -> void:
	if not is_running:
		return
	_abort_children()
	is_running = false
	status = Status.INACTIVE
	_on_end()
	if agent:
		agent._task_changed(self, Status.INACTIVE)


## Returns the name of a task script: its class name without the "Behavior" prefix, or
## its file name.
static func get_type_name(script: Script) -> String:
	if not script:
		return "Task"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		global_name = script.resource_path.get_file().get_basename().to_pascal_case()
	if global_name.begins_with("Behavior") and global_name.length() > 8:
		global_name = global_name.substr(8)
	return global_name.capitalize()

#endregion

#region Runtime internals

func _setup(owner_agent: BehaviorAgent, owner_actor: Node, board: BehaviorBlackboard, parent: BehaviorTask, index: int) -> void:
	agent = owner_agent
	actor = owner_actor
	blackboard = board
	_parent_ref = weakref(parent) if parent else null
	index_in_parent = index
	_build()
	for inline_task in _get_inline_tasks():
		if inline_task:
			inline_task._setup(owner_agent, owner_actor, _get_child_blackboard(), self, -1)
	_setup_children()
	_on_awake()


func _setup_children() -> void:
	pass


# Lets subtrees build their tasks before they are set up.
func _build() -> void:
	pass


func _get_child_blackboard() -> BehaviorBlackboard:
	return blackboard


func _start() -> void:
	is_running = true
	status = Status.RUNNING
	if agent:
		agent._task_changed(self, Status.RUNNING)
		if breakpoint_enabled and agent._breakpoints_enabled():
			breakpoint
	_pull_bindings()
	_on_start()
	_push_bindings()


func _execute(delta: float) -> Status:
	_pull_bindings()
	var result := _on_update(delta)
	_push_bindings()
	return result


func _finish(result: Status) -> void:
	status = result
	_observed = result
	is_running = false
	_on_end()
	_push_bindings()
	if agent:
		agent._task_changed(self, result)


func _abort_children() -> void:
	pass


# True when composites to the left of a running task should check this task again.
func _observes_lower_priority() -> bool:
	return false


# Runs the task again without its parent noticing, for conditional aborts. Returns
# true when the result differs from the last one.
func _reevaluate(delta: float) -> bool:
	if _observed == Status.INACTIVE or _observed == Status.RUNNING:
		return false
	_pull_bindings()
	var result := _on_update(delta)
	_push_bindings()
	if agent:
		agent._task_reevaluated(self, result)
	if result == Status.RUNNING or result == _observed:
		return false
	_observed = result
	return true


func _pull_bindings() -> void:
	if bindings.is_empty() or not blackboard:
		return
	for property in bindings:
		var variable := bindings[property]
		if variable.is_empty() or not blackboard.has_value(variable):
			_pulled.erase(property)
			continue
		var value: Variant = blackboard.get_value(variable)
		set(property, value)
		_pulled[property] = get(property)


func _push_bindings() -> void:
	if bindings.is_empty() or not blackboard:
		return
	for property in bindings:
		var variable := bindings[property]
		if variable.is_empty():
			continue
		var value: Variant = get(property)
		if _pulled.has(property):
			var before: Variant = _pulled[property]
			if typeof(before) == typeof(value) and before == value:
				continue
		_pulled[property] = value
		blackboard.set_value(variable, value)


func _pause(paused: bool) -> void:
	if not is_running:
		return
	_on_pause(paused)
	for inline_task in _get_inline_tasks():
		if inline_task:
			inline_task._pause(paused)


func _visit(callback: Callable) -> void:
	callback.call(self)
	for inline_task in _get_inline_tasks():
		if inline_task:
			inline_task._visit(callback)

#endregion
