class_name QuestButtonContent
extends QuestIconContent
## A button that runs actions when clicked.

const NO_GROUP := -1

## Group number this button belongs to, or -1 if none. When one button in a group
## is clicked, the UI makes every button in the group non-interactable.
@export var group_number := NO_GROUP
## The actions to run when the button is clicked.
@export var action_list: Array[QuestAction] = []

## Whether the button does anything.
var interactable: bool:
	get:
		return not action_list.is_empty()


func get_editor_name() -> String:
	if not caption.is_empty():
		return "Button: " + (str(count) + " " if count > 1 else "") + caption
	if image != null:
		return "Button: " + image.resource_path.get_file().get_basename()
	return "Button"


func set_runtime_references(p_quest: Quest, p_node: QuestNode) -> void:
	super.set_runtime_references(p_quest, p_node)
	for action in action_list:
		if action != null:
			action.set_runtime_references(p_quest, p_node)


## Runs the button's actions.
func click() -> void:
	for action in action_list:
		if action != null:
			action.execute()
