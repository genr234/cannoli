class_name QuestDomainSpecifier
extends Resource
## Specifies a domain type relative to a world model: the domain of the entity
## being observed, the quest giver's domain, the quester's domain, or a specific
## domain type.

enum Type { THIS_ENTITY_DOMAIN, QUEST_GIVER_DOMAIN, QUESTER_DOMAIN, OTHER }

## The type of domain being specified.
@export var specifier_type := Type.THIS_ENTITY_DOMAIN
## If [constant Type.OTHER], this is the specified domain.
@export var domain_type: QuestDomainType


static func create(p_type: Type, p_domain_type: QuestDomainType = null) -> QuestDomainSpecifier:
	var s := QuestDomainSpecifier.new()
	s.specifier_type = p_type
	s.domain_type = p_domain_type
	return s


static func other(p_domain_type: QuestDomainType) -> QuestDomainSpecifier:
	return create(Type.OTHER, p_domain_type)


func get_type_name() -> String:
	match specifier_type:
		Type.THIS_ENTITY_DOMAIN:
			return "This Entity's Domain"
		Type.QUESTER_DOMAIN:
			return "Quester's Domain"
		Type.QUEST_GIVER_DOMAIN:
			return "Quest Giver's Domain"
	return domain_type.get_asset_name() if domain_type != null else "Unspecified"


func get_domain_type(world_model: QuestWorldModel) -> QuestDomainType:
	match specifier_type:
		Type.THIS_ENTITY_DOMAIN:
			return world_model.observed.domain_type if world_model.observed != null else null
		Type.QUESTER_DOMAIN:
			return QuestDomainType.player_domain_instance
		Type.QUEST_GIVER_DOMAIN:
			return world_model.observer.domain_type if world_model.observer != null else null
	return domain_type
