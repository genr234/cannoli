extends QuestsTest
## Tests for the default quest UIs, built headless from their scenes.

const UI_DIR := "res://addons/quests/ui/"

var _journal: QuestJournal
var _clicks := 0


class CountingAction extends QuestAction:
	var target: Object

	func execute() -> void:
		target.set("_clicks", int(target.get("_clicks")) + 1)


func before_each() -> void:
	_journal = QuestJournal.new()
	_journal.id = "player"
	add_node(_journal)
	_clicks = 0


func _scene(file: String) -> Node:
	var node := (load(UI_DIR + file) as PackedScene).instantiate()
	add_node(node)
	return node


func _body(text: String) -> QuestBodyContent:
	var body := QuestBodyContent.new()
	body.text = text
	return body


func _heading(text: String, level := 1) -> QuestHeadingContent:
	var heading := QuestHeadingContent.new()
	heading.text = text
	heading.heading_level = level
	return heading


func _contents(list: Array) -> Array[QuestContent]:
	var result: Array[QuestContent] = []
	result.assign(list)
	return result


func _quest(id: String, title: String, group := "", state := Quest.State.ACTIVE, setup := Callable()) -> Quest:
	var asset := Quest.new()
	asset.id = id
	asset.title = title
	asset.group = group
	QuestStateInfo.validate_list(asset.state_info_list, 6)
	if setup.is_valid():
		setup.call(asset)
	var instance := _journal.add_quest(asset)
	instance.set_state(state)
	return instance


func _label_texts(node: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for child in node.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	for child in node.find_children("*", "RichTextLabel", true, false):
		texts.append((child as RichTextLabel).get_parsed_text())
	for child in node.find_children("*", "CheckBox", true, false):
		texts.append((child as CheckBox).text)
	return texts


func _find_button(node: Node, text: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if (button as Button).text == text and button.is_visible_in_tree():
			return button as Button
	return null


func test_content_view_renders_each_type() -> void:
	var view := QuestContentView.new()
	add_node(view)
	var icon := QuestIconContent.new()
	icon.caption = "Wolf pelt"
	icon.count = 3
	var icon2 := QuestIconContent.new()
	icon2.caption = "Coin"
	var button := QuestButtonContent.new()
	button.caption = "Do it"
	var action := CountingAction.new()
	action.target = self
	button.action_list.append(action)
	view.set_contents(_contents([_heading("Big"), _heading("Small", 2), _body("[b]Bold[/b] text"), icon, icon2, button]))
	var texts := _label_texts(view)
	assert_true(texts.has("Big") and texts.has("Small"), "headings rendered")
	assert_true(texts.has("Bold text"), "body rendered through BBCode")
	assert_true(texts.has("Wolf pelt") and texts.has("3"), "icon caption and count rendered")
	var lists := view.find_children("IconList", "", true, false)
	assert_eq(lists.size(), 1, "consecutive icons share one list")
	var rendered_button := _find_button(view, "Do it")
	assert_true(rendered_button != null, "button rendered")
	rendered_button.pressed.emit()
	assert_eq(_clicks, 1, "button runs its actions")


func test_content_view_group_buttons_disable_together() -> void:
	var view := QuestContentView.new()
	add_node(view)
	var list: Array[QuestContent] = []
	for caption in ["A", "B"]:
		var button := QuestButtonContent.new()
		button.caption = caption
		button.group_number = 4
		var action := CountingAction.new()
		action.target = self
		button.action_list.append(action)
		list.append(button)
	view.set_contents(list)
	assert_true(QuestContentView.contains_group_button(list), "group button detected")
	_find_button(view, "A").pressed.emit()
	assert_true(_find_button(view, "B").disabled, "other button of the group is disabled")


func test_content_view_template_override() -> void:
	var scene := PackedScene.new()
	var label := Label.new()
	label.name = "Custom"
	scene.pack(label)
	label.free()
	var view := QuestContentView.new()
	view.heading_template = scene
	add_node(view)
	view.set_contents(_contents([_heading("Hi")]))
	assert_true(view.get_child(0).name == "Custom" and (view.get_child(0) as Label).text == "Hi", "heading template used")


func test_journal_lists_active_before_completed_in_groups() -> void:
	_quest("a", "Alpha", "Main", Quest.State.SUCCESSFUL)
	_quest("b", "Beta", "Main", Quest.State.ACTIVE)
	_quest("c", "Gamma", "", Quest.State.ACTIVE)
	_quest("d", "Delta", "", Quest.State.WAITING_TO_START)
	var ui := _scene("quest_journal_ui.tscn") as QuestDefaultJournalUI
	ui.open(_journal)
	var rows := ui.selection_container.find_children("*", "HBoxContainer", true, false).filter(
			func(n: Node) -> bool: return n is QuestNameButton)
	var names: Array[String] = []
	for row in rows:
		names.append((row as QuestNameButton).name_button.text)
	assert_eq(names, ["Beta", "Alpha", "Gamma"], "active quests first inside a group; waiting quests hidden")
	var foldouts := ui.selection_container.get_children().filter(func(n: Node) -> bool: return n is QuestFoldout)
	assert_eq(foldouts.size(), 1, "one group foldout")
	ui.show_completed_quests = false
	ui.refresh_now()
	names.clear()
	for row in ui.selection_container.find_children("*", "HBoxContainer", true, false):
		if row is QuestNameButton:
			names.append((row as QuestNameButton).name_button.text)
	assert_eq(names, ["Beta", "Gamma"], "completed quests can be hidden")


func test_journal_select_shows_details_and_toggles() -> void:
	var quest := _quest("a", "Alpha", "", Quest.State.ACTIVE, func(q: Quest) -> void:
		q.is_abandonable = true
		q.remember_if_abandoned = true
		q.state_info_list[Quest.State.ACTIVE].journal_content.append(_body("Kill the wolves")))
	var ui := _scene("quest_journal_ui.tscn") as QuestDefaultJournalUI
	ui.show_track_button_in_details = true
	ui.open(_journal)
	assert_true(ui.is_group_expanded("x"), "unknown groups start expanded")
	ui.select_quest(quest)
	assert_true(_label_texts(ui.details).has("Kill the wolves"), "details show journal content")
	assert_true(ui.track_button.visible and ui.abandon_button.visible, "track and abandon buttons shown")
	ui.track_button.button_pressed = false
	assert_true(not quest.show_in_track_hud, "track toggle updates the quest")
	ui.open_abandon_quest_confirmation_dialog()
	assert_true(ui.abandon_panel.visible, "abandon confirmation opens")
	ui.confirm_abandon_quest()
	assert_eq(quest.get_state(), Quest.State.ABANDONED, "confirming abandons the quest")
	assert_true(not ui.abandon_panel.visible, "confirmation closes")


func test_journal_cancel_closes_and_foldouts_toggle() -> void:
	_quest("a", "Alpha", "Main")
	var ui := _scene("quest_journal_ui.tscn") as QuestDefaultJournalUI
	ui.toggle(_journal)
	assert_true(ui.is_open, "toggle opens")
	ui.toggle_group("Main")
	assert_true(not ui.is_group_expanded("Main"), "group collapses")
	ui.always_expand_all_groups = true
	assert_true(ui.is_group_expanded("Main"), "always expand wins")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	ui._unhandled_input(cancel)
	assert_true(not ui.is_open, "ui_cancel closes")


func test_hud_shows_only_tracked_quests_and_objectives() -> void:
	var wolves := QuestCounter.create("wolves", 0, 0, 5)
	wolves.display_name = "Wolves slain"
	_quest("a", "Hunt", "", Quest.State.ACTIVE, func(q: Quest) -> void:
		q.counter_list.append(wolves))
	_quest("b", "Hidden", "", Quest.State.ACTIVE, func(q: Quest) -> void:
		q.show_in_track_hud = false
		q.state_info_list[Quest.State.ACTIVE].hud_content.append(_body("should not show")))
	_quest("c", "Authored", "", Quest.State.ACTIVE, func(q: Quest) -> void:
		q.state_info_list[Quest.State.ACTIVE].hud_content.append(_body("authored line")))
	var hud := _scene("quest_hud.tscn") as QuestDefaultHUD
	hud.open(_journal)
	hud.refresh_now()
	var texts := _label_texts(hud.content_view)
	assert_true(texts.has("Hunt"), "objective quest title shown")
	assert_true(texts.has("Wolves slain 0/5"), "objective line shown: %s" % [texts])
	assert_true(texts.has("authored line"), "authored HUD content shown")
	assert_true(not texts.has("should not show"), "untracked quest hidden")
	assert_true(not texts.has("Authored"), "no objectives when HUD content exists")
	var quest := _journal.find_quest("a")
	quest.get_counter("wolves").set_value(5)
	hud.refresh_now()
	var boxes := hud.content_view.find_children("Objective", "CheckBox", true, false)
	assert_true(boxes.size() == 1 and (boxes[0] as CheckBox).button_pressed, "completed objective is checked")


func test_hud_time_remaining_and_hide_when_empty() -> void:
	var quest := _quest("a", "Timed", "", Quest.State.ACTIVE, func(q: Quest) -> void:
		q.time_limit = 90.0)
	quest.time_remaining = 83.0
	var hud := _scene("quest_hud.tscn") as QuestDefaultHUD
	hud.hide_if_no_tracked_quests = true
	hud.open(_journal)
	hud.refresh_now()
	var found := false
	for text in _label_texts(hud.content_view):
		found = found or text.begins_with("Time remaining")
	assert_true(found, "time remaining line shown")
	quest.show_in_track_hud = false
	hud.repaint(_journal)
	assert_true(hud.modulate.a == 0.0, "HUD hidden when no quest is tracked")


func test_dialogue_offer_handlers() -> void:
	var quest := _quest("a", "Alpha", "", Quest.State.WAITING_TO_START, func(q: Quest) -> void:
		q.offer_content_list.append(_body("Will you help?")))
	var ui := _scene("quest_dialogue_ui.tscn") as QuestDefaultDialogueUI
	var accepted: Array[Quest] = []
	var declined: Array[Quest] = []
	var speaker := QuestParticipant.new("npc", "Old Man")
	ui.show_offer_quest(speaker, quest, func(q: Quest) -> void: accepted.append(q), func(q: Quest) -> void: declined.append(q))
	assert_true(ui.is_open, "dialogue opens")
	assert_eq(ui.speaker_name.text, "Old Man", "speaker name shown")
	assert_true(_label_texts(ui.content_view).has("Will you help?"), "offer content shown")
	assert_true(ui.accept_button.visible and ui.decline_button.visible and not ui.close_button.visible, "accept/decline visible")
	ui.accept_button.pressed.emit()
	ui.decline_button.pressed.emit()
	assert_eq(accepted, [quest], "accept handler called with quest")
	assert_eq(declined, [quest], "decline handler called with quest")


func test_dialogue_quest_list_back_and_close() -> void:
	var a := _quest("a", "Alpha", "", Quest.State.ACTIVE)
	var b := _quest("b", "Beta", "", Quest.State.WAITING_TO_START)
	var ui := _scene("quest_dialogue_ui.tscn") as QuestDefaultDialogueUI
	var chosen: Array[Quest] = []
	var none: Array[QuestContent] = []
	var actives: Array[Quest] = [a]
	var offers: Array[Quest] = [b]
	ui.show_quest_list(null, _contents([_heading("Active")]), actives, none, offers,
			func(q: Quest) -> void: chosen.append(q))
	_find_button(ui.content_view, "Beta").pressed.emit()
	assert_eq(chosen, [b], "select handler called with chosen quest")
	assert_eq(ui.content_view.get_children().filter(func(n: Node) -> bool: return n is VBoxContainer).size(), 2, "active and offerable lists are separate")
	var backed: Array[Quest] = []
	ui.show_active_quest(null, a, Callable(), func(q: Quest) -> void: backed.append(q))
	assert_true(ui.back_button.visible, "back button shown with a back handler")
	ui.back_button.pressed.emit()
	assert_eq(backed, [a], "back handler called")
	var closed: Array[bool] = []
	ui.closed.connect(func() -> void: closed.append(true))
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	ui._unhandled_input(cancel)
	assert_true(not ui.is_open and closed.size() == 1, "ui_cancel closes and emits closed")


func test_alert_queue_order_and_hide() -> void:
	var ui := _scene("quest_alert_ui.tscn") as QuestDefaultAlertUI
	ui.queue_alerts = true
	ui.min_display_duration = 0.05
	var shown: Array[String] = []
	ui.alert_shown.connect(func() -> void:
		shown.append(_label_texts(ui.content_container)[-1]))
	ui.show_alert("one")
	ui.show_alert("two")
	ui.show_alert("three")
	assert_eq(ui.get_alert_count(), 1, "only one alert at a time while queueing")
	assert_eq(ui.get_queued_count(), 2, "others are queued")
	await root.get_tree().create_timer(0.5).timeout
	assert_eq(shown, ["one", "two", "three"], "alerts show in queue order")
	assert_true(not ui.visible and ui.get_alert_count() == 0, "UI hides after the last alert")


func test_alert_contents_use_container_and_duration() -> void:
	var ui := _scene("quest_alert_ui.tscn") as QuestDefaultAlertUI
	ui.min_display_duration = 0.05
	ui.show_alert_contents("q", _contents([_heading("Quest started"), _body("Find the wolves")]))
	assert_true(ui.content_container.get_child(0) is PanelContainer, "several contents use the container")
	assert_true(_label_texts(ui).has("Find the wolves"), "alert body shown")
	ui.chars_per_sec_duration = 10
	assert_eq(ui.get_display_duration_for_text("x".repeat(20)), 2.0, "duration scales with text length")
	await root.get_tree().create_timer(0.3).timeout
	assert_eq(ui.get_alert_count(), 0, "alert despawns")


func test_ui_root_and_input_action() -> void:
	var ui := _scene("quest_ui.tscn") as QuestUIRoot
	assert_true(ui.dialogue_ui != null and ui.journal_ui != null and ui.hud != null and ui.alert_ui != null, "root contains all four UIs")
	assert_true(InputMap.has_action(QuestUIHelpers.TOGGLE_JOURNAL_ACTION), "toggle journal action registered")
	assert_true(not ui.journal_ui.is_open and not ui.dialogue_ui.is_open, "journal and dialogue start closed")


func test_alert_displayer_shows_alert_messages() -> void:
	var ui := _scene("quest_ui.tscn") as QuestUIRoot
	ui.alert_ui.min_display_duration = 0.05
	QuestMessages.quest_alert(self, "q", _contents([_body("Hello alert")]))
	assert_true(_label_texts(ui.alert_ui).has("Hello alert"), "alert message shown through the displayer")
	await root.get_tree().create_timer(0.3).timeout
