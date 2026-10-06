@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceListener
extends Node
## Listens for an event sent by [JuiceBroadcast], and reacts.
##
## It emits [signal received] and can play a [JuicePlayer]. It replaces event and radio
## receivers: put one in a scene, give it an event name (and a channel if you use
## channels), and connect the signal. It does nothing in the editor.

## Which parts of an event are accepted.
enum Phase { ALL, PLAY, PROGRESS, STOP }

## Emitted for every accepted event. [param value] is the float of the broadcast and
## [param payload] holds everything else (see [JuiceBroadcast]).
signal received(value: float, payload: Dictionary)

## The event name to listen to.
@export var event_name: StringName = &"juice_event"
## Hears the event on every channel.
@export var all_channels: bool = true:
	set(value):
		all_channels = value
		notify_property_list_changed()
## The channel number to listen to when [member all_channels] is off.
@export var channel: int = 0
## A channel resource to listen to. It wins over [member channel] when set.
@export var channel_resource: JuiceChannel
## Which parts of a broadcast are accepted.
@export var phase: Phase = Phase.ALL
## Ignores events that are further away than their range allows.
@export var respect_range: bool = true
## A player to play when an event is accepted. Path is relative to this node.
@export var play_player: NodePath
## Passes the broadcast value to the player as its intensity scale.
@export var value_as_intensity: bool = false


func _validate_property(property: Dictionary) -> void:
	if property.name in ["channel", "channel_resource"] and all_channels:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		_register()


func _exit_tree() -> void:
	Juice.unlisten(event_name, _on_event)


## Starts listening again after [member event_name] or the channel changed in code.
func refresh() -> void:
	Juice.unlisten(event_name, _on_event)
	if is_inside_tree() and not Engine.is_editor_hint():
		_register()


func _register() -> void:
	var listened: Variant = null
	if not all_channels:
		listened = channel_resource if channel_resource != null else channel
	Juice.listen(event_name, listened, _on_event)


func _on_event(payload: Dictionary) -> void:
	if not _accepts(payload.get("phase", &"play")):
		return
	var reach := 1.0
	if respect_range:
		var spatial := _find_spatial()
		if spatial != null:
			reach = Juice.get_range_multiplier(payload, Juice.node_position(spatial))
		if reach <= 0.0:
			return
	var sent: float = payload.get("value", 0.0)
	received.emit(sent, payload)
	var target := get_node_or_null(play_player) as JuicePlayer
	if target != null:
		var scale := reach * (sent if value_as_intensity else 1.0)
		target.play(payload.get("position", null), scale)


func _accepts(sent_phase: StringName) -> bool:
	match phase:
		Phase.PLAY:
			return sent_phase == &"play"
		Phase.PROGRESS:
			return sent_phase == &"progress"
		Phase.STOP:
			return sent_phase == &"stop"
	return true


# The first node from here upward that has a position. Without one, range is ignored.
func _find_spatial() -> Node:
	var node: Node = self
	while node != null:
		if node is Node2D or node is Node3D or node is Control:
			return node
		node = node.get_parent()
	return null
