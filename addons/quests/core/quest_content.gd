class_name QuestContent
extends QuestSubasset
## Base class for UI content: text, icons, buttons and so on.

enum Category { DIALOGUE, JOURNAL, HUD, ALERT, OFFER, OFFER_CONDITIONS_UNMET }

## Bitmask of [enum Category] values this content is meant for, or -1 for all.
@export var use_in_categories: int = -1
## Unique number within the quest, so links can refer to this content.
@export_storage var content_id := -1


## Virtual. The text before tags are replaced.
func get_original_text() -> String:
	return ""


## The text with tags replaced and translated.
func get_text() -> String:
	return QuestTags.replace_tags(get_original_text(), quest)


func add_tags_to_dictionary() -> void:
	add_text_tags(get_original_text())


static func set_runtime_references_in(content_list: Array, p_quest: Quest, p_node: QuestNode) -> void:
	for content in content_list:
		if content != null:
			content.set_runtime_references(p_quest, p_node)
