@tool
@icon("res://addons/behaviors/icons/ear.svg")
class_name BehaviorCanHear
extends BehaviorCondition
## Succeeds when the actor hears a noise made with [method Behaviors.emit_noise] or a
## [BehaviorNoiseEmitter].
##
## A noise is heard when the actor is within its radius, scaled by [member hearing_range].
## Noises last a short time (the [code]behaviors/perception/noise_lifetime[/code]
## project setting), so the condition keeps succeeding until they fade. The chosen noise's
## source and position are stored.

## What to pick when several noises are heard.
enum Pick {
	## The noise with the biggest radius.
	LOUDEST,
	## The noise that is closest to the actor.
	NEAREST,
}

## Scales every noise radius. 2 hears twice as far, 0.5 only half as far.
@export_range(0.0, 100.0, 0.01, "or_greater") var hearing_range: float = 1.0
## Hears only noises with this tag. Empty hears every noise.
@export var tag: StringName = &""
## Which noise to pick when there are several.
@export var pick: Pick = Pick.LOUDEST
## Ignores noises made by the actor itself or by its children.
@export var ignore_own_noises: bool = true

@export_group("Results")
## The variable that receives the node that made the noise.
@export var store_source: String = ""
## The variable that receives where the noise was made.
@export var store_position: String = ""
## The variable that receives the tag of the noise.
@export var store_tag: String = ""


func _on_update(_delta: float) -> Status:
	var own: Variant = BehaviorSpace.get_position(actor)
	if own == null:
		return Status.FAILURE
	var best: Dictionary = {}
	var best_position: Variant = null
	var best_score := -INF
	for noise in Behaviors.get_noises():
		if not String(tag).is_empty() and noise.tag != tag:
			continue
		var source: Object = noise.source
		if ignore_own_noises and source is Node and is_instance_valid(source) and (source == actor or actor.is_ancestor_of(source)):
			continue
		var position: Variant = BehaviorSpace.convert_dimension(noise.position, actor is Node3D)
		if position == null:
			continue
		var distance: float = own.distance_to(position)
		var radius: float = float(noise.radius) * hearing_range
		if distance > radius:
			continue
		var score: float = float(noise.radius) if pick == Pick.LOUDEST else -distance
		if score > best_score:
			best_score = score
			best = noise
			best_position = position
	if best.is_empty():
		return Status.FAILURE
	if not store_source.is_empty():
		set_var(StringName(store_source), best.source if is_instance_valid(best.source) else null)
	if not store_position.is_empty():
		set_var(StringName(store_position), best_position)
	if not store_tag.is_empty():
		set_var(StringName(store_tag), best.tag)
	return Status.SUCCESS


func _get_graph_text() -> String:
	return String(tag) if not String(tag).is_empty() else "any noise"
