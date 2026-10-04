@tool
class_name TraitDefinition
extends Resource
## Defines a single personality trait (such as Charity) or relationship trait
## (such as Rivalry).

@export var name := "":
	set(value):
		name = value
		resource_name = value
		emit_changed()
@export_multiline var description := ""
## Trait values are clamped to this minimum.
@export var min_value := -100.0
## Trait values are clamped to this maximum.
@export var max_value := 100.0
@export_multiline var custom_data := ""

@export_group("Drift", "drift_")
## For relationship traits: how many points per minute a personal value above
## its baseline falls back toward it. The baseline is the value in the
## database resource, or the inherited value if the resource has none.
## 0 means it never falls back.
@export_range(0, 100, 0.01, "or_greater") var drift_fall_per_minute := 0.0
## For relationship traits: how many points per minute a personal value below
## its baseline rises back toward it. Set lower than
## [member drift_fall_per_minute] for grudges that outlast favors.
@export_range(0, 100, 0.01, "or_greater") var drift_rise_per_minute := 0.0


static func create(trait_name: String, trait_description := "") -> TraitDefinition:
	var definition := TraitDefinition.new()
	definition.name = trait_name
	definition.description = trait_description
	return definition
