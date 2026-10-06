@tool
extends RefCounted
## Edits the feedback list of one player, with undo and redo.

## Feedbacks copied with "Copy". Shared by every player in the editor session.
static var clipboard: Array[JuiceFeedback] = []

var player: JuicePlayer
var undo_redo: EditorUndoRedoManager


func _init(target_player: JuicePlayer, undo_redo_manager: EditorUndoRedoManager) -> void:
	player = target_player
	undo_redo = undo_redo_manager


## Adds a new feedback of the given script at the end, or after [param after_index].
func add(script: Script, after_index: int = -1) -> JuiceFeedback:
	var feedback := script.new() as JuiceFeedback
	if feedback == null:
		return null
	var list: Array[JuiceFeedback] = player.feedbacks.duplicate()
	list.insert(list.size() if after_index < 0 else after_index + 1, feedback)
	_commit("Add Feedback", list, [feedback])
	return feedback


func remove(index: int) -> void:
	if index < 0 or index >= player.feedbacks.size():
		return
	var list: Array[JuiceFeedback] = player.feedbacks.duplicate()
	list.remove_at(index)
	_commit("Remove Feedback", list)


func move(index: int, offset: int) -> void:
	var target := index + offset
	if index < 0 or target < 0 or index >= player.feedbacks.size() or target >= player.feedbacks.size():
		return
	var list: Array[JuiceFeedback] = player.feedbacks.duplicate()
	var feedback: JuiceFeedback = list[index]
	list.remove_at(index)
	list.insert(target, feedback)
	_commit("Move Feedback", list)


func duplicate_at(index: int) -> void:
	if index < 0 or index >= player.feedbacks.size() or player.feedbacks[index] == null:
		return
	var copy := player.feedbacks[index].duplicate(true) as JuiceFeedback
	var list: Array[JuiceFeedback] = player.feedbacks.duplicate()
	list.insert(index + 1, copy)
	_commit("Duplicate Feedback", list, [copy])


func set_active(feedback: JuiceFeedback, value: bool) -> void:
	if feedback == null or feedback.active == value:
		return
	if undo_redo == null:
		feedback.active = value
		return
	undo_redo.create_action("Toggle Feedback", UndoRedo.MERGE_DISABLE, player)
	undo_redo.add_do_property(feedback, &"active", value)
	undo_redo.add_undo_property(feedback, &"active", feedback.active)
	undo_redo.commit_action()


func clear() -> void:
	if player.feedbacks.is_empty():
		return
	var list: Array[JuiceFeedback] = []
	_commit("Clear Feedbacks", list)


## Remembers copies of the feedbacks at [param indices] (all of them when empty).
func copy(indices: Array[int] = []) -> int:
	clipboard = []
	for i in player.feedbacks.size():
		var feedback := player.feedbacks[i]
		if feedback != null and (indices.is_empty() or i in indices):
			clipboard.append(feedback.duplicate(true) as JuiceFeedback)
	return clipboard.size()


## Adds copies of the clipboard, or replaces the whole list with them.
func paste(replace: bool = false) -> void:
	if clipboard.is_empty():
		return
	var added: Array[JuiceFeedback] = []
	for feedback in clipboard:
		added.append(feedback.duplicate(true) as JuiceFeedback)
	_apply_copies("Paste Feedbacks", added, replace)


func save_preset(path: String) -> Error:
	var preset := JuicePreset.new()
	var list: Array[JuiceFeedback] = []
	for feedback in player.feedbacks:
		if feedback != null:
			list.append(feedback.duplicate(true) as JuiceFeedback)
	preset.feedbacks = list
	return ResourceSaver.save(preset, path)


## Loads a [JuicePreset] file into the list. Returns false when the file is not a preset.
func load_preset(path: String, replace: bool = false) -> bool:
	var preset := load(path) as JuicePreset
	if preset == null:
		return false
	apply_preset(preset, replace)
	return true


func apply_preset(preset: JuicePreset, replace: bool = false) -> void:
	_apply_copies("Load Preset", preset.make_copies(), replace)


## Asks for a file and saves the list there as a [JuicePreset].
func ask_save_preset() -> void:
	var dialog := _make_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE, "Save Feedbacks as Preset")
	dialog.current_file = "new_preset.tres"
	dialog.file_selected.connect(_on_save_path)


## Asks for a preset file and loads it into the list.
func ask_load_preset(replace: bool) -> void:
	var dialog := _make_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, "Load Preset (Replace)" if replace else "Load Preset (Add)")
	dialog.file_selected.connect(_on_load_path.bind(replace))


func _make_dialog(mode: EditorFileDialog.FileMode, title: String) -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.file_mode = mode
	dialog.title = title
	dialog.filters = PackedStringArray(["*.tres, *.res ; Juice preset"])
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free.call_deferred())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()
	return dialog


func _on_save_path(path: String) -> void:
	var error := save_preset(path)
	if error != OK:
		push_error("Juice: could not save the preset to %s (%s)." % [path, error_string(error)])
		return
	EditorInterface.get_resource_filesystem().update_file(path)


func _on_load_path(path: String, replace: bool) -> void:
	if not load_preset(path, replace):
		push_error("Juice: %s is not a JuicePreset." % path)


func _apply_copies(action_name: String, copies: Array[JuiceFeedback], replace: bool) -> void:
	var list: Array[JuiceFeedback] = [] if replace else player.feedbacks.duplicate()
	list.append_array(copies)
	_commit(action_name, list, copies)


func _commit(action_name: String, new_list: Array[JuiceFeedback], new_items: Array[JuiceFeedback] = []) -> void:
	var old_list: Array[JuiceFeedback] = player.feedbacks.duplicate()
	if undo_redo == null:
		player.feedbacks = new_list
		return
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, player)
	undo_redo.add_do_property(player, &"feedbacks", new_list)
	undo_redo.add_undo_property(player, &"feedbacks", old_list)
	for feedback in new_items:
		undo_redo.add_do_reference(feedback)
	undo_redo.commit_action()
