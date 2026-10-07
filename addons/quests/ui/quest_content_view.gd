@icon("../icons/quest_content.svg")
class_name QuestContentView
extends VBoxContainer
## Renders quest content to Controls: headings, body text, icons, buttons, links
## and audio.
##
## Consecutive icons are grouped into one flowing list and consecutive buttons into
## one button list, like the original content templates. Every content type can be
## replaced with a [PackedScene] template; templates fall back to built-in Controls.
##
## Template conventions: a template root may define [code]assign_text(text)[/code]
## (heading, body), [code]assign_icon(texture, count, caption, color)[/code]
## (icon) or [code]assign_button(texture, count, caption, color)[/code] (button).
## Without those methods, [Label]/[RichTextLabel]/[BaseButton] roots are filled
## directly, and icon templates may contain unique-named [code]%Icon[/code],
## [code]%Count[/code] and [code]%Caption[/code] nodes.

## Button group value meaning "not in a group".
const NO_GROUP := QuestButtonContent.NO_GROUP

## Emitted after a content button that belongs to a group was clicked.
signal group_button_clicked(group_number: int)

## Optional template for level 0 and 1 headings.
@export var heading_template: PackedScene
## Optional templates for heading levels 2, 3, ...
@export var subheading_templates: Array[PackedScene] = []
## Optional template for body text.
@export var body_template: PackedScene
## Optional container template for icon lists; icons are added to its root,
## or to its unique-named [code]%Items[/code] child.
@export var icon_list_template: PackedScene
## Optional template for a single icon.
@export var icon_template: PackedScene
## Optional container template for button lists.
@export var button_list_template: PackedScene
## Optional template for a single button.
@export var button_template: PackedScene
## Size of icons drawn by the built-in icon and button controls.
@export var icon_size := Vector2(32, 32)
## Color multiplier for text drawn as completed.
@export var completed_modulate := Color(0.7, 0.7, 0.7, 1.0)
## Play audio content.
@export var play_audio := true

var _current_icon_list: Container
var _current_button_list: Container
var _group_buttons: Array[Dictionary] = []


## Replaces the shown content.
func set_contents(contents: Array[QuestContent]) -> void:
	clear()
	add_contents(contents)


## Adds content after the existing content. If [param completed] is true, text is
## dimmed.
func add_contents(contents: Array[QuestContent], completed := false) -> void:
	if contents == null:
		return
	for content in contents:
		add_content(content, completed)


## Removes all content.
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_current_icon_list = null
	_current_button_list = null
	_group_buttons.clear()


## Ends the current icon and button lists, so the next icon or button starts a
## new list.
func end_lists() -> void:
	_current_icon_list = null
	_current_button_list = null


## Adds one content.
func add_content(content: QuestContent, completed := false) -> void:
	if content == null:
		return
	if content is QuestHeadingContent:
		add_heading(content.get_text(), content.heading_level, completed)
	elif content is QuestBodyContent:
		add_body(content.get_text(), completed)
	elif content is QuestButtonContent:
		_add_button_content(content)
	elif content is QuestIconContent:
		_add_icon_content(content)
	elif content is QuestAudioContent:
		_play_audio_content(content)
	elif content is QuestLinkContent:
		_add_link_content(content, completed)
	else:
		var text := content.get_text()
		if not text.is_empty():
			add_body(text, completed)


## Adds a heading. Levels 0 and 1 use the main heading; level 2 and up use the
## subheading templates (falling back to the main heading).
func add_heading(text: String, level := 1, completed := false) -> Control:
	var scene: PackedScene = heading_template
	var variation := &"QuestHeading"
	if level >= 2:
		var index := level - 2
		if index < subheading_templates.size() and subheading_templates[index] != null:
			scene = subheading_templates[index]
		variation = &"QuestSubheading" if level == 2 else &"QuestSubsubheading"
	var control: Control
	if scene != null:
		control = scene.instantiate() as Control
		_assign_text(control, text)
	else:
		var label := Label.new()
		label.theme_type_variation = variation
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control = label
	return _add_text_control(control, completed)


## Adds body text. BBCode is supported by the built-in control.
func add_body(text: String, completed := false) -> Control:
	var control: Control
	if body_template != null:
		control = body_template.instantiate() as Control
		_assign_text(control, text)
	else:
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.focus_mode = Control.FOCUS_NONE
		rich.text = text
		control = rich
	return _add_text_control(control, completed)


## Adds an icon to the current icon list, starting a new list if needed.
func add_icon(texture: Texture2D, count := 1, caption := "", color := Color.WHITE) -> Control:
	if _current_icon_list == null:
		_current_icon_list = _make_list(icon_list_template, true)
		add_child(_current_icon_list)
	_current_button_list = null
	var control: Control
	if icon_template != null:
		control = icon_template.instantiate() as Control
		if control.has_method("assign_icon"):
			control.call("assign_icon", texture, count, caption, color)
		else:
			_assign_icon_nodes(control, texture, count, caption, color)
	else:
		control = _build_icon(texture, count, caption, color)
	_list_target(_current_icon_list).add_child(control)
	return control


## Adds a button to the current button list, starting a new list if needed. A null
## [param callback] makes a disabled button, like the original. [param group_number]
## ties the button to a group; clicking one group button disables all its group.
func add_button(texture: Texture2D, count := 1, caption := "", color := Color.WHITE,
		callback: Callable = Callable(), group_number := NO_GROUP) -> BaseButton:
	if _current_button_list == null:
		_current_button_list = _make_list(button_list_template, false)
		add_child(_current_button_list)
	_current_icon_list = null
	var control: Control
	if button_template != null:
		control = button_template.instantiate() as Control
		if control.has_method("assign_button"):
			control.call("assign_button", texture, count, caption, color)
		elif control is Button:
			(control as Button).text = caption
			(control as Button).icon = texture
	else:
		control = _build_button(texture, count, caption, color)
	var button := control as BaseButton
	if button == null:
		var found := control.find_children("*", "BaseButton", true, false)
		if not found.is_empty():
			button = found[0] as BaseButton
	_list_target(_current_button_list).add_child(control)
	if button == null:
		push_warning("Quests: Button template has no BaseButton.")
		return null
	if callback.is_valid():
		button.pressed.connect(callback)
	else:
		button.disabled = true
	if group_number != NO_GROUP:
		_group_buttons.append({"button": button, "group": group_number})
	return button


## Adds a link-styled button that runs [param callback]. Not used for
## [QuestLinkContent], which shows the content it links to.
func add_link(text: String, callback: Callable) -> BaseButton:
	var link := LinkButton.new()
	link.text = text
	var control: Control = link
	_current_icon_list = null
	_current_button_list = null
	var button := control as BaseButton
	if button != null and callback.is_valid():
		button.pressed.connect(callback)
	add_child(control)
	return button


## Adds a checkable line for a quest objective, as returned by
## [method Quest.get_objectives].
func add_objective(objective: Dictionary) -> CheckBox:
	var box := CheckBox.new()
	box.text = QuestUIHelpers.format_objective(objective)
	box.set_pressed_no_signal(bool(objective.get("done", false)))
	box.focus_mode = Control.FOCUS_NONE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme_type_variation = &"QuestObjective"
	box.name = "Objective"
	_current_icon_list = null
	_current_button_list = null
	add_child(box)
	return box


## Adds the objective lines of [param quest].
func add_objectives(quest: Quest) -> void:
	for objective in quest.get_objectives():
		add_objective(objective)


## Adds a "Time remaining" line for a quest with a time limit.
func add_time_remaining(quest: Quest) -> Label:
	var label := Label.new()
	label.name = "TimeRemaining"
	label.text = QuestUIHelpers.format_time_remaining(quest)
	_current_icon_list = null
	_current_button_list = null
	add_child(label)
	return label


## True if any content in [param contents] is a button that belongs to a group.
static func contains_group_button(contents: Array[QuestContent]) -> bool:
	if contents == null:
		return false
	for content in contents:
		if content is QuestButtonContent and _group_of(content) != NO_GROUP:
			return true
	return false


## Disables every button belonging to [param group_number].
func disable_group_buttons(group_number: int) -> void:
	for entry in _group_buttons:
		var button := entry["button"] as BaseButton
		if entry["group"] == group_number and is_instance_valid(button):
			button.disabled = true


## The buttons currently shown (including template-made ones).
func get_buttons() -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for node in find_children("*", "BaseButton", true, false):
		result.append(node as BaseButton)
	return result


static func _group_of(content: QuestContent) -> int:
	var value: Variant = content.get("group_number")
	return int(value) if value != null else NO_GROUP


func _add_icon_content(content: QuestIconContent) -> void:
	var color := _get_color(content)
	add_icon(content.image, content.count, content.get_text(), color)


func _add_button_content(content: QuestButtonContent) -> void:
	var group := _group_of(content)
	var count := int(content.get("count")) if content.get("count") != null else 1
	add_button(content.image, count, content.get_text(), _get_color(content),
			_on_content_button_pressed.bind(content, group), group)


func _add_link_content(content: QuestLinkContent, completed := false) -> void:
	var linked := content.get_linked_content()
	if linked != null:
		add_content(linked, completed)


func _on_content_button_pressed(content: QuestButtonContent, group: int) -> void:
	content.click()
	if group != NO_GROUP:
		disable_group_buttons(group)
		group_button_clicked.emit(group)
		QuestMessages.send(self, null, QuestMessages.GROUP_BUTTON_CLICKED, "", [group])


func _play_audio_content(content: QuestAudioContent) -> void:
	if not play_audio or content.audio == null:
		return
	if content.use_audio_source_on != null and content.use_audio_source_on.find_host() != null:
		content.play()
		return
	var player := AudioStreamPlayer.new()
	player.stream = content.audio
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _get_color(content: QuestContent) -> Color:
	var value: Variant = content.get("color")
	return value if value is Color else Color.WHITE


func _add_text_control(control: Control, completed: bool) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if completed:
		control.modulate = completed_modulate
	_current_icon_list = null
	_current_button_list = null
	add_child(control)
	return control


func _assign_text(control: Control, text: String) -> void:
	if control.has_method("assign_text"):
		control.call("assign_text", text)
	elif control is RichTextLabel:
		(control as RichTextLabel).text = text
	elif control is Label:
		(control as Label).text = text
	elif control is BaseButton:
		(control as BaseButton).text = text
	else:
		var label := control.find_children("*", "Label", true, false)
		if not label.is_empty():
			(label[0] as Label).text = text


func _make_list(template: PackedScene, flow_horizontal: bool) -> Container:
	if template != null:
		var instance := template.instantiate() as Container
		if instance != null:
			return instance
	var list: Container
	if flow_horizontal:
		list = HFlowContainer.new()
		list.name = "IconList"
	else:
		list = VBoxContainer.new()
		list.name = "ButtonList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list


func _list_target(list: Container) -> Node:
	var items := list.get_node_or_null("%Items")
	return items if items != null else list


func _build_icon(texture: Texture2D, count: int, caption: String, color: Color) -> Control:
	var box := HBoxContainer.new()
	box.name = "Icon"
	var rect := TextureRect.new()
	rect.name = "Icon"
	rect.unique_name_in_owner = false
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = icon_size
	rect.texture = texture
	rect.modulate = color
	rect.visible = texture != null
	box.add_child(rect)
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.text = str(count)
	count_label.visible = count > 1
	box.add_child(count_label)
	var caption_label := Label.new()
	caption_label.name = "Caption"
	caption_label.text = caption
	caption_label.visible = not caption.is_empty()
	box.add_child(caption_label)
	return box


func _assign_icon_nodes(control: Control, texture: Texture2D, count: int, caption: String, color: Color) -> void:
	var rect := control.find_child("Icon", true, false) as TextureRect
	if rect != null:
		rect.texture = texture
		rect.modulate = color
	var count_label := control.find_child("Count", true, false) as Label
	if count_label != null:
		count_label.text = str(count)
		count_label.visible = count > 1
	var caption_label := control.find_child("Caption", true, false) as Label
	if caption_label != null:
		caption_label.text = caption
		caption_label.visible = not caption.is_empty()


func _build_button(texture: Texture2D, count: int, caption: String, color: Color) -> Control:
	var button := Button.new()
	button.name = "Button"
	button.text = caption if count <= 1 else "%s x%d" % [caption, count]
	button.icon = texture
	button.expand_icon = texture != null
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", int(icon_size.x))
	button.modulate = color
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
