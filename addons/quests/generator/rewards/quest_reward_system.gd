@icon("../../icons/quest_reward.svg")
class_name QuestRewardSystem
extends Node
## Base class for reward systems. A [QuestGeneratorEntity] asks each of its
## reward systems, in order, to use up the reward points of a generated quest
## until none are left. Extend this class and override [method determine_reward].

## Probability that this reward system gives a reward, where 0 is never and 1 is always.
@export_range(0.0, 1.0) var probability := 1.0


## Adds rewards to [param quest] (offer text and success actions) and returns the
## points that remain. [param entity_type] is the goal entity type, if known.
## The base class doesn't do anything, so it doesn't use up any points.
func determine_reward(points: int, _quest: Quest, _entity_type: QuestEntityType = null) -> int:
	return points
