@tool
class_name DeedTemplate
extends Resource
## The attributes of a kind of deed, which a [DeedReporter] reports by tag.

## Unique tag for the kind of deed, such as "attack".
@export var tag := "":
	set(value):
		tag = value
		resource_name = value
		emit_changed()
## For the designer's use.
@export_multiline var description := ""
@export var category: DeedCategory
## How good or bad the deed is for its target, from -100 (worst) to 100 (best).
@export_range(-100, 100) var impact := 0.0
## How aggressive the deed is, from -100 (most submissive) to 100 (most aggressive).
@export_range(-100, 100) var aggression := 0.0
## The deed's personality trait values.
@export var traits := PackedFloat32Array()
## Whether witnesses must be able to see the actor.
@export var requires_sight := false
## How far away the deed can be witnessed. 0 means anywhere.
@export var radius := 10.0
@export var permitted_evaluators := Deed.PermittedEvaluators.EVERYONE
## Evaluating this deed never pushes affinity to the actor below this.
@export_range(-100, 100) var min_affinity_effect := -100.0
## Evaluating this deed never pushes affinity to the actor above this.
@export_range(-100, 100) var max_affinity_effect := 100.0
## Witnesses ignore the deed if it's repeated within this many seconds.
@export var no_repeat_duration := 0.0


static func create(deed_tag: String, deed_impact: float, deed_aggression: float, deed_traits := PackedFloat32Array(),
		sight := false, deed_radius := 10.0) -> DeedTemplate:
	var template := DeedTemplate.new()
	template.tag = deed_tag
	template.impact = deed_impact
	template.aggression = deed_aggression
	template.traits = deed_traits.duplicate()
	template.requires_sight = sight
	template.radius = deed_radius
	return template
