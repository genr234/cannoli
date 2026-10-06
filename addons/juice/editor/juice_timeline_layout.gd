@tool
extends RefCounted
## Works out where each feedback of a player sits on the timeline.
##
## It follows the same walk as [method JuicePlayer.get_total_duration] but keeps the
## start of every feedback. Loops are shown as markers, only the first pass is drawn.


## Returns [code]{"rows": Array[Dictionary], "length": float}[/code]. Every row has:
## [code]skipped[/code], [code]start[/code], [code]delay[/code], [code]duration[/code], [code]gap[/code],
## [code]repeats[/code], [code]endless[/code], [code]pause[/code] (seconds, -1 for a script driven one),
## [code]is_pause[/code], [code]looper[/code], [code]loops[/code] (0 = endless).
static func compute(player: JuicePlayer) -> Dictionary:
	var list := player.feedbacks
	var rows: Array[Dictionary] = []
	for i in list.size():
		rows.append({"skipped": true, "start": 0.0, "delay": 0.0, "duration": 0.0, "gap": 0.0, "repeats": 0,
				"endless": false, "pause": 0.0, "is_pause": false, "looper": false, "loops": 1})
	var backward := player.direction == Juice.Direction.BACKWARD
	var step := -1 if backward else 1
	var head := list.size() - 1 if backward else 0
	var base := player.apply_time_multiplier(player.initial_delay)
	var time := 0.0
	var mark := 0.0
	var hold := 0.0
	var length := base
	while head >= 0 and head < list.size():
		var feedback := list[head]
		if feedback == null or not feedback.active or not _plays_in_direction(feedback, backward):
			head += step
			continue
		var row := rows[head]
		row.skipped = false
		if feedback._is_holding_pause() or feedback._is_looper():
			time = maxf(time, mark + hold)
			hold = 0.0
			mark = time
		var total := feedback.compute_total_duration(player)
		var duration := feedback.apply_time_multiplier(feedback._get_duration())
		row.start = base + time
		row.delay = feedback.apply_time_multiplier(feedback.initial_delay)
		row.duration = duration
		row.gap = feedback.apply_time_multiplier(feedback.delay_between_repeats)
		row.repeats = 0 if feedback.repeat_forever else feedback.repeats
		row.endless = feedback.repeat_forever
		length = maxf(length, base + time + total)
		if feedback._is_pause():
			row.is_pause = true
			row.pause = -1.0 if feedback._is_script_driven_pause() else feedback.get_pause_duration(player)
			var wait: float = feedback._get_auto_resume() if feedback._is_script_driven_pause() else row.pause
			time += wait
			length = maxf(length, base + time)
			mark = time
			hold = 0.0
		elif not feedback.exclude_from_holding_pauses:
			hold = maxf(hold, total)
		if feedback._is_looper():
			row.looper = true
			row.loops = feedback._get_loop_count()
		head += step
	return {"rows": rows, "length": length}


static func _plays_in_direction(feedback: JuiceFeedback, backward: bool) -> bool:
	match feedback.direction_condition:
		Juice.DirectionCondition.ONLY_FORWARD:
			return not backward
		Juice.DirectionCondition.ONLY_BACKWARD:
			return backward
	return true
