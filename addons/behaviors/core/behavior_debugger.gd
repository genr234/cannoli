extends Object
## The game side of the Behaviors debugger tab.
##
## Only active while the game runs from the editor with the debugger attached. It
## lists the running agents, and for the one the editor watches it streams task
## states and variables once per frame when something changed. Messages use the
## "behaviors" capture:
## [br]- game to editor: [code]behaviors:agents[/code] [code][agents][/code],
## [code]behaviors:state[/code] [code][agent_id, frame, time, states, variables][/code].
## [br]- editor to game: [code]behaviors:watch[/code] [code][agent_id][/code] (0 stops),
## [code]behaviors:set_variable[/code] [code][agent_id, name, value_text][/code],
## [code]behaviors:control[/code] [code][agent_id, "pause" | "resume" | "restart" | "stop"][/code].
## [br][br]
## [code]states[/code] maps task id to [code][status, running, reevaluated][/code].

const CAPTURE := "behaviors"

static var _registered: bool = false
static var _agents_dirty: bool = false
static var _watched: WeakRef
static var _states: Dictionary[int, Array] = {}
static var _state_dirty: bool = false
static var _frame_hooked: bool = false


static func is_active() -> bool:
	return EngineDebugger.is_active() and not Engine.is_editor_hint()


## Called when an agent enters or leaves the scene tree.
static func agents_changed() -> void:
	if not is_active():
		return
	_ensure_registered()
	_agents_dirty = true
	_hook_frame()


static func _ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	EngineDebugger.register_message_capture(CAPTURE, _capture)


static func _hook_frame() -> void:
	if _frame_hooked:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_frame_hooked = true
	tree.process_frame.connect(_flush)


static func _flush() -> void:
	if _agents_dirty:
		_agents_dirty = false
		_send_agents()
	var agent := _get_watched()
	if agent and _state_dirty:
		_state_dirty = false
		_send_state(agent)
		for id in _states:
			_states[id][2] = false


static func _capture(message: String, data: Array) -> bool:
	match message:
		"watch":
			_watch(_find_agent(int(data[0])) if not data.is_empty() else null)
		"set_variable":
			var agent := _find_agent(int(data[0]))
			if agent and agent.blackboard:
				var text := String(data[2])
				var value: Variant = str_to_var(text)
				if typeof(value) == TYPE_NIL and text != "null":
					value = text
				agent.blackboard.set_value(StringName(data[1]), value)
				_state_dirty = true
		"control":
			var agent := _find_agent(int(data[0]))
			if agent:
				match String(data[1]):
					"pause":
						agent.stop(true)
					"resume":
						agent.start()
					"restart":
						agent.restart()
					"stop":
						agent.stop()
				_agents_dirty = true
		"request_agents":
			_agents_dirty = true
		_:
			return false
	return true


static func _watch(agent: BehaviorAgent) -> void:
	var previous := _get_watched()
	if previous:
		previous.debug_enabled = false
		if previous.task_changed.is_connected(_on_task_changed):
			previous.task_changed.disconnect(_on_task_changed)
			previous.task_reevaluated.disconnect(_on_task_reevaluated)
			previous.started.disconnect(_on_rebuilt)
	_watched = weakref(agent) if agent else null
	_states.clear()
	if agent == null:
		return
	agent.debug_enabled = true
	agent.task_changed.connect(_on_task_changed)
	agent.task_reevaluated.connect(_on_task_reevaluated)
	agent.started.connect(_on_rebuilt)
	_on_rebuilt()


static func _on_rebuilt() -> void:
	_states.clear()
	var agent := _get_watched()
	if agent == null:
		return
	for task in agent.get_tasks():
		_states[task.id] = [task.status, task.is_running, false]
	_state_dirty = true


static func _on_task_changed(task: BehaviorTask, status: BehaviorTask.Status) -> void:
	var entry: Array = _states.get_or_add(task.id, [BehaviorTask.Status.INACTIVE, false, false])
	entry[0] = status
	entry[1] = status == BehaviorTask.Status.RUNNING
	_state_dirty = true


static func _on_task_reevaluated(task: BehaviorTask, _status: BehaviorTask.Status) -> void:
	var entry: Array = _states.get_or_add(task.id, [task.status, task.is_running, false])
	entry[2] = true
	_state_dirty = true


static func _send_agents() -> void:
	var list: Array = []
	for agent in Behaviors.get_all_agents():
		if not is_instance_valid(agent):
			continue
		list.append({
			"id": agent.get_instance_id(),
			"path": String(agent.get_path()),
			"actor": String(agent.get_actor().name),
			"tree": agent.tree.resource_path if agent.tree else "",
			"state": agent.get_state(),
		})
	EngineDebugger.send_message(CAPTURE + ":agents", [list])


static func _send_state(agent: BehaviorAgent) -> void:
	var variables := {}
	if agent.blackboard:
		for variable in agent.blackboard.get_names():
			variables[String(variable)] = _describe(agent.blackboard.get_value(variable))
	EngineDebugger.send_message(CAPTURE + ":state", [
		agent.get_instance_id(),
		Engine.get_process_frames(),
		agent.get_time(),
		_states.duplicate(true),
		variables,
	])


static func _describe(value: Variant) -> String:
	if value is Object:
		if not is_instance_valid(value):
			return "<freed>"
		if value is Node:
			return "%s (%s)" % [value.name, value.get_class()]
		if value is Resource and not value.resource_path.is_empty():
			return value.resource_path
		return str(value)
	return var_to_str(value)


static func _get_watched() -> BehaviorAgent:
	if _watched == null:
		return null
	var agent := _watched.get_ref() as BehaviorAgent
	return agent if is_instance_valid(agent) else null


static func _find_agent(id: int) -> BehaviorAgent:
	if id == 0:
		return null
	var object := instance_from_id(id)
	return object as BehaviorAgent if is_instance_valid(object) else null
