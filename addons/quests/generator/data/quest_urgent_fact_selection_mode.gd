class_name QuestUrgentFactSelectionMode
extends Resource
## How a generator weights the urgency of facts, and how many of the most urgent
## facts it considers as potential goals for a quest.

enum Criterion { SAME_AS_GLOBAL_SETTING, WEIGHTED, WEIGHTED_SQUARED, EQUAL_WEIGHT }

## How to weight the urgencies of facts. Higher urgency facts are more likely to get quests.
@export var criterion := Criterion.WEIGHTED
## Number of top-urgency facts to consider when choosing a fact to create a quest about.
@export var max_facts := 1


static func create(p_criterion: Criterion, p_max_facts: int) -> QuestUrgentFactSelectionMode:
	var m := QuestUrgentFactSelectionMode.new()
	m.criterion = p_criterion
	m.max_facts = p_max_facts
	return m


## A mode that considers only the single most urgent fact.
static func most_urgent() -> QuestUrgentFactSelectionMode:
	return create(Criterion.WEIGHTED, 1)


func adjust_urgency(urgency: float) -> float:
	match criterion:
		Criterion.WEIGHTED_SQUARED:
			return urgency * urgency
		Criterion.EQUAL_WEIGHT:
			return 1.0
		Criterion.SAME_AS_GLOBAL_SETTING:
			var global_mode := QuestGeneratorData.global_goal_selection
			if global_mode == null or global_mode.criterion == Criterion.SAME_AS_GLOBAL_SETTING:
				return urgency
			return global_mode.adjust_urgency(urgency)
	return urgency
