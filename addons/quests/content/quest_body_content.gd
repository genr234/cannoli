class_name QuestBodyContent
extends QuestContent
## Text in the regular body style.

## Text to show in regular body text style.
@export_multiline var text := ""


func get_original_text() -> String:
	return text


func get_editor_name() -> String:
	return "Text: " + text if not text.is_empty() else "Body Text"
