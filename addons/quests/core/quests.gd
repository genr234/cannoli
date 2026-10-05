class_name Quests
extends RefCounted
## Static access to the quest system: registries of quest lists, quest assets
## and quest instances, and shortcuts for common operations.
##
## [codeblock]
## Quests.give_quest("rat_hunt")
## if Quests.is_state("rat_hunt", "active"):
##     print(Quests.counter("rat_hunt", "rats"))
## [/codeblock]

## Prints activity to the output.
static var debug := false
## Kept for parity with the original system. GDScript has no exceptions, so it does nothing.
static var allow_exceptions := false
## True while a saved game is being applied. Quests then start without running actions.
static var is_loading_game := false
## Code that adds generator data to [method QuestManager.record_data]. Returns a Dictionary.
static var generator_record_callback := Callable()
## Code that restores generator data. Takes the Dictionary that was recorded.
static var generator_apply_callback := Callable()

static var _quest_lists := {}
static var _quest_assets := {}
static var _quest_instances := {}
static var _images := {}
static var _audio := {}
static var _timers: Array[Object] = []
static var _completed_quest_ids := {}
static var _save_section := "quests"


## Clears all registries and static settings. Mainly for tests.
static func reset_static_state() -> void:
	_quest_lists.clear()
	_quest_assets.clear()
	_quest_instances.clear()
	_images.clear()
	_audio.clear()
	_timers.clear()
	_completed_quest_ids.clear()
	is_loading_game = false
	debug = false
	generator_record_callback = Callable()
	generator_apply_callback = Callable()
	QuestMessages.clear_listeners()
	QuestGeneratorData.reset_static_state()
	QuestsTime.mode = QuestsTime.Mode.STANDARD
	QuestsTime.reset()


## The active quest manager, or null.
static func get_manager() -> QuestManager:
	return QuestManager.instance if is_instance_valid(QuestManager.instance) else null


#region Quest lists

static func register_quest_list(list: QuestList) -> void:
	if list == null:
		return
	if _quest_lists.has(list.id) and _quest_lists[list.id] != list and is_instance_valid(_quest_lists[list.id]):
		push_warning("Quests: A quest list with id '%s' is already registered. Can't register %s." % [list.id, list.get_path()])
		return
	_quest_lists[list.id] = list


static func unregister_quest_list(list: QuestList) -> void:
	if list != null and _quest_lists.get(list.id) == list:
		_quest_lists.erase(list.id)


static func get_quest_list(id: String) -> QuestList:
	var list: Variant = _quest_lists.get(id)
	return list if not id.is_empty() and is_instance_valid(list) else null


## Quest list id -> [QuestList]. Includes quest givers and journals.
static func get_all_quest_lists() -> Dictionary:
	return _quest_lists


## The journal with the given id. With no id, the first journal, which is
## normally the player's. If no registered journal matches, falls back to the
## first journal in the scene tree.
static func get_journal(id := "") -> QuestJournal:
	for key: String in _quest_lists:
		var journal := _quest_lists[key] as QuestJournal
		if is_instance_valid(journal) and (id.is_empty() or id == key):
			return journal
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		return tree.get_first_node_in_group(&"quest_journals") as QuestJournal
	return null


static func show_journal_ui() -> void:
	var journal := get_journal()
	if journal != null:
		journal.show_journal_ui()
	else:
		push_warning("Quests: No quest journal found in scene. Can't show journal UI.")


static func hide_journal_ui() -> void:
	var journal := get_journal()
	if journal != null:
		journal.hide_journal_ui()
	else:
		push_warning("Quests: No quest journal found in scene. Can't hide journal UI.")


static func toggle_journal_ui() -> void:
	var journal := get_journal()
	if journal != null:
		journal.toggle_journal_ui()
	else:
		push_warning("Quests: No quest journal found in scene. Can't toggle journal UI.")

#endregion

#region Quest assets and instances

static func _get_quest_key(quest: Quest) -> String:
	return str(quest.get_instance_id()) if quest.id.is_empty() else quest.id


static func register_quest_asset(q: Quest) -> void:
	if q == null:
		return
	if q.is_instance:
		push_warning("Quests: '%s' is not an asset. Not registering it as a quest asset." % q.id)
		return
	if q.id.is_empty():
		push_warning("Quests: A quest asset has a blank id. This may affect registration.")
	if debug:
		print("Quests: Registering quest asset '%s'." % q.id)
	_quest_assets[_get_quest_key(q)] = q
	register_quest_media(q)


static func unregister_quest_asset(q: Quest) -> void:
	if q != null:
		_quest_assets.erase(_get_quest_key(q))


static func unregister_all_quest_assets() -> void:
	_quest_assets.clear()


static func get_quest_asset(id: String) -> Quest:
	if _quest_assets.has(id):
		return _quest_assets[id]
	if debug:
		push_warning("Quests: A quest asset with id '%s' is not registered." % id)
	return null


static func register_quest_instance(q: Quest) -> void:
	if q == null:
		return
	if not q.is_instance:
		push_warning("Quests: '%s' is an asset. Not registering it as a quest instance." % q.id)
		return
	var key := _get_quest_key(q)
	if debug:
		print("Quests: Registering quest instance '%s'." % q.id)
	if not _quest_instances.has(key):
		_quest_instances[key] = []
	var list: Array = _quest_instances[key]
	if not list.has(q):
		list.insert(0, q)
	register_quest_media(q)


static func unregister_quest_instance(q: Quest) -> void:
	if q == null:
		return
	var key := _get_quest_key(q)
	if _quest_instances.has(key):
		var list: Array = _quest_instances[key]
		list.erase(q)
		if list.is_empty():
			_quest_instances.erase(key)


static func unregister_all_quest_instances() -> void:
	_quest_instances.clear()


## Returns the quester's instance of a quest. With no quester id, returns the
## player's journal's instance, or any instance.
static func get_quest_instance(quest_id: String, quester_id := "") -> Quest:
	var journal := get_journal(quester_id)
	if journal != null:
		var quest := journal.find_quest(quest_id)
		if quest != null:
			return quest
	var any_quester := quester_id.is_empty()
	for quest: Quest in _quest_instances.get(quest_id, []):
		if quest != null and (any_quester or quest.quester_id == quester_id):
			return quest
	if debug:
		push_warning("Quests: A quest instance with id '%s' is not registered." % quest_id)
	return null


## Quest id -> Array[Quest] of registered instances.
static func get_all_quest_instances() -> Dictionary:
	return _quest_instances


## True if a quest with this id has ever succeeded, even if the journal
## deleted it afterwards. Used for [member Quest.requires_quests].
static func was_completed(quest_id: String) -> bool:
	return _completed_quest_ids.has(quest_id)


## Ids of the quests that have succeeded. Saved with the manager's data.
static func get_completed_quest_ids() -> PackedStringArray:
	return PackedStringArray(_completed_quest_ids.keys())


static func set_completed_quest_ids(ids: Array) -> void:
	_completed_quest_ids.clear()
	for completed_id in ids:
		_completed_quest_ids[str(completed_id)] = true


## Called when a quest becomes successful so quests that require it can be offered.
static func notify_quest_succeeded(quest: Quest) -> void:
	_completed_quest_ids[quest.id] = true
	for list: Array in _quest_instances.values().duplicate():
		for other: Quest in list.duplicate():
			if other != quest and other.state == Quest.State.WAITING_TO_START \
					and other.requires_quests.has(quest.id) and other.can_be_offered():
				other.become_offerable()

#endregion

#region Media

static func register_quest_media(quest: Quest) -> void:
	register_image(quest.icon)
	for list: Array in [quest.offer_content_list, quest.offer_conditions_unmet_content_list]:
		_register_subassets_media(list)
	for info in quest.state_info_list:
		_register_state_info_media(info)
	for node in quest.node_list:
		if node != null:
			for info in node.state_info_list:
				_register_state_info_media(info)


static func _register_state_info_media(info: QuestStateInfo) -> void:
	_register_subassets_media(info.action_list)
	for category in [QuestContent.Category.DIALOGUE, QuestContent.Category.JOURNAL, QuestContent.Category.HUD]:
		_register_subassets_media(info.get_content_list(category))


static func _register_subassets_media(list: Array) -> void:
	for subasset: QuestSubasset in list:
		if subasset == null:
			continue
		for image in subasset.get_images():
			register_image(image)
		for stream in subasset.get_audio():
			register_audio(stream)


static func _media_key(resource: Resource) -> String:
	return resource.resource_path if not resource.resource_path.is_empty() else resource.resource_name


static func register_image(image: Texture2D) -> void:
	if image != null and not _media_key(image).is_empty():
		_images[_media_key(image)] = image


static func register_audio(stream: AudioStream) -> void:
	if stream != null and not _media_key(stream).is_empty():
		_audio[_media_key(stream)] = stream


## Finds a registered image by resource path, or loads it from the path.
static func get_image(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _images.has(path):
		return _images[path]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func get_audio(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _audio.has(path):
		return _audio[path]
	return load(path) as AudioStream if ResourceLoader.exists(path) else null

#endregion

#region Convenience

## Gives a quest to the player's journal and activates it. Returns the instance.
static func give_quest(quest_or_id: Variant) -> Quest:
	return give_quest_to_quester(quest_or_id, "")


## Gives a quest to a quester and activates it. [param quest_or_id] is a [Quest]
## or a quest id. [param quester] is a journal, a node with a journal, or a
## quester id. Returns the instance, or null.
static func give_quest_to_quester(quest_or_id: Variant, quester: Variant) -> Quest:
	var quest: Quest = quest_or_id as Quest if quest_or_id is Quest else get_quest_asset(str(quest_or_id))
	var journal := _resolve_journal(quester)
	if quest == null:
		push_warning("Quests: give_quest_to_quester() quest '%s' not found." % str(quest_or_id))
		return null
	if journal == null:
		push_warning("Quests: give_quest_to_quester() quest journal not found.")
		return null
	if not quest.is_instance:
		quest = quest.clone()
	quest.assign_quester(journal.get_participant())
	quest.times_accepted = 1
	journal.deleted_static_quests.erase(quest.id)
	journal.add_quest(quest)
	quest.set_state(Quest.State.ACTIVE)
	QuestMessages.refresh_indicators(quest)
	return quest


## Abandons a quest in the quester's journal, if the quest is abandonable. See
## [method QuestJournal.abandon_quest]. Returns true if the quest was found.
static func abandon_quest(quest_id: String, quester_id := "") -> bool:
	var quest := get_quest_instance(quest_id, quester_id)
	var journal := get_journal(quester_id)
	if quest == null or journal == null or journal.find_quest(quest_id) != quest:
		return false
	journal.abandon_quest(quest)
	return true


static func _resolve_journal(quester: Variant) -> QuestJournal:
	if quester is QuestJournal:
		return quester
	if quester is Node:
		var found := QuestMessages.find_identifiable(quester)
		if found is QuestJournal:
			return found
		return get_journal(QuestMessages.get_id(quester))
	return get_journal(str(quester) if quester != null else "")


## The state of the quester's instance of a quest. WAITING_TO_START if there isn't one.
static func get_quest_state(quest_id: String, quester_id := "") -> Quest.State:
	var quest := get_quest_instance(quest_id, quester_id)
	return quest.get_state() if quest != null else Quest.State.WAITING_TO_START


static func set_quest_state(quest_id: String, state: Quest.State, quester_id := "") -> void:
	var quest := get_quest_instance(quest_id, quester_id)
	if quest == null:
		push_warning("Quests: set_quest_state(%s, %s): Couldn't find a quest with id '%s'." % [quest_id, Quest.State.find_key(state), quest_id])
		return
	quest.set_state(state)


static func get_quest_node_state(quest_id: String, node_id: String, quester_id := "") -> QuestNode.State:
	var quest := get_quest_instance(quest_id, quester_id)
	if quest == null:
		return QuestNode.State.INACTIVE
	var node := quest.get_node(node_id)
	if node == null:
		push_warning("Quests: get_quest_node_state(%s, %s): Quest doesn't have a node with id '%s'." % [quest_id, node_id, node_id])
		return QuestNode.State.INACTIVE
	return node.get_state()


static func set_quest_node_state(quest_id: String, node_id: String, state: QuestNode.State, quester_id := "") -> void:
	var quest := get_quest_instance(quest_id, quester_id)
	if quest == null:
		push_warning("Quests: set_quest_node_state(%s, %s): Couldn't find a quest with id '%s'." % [quest_id, node_id, quest_id])
		return
	var node := quest.get_node(node_id)
	if node == null:
		push_warning("Quests: set_quest_node_state(%s, %s): Quest doesn't have a node with id '%s'." % [quest_id, node_id, node_id])
		return
	node.set_state(state)


static func get_quest_counter(quest_id: String, counter_name: String, quester_id := "") -> QuestCounter:
	var quest := get_quest_instance(quest_id, quester_id)
	if quest == null:
		push_warning("Quests: get_quest_counter(%s, %s): Couldn't find a quest with id '%s'." % [quest_id, counter_name, quest_id])
		return null
	var found := quest.get_counter(counter_name)
	if found == null:
		push_warning("Quests: get_quest_counter(%s, %s): Couldn't find a counter named '%s'." % [quest_id, counter_name, counter_name])
	return found


## Sends a message. [param value] is added as the message's first value if not null.
static func send_message(message: String, parameter := "", value: Variant = null, sender: Variant = null, target: Variant = null) -> void:
	QuestMessages.send(sender, target, message, parameter, [] if value == null else [value])


## True if the quest is in the state named [param state_name], such as "active"
## or "waiting to start". Usable in expressions.
static func is_state(quest_id: String, state_name: String, quester_id := "") -> bool:
	var state := state_from_name(state_name)
	return state != -1 and int(get_quest_state(quest_id, quester_id)) == state


## The current value of a counter, or 0 if the quest or counter doesn't exist.
## Usable in expressions.
static func counter(quest_id: String, counter_name: String, quester_id := "") -> int:
	var quest := get_quest_instance(quest_id, quester_id)
	var found := quest.get_counter(counter_name) if quest != null else null
	return found.current_value if found != null else 0


## Converts a quest state name, such as "active" or "waiting to start", to a
## [enum Quest.State] value. An int is returned as is. Returns -1 if unknown.
static func state_from_name(state_name: Variant) -> int:
	if typeof(state_name) == TYPE_INT:
		return state_name if state_name >= 0 and state_name < Quest.NUM_STATES else -1
	var key := str(state_name).to_lower().replace(" ", "").replace("_", "").replace("-", "")
	match key:
		"waitingtostart", "waiting":
			return Quest.State.WAITING_TO_START
		"active":
			return Quest.State.ACTIVE
		"successful", "success", "succeeded":
			return Quest.State.SUCCESSFUL
		"failed", "failure":
			return Quest.State.FAILED
		"abandoned":
			return Quest.State.ABANDONED
		"disabled":
			return Quest.State.DISABLED
	return -1


## Converts a node state name, such as "active" or "true", to a
## [enum QuestNode.State] value. An int is returned as is. Returns -1 if unknown.
static func node_state_from_name(state_name: Variant) -> int:
	if typeof(state_name) == TYPE_INT:
		return state_name if state_name >= 0 and state_name < QuestNode.NUM_STATES else -1
	match str(state_name).to_lower().strip_edges():
		"inactive":
			return QuestNode.State.INACTIVE
		"active":
			return QuestNode.State.ACTIVE
		"true":
			return QuestNode.State.TRUE
	return -1

#endregion

#region Timers

## Registers an object whose tick() method is called once per second of
## [QuestsTime], such as a timer condition.
static func register_timer(timer: Object) -> void:
	if timer != null and not _timers.has(timer):
		_timers.append(timer)


static func unregister_timer(timer: Object) -> void:
	_timers.erase(timer)


## Calls tick() on every registered timer. [QuestManager] calls this once per second.
static func tick_timers() -> void:
	for timer in _timers.duplicate():
		if is_instance_valid(timer):
			timer.tick()
		else:
			_timers.erase(timer)

#endregion

#region Save addon

## Connects the quest system to the Save addon if it is installed: the manager's
## data is stored in [param section] when saving and applied when a slot loads.
## Looks up the autoload named "Save" at runtime, so there is no hard dependency.
## Returns false if the autoload doesn't exist.
static func register_with_save(section := "quests") -> bool:
	var save := _get_save()
	if save == null:
		return false
	_save_section = section
	save.call(&"register_section", section, _provide_save_data)
	if not save.is_connected(&"loaded", _on_save_loaded):
		save.connect(&"loaded", _on_save_loaded)
	return true


static func _get_save() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var save := tree.root.get_node_or_null("Save")
	if save == null or not save.has_signal(&"loaded") or not save.has_method(&"register_section"):
		return null
	return save


static func _provide_save_data() -> Dictionary:
	var manager := get_manager()
	return manager.record_data() if manager != null else {}


static func _on_save_loaded(_slot: int) -> void:
	var manager := get_manager()
	var save := _get_save()
	if manager == null or save == null:
		return
	var data: Dictionary = save.call(&"get_section", _save_section)
	if not data.is_empty():
		manager.apply_data(data)

#endregion
