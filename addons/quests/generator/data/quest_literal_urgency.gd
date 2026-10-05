class_name QuestLiteralUrgency
extends QuestUrgencyFunction
## Always returns a fixed urgency.

@export var value := 0.0


static func create(p_value: float) -> QuestLiteralUrgency:
	var f := QuestLiteralUrgency.new()
	f.value = p_value
	return f


func get_type_name() -> String:
	return str(value)


func compute(_world_model: QuestWorldModel) -> float:
	return value
