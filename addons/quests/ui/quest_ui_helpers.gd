class_name QuestUIHelpers
extends RefCounted
## Static helpers shared by the quest UIs.

## Action name of the journal toggle hint. Registered at runtime if missing.
const TOGGLE_JOURNAL_ACTION := &"quests_toggle_journal"


## Registers [constant TOGGLE_JOURNAL_ACTION] (J key and the gamepad back button)
## if the project hasn't defined it. Project settings files are not modified.
static func ensure_input_actions() -> void:
	if InputMap.has_action(TOGGLE_JOURNAL_ACTION):
		return
	InputMap.add_action(TOGGLE_JOURNAL_ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	InputMap.action_add_event(TOGGLE_JOURNAL_ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(TOGGLE_JOURNAL_ACTION, pad)


## The quest's title with tags replaced and translated.
static func get_title(quest: Quest) -> String:
	if quest == null:
		return ""
	return QuestTags.replace_tags(quest.title, quest)


## True for SUCCESSFUL, FAILED and ABANDONED.
static func is_completed_state(state: Quest.State) -> bool:
	return state == Quest.State.SUCCESSFUL or state == Quest.State.FAILED or state == Quest.State.ABANDONED


## Whether [param quest] is shown in a HUD with the given visibility options.
static func is_hud_visible_quest(quest: Quest, show_active: bool, show_successful: bool, show_failed: bool) -> bool:
	if quest == null or not quest.show_in_track_hud:
		return false
	var state := quest.get_state()
	return (state == Quest.State.ACTIVE and show_active) \
			or (state == Quest.State.SUCCESSFUL and show_successful) \
			or (state == Quest.State.FAILED and show_failed)


## HUD content of a quest: its current state's HUD content, then the HUD content of
## each node. Returns pairs of [code]{"contents": Array[QuestContent], "active": bool}[/code].
static func get_hud_content_groups(quest: Quest) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var info := quest.get_state_info(quest.get_state())
	if info != null:
		groups.append({"contents": info.get_content_list(QuestContent.Category.HUD),
				"active": quest.get_state() == Quest.State.ACTIVE})
	for node in quest.node_list:
		if node == null:
			continue
		groups.append({"contents": node.get_content_list(QuestContent.Category.HUD),
				"active": node.get_state() == QuestNode.State.ACTIVE})
	return groups


## True if the quest has any HUD content.
static func has_hud_content(quest: Quest) -> bool:
	for group: Dictionary in get_hud_content_groups(quest):
		if not (group["contents"] as Array).is_empty():
			return true
	return false


## True if auto objectives should be drawn for [param quest]: the quest enables
## them, it has objectives, and no HUD/journal content was authored.
static func wants_objectives(quest: Quest, has_authored_content: bool) -> bool:
	if quest == null or not quest.auto_objectives or has_authored_content:
		return false
	return not quest.get_objectives().is_empty()


## True if a "time remaining" line applies to the quest.
static func wants_time_remaining(quest: Quest) -> bool:
	return quest != null and quest.time_limit > 0.0 and quest.get_state() == Quest.State.ACTIVE


## "Time remaining: 1:23" text for a quest.
static func format_time_remaining(quest: Quest) -> String:
	return "%s: %s" % [tr_static("Time remaining"), QuestTags.seconds_to_time_string(ceili(maxf(0.0, quest.time_remaining)))]


## "Wolves slain 3/5" text for an objective dictionary from [method Quest.get_objectives].
static func format_objective(objective: Dictionary) -> String:
	return str(objective.get("text", ""))


static func tr_static(text: String) -> String:
	return TranslationServer.translate(text)
