extends Control
## A starter scene: a coin counter, Juice animation, and a persistent Save slot.

const SLOT := 1
var _coins := 0
var _counter: Label
var _status: Label
var _juice: JuicePlayer


func _ready() -> void:
	# Keep demo saves separate from games using the addons.
	ProjectSettings.set_setting("save/directory", "user://cannoli_demo")
	var column := VBoxContainer.new()
	column.position = Vector2(80, 80)
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var title := Label.new()
	title.text = "Cannoli: collect, animate, save"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 24)
	column.add_child(_counter)
	_status = Label.new()
	column.add_child(_status)
	_add_button(column, "Collect a coin", _collect)
	_add_button(column, "Save", _save)
	_add_button(column, "Load", _load)
	_add_button(column, "Reset demo save", _reset)
	var hint := Label.new()
	hint.text = "Open the addon READMEs for Quests, Relationships and Behaviors setup."
	column.add_child(hint)
	var punch := JuiceScale.new()
	punch.duration = 0.25
	_juice = JuicePlayer.new()
	_juice.feedbacks = [punch]
	_counter.add_child(_juice)
	Save.register_section("demo", func() -> Dictionary: return {"coins": _coins})
	Save.loaded.connect(_on_loaded)
	_refresh()
	if Save.has_slot(SLOT):
		_load()
	else:
		_save()
	if "--smoke" in OS.get_cmdline_user_args():
		_collect()
		var expected := _coins
		assert(Save.save() == OK)
		_coins = -1
		assert(Save.load_slot(SLOT) == OK)
		assert(_coins == expected, "Saved coin count did not round-trip")
		await _juice.finished
		print("CANNOLI_DEMO_OK")
		get_tree().quit()


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _collect() -> void:
	_coins += 1
	_refresh()
	_juice.play()


func _save() -> void:
	var error := Save.save() if Save.get_slot() == SLOT else Save.start_slot(SLOT)
	_status.text = "Saved to demo slot 1." if error == OK else "Save failed: " + error_string(error)


func _load() -> void:
	var error := Save.load_slot(SLOT)
	_status.text = "Loaded demo slot 1." if error == OK else "Load failed: " + error_string(error)


func _on_loaded(_slot: int) -> void:
	_coins = int(Save.get_value("demo", "coins", 0))
	_refresh()


func _reset() -> void:
	var error := Save.delete_slot(SLOT)
	if error != OK:
		_status.text = "Reset failed: " + error_string(error)
		return
	_coins = 0
	_refresh()
	_save()


func _refresh() -> void:
	_counter.text = "Coins: %d" % _coins
