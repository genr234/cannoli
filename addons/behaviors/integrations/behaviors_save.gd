@tool
class_name BehaviorsSave
extends RefCounted
## Optional bridge to the Save addon.
##
## Stores the global variables and the variables of every [BehaviorAgent] that has a
## [member BehaviorAgent.save_key] in the "behaviors" section of the Save autoload, and
## puts them back when a slot loads. Agents register themselves when they enter the
## scene, so there is nothing to set up besides the save key. The autoload is found by
## name at runtime, so Behaviors runs without the addon.
## [codeblock]
## # Agent "guard_1" remembers its variables between sessions.
## $BehaviorAgent.save_key = "guard_1"
## [/codeblock]

## The section of the Save autoload that holds the data.
const SECTION := "behaviors"

static var _agents: Dictionary[String, WeakRef] = {}
# Data of agents that are not in the scene right now: not loaded yet, or left it.
static var _pending: Dictionary = {}
static var _registered: bool = false


## True when the Save autoload exists.
static func is_available() -> bool:
	return _get_save() != null


## Called by [BehaviorAgent] when it enters the scene. Does nothing without a save key or
## without the Save addon. Applies data that was loaded before the agent existed.
static func register_agent(agent: BehaviorAgent) -> void:
	if agent.save_key.is_empty() or not _ensure_registered():
		return
	_agents[agent.save_key] = weakref(agent)
	if _pending.has(agent.save_key):
		agent.load_save_data(_pending[agent.save_key])
		_pending.erase(agent.save_key)


## Called by [BehaviorAgent] when it leaves the scene. Keeps its data for the next save.
static func unregister_agent(agent: BehaviorAgent) -> void:
	var key := agent.save_key
	if key.is_empty() or not _agents.has(key) or _agents[key].get_ref() != agent:
		return
	_agents.erase(key)
	_pending[key] = agent.get_save_data()


## Forgets every registered agent and pending data. Call it when starting a new game.
static func reset() -> void:
	_agents.clear()
	_pending.clear()


static func _ensure_registered() -> bool:
	var save := _get_save()
	if save == null:
		return false
	if not _registered or not save.is_connected(&"loaded", _on_loaded):
		save.call(&"register_section", SECTION, _provide)
		if not save.is_connected(&"loaded", _on_loaded):
			save.connect(&"loaded", _on_loaded)
		_registered = true
	return true


static func _get_save() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var save := tree.root.get_node_or_null("Save")
	if save == null or not save.has_signal(&"loaded") or not save.has_method(&"register_section"):
		return null
	return save


static func _provide() -> Dictionary:
	var agents := _pending.duplicate(true)
	for key in _agents.keys():
		var agent := _agents[key].get_ref() as BehaviorAgent
		if agent == null:
			_agents.erase(key)
		else:
			agents[key] = agent.get_save_data()
	return {
		"globals": BehaviorAgent.to_plain(Behaviors.get_globals().to_dictionary(true)),
		"agents": agents,
	}


static func _on_loaded(_slot: int) -> void:
	var save := _get_save()
	if save == null:
		return
	var data: Dictionary = save.call(&"get_section", SECTION)
	Behaviors.get_globals().from_dictionary(data.get("globals", {}))
	_pending = data.get("agents", {}).duplicate(true)
	for key in _agents.keys():
		var agent := _agents[key].get_ref() as BehaviorAgent
		if agent == null:
			_agents.erase(key)
		elif _pending.has(key):
			agent.load_save_data(_pending[key])
			_pending.erase(key)
