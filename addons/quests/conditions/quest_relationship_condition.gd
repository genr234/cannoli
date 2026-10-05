class_name QuestRelationshipCondition
extends QuestCondition
## True when one faction's relationship to another meets a requirement.
##
## Needs the Relationships addon (see [QuestsRelationships]); without it the
## condition never becomes true.

enum CheckMode {
	## Compare the affinity number with a value.
	AFFINITY,
	## The judge must be in exactly this affinity tier.
	TIER_IS,
	## The judge must be in this affinity tier or a higher one.
	TIER_AT_LEAST,
}

enum Comparison { LESS, LESS_OR_EQUAL, EQUAL, NOT_EQUAL, GREATER_OR_EQUAL, GREATER }

## Faction ID or name of the faction whose opinion is checked. Can contain tags such as {QUESTERID}.
@export var judge_faction := ""
## Faction ID or name of the faction being judged. Can contain tags such as {QUESTERID}.
@export var subject_faction := ""
@export var check_mode := CheckMode.AFFINITY
## For AFFINITY mode: how to compare the affinity with the value.
@export var comparison := Comparison.GREATER_OR_EQUAL
## For AFFINITY mode: the value to compare with.
@export var affinity_value := 0.0
## For the tier modes: the tier name.
@export var tier_name := ""
## Seconds between checks. 0 only checks when the Relationships manager reports a change.
@export var check_interval := 0.5

var _generation := 0
var _watched_manager: Object


func get_editor_name() -> String:
	var who := "%s -> %s" % [judge_faction, subject_faction]
	match check_mode:
		CheckMode.TIER_IS:
			return "Relationship: %s is %s" % [who, tier_name]
		CheckMode.TIER_AT_LEAST:
			return "Relationship: %s at least %s" % [who, tier_name]
	return "Relationship: %s %s %s" % [who, _comparison_symbol(), str(affinity_value)]


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	if _evaluate():
		set_true()
		return
	_generation += 1
	_watch_manager()
	if check_interval > 0.0:
		_poll(_generation)


func stop_checking() -> void:
	super.stop_checking()
	_generation += 1
	_unwatch_manager()


## Evaluates the requirement right now.
func is_requirement_met() -> bool:
	return _evaluate()


func _evaluate() -> bool:
	if not QuestsRelationships.has_manager():
		return false
	var judge := QuestTags.replace_tags(judge_faction, quest)
	var subject := QuestTags.replace_tags(subject_faction, quest)
	if judge.is_empty() or subject.is_empty():
		return false
	match check_mode:
		CheckMode.TIER_IS:
			return QuestsRelationships.get_tier_name(judge, subject) == tier_name
		CheckMode.TIER_AT_LEAST:
			return QuestsRelationships.is_at_least_tier(judge, subject, tier_name)
	return QuestsRelationships.check(judge, subject, _comparison_symbol(), affinity_value)


func _comparison_symbol() -> String:
	match comparison:
		Comparison.LESS:
			return "<"
		Comparison.LESS_OR_EQUAL:
			return "<="
		Comparison.EQUAL:
			return "=="
		Comparison.NOT_EQUAL:
			return "!="
		Comparison.GREATER:
			return ">"
	return ">="


func _poll(generation: int) -> void:
	var tree := QuestSceneLookup.get_tree()
	while tree != null and is_checking and generation == _generation:
		await tree.create_timer(check_interval).timeout
		if not is_checking or generation != _generation:
			return
		if _evaluate():
			set_true()
			return


func _watch_manager() -> void:
	_unwatch_manager()
	var manager := QuestsRelationships.get_manager()
	if manager != null and manager.has_signal("relationship_changed"):
		manager.connect("relationship_changed", _on_relationship_changed)
		_watched_manager = manager


func _unwatch_manager() -> void:
	if _watched_manager != null and is_instance_valid(_watched_manager):
		if _watched_manager.is_connected("relationship_changed", _on_relationship_changed):
			_watched_manager.disconnect("relationship_changed", _on_relationship_changed)
	_watched_manager = null


func _on_relationship_changed(_judge_id: int, _subject_id: int, _trait_id: int, _old_value: float, _new_value: float) -> void:
	if is_checking and _evaluate():
		set_true()
