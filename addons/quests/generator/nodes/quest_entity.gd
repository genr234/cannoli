@icon("../../icons/quest_entity.svg")
class_name QuestEntity
extends Node
## Marks a character or object as an entity of a [QuestEntityType]. Quest
## generators that observe a [QuestDomain] containing this entity can create
## quests about it.

## Emitted when this entity leaves the tree (is despawned or destroyed).
signal despawned(entity: QuestEntity)

## This entity's entity type.
@export var entity_type: QuestEntityType

var _fallback_name := ""


func _exit_tree() -> void:
	despawned.emit(self)


## The image of the entity type.
func get_image() -> Texture2D:
	return entity_type.image if entity_type != null else null


## The id used for this entity in quests: the id of a quest list or identity
## near it, otherwise the entity type's display name.
func get_id() -> String:
	var list := find_quest_list()
	if list != null and not list.id.is_empty():
		return list.id
	var identity := QuestIdentity.find_for(self)
	if identity != null and not identity.id.is_empty():
		return identity.id
	return _get_fallback_name()


func get_display_name() -> String:
	var list := find_quest_list()
	if list != null and not list.display_name.is_empty():
		return list.display_name
	var identity := QuestIdentity.find_for(self)
	if identity != null and not identity.display_name.is_empty():
		return identity.display_name
	return _get_fallback_name()


func _get_fallback_name() -> String:
	if entity_type != null:
		var display := entity_type.get_display_name()
		if not display.is_empty():
			return display
	if _fallback_name.is_empty():
		_fallback_name = String(name)
	return _fallback_name


## Finds the quest list (giver) that belongs to this entity: a child, a sibling,
## or a child of an ancestor up to three levels up. Journals are ignored.
func find_quest_list() -> QuestList:
	var found := _find_list_in_children(self)
	if found != null:
		return found
	var node := get_parent()
	var depth := 0
	while node != null and depth < 3:
		if node is QuestList and not node is QuestJournal:
			return node
		found = _find_list_in_children(node)
		if found != null:
			return found
		node = node.get_parent()
		depth += 1
	return null


static func _find_list_in_children(node: Node) -> QuestList:
	var fallback: QuestList = null
	for child in node.get_children():
		if child is QuestGiver:
			return child
		if child is QuestList and not child is QuestJournal and fallback == null:
			fallback = child
	return fallback
