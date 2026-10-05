class_name QuestTestAction
extends QuestAction
## An action for tests that counts how often it ran.

@export var label := ""
var executed := 0


func execute() -> void:
	executed += 1


func get_editor_name() -> String:
	return "Test Action " + label
