@tool
extends RefCounted
## Editor previews that the player itself does not offer.


## Plays one feedback of [param player] alone, on a short lived copy of the player that sits
## next to it (so relative target paths keep working). Everything is restored when it ends.
static func play_only(player: JuicePlayer, feedback: JuiceFeedback) -> JuicePlayer:
	var parent := player.get_parent()
	if parent == null or not player.is_inside_tree():
		push_warning("Juice: put the player under another node to preview a single feedback.")
		return null
	var copy := feedback.duplicate() as JuiceFeedback
	copy.active = true
	copy.direction_condition = Juice.DirectionCondition.ALWAYS
	var solo := player.duplicate() as JuicePlayer
	solo.name = &"JuicePreviewSolo"
	var list: Array[JuiceFeedback] = [copy]
	solo.feedbacks = list
	solo.initial_delay = 0.0
	solo.direction = Juice.Direction.FORWARD
	parent.add_child(solo)
	solo.finished.connect(_end.bind(solo), CONNECT_ONE_SHOT)
	solo.stopped.connect(_end.bind(solo), CONNECT_ONE_SHOT)
	if not solo.play():
		_end(solo)
		return null
	return solo


## Plays the whole list backwards once, then puts the exported direction back.
static func play_reversed(player: JuicePlayer) -> void:
	var original := player.direction
	var restore := func() -> void:
		if is_instance_valid(player):
			player.direction = original
	player.finished.connect(restore, CONNECT_ONE_SHOT)
	player.stopped.connect(restore, CONNECT_ONE_SHOT)
	if not player.play_reversed():
		restore.call()
		return


static func _end(solo: JuicePlayer) -> void:
	if not is_instance_valid(solo) or solo.is_queued_for_deletion():
		return
	solo.restore_initial_values()
	solo.queue_free()
