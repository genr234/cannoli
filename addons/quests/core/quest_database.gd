@icon("../icons/quest_database.svg")
class_name QuestDatabase
extends Resource
## A collection of quest assets.
##
## Assign databases to a [QuestManager] to register their quests, so quest
## givers, save files and scripts can look quests up by id.

@export_multiline var description := ""
@export var quest_assets: Array[Quest]
## Images used by quests, so generated quests can find their icons by path.
@export var images: Array[Texture2D]


## Returns the quest asset with the given id, or null.
func get_quest_asset(id: String) -> Quest:
	for quest in quest_assets:
		if quest != null and quest.id == id:
			return quest
	return null


## Adds a quest asset, replacing any quest with the same id.
func add_quest(q: Quest) -> void:
	if q == null:
		return
	for i in quest_assets.size():
		if quest_assets[i] != null and quest_assets[i].id == q.id:
			quest_assets[i] = q
			return
	quest_assets.append(q)


func remove_quest(id: String) -> void:
	for i in range(quest_assets.size() - 1, -1, -1):
		if quest_assets[i] != null and quest_assets[i].id == id:
			quest_assets.remove_at(i)


## Registers the quests and images with [Quests].
func register() -> void:
	for quest in quest_assets:
		Quests.register_quest_asset(quest)
	register_images()


func register_images() -> void:
	for image in images:
		Quests.register_image(image)
