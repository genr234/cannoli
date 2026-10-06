@tool
extends AcceptDialog
## Lists the tags and messages the quest system understands, plus the open
## quest's counter tags. Clicking an entry copies it to the clipboard.


func _init() -> void:
	title = "Quest Reference"
	min_size = Vector2(520, 480)


## Rebuilds the pages for `quest` (may be null) and shows the dialog.
func show_reference(quest: Quest) -> void:
	for child in get_children():
		if child is TabContainer:
			remove_child(child)
			child.queue_free()
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(500, 400)
	tabs.add_child(_page("Tags", _tag_entries(quest)))
	tabs.add_child(_page("Messages", _message_entries()))
	add_child(tabs)
	popup_centered()


func _page(page_name: String, entries: Array) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = page_name
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = entry[1] + "\nClick to copy."
		button.pressed.connect(func() -> void: DisplayServer.clipboard_set(entry[0]))
		box.add_child(button)
	return scroll


func _tag_entries(quest: Quest) -> Array:
	var entries: Array = []
	var tags_script: GDScript = QuestTags
	var constants := tags_script.get_script_constant_map()
	for constant_name: String in constants:
		if constants[constant_name] is String and String(constants[constant_name]).begins_with("{"):
			entries.append([constants[constant_name], constant_name.capitalize()])
	if quest != null:
		for counter in quest.counter_list:
			if counter != null:
				entries.append(["{#%s}" % counter.name, "Value of counter " + counter.name])
				entries.append(["{<#%s}" % counter.name, "Minimum of counter " + counter.name])
				entries.append(["{>#%s}" % counter.name, "Maximum of counter " + counter.name])
				entries.append(["{:%s}" % counter.name, "Counter " + counter.name + " as a time"])
	return entries


func _message_entries() -> Array:
	var entries: Array = []
	var messages_script: GDScript = QuestMessages
	var constants := messages_script.get_script_constant_map()
	for constant_name: String in constants:
		if constants[constant_name] is String:
			entries.append([constants[constant_name], constant_name.capitalize()])
	return entries
