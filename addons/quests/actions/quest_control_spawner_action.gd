class_name QuestControlSpawnerAction
extends QuestAction
## Starts, stops or despawns a [QuestSpawner].

enum ControlState { START, STOP, DESPAWN }

## Name of the spawner to control.
@export var spawner_name := ""
## What to do.
@export var state := ControlState.START


func get_editor_name() -> String:
	if spawner_name.is_empty():
		return "Control Spawner"
	return "Control Spawner: %s %s" % [String(ControlState.keys()[state]).capitalize(), spawner_name]


func execute() -> void:
	match state:
		ControlState.START:
			QuestMessages.start_spawner(spawner_name)
		ControlState.STOP:
			QuestMessages.stop_spawner(spawner_name)
		ControlState.DESPAWN:
			QuestMessages.despawn_spawner(spawner_name)
