@tool
@icon("res://addons/behaviors/icons/group.svg")
class_name BehaviorFindInGroup
extends BehaviorAction
## Picks a node from a group and stores it in a variable. Fails when the group has no
## usable node. The actor is never picked.

## Which node to pick.
enum Pick {
	## The first node in the group.
	FIRST,
	## Any node, at random.
	RANDOM,
	## The node closest to the actor. Works with 2D and 3D nodes.
	NEAREST,
	## The node farthest from the actor. Works with 2D and 3D nodes.
	FARTHEST,
}

## The group to search.
@export var group: StringName = &""
## Which node to pick.
@export var pick: Pick = Pick.NEAREST
## Ignore nodes farther than this from the actor. 0 means no limit.
@export_range(0.0, 10000.0, 0.1, "or_greater", "suffix:m") var max_distance: float = 0.0
## The variable that receives the node.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	if String(group).is_empty() or store_in.is_empty() or actor == null or not actor.is_inside_tree():
		return Status.FAILURE
	var candidates: Array[Node] = []
	for node in actor.get_tree().get_nodes_in_group(group):
		if node != actor:
			candidates.append(node)
	if max_distance > 0.0 or pick == Pick.NEAREST or pick == Pick.FARTHEST:
		candidates = _by_distance(candidates)
	if candidates.is_empty():
		return Status.FAILURE
	var chosen: Node
	match pick:
		Pick.RANDOM:
			chosen = candidates.pick_random()
		Pick.FARTHEST:
			chosen = candidates.back()
		_:
			chosen = candidates.front()
	set_var(StringName(store_in), chosen)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(group).is_empty():
		warnings.append("Find In Group has no group.")
	if store_in.is_empty():
		warnings.append("Find In Group has no variable to store in.")
	return warnings


func _get_graph_text() -> String:
	return "%s ← %s" % [store_in, group]


# Nodes sorted near to far, dropping those that cannot be measured or are too far.
func _by_distance(nodes: Array[Node]) -> Array[Node]:
	var origin: Variant = Targets.get_position_of(actor)
	if origin == null:
		return []
	var measured: Array[Dictionary] = []
	for node in nodes:
		var position: Variant = Targets.get_position_of(node)
		if typeof(position) != typeof(origin):
			continue
		var distance: float = origin.distance_to(position)
		if max_distance > 0.0 and distance > max_distance:
			continue
		measured.append({"node": node, "distance": distance})
	measured.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var sorted: Array[Node] = []
	for entry in measured:
		sorted.append(entry.node)
	return sorted
