@tool
@icon("res://addons/behaviors/icons/distance.svg")
class_name BehaviorIsWithinDistance
extends BehaviorCondition
## Succeeds when the actor is closer to a target than a distance, or farther away.
##
## Fails when there is no target.

## Which side of the distance succeeds.
enum Mode {
	## The target is at most this far away.
	WITHIN,
	## The target is farther than this.
	BEYOND,
}

## The node or position to measure to. Bind it to a variable holding a node, a Vector2
## or a Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## The distance, in world units.
@export_range(0.0, 10000.0, 0.01, "or_greater", "suffix:units") var distance: float = 5.0
## Whether being closer or being farther succeeds.
@export var mode: Mode = Mode.WITHIN
## Ignores the height in 3D, so only the distance on the ground counts.
@export var ignore_height: bool = false
## The variable that receives the measured distance.
@export var store_distance: String = ""


func _on_update(_delta: float) -> Status:
	var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
	if position == null:
		return Status.FAILURE
	var measured := BehaviorSpace.distance_between(BehaviorSpace.get_position(actor), position, ignore_height)
	if not store_distance.is_empty():
		set_var(StringName(store_distance), measured)
	var within := measured <= distance
	return Status.SUCCESS if within == (mode == Mode.WITHIN) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("Is Within Distance needs a target: bind \"target\" or set a target path.")
	return warnings


func _get_graph_text() -> String:
	return "%s %s u" % ["<=" if mode == Mode.WITHIN else ">", distance]
