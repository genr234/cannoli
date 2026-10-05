class_name QuestGoalFactSelection
extends RefCounted
## How a goal fact is selected from the facts a generator knows about.

enum Method { MOST_URGENT, WEIGHTED, WEIGHTED_SQUARED, EQUAL_WEIGHT }


## Returns the equivalent [QuestUrgentFactSelectionMode] that considers [param max_facts] facts.
static func to_mode(method: Method, max_facts := 1) -> QuestUrgentFactSelectionMode:
	match method:
		Method.WEIGHTED_SQUARED:
			return QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.WEIGHTED_SQUARED, max_facts)
		Method.EQUAL_WEIGHT:
			return QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.EQUAL_WEIGHT, max_facts)
		Method.MOST_URGENT:
			return QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.WEIGHTED, 1)
	return QuestUrgentFactSelectionMode.create(QuestUrgentFactSelectionMode.Criterion.WEIGHTED, max_facts)
