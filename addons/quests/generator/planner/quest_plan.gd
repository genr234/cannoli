class_name QuestPlan
extends RefCounted
## A sequence of steps that the planner has found, and the world model that
## results from taking them.

var steps: Array[QuestPlanStep] = []
## The resulting world model.
var world_model: QuestWorldModel
## Set on the plan returned by the planner: the goal step and the motive chosen for it.
var goal: QuestPlanStep
var motive: QuestMotive


## Creates a plan that continues [param plan] with [param step].
func _init(p_plan: QuestPlan = null, p_step: QuestPlanStep = null, p_world_model: QuestWorldModel = null) -> void:
	if p_plan != null:
		steps.append_array(p_plan.steps)
	if p_step != null:
		steps.append(p_step)
	world_model = p_world_model


func _to_string() -> String:
	var s := ""
	for step in steps:
		s += str(step) + ", "
	return s + ">"
