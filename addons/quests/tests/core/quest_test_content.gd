class_name QuestTestContent
extends QuestContent
## A content item for tests.

@export var text := ""


func get_original_text() -> String:
	return text


static func make(p_text: String) -> QuestTestContent:
	var content := QuestTestContent.new()
	content.text = p_text
	return content
