@tool
@icon("res://addons/behaviors/icons/random_probability.svg")
class_name BehaviorRandomProbability
extends BehaviorCondition
## Succeeds at random, with the given odds.

## The odds of success, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var success_probability: float = 0.5
## Uses [member random_seed] so the results are the same every run.
@export var use_seed: bool = false
## The seed used with [member use_seed].
@export var random_seed: int = 0

var _rng := RandomNumberGenerator.new()


func _on_awake() -> void:
	if use_seed:
		_rng.seed = random_seed
	else:
		_rng.randomize()


func _on_update(_delta: float) -> Status:
	return Status.SUCCESS if _rng.randf() < success_probability else Status.FAILURE


func _get_graph_text() -> String:
	return "%d%%" % roundi(success_probability * 100.0)
