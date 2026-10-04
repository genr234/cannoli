@tool
class_name AffinityTier
extends Resource
## A named band of affinity, such as Hostile or Friendly. A judge's tier
## toward a subject is the tier with the highest [member min_affinity] that
## the affinity reaches. See [member FactionDatabase.affinity_tiers].

@export var name := "":
	set(value):
		name = value
		resource_name = value
		emit_changed()
## The lowest affinity in this tier.
@export_range(-100, 100) var min_affinity := 0.0
## Used by the editor's relationship matrix and the debugger.
@export var color := Color.WHITE


static func create(tier_name: String, minimum: float, tier_color: Color) -> AffinityTier:
	var tier := AffinityTier.new()
	tier.name = tier_name
	tier.min_affinity = minimum
	tier.color = tier_color
	return tier


## The translated name.
func get_display_name() -> String:
	return tr(name)
