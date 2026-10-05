extends QuestsTest
## Alerts must be shown exactly once, whichever way they are triggered.


class CountingAlertUI extends QuestAlertUI:
	var shown: Array = []

	func show_alert(message: String) -> void:
		shown.append(message)

	func show_alert_contents(quest_id: String, contents: Array[QuestContent]) -> void:
		shown.append(quest_id)


func _body(text: String) -> QuestBodyContent:
	var body := QuestBodyContent.new()
	body.text = text
	return body


func _contents(list: Array) -> Array[QuestContent]:
	var result: Array[QuestContent] = []
	result.assign(list)
	return result


func test_alert_message_shows_once_and_emits_manager_signal() -> void:
	var manager := make_manager()
	var ui := CountingAlertUI.new()
	manager.alert_ui = ui
	var displayer := QuestAlertDisplayer.new()
	add_node(displayer)
	var emitted := []
	manager.quest_alert.connect(func(quest_id: String, _contents: Array[QuestContent]) -> void: emitted.append(quest_id))
	QuestMessages.quest_alert(self, "q1", _contents([_body("hi")]))
	assert_eq(ui.shown.size(), 1, "shown once through the message")
	assert_eq(emitted, ["q1"], "manager emits quest_alert once")


func test_two_displayers_sharing_a_ui_show_once() -> void:
	var manager := make_manager()
	var ui := CountingAlertUI.new()
	manager.alert_ui = ui
	add_node(QuestAlertDisplayer.new())
	add_node(QuestAlertDisplayer.new())
	QuestMessages.quest_alert(self, "q1", _contents([_body("hi")]))
	assert_eq(ui.shown.size(), 1, "same alert isn't displayed twice")
	QuestMessages.quest_alert(self, "q1", _contents([_body("hi")]))
	assert_eq(ui.shown.size(), 2, "a second alert is displayed")


func test_alert_action_shows_once() -> void:
	var manager := make_manager()
	var ui := CountingAlertUI.new()
	manager.alert_ui = ui
	add_node(QuestAlertDisplayer.new())
	var action := QuestAlertAction.new()
	action.content_list = _contents([_body("hello")])
	var emitted := []
	manager.quest_alert.connect(func(quest_id: String, _contents: Array[QuestContent]) -> void: emitted.append(quest_id))
	action.execute()
	assert_eq(ui.shown.size(), 1, "alert action displays once")
	assert_eq(emitted.size(), 1, "alert action emits once")


func test_quest_control_alert_shows_once() -> void:
	var manager := make_manager()
	var ui := CountingAlertUI.new()
	manager.alert_ui = ui
	add_node(QuestAlertDisplayer.new())
	var control := QuestControl.new()
	add_node(control)
	control.show_alert("Found it")
	assert_eq(ui.shown, ["Found it"], "quest control shows text once")
