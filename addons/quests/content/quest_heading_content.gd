class_name QuestHeadingContent
extends QuestContent
## Text in a heading style.

## Use the quest's title for the heading text.
@export var use_quest_title := false
## Text to show in heading text style.
@export_multiline var text := ""
## Heading level (1 = main heading, 2 = subheading, and so on).
@export_range(1, 5) var heading_level := 1


func get_original_text() -> String:
	if use_quest_title:
		return quest.title if quest != null else "Quest"
	return text


func get_editor_name() -> String:
	return "Heading: <Quest Title>" if use_quest_title else "Heading: " + text
