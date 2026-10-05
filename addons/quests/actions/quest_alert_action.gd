class_name QuestAlertAction
extends QuestAction
## Shows an alert.

## The alert's content.
@export var content_list: Array[QuestContent] = []


func get_editor_name() -> String:
	if content_list.is_empty() or content_list[0] == null:
		return "Alert"
	return "Alert: " + content_list[0].get_editor_name() + ("..." if content_list.size() > 1 else "")


func set_runtime_references(p_quest: Quest, p_node: QuestNode) -> void:
	super.set_runtime_references(p_quest, p_node)
	for content in content_list:
		if content != null:
			content.set_runtime_references(p_quest, p_node)


func execute() -> void:
	if content_list.is_empty():
		push_warning("Quests: Alert text is empty in %s." % (quest.id if quest != null else "quest"))
	# The quest may have been removed at the end of the quest, so it can be null.
	QuestMessages.quest_alert(quest, quest.id if quest != null else "", content_list)


func get_images() -> Array[Texture2D]:
	var images: Array[Texture2D] = []
	for content in content_list:
		if content != null:
			images.append_array(content.get_images())
	return images


func get_audio() -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for content in content_list:
		if content != null:
			streams.append_array(content.get_audio())
	return streams
