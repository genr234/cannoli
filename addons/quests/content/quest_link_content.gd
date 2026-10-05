class_name QuestLinkContent
extends QuestContent
## Shows another piece of the same quest's content, by content ID.

## The content ID of the content to show, or -1.
@export var linked_content_id := -1


## Returns the linked content, or null.
func get_linked_content() -> QuestContent:
	if quest == null or linked_content_id < 0:
		return null
	var linked := quest.get_content_by_id(linked_content_id)
	return linked if linked != self else null


func get_editor_name() -> String:
	var linked := get_linked_content()
	return "Link (unassigned)" if linked == null else "Linked to: " + linked.get_editor_name()


func get_original_text() -> String:
	var linked := get_linked_content()
	return linked.get_original_text() if linked != null else ""
