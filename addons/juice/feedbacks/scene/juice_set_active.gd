@tool
@icon("res://addons/juice/icons/scene.svg")
class_name JuiceSetActive
extends JuiceFeedback
## Switches nodes on or off at chosen moments: visibility, processing, or both.
##
## "Active" means visible and processing. "Inactive" means hidden and with processing
## disabled. Use the aspects to change only one of the two. Each moment (init, play,
## stop, reset, skip, end, player complete) can set ACTIVE, INACTIVE or TOGGLE, or leave
## the nodes alone. Reversed plays swap ACTIVE and INACTIVE unless
## [member ignore_play_direction] is on. Restoring puts every node back as it was found.

enum State { NO_CHANGE, ACTIVE, INACTIVE, TOGGLE }
enum Aspect { VISIBLE_AND_PROCESSING, VISIBLE, PROCESSING }

@export_group("Set Active")
## What "active" means.
@export var aspect: Aspect = Aspect.VISIBLE_AND_PROCESSING
## More nodes to change besides the target. Paths are relative to the player.
@export var extra_targets: Array[NodePath] = []
## Applies the chosen states as they are, also when the play is reversed.
@export var ignore_play_direction: bool = false
@export_group("States")
## Set when the player initializes. Initial values are read before this is applied.
@export var state_on_init: State = State.NO_CHANGE
## Set when the feedback plays.
@export var state_on_play: State = State.INACTIVE
## Set when the feedback is stopped.
@export var state_on_stop: State = State.NO_CHANGE
## Set when the player starts a new play.
@export var state_on_reset: State = State.NO_CHANGE
## Set when the player skips to the end.
@export var state_on_skip: State = State.NO_CHANGE
## Set when one run of the feedback ends (after the hold time of a repeat too).
@export var state_on_end: State = State.NO_CHANGE
## Set when the player has played all its feedbacks.
@export var state_on_player_complete: State = State.NO_CHANGE

# Each entry is [node, visible, process_mode].
var _initial: Array = []


func _has_randomness() -> bool:
	return false


func _on_initialize() -> void:
	_initial.clear()
	for node in _nodes():
		_initial.append([node, node.get("visible") if "visible" in node else true, node.process_mode])
	_apply_state(state_on_init)


func _on_play(_feedback_intensity: float) -> void:
	_apply_state(state_on_play)


func _on_finished() -> void:
	_apply_state(state_on_end)


func _on_stop() -> void:
	_apply_state(state_on_stop)


func _on_reset() -> void:
	_apply_state(state_on_reset)


func _on_skip_to_end() -> void:
	_apply_state(state_on_skip)


func _on_player_complete() -> void:
	_apply_state(state_on_player_complete)


func _on_restore() -> void:
	for entry: Array in _initial:
		var node: Node = entry[0]
		if not is_instance_valid(node):
			continue
		if "visible" in node:
			node.visible = entry[1]
		node.process_mode = entry[2]


func _nodes() -> Array[Node]:
	var list: Array[Node] = []
	var main := get_target()
	if main != null:
		list.append(main)
	for path in extra_targets:
		var extra := resolve(path)
		if extra != null and not list.has(extra):
			list.append(extra)
	return list


func _apply_state(state: State) -> void:
	if state == State.NO_CHANGE:
		return
	var nodes := _nodes()
	if nodes.is_empty():
		return
	for node in nodes:
		var wanted: bool
		match state:
			State.ACTIVE:
				wanted = true if ignore_play_direction or not is_reversed() else false
			State.INACTIVE:
				wanted = false if ignore_play_direction or not is_reversed() else true
			_:
				wanted = not _is_active(node)
		_set_active(node, wanted)


func _is_active(node: Node) -> bool:
	if aspect != Aspect.PROCESSING and "visible" in node:
		return node.visible
	return node.process_mode != Node.PROCESS_MODE_DISABLED


func _set_active(node: Node, active: bool) -> void:
	if aspect != Aspect.PROCESSING and "visible" in node:
		node.visible = active
	if aspect == Aspect.VISIBLE:
		return
	if not active:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		return
	# Back to what the node had at the start, unless that was already disabled.
	var original := Node.PROCESS_MODE_INHERIT
	for entry: Array in _initial:
		if entry[0] == node and entry[2] != Node.PROCESS_MODE_DISABLED:
			original = entry[2]
	node.process_mode = original
