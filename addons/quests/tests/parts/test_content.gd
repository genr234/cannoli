extends QuestsTest


func before_each() -> void:
	make_manager()


func test_heading_content() -> void:
	var quest := PartsTestUtil.make_quest("q")
	quest.title = "Wolf Hunt"
	var heading := QuestHeadingContent.new()
	heading.text = "Chapter"
	heading.heading_level = 2
	heading.set_runtime_references(quest, null)
	assert_eq(heading.get_text(), "Chapter")
	assert_eq(heading.get_editor_name(), "Heading: Chapter")
	heading.use_quest_title = true
	assert_eq(heading.get_text(), "Wolf Hunt")
	assert_eq(heading.get_editor_name(), "Heading: <Quest Title>")
	var unassigned := QuestHeadingContent.new()
	unassigned.use_quest_title = true
	assert_eq(unassigned.get_original_text(), "Quest")


func test_body_content_replaces_tags() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var body := QuestBodyContent.new()
	body.text = "Quest {QUESTID} is on."
	body.set_runtime_references(quest, null)
	assert_eq(body.get_text(), "Quest q is on.")
	assert_eq(body.get_editor_name(), "Text: Quest {QUESTID} is on.")
	assert_eq(QuestBodyContent.new().get_editor_name(), "Body Text")


func test_icon_content() -> void:
	var icon := QuestIconContent.new()
	assert_eq(icon.get_editor_name(), "Icon")
	icon.caption = "Wolf pelts"
	icon.count = 3
	assert_eq(icon.get_editor_name(), "Icon: 3 Wolf pelts")
	assert_eq(icon.get_original_text(), "Wolf pelts")
	assert_eq(icon.get_images().size(), 0)
	icon.image = PlaceholderTexture2D.new()
	assert_eq(icon.get_images().size(), 1)
	assert_eq(icon.color, Color.WHITE)


func test_button_content_runs_actions() -> void:
	var quest := PartsTestUtil.make_quest("q", ["clicks"])
	quest.initialize()
	var action := QuestSetCounterAction.new()
	action.counter_name = "clicks"
	action.operation = QuestSetCounterAction.Operation.MODIFY_BY_VALUE
	action.operation_value = 1
	var button := QuestButtonContent.new()
	button.caption = "Accept"
	assert_false(button.interactable)
	button.action_list.append(action)
	button.set_runtime_references(quest, null)
	assert_true(button.interactable)
	assert_eq(button.group_number, QuestButtonContent.NO_GROUP)
	assert_eq(action.quest, quest, "propagates references to its actions")
	button.click()
	button.click()
	assert_eq(quest.get_counter("clicks").current_value, 2)
	assert_eq(button.get_editor_name(), "Button: Accept")


func test_link_content() -> void:
	var quest := PartsTestUtil.make_quest("q")
	var body := QuestBodyContent.new()
	body.text = "Linked text"
	quest.assign_content_id(body)
	quest.offer_content_list.append(body)
	var link := QuestLinkContent.new()
	assert_eq(link.get_editor_name(), "Link (unassigned)")
	link.linked_content_id = body.content_id
	quest.offer_content_list.append(link)
	quest.initialize()
	link.set_runtime_references(quest, null)
	assert_eq(link.get_linked_content(), body)
	assert_eq(link.get_editor_name(), "Linked to: Text: Linked text")
	assert_eq(link.get_original_text(), "Linked text")


func test_audio_content() -> void:
	var audio := QuestAudioContent.new()
	assert_eq(audio.get_editor_name(), "Audio Clip")
	assert_eq(audio.get_audio().size(), 0)
	audio.audio = AudioStreamWAV.new()
	assert_eq(audio.get_audio().size(), 1)
	assert_not_null(audio.use_audio_source_on)
	audio.text = "caption"
	assert_eq(audio.get_original_text(), "caption")
	audio.play()
	assert_true(true, "playing without a camera doesn't crash")
