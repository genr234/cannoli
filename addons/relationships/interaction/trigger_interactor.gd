@tool
class_name TriggerInteractor
extends Node
## Base class for nodes that react when a faction member enters an
## [Area2D] or [Area3D], such as [GossipTrigger] and [GreetingTrigger].
##
## Bodies and areas that enter the area are matched to their
## [FactionMember] with [method FactionMember.find_member].

## The trigger area. If empty, the parent is used when it's an [Area2D] or [Area3D].
@export var area: Node:
	set(value):
		area = value
		update_configuration_warnings()
## How many bodies to remember, to avoid searching for their members again.
@export var cache_size := 32

var _member_cache: Dictionary[Node, FactionMember] = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var trigger_area := get_area()
	if trigger_area == null:
		push_warning("Relationships: %s needs an Area2D or Area3D." % get_path())
		return
	trigger_area.body_entered.connect(_on_node_entered)
	trigger_area.area_entered.connect(_on_node_entered)


func _get_configuration_warnings() -> PackedStringArray:
	if get_area() == null:
		return PackedStringArray(["Make this a child of an Area2D or Area3D, or assign an area."])
	return PackedStringArray()


## The trigger area, or null.
func get_area() -> Node:
	var candidate := area if area != null else get_parent()
	return candidate if candidate is Area2D or candidate is Area3D else null


## Returns the [FactionMember] for a node that entered the area, or null.
func get_faction_member(other: Node) -> FactionMember:
	if other == null:
		return null
	if _member_cache.has(other):
		var cached := _member_cache[other]
		if cached == null or is_instance_valid(cached):
			return cached
		_member_cache.erase(other)
	var found := FactionMember.find_member(other)
	if _member_cache.size() < cache_size:
		_member_cache[other] = found
		other.tree_exiting.connect(func() -> void: _member_cache.erase(other), CONNECT_ONE_SHOT)
	return found


## Called with the member of each body or area that enters.
func _on_member_entered(_other: FactionMember) -> void:
	pass


func _on_node_entered(node: Node) -> void:
	var other := get_faction_member(node)
	if other != null:
		_on_member_entered(other)
