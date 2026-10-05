class_name QuestStateInfo
extends Resource
## Actions and UI content for one state of a quest or a quest node.

@export var action_list: Array[QuestAction]
@export var dialogue_content: Array[QuestContent]
@export var journal_content: Array[QuestContent]
@export var hud_content: Array[QuestContent]


func set_runtime_references(quest: Quest, quest_node: QuestNode) -> void:
	for action in action_list:
		if action != null:
			action.set_runtime_references(quest, quest_node)
	for category_list in [dialogue_content, journal_content, hud_content]:
		QuestContent.set_runtime_references_in(category_list, quest, quest_node)


func has_content(category: QuestContent.Category) -> bool:
	return not get_content_list(category).is_empty()


## The content for [param category]. The alert, offer and offer conditions
## unmet categories have no per-state content, so they return an empty array.
func get_content_list(category: QuestContent.Category) -> Array[QuestContent]:
	match category:
		QuestContent.Category.DIALOGUE:
			return dialogue_content
		QuestContent.Category.JOURNAL:
			return journal_content
		QuestContent.Category.HUD:
			return hud_content
	var empty: Array[QuestContent] = []
	return empty


## Executes every action.
func execute_actions() -> void:
	for action in action_list:
		if action != null:
			action.execute()


## Fills [param list] with new state infos until it has [param count] entries,
## and replaces null entries.
static func validate_list(list: Array[QuestStateInfo], count: int) -> void:
	while list.size() < count:
		list.append(QuestStateInfo.new())
	for i in list.size():
		if list[i] == null:
			list[i] = QuestStateInfo.new()
