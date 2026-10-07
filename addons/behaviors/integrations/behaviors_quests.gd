@tool
class_name BehaviorsQuests
extends RefCounted
## Optional bridge to the Quests addon.
##
## The addon is found through the project's global class list and driven with dynamic
## calls, so Behaviors runs without it. States are the numbers of [code]Quest.State[/code]:
## waiting to start, active, successful, failed, abandoned, disabled.

const _API_CLASS := "Quests"

static var _scripts: Dictionary = {}


## True when the Quests addon is installed.
static func is_available() -> bool:
	return _get_script(_API_CLASS) != null


## Forgets cached lookups. Call this if the addon is enabled while running.
static func reset_cache() -> void:
	_scripts.clear()


## The state of a quest, or -1 when the addon is missing.
static func get_state(quest_id: String, quester_id: String = "") -> int:
	var api := _get_script(_API_CLASS)
	if api == null:
		return -1
	return int(api.call("get_quest_state", quest_id, quester_id))


## Sets the state of a quest. Returns false when the addon is missing.
static func set_state(quest_id: String, state: int, quester_id: String = "") -> bool:
	var api := _get_script(_API_CLASS)
	if api == null:
		return false
	api.call("set_quest_state", quest_id, state, quester_id)
	return true


static func _get_script(global_name: String) -> Script:
	if _scripts.has(global_name):
		return _scripts[global_name]
	var script: Script = null
	for info in ProjectSettings.get_global_class_list():
		if info.get("class", "") == global_name:
			script = load(info["path"]) as Script
			break
	_scripts[global_name] = script
	return script
