class_name QuestMotive
extends Resource
## A reason why a quest giver wants a verb done. Includes text shown to the
## player and drive values that the generator matches to the giver's personality.

@export_multiline var text := ""
@export var drive_values: Array[QuestDriveValue] = []


static func create(p_text: String, p_drive_values: Array[QuestDriveValue] = []) -> QuestMotive:
	var m := QuestMotive.new()
	m.text = p_text
	m.drive_values = p_drive_values
	return m
