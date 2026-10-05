class_name QuestVerbEffect
extends Resource
## How a verb changes the world model.

enum Operation { ADD, REMOVE }

@export var operation := Operation.ADD
@export var domain_specifier: QuestDomainSpecifier
@export var entity_specifier: QuestEntitySpecifier
@export var count := 1


static func create(p_operation: Operation, p_domain: QuestDomainSpecifier, p_entity: QuestEntitySpecifier, p_count := 1) -> QuestVerbEffect:
	var e := QuestVerbEffect.new()
	e.operation = p_operation
	e.domain_specifier = p_domain
	e.entity_specifier = p_entity
	e.count = p_count
	return e
