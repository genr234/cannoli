class_name QuestAnimationAction
extends QuestAction
## Controls an [AnimationPlayer] or [AnimationTree]. The original's Animator action.
##
## [AnimationTree] parameters are addressed without the "parameters/" prefix, for
## example "OneShot/request" or "blend_amount".

enum AnimationControl {
	## Plays an animation (AnimationPlayer) or travels to a state (AnimationTree).
	## The float value is the blend time.
	PLAY,
	## Fires a one-shot request on an AnimationTree.
	SET_TRIGGER,
	## Sets a boolean AnimationTree parameter.
	SET_BOOL,
	## Sets a float AnimationTree parameter.
	SET_FLOAT,
	## Stops the AnimationPlayer.
	STOP,
}

## Group name, [QuestIdentity] id or node name of the node that has the animation player or tree.
@export var target_node := ""
## How to control the animation.
@export var action := AnimationControl.PLAY
## Animation, state or parameter to control.
@export var target := ""
@export var bool_value := false
@export var float_value := 0.0


func get_editor_name() -> String:
	if target_node.is_empty():
		return "Control Animation"
	match action:
		AnimationControl.PLAY:
			return "Animation on %s: Play %s" % [target_node, target]
		AnimationControl.SET_TRIGGER:
			return "Animation on %s: Set %s" % [target_node, target]
		AnimationControl.SET_BOOL:
			return "Animation on %s: Set %s to %s" % [target_node, target, str(bool_value)]
		AnimationControl.SET_FLOAT:
			return "Animation on %s: Set %s to %s" % [target_node, target, str(float_value)]
		AnimationControl.STOP:
			return "Animation on %s: Stop" % target_node
	return "Animation on %s: Action not set yet" % target_node


func execute() -> void:
	if target_node.is_empty() or (target.is_empty() and action != AnimationControl.STOP):
		return
	var nodes := QuestSceneLookup.find_nodes(target_node)
	if nodes.is_empty():
		if Quests.debug:
			push_warning("Quests: QuestAnimationAction can't find '%s'." % target_node)
		return
	for node in nodes:
		_control(node)


func _control(node: Node) -> void:
	var player := QuestSceneLookup.find_first_of(node, ["AnimationPlayer"]) as AnimationPlayer
	var tree := QuestSceneLookup.find_first_of(node, ["AnimationTree"]) as AnimationTree
	match action:
		AnimationControl.PLAY:
			if player != null and player.has_animation(target):
				player.play(target, float_value)
			elif tree != null:
				var playback: Variant = tree.get("parameters/playback")
				if playback is AnimationNodeStateMachinePlayback:
					playback.travel(target)
				else:
					_warn_missing(node, "state machine")
			else:
				_warn_missing(node, "AnimationPlayer with animation '%s'" % target)
		AnimationControl.STOP:
			if player != null:
				player.stop()
			else:
				_warn_missing(node, "AnimationPlayer")
		AnimationControl.SET_TRIGGER:
			if tree != null:
				var path := _parameter_path(target)
				if not path.ends_with("/request"):
					path += "/request"
				tree.set(path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			else:
				_warn_missing(node, "AnimationTree")
		AnimationControl.SET_BOOL:
			if tree != null:
				tree.set(_parameter_path(target), bool_value)
			else:
				_warn_missing(node, "AnimationTree")
		AnimationControl.SET_FLOAT:
			if tree != null:
				tree.set(_parameter_path(target), float_value)
			else:
				_warn_missing(node, "AnimationTree")


func _parameter_path(name: String) -> String:
	return name if name.begins_with("parameters/") else "parameters/" + name


func _warn_missing(node: Node, what: String) -> void:
	if Quests.debug:
		push_warning("Quests: QuestAnimationAction: '%s' doesn't have a %s." % [node.name, what])
