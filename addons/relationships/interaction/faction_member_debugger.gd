@tool
@icon("../icons/debugger.svg")
class_name FactionMemberDebugger
extends Node
## Shows a faction member's faction, PAD values and memories above its head.
##
## Uses a [Label3D] for 3D bodies and a [Label] for 2D bodies.

## If empty, the nearest [FactionMember] is used.
@export var member: FactionMember
## Toggles the label.
@export var toggle_key := KEY_QUOTELEFT
## Offset from the body's origin. For 2D, x and y are used and -y is up.
@export var offset := Vector3(0.0, 2.5, 0.0)
@export var visible := true
## Only show the debugger in debug builds.
@export var only_in_debug_build := true

var _label: Node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if only_in_debug_build and not OS.is_debug_build():
		queue_free()
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member == null:
		push_warning("Relationships: %s can't find a FactionMember." % get_path())
		return
	_create_label.call_deferred()
	member.pad_modified.connect(func(_h: float, _p: float, _a: float, _d: float) -> void: update_text())
	member.deed_remembered.connect(func(_rumor: Rumor) -> void: update_text())
	member.deed_forgotten.connect(func(_rumor: Rumor) -> void: update_text())


func _create_label() -> void:
	var body := member.get_body()
	if body is Node3D:
		var label_3d := Label3D.new()
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.no_depth_test = true
		label_3d.font_size = 24
		label_3d.pixel_size = 0.005
		label_3d.position = offset
		_label = label_3d
	elif body is Node2D:
		var label_2d := Label.new()
		label_2d.position = Vector2(offset.x, -offset.y * 16.0)
		label_2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_2d.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_label = label_2d
	else:
		return
	body.add_child(_label)
	_label.visible = visible
	update_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		visible = not visible
		if is_instance_valid(_label):
			_label.visible = visible


func _exit_tree() -> void:
	if is_instance_valid(_label):
		_label.queue_free()


func _faction_display_name() -> String:
	var faction := member.get_faction()
	return faction.get_display_name() if faction != null else ""


## Refreshes the label.
func update_text() -> void:
	if not is_instance_valid(_label) or member == null:
		return
	var pad := member.pad
	var text := "%s\nP:%d A:%d D:%d H:%d\nMemories: %d" % [
			_faction_display_name(), pad.pleasure, pad.arousal, pad.dominance, pad.happiness, member.long_term_memory.size()]
	if not member.long_term_memory.is_empty():
		var last: Rumor = member.long_term_memory.back()
		text += "\nLast: <%s, %s, %s>" % [member.describe_faction(last.actor_faction_id), last.tag, member.describe_faction(last.target_faction_id)]
	_label.text = text
	var faction := member.get_faction()
	if faction != null:
		_label.modulate = faction.color
