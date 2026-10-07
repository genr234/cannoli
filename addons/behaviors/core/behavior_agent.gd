@tool
@icon("res://addons/behaviors/icons/agent.svg")
class_name BehaviorAgent
extends Node
## Runs a [BehaviorTree] for the node it is attached to.
##
## Add an agent as a child of the character it drives (the [b]actor[/b]) and assign a
## tree. The agent clones the tree when it starts, so tasks never share state between
## agents. By default it ticks every frame. Set [member tick_interval] to tick less
## often, or [member tick_mode] to [constant TickMode.MANUAL] and call [method tick].
## [br][br]
## [codeblock]
## $BehaviorAgent.set_variable(&"target", player)
## $BehaviorAgent.send_event(&"heard_noise", [noise_position])
## [/codeblock]

## Emitted when the tree starts from the beginning.
signal started
## Emitted when the tree starts again after it finished, with
## [member restart_when_complete].
signal restarted
## Emitted when the root task ends.
signal finished(status: BehaviorTask.Status)
## Emitted when [method stop] ends the tree before it finished.
signal stopped
## Emitted for every event sent to this agent.
signal event_received(event: StringName, args: Array)
## Emitted for every task start and end while [member debug_enabled] is on.
signal task_changed(task: BehaviorTask, status: BehaviorTask.Status)
## Emitted when a conditional abort checks a task again, while [member debug_enabled]
## is on.
signal task_reevaluated(task: BehaviorTask, status: BehaviorTask.Status)

## When the agent ticks its tree.
enum TickMode {
	## Every process frame.
	IDLE,
	## Every physics frame.
	PHYSICS,
	## Only when [method tick] is called.
	MANUAL,
}

## How the agent stops a tick from running forever.
enum ExecutionLimit {
	## A task can start at most once per tick. A repeater with an instant child runs it
	## once per tick.
	NO_DUPLICATES,
	## At most [member max_task_executions] tasks start per tick.
	COUNT,
}

## Where the agent is in its run.
enum State { STOPPED, RUNNING, PAUSED }

## The tree to run. Changing it while running restarts the agent with the new tree.
@export var tree: BehaviorTree:
	set(value):
		tree = value
		update_configuration_warnings()
		if _state != State.STOPPED:
			stop()
			start()
## The node tasks act on. Empty uses the agent's parent.
@export var actor_path: NodePath = NodePath()
## Disabling stops the tree, or pauses it with [member pause_when_disabled]. Enabling
## starts it again with [member autostart], and resumes it when paused.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if Engine.is_editor_hint() or not is_inside_tree():
			return
		if enabled:
			if _state == State.PAUSED or autostart:
				start()
		else:
			stop(pause_when_disabled)
## Starts the tree when the agent is ready or enabled.
@export var autostart: bool = true
## Disabling pauses the tree instead of stopping it.
@export var pause_when_disabled: bool = false
## Runs the tree again when it finishes.
@export var restart_when_complete: bool = false
## On restart, rebuilds the tasks and resets the variables.
@export var reset_values_on_restart: bool = false
## Prints every task start and end.
@export var log_task_changes: bool = false

@export_group("Ticking")
## When the tree ticks.
@export var tick_mode: TickMode = TickMode.IDLE:
	set(value):
		tick_mode = value
		_update_processing()
## Seconds between ticks. 0 ticks every frame. Tasks receive the time since the last
## tick as their delta.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var tick_interval: float = 0.0
## Counts this agent toward the project's agents-per-frame budget
## ([code]behaviors/runtime/max_agents_per_frame[/code]). Agents over budget tick on a
## later frame with the time they missed.
@export var time_sliced: bool = true
## How a tick avoids running forever.
@export var execution_limit: ExecutionLimit = ExecutionLimit.NO_DUPLICATES
## The most task starts per tick with [constant ExecutionLimit.COUNT].
@export_range(1, 10000, 1, "or_greater") var max_task_executions: int = 100

@export_group("Variables")
## Starting values that replace the tree's, for this agent only.
@export var variable_overrides: Dictionary[StringName, Variant] = {}

@export_group("Save")
## Saves this agent's variables with the Save addon under this key, and loads them back.
## Must be unique among agents. Empty does not save.
@export var save_key: String = ""

## The live variables. Null until the agent starts.
var blackboard: BehaviorBlackboard
## The running copy of the tree's root. Null until the agent starts.
var root: BehaviorTask
## Emits [signal task_changed] and [signal task_reevaluated]. Turned on by the
## debugger.
var debug_enabled: bool = false

var _state: State = State.STOPPED
var _status: BehaviorTask.Status = BehaviorTask.Status.INACTIVE
var _tick_id: int = 0
var _clock: float = 0.0
var _executions: int = 0
var _accumulated: float = 0.0
var _restart_pending: bool = false
var _paused_by_exit: bool = false
var _events: Dictionary[StringName, Array] = {}
var _physics_tasks: Array[BehaviorTask] = []
var _guards: Dictionary[StringName, int] = {}

static var _physics_scripts: Dictionary[Script, bool] = {}


func _ready() -> void:
	_update_processing()
	if Engine.is_editor_hint():
		return
	if enabled and autostart:
		start.call_deferred()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	Behaviors._register(self)
	BehaviorsSave.register_agent(self)
	if _paused_by_exit:
		_paused_by_exit = false
		start()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Behaviors._unregister(self)
	BehaviorsSave.unregister_agent(self)
	if _state == State.RUNNING:
		stop(true)
		_paused_by_exit = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			if root and root.is_running:
				root.abort()
		NOTIFICATION_PAUSED:
			if _state == State.RUNNING and root:
				root._pause(true)
		NOTIFICATION_UNPAUSED:
			if _state == State.RUNNING and root:
				root._pause(false)


func _process(delta: float) -> void:
	if tick_mode == TickMode.IDLE:
		_auto_tick(delta)


func _physics_process(delta: float) -> void:
	if tick_mode == TickMode.PHYSICS:
		_auto_tick(delta)
	for task in _physics_tasks.duplicate():
		if task.is_running:
			task._on_physics_update(delta)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tree == null:
		warnings.append("Assign a BehaviorTree to run.")
	else:
		var issues := tree.validate()
		if not issues.is_empty():
			warnings.append("The tree has %d problem(s). Open it in the Behaviors screen to see them." % issues.size())
	return warnings


#region Control

## Starts the tree from the beginning, or resumes it when paused.
func start() -> void:
	if Engine.is_editor_hint():
		return
	if _state == State.PAUSED:
		_state = State.RUNNING
		if root:
			root._pause(false)
		_update_processing()
		return
	if _state == State.RUNNING:
		return
	if tree == null or tree.root == null:
		push_warning("BehaviorAgent \"%s\" has no tree to run." % name)
		return
	_build()
	_state = State.RUNNING
	_status = BehaviorTask.Status.RUNNING
	_accumulated = 0.0
	_restart_pending = false
	_update_processing()
	started.emit()


## Stops the tree. With [param pause], keeps its place so [method start] resumes it.
func stop(pause: bool = false) -> void:
	if _state == State.STOPPED:
		return
	if pause:
		if _state == State.RUNNING:
			_state = State.PAUSED
			if root:
				root._pause(true)
			_update_processing()
		return
	if root:
		root.abort()
	_state = State.STOPPED
	_status = BehaviorTask.Status.INACTIVE
	_physics_tasks.clear()
	_update_processing()
	stopped.emit()


## Interrupts the running tasks and runs the tree again from the root.
func restart() -> void:
	if _state == State.STOPPED:
		start()
		return
	if root:
		root.abort()
	if reset_values_on_restart:
		_build()
	_state = State.RUNNING
	_status = BehaviorTask.Status.RUNNING
	_restart_pending = false
	_update_processing()
	restarted.emit()


## Ticks the tree once. Use it with [constant TickMode.MANUAL], or to step the tree
## yourself. Returns the root's status.
func tick(delta: float = 0.0) -> BehaviorTask.Status:
	if _state != State.RUNNING:
		return _status
	return _tick(delta)


## [constant State.RUNNING], [constant State.PAUSED] or [constant State.STOPPED].
func get_state() -> State:
	return _state


## The tree's status: running, or how the last run ended.
func get_status() -> BehaviorTask.Status:
	return _status


## True while the tree runs (not paused).
func is_running() -> bool:
	return _state == State.RUNNING


## Seconds of tree time: the sum of every tick's delta. It stops while the agent is
## paused or not ticking.
func get_time() -> float:
	return _clock


## The node tasks act on.
func get_actor() -> Node:
	if not actor_path.is_empty():
		var node := get_node_or_null(actor_path)
		if node:
			return node
	var parent := get_parent()
	return parent if parent else self

#endregion

#region Variables

## Reads a variable. Before the agent starts, reads the override or the tree's value.
func get_variable(variable: StringName, default: Variant = null) -> Variant:
	if blackboard:
		return blackboard.get_value(variable, default)
	if variable_overrides.has(variable):
		return variable_overrides[variable]
	var declaration := tree.get_variable(variable) if tree else null
	return declaration.get_default_value() if declaration else default


## Writes a variable. Before the agent starts, sets an override used when it starts.
func set_variable(variable: StringName, value: Variant) -> void:
	if blackboard:
		blackboard.set_value(variable, value)
	else:
		variable_overrides[variable] = value


## True when the variable exists.
func has_variable(variable: StringName) -> bool:
	if blackboard:
		return blackboard.has_value(variable)
	return variable_overrides.has(variable) or (tree != null and tree.get_variable(variable) != null)

#endregion

#region Events

## Sends an event to this agent's tasks and listeners. [param args] reach
## [BehaviorHasReceivedEvent] and every registered callable.
func send_event(event: StringName, args: Array = []) -> void:
	if _events.has(event):
		var listeners: Array = _events[event]
		for callable: Callable in listeners.duplicate():
			if callable.is_valid():
				callable.call(args)
			else:
				# Tasks of an earlier build listened here and are gone now.
				listeners.erase(callable)
	event_received.emit(event, args)


## Calls [param callable] with the event's argument array each time [param event] is
## sent.
func register_event(event: StringName, callable: Callable) -> void:
	var listeners: Array = _events.get_or_add(event, [])
	if not listeners.has(callable):
		listeners.append(callable)


## Stops calling [param callable] for [param event].
func unregister_event(event: StringName, callable: Callable) -> void:
	if not _events.has(event):
		return
	_events[event].erase(callable)
	if _events[event].is_empty():
		_events.erase(event)

#endregion

#region Finding tasks

## Every running copy of the tree's tasks. Empty until the agent starts.
func get_tasks() -> Array[BehaviorTask]:
	var tasks: Array[BehaviorTask] = []
	if root:
		root._visit(func(task: BehaviorTask) -> void: tasks.append(task))
	return tasks


## The first task that is an instance of [param type] (a task script).
func find_task(type: Script) -> BehaviorTask:
	for task in get_tasks():
		if is_instance_of(task, type):
			return task
	return null


## Every task that is an instance of [param type].
func find_tasks(type: Script) -> Array[BehaviorTask]:
	return get_tasks().filter(func(task: BehaviorTask) -> bool: return is_instance_of(task, type))


## The first task whose label is [param task_label].
func find_task_named(task_label: String) -> BehaviorTask:
	for task in get_tasks():
		if task.label == task_label:
			return task
	return null


## Every task whose label is [param task_label].
func find_tasks_named(task_label: String) -> Array[BehaviorTask]:
	return get_tasks().filter(func(task: BehaviorTask) -> bool: return task.label == task_label)


## The running copy of the task with [param task_id].
func find_task_by_id(task_id: int) -> BehaviorTask:
	for task in get_tasks():
		if task.id == task_id:
			return task
	return null

#endregion

#region Save

## The variables to save: plain values only, and only variables marked to persist.
## Before the agent starts these are its overrides.
func get_save_data() -> Dictionary:
	var values: Dictionary = blackboard.to_dictionary(true) if blackboard else variable_overrides
	return {"variables": to_plain(values)}


## Puts back data made by [method get_save_data]. Before the agent starts the values
## become overrides.
func load_save_data(data: Dictionary) -> void:
	var values: Dictionary = data.get("variables", {})
	for variable in values:
		set_variable(StringName(variable), values[variable])


## The dictionary without the values the Save addon cannot store, such as nodes.
static func to_plain(values: Dictionary) -> Dictionary:
	var plain := {}
	for key in values:
		var value: Variant = values[key]
		match typeof(value):
			TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL:
				continue
		plain[String(key)] = value
	return plain

#endregion

#region Internals

func _build() -> void:
	if root and root.is_running:
		root.abort()
	var actor := get_actor()
	blackboard = BehaviorBlackboard.new(tree.variables, actor)
	for variable in variable_overrides:
		blackboard.set_value(variable, variable_overrides[variable])
	_physics_tasks.clear()
	_guards.clear()
	root = tree.instantiate()
	root._setup(self, actor, blackboard, null, -1)


func _auto_tick(delta: float) -> void:
	if _state != State.RUNNING:
		return
	_accumulated += delta
	if _accumulated < tick_interval:
		return
	if time_sliced and not Behaviors._claim_tick(self):
		return
	var elapsed := _accumulated
	_accumulated = 0.0
	_tick(elapsed)


func _tick(delta: float) -> BehaviorTask.Status:
	if _restart_pending:
		restart()
	_tick_id += 1
	_executions = 0
	_clock += delta
	var result := root.tick(delta)
	if result == BehaviorTask.Status.RUNNING:
		return result
	_status = result
	root._visit(func(task: BehaviorTask) -> void: task._on_tree_complete(result))
	if restart_when_complete:
		_restart_pending = true
	else:
		_state = State.STOPPED
		_physics_tasks.clear()
		_update_processing()
	finished.emit(result)
	return result


func _update_processing() -> void:
	var running := not Engine.is_editor_hint() and _state == State.RUNNING
	set_process(running and tick_mode == TickMode.IDLE)
	set_physics_process(running and (tick_mode == TickMode.PHYSICS or not _physics_tasks.is_empty()))


func _claim_start(task: BehaviorTask) -> bool:
	if execution_limit == ExecutionLimit.NO_DUPLICATES:
		if task._start_tick == _tick_id:
			return false
		task._start_tick = _tick_id
		return true
	if _executions >= max_task_executions:
		return false
	_executions += 1
	return true


func _task_changed(task: BehaviorTask, task_status: BehaviorTask.Status) -> void:
	if _uses_physics(task):
		if task_status == BehaviorTask.Status.RUNNING:
			if not _physics_tasks.has(task):
				_physics_tasks.append(task)
		else:
			_physics_tasks.erase(task)
		_update_processing()
	if log_task_changes:
		_log_task(task, task_status)
	if debug_enabled:
		task_changed.emit(task, task_status)


func _task_reevaluated(task: BehaviorTask, task_status: BehaviorTask.Status) -> void:
	if debug_enabled:
		task_reevaluated.emit(task, task_status)


func _task_aborted_by(observer: BehaviorTask, interrupted: BehaviorTask) -> void:
	if log_task_changes:
		print("%s - %s: %s aborted %s" % [get_actor().name, _tree_name(), observer.get_display_name(), interrupted.get_display_name() if interrupted else "nothing"])


func _breakpoints_enabled() -> bool:
	return EngineDebugger.is_active()


func _log_task(task: BehaviorTask, task_status: BehaviorTask.Status) -> void:
	var depth := 0
	var parent := task.get_parent_task()
	while parent:
		depth += 1
		parent = parent.get_parent_task()
	var verb := "Push"
	var suffix := ""
	match task_status:
		BehaviorTask.Status.INACTIVE:
			verb = "Abort"
		BehaviorTask.Status.SUCCESS, BehaviorTask.Status.FAILURE:
			verb = "Pop"
			suffix = " with status %s" % BehaviorTask.Status.keys()[task_status].capitalize()
	print("%s - %s: %s task %s (id %d) at depth %d%s" % [get_actor().name, _tree_name(), verb, task.get_display_name(), task.id, depth, suffix])


func _tree_name() -> String:
	if tree == null:
		return "Behavior"
	if not tree.resource_name.is_empty():
		return tree.resource_name
	return tree.resource_path.get_file().get_basename() if not tree.resource_path.is_empty() else "Behavior"


# True when the task's script overrides _on_physics_update. Method lists include
# inherited methods, so an override shows up twice.
static func _uses_physics(task: BehaviorTask) -> bool:
	var script: Script = task.get_script()
	if script == null:
		return false
	if not _physics_scripts.has(script):
		var count := 0
		for method in script.get_script_method_list():
			if method.name == "_on_physics_update":
				count += 1
		_physics_scripts[script] = count > 1
	return _physics_scripts[script]

#endregion
