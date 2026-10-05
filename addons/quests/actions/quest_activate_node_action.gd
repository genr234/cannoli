class_name QuestActivateNodeAction
extends QuestAction
## Shows or hides, enables or disables scene nodes. The original's
## ActivateGameObject action.

enum Mode {
	## Set the node's visibility and processing.
	BOTH,
	## Only set visibility.
	VISIBILITY,
	## Only set processing: INHERIT when active, DISABLED when not.
	PROCESS_MODE,
}

## Group name, [QuestIdentity] id or node name of the nodes.
@export var target := ""
## Tick to activate, untick to deactivate.
@export var state := true
@export var mode := Mode.BOTH


func get_editor_name() -> String:
	if target.is_empty():
		return "Activate Node"
	return ("Activate" if state else "Deactivate") + " Node: '" + target + "'"


func execute() -> void:
	if target.is_empty():
		return
	var nodes := QuestSceneLookup.find_nodes(target)
	if nodes.is_empty():
		if Quests.debug:
			push_warning("Quests: QuestActivateNodeAction can't find '%s'." % target)
		return
	for node in nodes:
		if mode != Mode.PROCESS_MODE and (node is CanvasItem or node is Node3D):
			node.set("visible", state)
		if mode != Mode.VISIBILITY:
			node.process_mode = Node.PROCESS_MODE_INHERIT if state else Node.PROCESS_MODE_DISABLED
