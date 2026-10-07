@tool
@icon("res://addons/behaviors/icons/relationship.svg")
class_name BehaviorCompareAffinity
extends BehaviorCondition
## Succeeds when a faction's affinity toward another passes a check.
##
## Needs the Relationships package. Fails, with one warning, when it is missing.

## The faction that feels the affinity, by ID or name. Empty uses the faction of the
## actor's faction member.
@export var judge: String = ""
## The faction it feels toward, by ID or name. Empty uses the actor's faction.
@export var subject: String = ""
## How to compare the affinity with [member value].
@export_enum("<", "<=", "==", "!=", ">=", ">") var comparison: String = ">="
## The value to compare with.
@export_range(-100.0, 100.0, 0.1, "or_greater", "or_less") var value: float = 0.0
## The variable that receives the affinity.
@export var store_affinity: String = ""

var _warned: bool = false


func _on_update(_delta: float) -> Status:
	if not BehaviorsRelationships.has_manager():
		if not _warned:
			_warned = true
			push_warning("%s: the Relationships package is not available." % get_display_name())
		return Status.FAILURE
	var affinity := BehaviorsRelationships.get_affinity(actor, _faction(judge), _faction(subject))
	if not store_affinity.is_empty():
		set_var(StringName(store_affinity), affinity)
	return Status.SUCCESS if _check(affinity) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not BehaviorsRelationships.is_available():
		warnings.append("Requires the Relationships package.")
	return warnings


func _get_graph_text() -> String:
	return "%s %s" % [comparison, value]


func _faction(text: String) -> Variant:
	return int(text) if text.is_valid_int() else text


func _check(affinity: float) -> bool:
	match comparison:
		"<":
			return affinity < value
		"<=":
			return affinity <= value
		"==":
			return is_equal_approx(affinity, value)
		"!=":
			return not is_equal_approx(affinity, value)
		">":
			return affinity > value
	return affinity >= value
