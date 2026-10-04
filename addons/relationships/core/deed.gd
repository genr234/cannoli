class_name Deed
extends RefCounted
## An objective record of something an actor did to a target.
##
## Report deeds with [method FactionManager.commit_deed], or more conveniently
## through a [DeedReporter] and a [DeedTemplateLibrary].

enum PermittedEvaluators {
	## Any faction member may evaluate the deed.
	EVERYONE,
	## Only members of the target's faction may evaluate the deed.
	ONLY_TARGET,
	## Anyone except members of the target's faction may evaluate the deed.
	EVERYONE_EXCEPT_TARGET,
}

## A unique ID, used to tell whether a member already heard about this deed.
var id := ""
var category: DeedCategory
## The type of deed, such as "attack" or "compliment".
var tag := ""
## The faction that committed the deed.
var actor_faction_id := 0
## The faction the deed was done to.
var target_faction_id := 0
## How good or bad the deed is for the target, from -100 (worst) to 100 (best).
var impact := 0.0
## How aggressive the deed is, from -100 (most submissive) to 100 (most aggressive).
var aggression := 0.0
## The actor's power level.
var actor_power_level := 1.0
## The deed's personality trait values.
var traits := PackedFloat32Array()
var permitted_evaluators := PermittedEvaluators.EVERYONE
## Evaluating this deed never pushes affinity to the actor below this.
var min_affinity_effect := -100.0
## Evaluating this deed never pushes affinity to the actor above this.
var max_affinity_effect := 100.0
## Witnesses ignore this deed if it's repeated within this many seconds.
var no_repeat_duration := 0.0


static func create(deed_tag: String, actor_id: int, target_id: int, deed_impact: float, deed_aggression: float,
		power_level := 1.0, deed_traits := PackedFloat32Array(), evaluators := PermittedEvaluators.EVERYONE,
		min_affinity := -100.0, max_affinity := 100.0, no_repeat := 0.0) -> Deed:
	var deed := Deed.new()
	deed.id = new_id()
	deed.tag = deed_tag
	deed.actor_faction_id = actor_id
	deed.target_faction_id = target_id
	deed.impact = deed_impact
	deed.aggression = deed_aggression
	deed.actor_power_level = power_level
	deed.traits = deed_traits.duplicate()
	deed.permitted_evaluators = evaluators
	deed.min_affinity_effect = min_affinity
	deed.max_affinity_effect = max_affinity
	deed.no_repeat_duration = no_repeat
	return deed


## Creates a deed from a template. [param magnitude] scales the impact, so one
## template can cover small and large versions of a deed.
static func from_template(template: DeedTemplate, actor_id: int, target_id: int, power_level := 1.0, magnitude := 1.0) -> Deed:
	var min_affinity := template.min_affinity_effect
	var max_affinity := template.max_affinity_effect
	if min_affinity == 0.0 and max_affinity == 0.0:
		min_affinity = -100.0
		max_affinity = 100.0
	var impact := clampf(template.impact * magnitude, -100.0, 100.0)
	var deed := create(template.tag, actor_id, target_id, impact, template.aggression, power_level,
			template.traits, template.permitted_evaluators, min_affinity, max_affinity, template.no_repeat_duration)
	deed.category = template.category
	return deed


## Returns a random 128-bit hex ID.
static func new_id() -> String:
	return "%08x%08x%08x%08x" % [randi(), randi(), randi(), randi()]
