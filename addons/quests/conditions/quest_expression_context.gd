class_name QuestExpressionContext
extends RefCounted
## The object that [QuestExpressionCondition] expressions run on.
##
## Its methods are available in expressions directly:
## [codeblock]
## is_state("rescue_miller", "successful") and counter("wolves", "killed") >= 3
## affinity("Villagers", "Player") > 20
## [/codeblock]

## The quest the expression belongs to, or null.
var quest: Quest


func _init(p_quest: Quest = null) -> void:
	quest = p_quest


## The ID of the quest the expression belongs to.
func quest_id() -> String:
	return quest.id if quest != null else ""


## Whether the quest is in the state named [param state_name] (such as "active").
## An empty [param id] means this quest.
func is_state(id: String, state_name: String, quester_id := "") -> bool:
	return Quests.is_state(id if not id.is_empty() else quest_id(), state_name, quester_id)


## The current state of the quest as an int, see [enum Quest.State].
func state(id: String, quester_id := "") -> int:
	return Quests.get_quest_state(id if not id.is_empty() else quest_id(), quester_id)


## The value of a quest's counter.
func counter(id: String, counter_name: String, quester_id := "") -> int:
	return Quests.counter(id if not id.is_empty() else quest_id(), counter_name, quester_id)


## The state of a quest node as an int, see [enum QuestNode.State].
func node_state(id: String, node_id: String, quester_id := "") -> int:
	return Quests.get_quest_node_state(id if not id.is_empty() else quest_id(), node_id, quester_id)


## Whether the Relationships addon is installed with an active manager.
func has_relationships() -> bool:
	return QuestsRelationships.has_manager()


## The judge's affinity to the subject (faction ID or name).
func affinity(judge: Variant, subject: Variant) -> float:
	return QuestsRelationships.get_affinity(judge, subject)


## The name of the judge's affinity tier toward the subject.
func tier(judge: Variant, subject: Variant) -> String:
	return QuestsRelationships.get_tier_name(judge, subject)


## Whether the judge's tier toward the subject is [param tier_name] or higher.
func is_at_least_tier(judge: Variant, subject: Variant, tier_name: String) -> bool:
	return QuestsRelationships.is_at_least_tier(judge, subject, tier_name)
