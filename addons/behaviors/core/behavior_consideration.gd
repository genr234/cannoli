@tool
@icon("res://addons/behaviors/icons/utility.svg")
class_name BehaviorConsideration
extends Resource
## One input to a task's utility score, for [BehaviorUtilitySelector].
##
## Reads a variable, maps it from [member input_min]..[member input_max] onto 0..1,
## samples [member curve] and blends the result toward 1 by [member weight]. A task's
## utility is the product of its considerations, so any consideration near zero
## vetoes the task.

## A name shown in the editor.
@export var label: String = ""
## The variable to read. Use a number variable, or a bool (false is 0, true is 1).
@export var variable: String = ""
## The input that maps to 0.
@export var input_min: float = 0.0
## The input that maps to 1.
@export var input_max: float = 1.0
## Turns the normalized input into a score. Empty uses the input as the score.
@export var curve: Curve
## How much this consideration counts. 0 ignores it, 1 uses the full score.
@export_range(0.0, 1.0, 0.01) var weight: float = 1.0


## The score for [param task], between 0 and 1 for curves that stay in 0..1.
func evaluate(task: BehaviorTask) -> float:
	var raw: Variant = task.get_var(variable, 0.0)
	var input := 0.0
	if raw is bool:
		input = 1.0 if raw else 0.0
	elif raw is int or raw is float:
		input = float(raw)
	var t := 0.0
	if not is_equal_approx(input_max, input_min):
		t = clampf(inverse_lerp(input_min, input_max, input), 0.0, 1.0)
	var score := curve.sample(t) if curve else t
	return lerpf(1.0, score, weight)
