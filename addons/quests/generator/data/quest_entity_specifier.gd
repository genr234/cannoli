class_name QuestEntitySpecifier
extends Resource
## Specifies an entity type relative to a world model: the entity being
## observed, the quest giver, the quester, or a specific entity type.

enum Type { THIS_ENTITY, QUEST_GIVER, QUESTER, OTHER }

## The type of entity being specified.
@export var specifier_type := Type.THIS_ENTITY
## If [constant Type.OTHER], this is the entity type.
@export var entity_type: QuestEntityType


static func create(p_type: Type, p_entity_type: QuestEntityType = null) -> QuestEntitySpecifier:
	var s := QuestEntitySpecifier.new()
	s.specifier_type = p_type
	s.entity_type = p_entity_type
	return s


static func other(p_entity_type: QuestEntityType) -> QuestEntitySpecifier:
	return create(Type.OTHER, p_entity_type)


func get_type_name() -> String:
	match specifier_type:
		Type.THIS_ENTITY:
			return "This Entity"
		Type.QUESTER:
			return "Quester"
		Type.QUEST_GIVER:
			return "Quest Giver"
	return entity_type.get_asset_name() if entity_type != null else "Unspecified"


func get_entity_type(world_model: QuestWorldModel) -> QuestEntityType:
	match specifier_type:
		Type.THIS_ENTITY:
			return world_model.observed.entity_type if world_model.observed != null else null
		Type.QUESTER:
			return QuestPlayerEntityType.instance
		Type.QUEST_GIVER:
			return world_model.observer.entity_type if world_model.observer != null else null
	return entity_type
