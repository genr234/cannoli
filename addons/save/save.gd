extends Node
## Stores named sections of game data in slot files.
##
## Enable the Save plugin to register this script as the [code]Save[/code] autoload.
## Each system registers a function that returns its own dictionary. [method save]
## calls those functions and writes the active slot. The scene tree is never walked.
##
## [code]user://saves/slot_1.save[/code] is slot 1. Files are Godot's binary format,
## so vectors and colors round-trip, and objects, callables, and signals are refused.
## Code that quits the game should call [method quit] so the active slot is saved first.

const MAGIC := "CNS1"
const FORMAT := 2
const FLAG_COMPRESSED := 1
const FLAG_ENCRYPTED := 2
const HEADER_SIZE := 127
const CHECKSUM_OFFSET := 95
const MAX_BYTES := 64 * 1024 * 1024
const MAX_META_BYTES := 64 * 1024
const MAX_DEPTH := 64

## Emitted after [method load_slot] has put a slot into memory.
## Apply section data here. The call finishes before [method load_slot] returns,
## and saving from this function is allowed.
signal loaded(slot: int)
## Emitted after [method save] or [method save_async] writes new bytes. Skipped when nothing changed.
signal saved(slot: int)
## Emitted after [method start_slot] writes a new slot.
signal started(slot: int)
## Emitted when writing fails in [method save], [method save_async], autosave, or [method start_slot].
signal save_failed(slot: int, error: Error)
## Emitted before providers are asked for data.
signal about_to_save(slot: int)

var _providers := {}
var _sections := {}
var _meta := {}
var _migration := Callable()
var _slot := -1
var _last_signature := PackedByteArray()
var _autosave_wait := 0.0
var _autosave_blocks := 0
var _busy := false
var _task_id := -1
var _job_slot := -1
var _job_signature := PackedByteArray()
var _job_result := {}


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	# No save here. The current scene has already left the tree, so providers
	# that read scene nodes would fail. Quit through quit() instead.
	_finish_async()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_autosave()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# Synchronous, after any write already in flight. A paused mobile app can be
			# suspended before a worker thread finishes.
			_finish_async()
			if _can_autosave():
				save()


func _process(delta: float) -> void:
	if _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		_finish_async()
	if not _autosave_enabled() or _autosave_blocks > 0:
		return
	_autosave_wait += delta
	if _autosave_wait >= _autosave_interval():
		_autosave_wait = 0.0
		_autosave()


## Registers [param provider] as the source of [param section].
## The function takes no arguments and returns a [Dictionary]. On [method save],
## its result replaces that section. Other sections are left alone.
func register_section(section: String, provider: Callable) -> Error:
	if section.is_empty():
		return _fail("Save: section name is empty.", ERR_INVALID_PARAMETER)
	if not provider.is_valid():
		return _fail("Save: section \"%s\" needs a function that returns a Dictionary." % section, ERR_INVALID_PARAMETER)
	_providers[section] = provider
	return OK


## Stops asking [param section] for fresh data. Data already stored is kept.
func unregister_section(section: String) -> void:
	_providers.erase(section)


## Stores [param value] at [param section] and [param key]. Does not write the file.
func set_value(section: String, key: String, value: Variant) -> Error:
	if section.is_empty() or key.is_empty():
		return _fail("Save: section and key must be non-empty.", ERR_INVALID_PARAMETER)
	var err := _validate(value, "%s.%s" % [section, key], 0)
	if err != OK:
		return err
	if typeof(_sections.get(section)) != TYPE_DICTIONARY:
		_sections[section] = {}
	_sections[section][key] = _normalize(value)
	return OK


## Returns the stored value, or [param default] when the section or key is missing.
## Does not create the key.
func get_value(section: String, key: String, default: Variant = null) -> Variant:
	if not has_value(section, key):
		return default
	return _normalize(_sections[section][key])


func has_value(section: String, key: String) -> bool:
	return typeof(_sections.get(section)) == TYPE_DICTIONARY and _sections[section].has(key)


func erase_value(section: String, key: String) -> void:
	if has_value(section, key):
		_sections[section].erase(key)


## Replaces a whole section. [method save] overwrites sections that have a provider.
func set_section(section: String, data: Dictionary) -> Error:
	if section.is_empty():
		return _fail("Save: section name is empty.", ERR_INVALID_PARAMETER)
	var err := _validate(data, section, 0)
	if err != OK:
		return err
	_sections[section] = _normalize(data)
	return OK


## Returns a copy of a section, or an empty dictionary when it is missing.
func get_section(section: String) -> Dictionary:
	if typeof(_sections.get(section)) != TYPE_DICTIONARY:
		return {}
	return _normalize(_sections[section])


func has_section(section: String) -> bool:
	return _sections.has(section)


func erase_section(section: String) -> void:
	_sections.erase(section)


## Sets the metadata stored with the active slot, such as a chapter, playtime, or label.
## Keep it small plain data (at most 64 KiB). It replaces the previous metadata and is
## written on the next save. [method get_slot_info] reads it without loading the slot.
func set_slot_meta(meta: Dictionary) -> Error:
	var err := _validate(meta, "slot meta", 0)
	if err != OK:
		return err
	if var_to_bytes(meta).size() > MAX_META_BYTES:
		return _fail("Save: slot meta is larger than %d bytes." % MAX_META_BYTES, ERR_INVALID_DATA)
	_meta = _normalize(meta)
	return OK


## Returns a copy of the active slot's metadata.
func get_slot_meta() -> Dictionary:
	return _normalize(_meta)


## The active slot, or -1 when none is loaded or started.
func get_slot() -> int:
	return _slot


## True when [param slot] has a file, temporary file, or backup.
## A [code].corrupt[/code] file alone doesn't count.
func has_slot(slot: int) -> bool:
	if slot < 0:
		return false
	return FileAccess.file_exists(_main_path(slot)) or FileAccess.file_exists(_temp_path(slot)) or FileAccess.file_exists(_temp_path(slot) + "2") or FileAccess.file_exists(_backup_path(slot))


## Slot numbers that have a file or a backup, lowest first.
func list_slots() -> PackedInt32Array:
	var found := {}
	var directory := DirAccess.open(_directory())
	if directory == null:
		return PackedInt32Array()
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		var slot := _slot_number(file_name)
		if slot >= 0:
			found[slot] = true
		file_name = directory.get_next()
	directory.list_dir_end()
	var numbers: Array = found.keys()
	numbers.sort()
	var packed := PackedInt32Array()
	for number in numbers:
		packed.append(int(number))
	return packed


## Reads a slot's header without loading it, for a load menu. Returns an empty dictionary
## when the slot is missing or unreadable. Otherwise:
## [code]slot[/code], [code]version[/code] (game version), [code]modified[/code] (file time, Unix),
## [code]saved_at[/code] (Unix time written in the file), [code]meta[/code] (see [method set_slot_meta]),
## and [code]encrypted[/code]. The payload is not decompressed or decoded.
## Falls back to the temporary file and backup like [method load_slot].
func get_slot_info(slot: int) -> Dictionary:
	if slot < 0:
		return {}
	var outcome := _read_slot(slot, false)
	if outcome.error != OK:
		return {}
	var modified := FileAccess.get_modified_time(str(outcome.path))
	var saved_at := int(outcome.saved_at)
	if saved_at == 0:
		saved_at = modified
	return {
		"slot": slot,
		"version": int(outcome.version),
		"modified": modified,
		"saved_at": saved_at,
		"meta": outcome.meta,
		"encrypted": bool(outcome.encrypted),
	}


## Starts a new game in [param slot] and writes it, replacing any file already there.
## Values set while no slot was active are kept. When another slot was active, its data
## and metadata are dropped first. Providers are called, so set up the new game, then call this.
## On failure the previous state is restored and [signal save_failed] is emitted.
func start_slot(slot: int) -> Error:
	var err := _check_slot(slot)
	if err != OK:
		return err
	_finish_async()
	if _busy:
		return _fail("Save: already saving or loading.", ERR_BUSY)
	_busy = true
	var previous_slot := _slot
	var previous_sections: Dictionary = _sections.duplicate(true)
	var previous_meta: Dictionary = _meta.duplicate(true)
	var previous_signature := _last_signature
	if _slot >= 0:
		_sections = {}
		_meta = {}
	_slot = slot
	about_to_save.emit(slot)
	err = _capture()
	if err == OK:
		err = _write_current()
	if err != OK:
		_slot = previous_slot
		_sections = previous_sections
		_meta = previous_meta
		_last_signature = previous_signature
		_busy = false
		save_failed.emit(slot, err)
		return err
	_autosave_wait = 0.0
	_busy = false
	started.emit(slot)
	return OK


## Reads [param slot] into memory and emits [signal loaded].
## A missing main file, or a main file that cannot be read, falls back to the backup.
## A main file that cannot be read is renamed to [code].corrupt[/code].
func load_slot(slot: int) -> Error:
	var err := _check_slot(slot)
	if err != OK:
		return err
	_finish_async()
	if _busy:
		return _fail("Save: already saving or loading.", ERR_BUSY)
	_busy = true
	var outcome := _read_slot(slot, true)
	if outcome.error != OK:
		_busy = false
		return _fail(str(outcome.message), outcome.error)
	err = _accept(slot, outcome)
	_busy = false
	if err == OK:
		loaded.emit(slot)
	return err


## Asks every provider for fresh data, then writes the active slot and waits for it.
## Does nothing when the data, metadata, version, compression, and password are unchanged.
func save() -> Error:
	return _save(false)


## Like [method save], but compression, encryption, and the file write run on a worker
## thread. Providers still run now. Returns [constant OK] once the write is queued.
## Other slot operations wait for it to finish before they run. The result arrives
## as [signal saved] or [signal save_failed] on the main thread.
func save_async() -> Error:
	return _save(true)


## Saves the active slot, if there is one, then quits. Ignores autosave settings and blocking.
## Use this instead of calling [code]get_tree().quit()[/code] from code.
func quit(exit_code := 0) -> void:
	_finish_async()
	if _slot >= 0 and not _busy:
		save()
	get_tree().quit(exit_code)


## Stops timer, focus, pause, and close-request saves until [method unblock_autosave] is
## called as many times. [method save], [method save_async], and [method quit] still work.
func block_autosave() -> void:
	_autosave_blocks += 1


func unblock_autosave() -> void:
	if _autosave_blocks <= 0:
		push_warning("Save: unblock_autosave called without block_autosave.")
		return
	_autosave_blocks -= 1


func is_autosave_blocked() -> bool:
	return _autosave_blocks > 0


## Deletes the slot file, its backup, a [code].corrupt[/code] file, and leftover temporary files.
## Deleting the active slot clears memory.
func delete_slot(slot: int) -> Error:
	var err := _check_slot(slot)
	if err != OK:
		return err
	_finish_async()
	if _busy:
		return _fail("Save: already saving or loading.", ERR_BUSY)
	err = _ensure_directory()
	if err != OK:
		return err
	var directory := DirAccess.open(_directory())
	if directory == null:
		return _fail("Save: couldn't open %s (%s)." % [_directory(), error_string(DirAccess.get_open_error())], DirAccess.get_open_error())
	for suffix in ["", ".bak", ".corrupt", ".tmp", ".tmp2"]:
		var file_name: String = _file_name(slot) + String(suffix)
		if not directory.file_exists(file_name):
			continue
		var remove_err := directory.remove(file_name)
		if remove_err != OK:
			return _fail("Save: couldn't delete %s (%s)." % [file_name, error_string(remove_err)], remove_err)
	if _slot == slot:
		_sections = {}
		_meta = {}
		_slot = -1
		_last_signature = PackedByteArray()
		_autosave_wait = 0.0
	return OK


## Sets the function called when a slot is older than [code]save/version[/code].
## It receives the file version and a copy of the sections, and returns the sections to keep.
## Pass an empty [Callable] to clear it.
func set_migration(migration: Callable) -> void:
	_migration = migration


func _save(background: bool) -> Error:
	_finish_async()
	if _slot < 0:
		return _fail("Save: there's no active slot. Call load_slot or start_slot first.", ERR_UNCONFIGURED)
	if _busy:
		return _fail("Save: already saving or loading.", ERR_BUSY)
	_busy = true
	var slot := _slot
	about_to_save.emit(slot)
	var err := _capture()
	var prepared := {}
	if err == OK:
		prepared = _prepare(slot, "")
		err = prepared.error
	if err != OK:
		_busy = false
		save_failed.emit(slot, err)
		return err
	var signature: PackedByteArray = prepared.signature
	if signature == _last_signature:
		_autosave_wait = 0.0
		_busy = false
		return OK
	_autosave_wait = 0.0
	if background:
		_job_slot = slot
		_job_signature = signature
		_job_result = {}
		_task_id = WorkerThreadPool.add_task(_run_job.bind(prepared.job), false, "Save slot %d" % slot)
		return OK
	err = _complete(_write_job(prepared.job), signature)
	_busy = false
	if err == OK:
		saved.emit(slot)
	else:
		save_failed.emit(slot, err)
	return err


## Runs on a worker thread. Touches no nodes and no project settings.
func _run_job(job: Dictionary) -> void:
	_job_result = _write_job(job)


## Collects the result of an async write. Waits if it is still running.
func _finish_async() -> void:
	if _task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	var slot := _job_slot
	var err := _complete(_job_result, _job_signature)
	_job_result = {}
	_autosave_wait = 0.0
	_busy = false
	if err == OK:
		saved.emit(slot)
	else:
		save_failed.emit(slot, err)


func _complete(result: Dictionary, signature: PackedByteArray) -> Error:
	var err: Error = result.error
	if err != OK:
		return _fail(str(result.message), err)
	_last_signature = signature
	return OK


func _autosave() -> void:
	if _can_autosave():
		save_async()


func _can_autosave() -> bool:
	return _slot >= 0 and _autosave_enabled() and _autosave_blocks == 0 and not _busy


func _autosave_enabled() -> bool:
	return _slot >= 0 and _flag("save/autosave_enabled", true)


func _autosave_interval() -> float:
	var interval := _number("save/autosave_seconds", 180.0)
	if interval < 1.0:
		return 1.0
	return interval


func _accept(slot: int, outcome: Dictionary) -> Error:
	var current := _game_version()
	if current < 1:
		return _fail("Save: save/version must be at least 1.", ERR_INVALID_PARAMETER)
	var sections: Dictionary = outcome.sections
	var file_version := int(outcome.version)
	var restored := bool(outcome.restored)
	var source_path := str(outcome.path)
	var meta_err := _validate(outcome.meta, "slot %d meta" % slot, 0)
	if meta_err != OK:
		return meta_err
	var meta: Dictionary = _normalize(outcome.meta)
	var data := sections
	var migrated := false
	if file_version > current:
		return _fail("Save: slot %d is version %d, newer than this project's version %d." % [slot, file_version, current], ERR_INVALID_DATA)
	if file_version < current:
		if not _migration.is_valid():
			return _fail("Save: slot %d is version %d. This project is version %d and no migration is set." % [slot, file_version, current], ERR_INVALID_DATA)
		var result: Variant = _migration.call(file_version, _normalize(sections))
		if typeof(result) != TYPE_DICTIONARY:
			return _fail("Save: migration must return a Dictionary.", ERR_INVALID_DATA)
		var migration_err := _validate(result, "migration", 0)
		if migration_err != OK:
			return migration_err
		data = _normalize(result)
		migrated = true
	else:
		var valid_err := _validate(data, "slot %d" % slot, 0)
		if valid_err != OK:
			return valid_err
		data = _normalize(data)
	_sections = data
	_meta = meta
	_slot = slot
	_autosave_wait = 0.0
	if migrated or restored:
		# Don't rewrite the file we just read. A crash mid-write would erase the only good copy.
		var avoid := source_path if source_path.ends_with(".tmp") or source_path.ends_with(".tmp2") else ""
		var write_err := OK
		if bool(outcome.main_corrupt):
			# Move the unreadable main file aside so the good backup isn't rotated out.
			write_err = _quarantine_main(slot)
		if write_err == OK:
			write_err = _write_current(avoid)
		if write_err != OK:
			_last_signature = PackedByteArray()
			push_error("Save: loaded slot %d but couldn't update the file (%s)." % [slot, error_string(write_err)])
		return OK
	# A file in an older format, or compressed or encrypted differently than the settings
	# ask, is written again on the next save even if the data didn't change.
	var stale := int(outcome.format) != FORMAT \
			or bool(outcome.compressed) != _flag("save/compress", true) \
			or bool(outcome.encrypted) != (not _password().is_empty())
	if stale:
		_last_signature = PackedByteArray()
	else:
		_last_signature = _current_stamp()
	return OK


func _capture() -> Error:
	var next: Dictionary = _sections.duplicate(true)
	for section in _providers.keys():
		var provider: Callable = _providers[section]
		if not provider.is_valid():
			return _fail("Save: the provider for \"%s\" is no longer valid." % str(section), ERR_UNCONFIGURED)
		var result: Variant = provider.call()
		if typeof(result) != TYPE_DICTIONARY:
			return _fail("Save: the provider for \"%s\" must return a Dictionary." % str(section), ERR_INVALID_DATA)
		var err := _validate(result, str(section), 0)
		if err != OK:
			return err
		next[str(section)] = _normalize(result)
	_sections = next
	return OK


## Serializes memory and reads every setting a write needs, on the main thread.
## Returns [code]error[/code], and on success [code]job[/code] and [code]signature[/code].
func _prepare(slot: int, avoid_path: String) -> Dictionary:
	var version := _game_version()
	if version < 1:
		return {"error": _fail("Save: save/version must be at least 1.", ERR_INVALID_PARAMETER)}
	var raw := var_to_bytes(_sections)
	if raw.is_empty():
		return {"error": _fail("Save: couldn't serialize slot %d." % slot, ERR_INVALID_DATA)}
	if raw.size() > MAX_BYTES:
		return {"error": _fail("Save: slot %d is larger than %d bytes." % [slot, MAX_BYTES], ERR_INVALID_DATA)}
	var meta := var_to_bytes(_meta)
	if meta.size() > MAX_META_BYTES:
		return {"error": _fail("Save: slot meta is larger than %d bytes." % MAX_META_BYTES, ERR_INVALID_DATA)}
	var err := _ensure_directory()
	if err != OK:
		return {"error": err}
	var compress := _flag("save/compress", true)
	var password := _password()
	var job := {
		"slot": slot,
		"directory": _directory(),
		"avoid": avoid_path,
		"version": version,
		"compress": compress,
		"password": password,
		"raw": raw,
		"meta": meta,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	return {"error": OK, "job": job, "signature": _stamp(version, compress, password, raw, meta)}


func _write_current(avoid_path := "") -> Error:
	var prepared := _prepare(_slot, avoid_path)
	if prepared.error != OK:
		return prepared.error
	return _complete(_write_job(prepared.job), prepared.signature)


func _quarantine_main(slot: int) -> Error:
	var directory := DirAccess.open(_directory())
	if directory == null:
		return _fail("Save: couldn't open %s (%s)." % [_directory(), error_string(DirAccess.get_open_error())], DirAccess.get_open_error())
	var main_name := _file_name(slot)
	var corrupt_name := main_name + ".corrupt"
	if not directory.file_exists(main_name):
		return OK
	if directory.file_exists(corrupt_name):
		var remove_err := directory.remove(corrupt_name)
		if remove_err != OK:
			return _fail("Save: couldn't replace %s (%s)." % [corrupt_name, error_string(remove_err)], remove_err)
	var rename_err := directory.rename(main_name, corrupt_name)
	if rename_err != OK:
		return _fail("Save: couldn't move %s aside (%s)." % [main_name, error_string(rename_err)], rename_err)
	return OK


## Compresses, encrypts, hashes, and writes a prepared job. Safe on a worker thread.
## Returns [code]error[/code] and [code]message[/code].
func _write_job(job: Dictionary) -> Dictionary:
	var slot: int = job.slot
	var directory: String = job.directory
	var raw: PackedByteArray = job.raw
	var meta: PackedByteArray = job.meta
	var password: String = job.password
	var flags := 0
	var stored := raw
	if bool(job.compress):
		stored = raw.compress(FileAccess.COMPRESSION_ZSTD)
		if stored.is_empty():
			return _result(ERR_INVALID_DATA, "Save: couldn't compress slot %d." % slot)
		flags |= FLAG_COMPRESSED
	var meta_stored := meta
	var iv_meta := PackedByteArray()
	var iv_data := PackedByteArray()
	var key_check := PackedByteArray()
	iv_meta.resize(16)
	iv_data.resize(16)
	key_check.resize(32)
	if not password.is_empty():
		var key := password.sha256_buffer()
		var crypto := Crypto.new()
		iv_meta = crypto.generate_random_bytes(16)
		iv_data = crypto.generate_random_bytes(16)
		meta_stored = _encrypt(meta, key, iv_meta)
		stored = _encrypt(stored, key, iv_data)
		if meta_stored.is_empty() or stored.is_empty():
			return _result(ERR_CANT_CREATE, "Save: couldn't encrypt slot %d." % slot)
		key_check = _digest([key])
		flags |= FLAG_ENCRYPTED
	if stored.size() > MAX_BYTES:
		return _result(ERR_INVALID_DATA, "Save: slot %d is larger than %d bytes." % [slot, MAX_BYTES])
	var header := PackedByteArray()
	header.resize(HEADER_SIZE)
	_put(header, 0, MAGIC.to_utf8_buffer())
	header.encode_u16(4, FORMAT)
	header.encode_u8(6, flags)
	header.encode_u32(7, int(job.version))
	header.encode_u64(11, int(job.saved_at))
	header.encode_u32(19, raw.size())
	header.encode_u32(23, meta_stored.size())
	header.encode_u32(27, stored.size())
	_put(header, 31, iv_meta)
	_put(header, 47, iv_data)
	_put(header, 63, key_check)
	_put(header, CHECKSUM_OFFSET, _digest([header.slice(0, CHECKSUM_OFFSET), meta_stored, stored]))
	var temp_path := _slot_path(directory, slot, ".tmp")
	if temp_path == str(job.avoid):
		temp_path = _slot_path(directory, slot, ".tmp2")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_err := FileAccess.get_open_error()
		return _result(open_err, "Save: couldn't write %s (%s)." % [temp_path, error_string(open_err)])
	file.store_buffer(header)
	file.store_buffer(meta_stored)
	file.store_buffer(stored)
	var write_err := file.get_error()
	file.close()
	if write_err != OK:
		return _result(write_err, "Save: couldn't write %s (%s)." % [temp_path, error_string(write_err)])
	return _replace_slot(directory, slot, temp_path.get_file())


func _replace_slot(directory_path: String, slot: int, temp_name: String) -> Dictionary:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return _result(DirAccess.get_open_error(), "Save: couldn't open %s (%s)." % [directory_path, error_string(DirAccess.get_open_error())])
	var main_name := _file_name(slot)
	var backup_name := main_name + ".bak"
	if not directory.file_exists(temp_name):
		return _result(ERR_FILE_NOT_FOUND, "Save: temporary file for slot %d is missing." % slot)
	# Temp already holds the new bytes. The previous main file becomes the backup
	# only when a main file exists, so a missing main file never deletes the only copy.
	if directory.file_exists(main_name):
		if directory.file_exists(backup_name):
			var remove_err := directory.remove(backup_name)
			if remove_err != OK:
				return _result(remove_err, "Save: couldn't replace the backup for slot %d (%s)." % [slot, error_string(remove_err)])
		var backup_err := directory.rename(main_name, backup_name)
		if backup_err != OK:
			return _result(backup_err, "Save: couldn't back up slot %d (%s)." % [slot, error_string(backup_err)])
	var rename_err := directory.rename(temp_name, main_name)
	if rename_err != OK:
		if directory.file_exists(backup_name) and not directory.file_exists(main_name):
			directory.rename(backup_name, main_name)
		return _result(rename_err, "Save: couldn't replace slot %d (%s)." % [slot, error_string(rename_err)])
	for suffix in [".tmp", ".tmp2"]:
		var leftover: String = main_name + String(suffix)
		if directory.file_exists(leftover):
			directory.remove(leftover)
	return _result(OK, "")


## Finds a readable copy of [param slot]. With [param full] false, the payload is only
## checked, not decompressed or decoded. Returns [code]error[/code] and [code]message[/code]
## on failure.
func _read_slot(slot: int, full: bool) -> Dictionary:
	var password := _password()
	var main_path := _main_path(slot)
	var candidates: Array = [
		[_temp_path(slot) + "2", true, "temporary file"],
		[_temp_path(slot), true, "temporary file"],
		[main_path, false, ""],
		[_backup_path(slot), true, "backup"],
	]
	var saw_any := false
	var main_failed := false
	var main_checked := false
	var last_error := ERR_FILE_CORRUPT
	for candidate in candidates:
		var path: String = candidate[0]
		if not FileAccess.file_exists(path):
			continue
		saw_any = true
		var is_main := path == main_path
		var decoded := _read_path(path, password, full)
		if is_main:
			main_checked = true
		if decoded.error == OK:
			if candidate[1] and full:
				push_warning("Save: slot %d is missing or unreadable. Loading the %s." % [slot, candidate[2]])
			decoded["restored"] = candidate[1]
			decoded["path"] = path
			decoded["main_corrupt"] = main_failed
			if full and candidate[1] and not main_checked and FileAccess.file_exists(main_path):
				# A temporary file won before the main file was looked at.
				var check := _read_path(main_path, password, false)
				decoded["main_corrupt"] = check.error == ERR_FILE_CORRUPT or check.error == ERR_FILE_UNRECOGNIZED
			return decoded
		if decoded.error == ERR_UNAUTHORIZED:
			# The password is the problem, not the file. Don't fall back or move anything.
			var reason := str(decoded.get("reason", ""))
			if reason == "missing":
				return _result(ERR_UNAUTHORIZED, "Save: slot %d is encrypted and save/encryption_password is empty." % slot)
			return _result(ERR_UNAUTHORIZED, "Save: slot %d is encrypted and the password doesn't match." % slot)
		if is_main and (decoded.error == ERR_FILE_CORRUPT or decoded.error == ERR_FILE_UNRECOGNIZED):
			main_failed = true
		last_error = decoded.error
	if not saw_any:
		return _result(ERR_FILE_NOT_FOUND, "Save: slot %d doesn't exist." % slot)
	return _result(last_error, "Save: couldn't read slot %d (%s)." % [slot, error_string(last_error)])


func _read_path(path: String, password: String, full: bool) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error()}
	var head := file.get_buffer(MAGIC.length())
	if head.get_string_from_utf8() == MAGIC:
		file.seek(0)
		var decoded := _decode(file, password, full, false)
		file.close()
		return decoded
	file.close()
	# Format 1 files were encrypted as a whole when a password was set.
	if password.is_empty():
		return {"error": ERR_FILE_CORRUPT}
	var encrypted := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, password)
	if encrypted == null:
		return {"error": ERR_FILE_CORRUPT}
	var legacy := _decode(encrypted, password, full, true)
	encrypted.close()
	return legacy


func _decode(file: FileAccess, password: String, full: bool, wrapped: bool) -> Dictionary:
	var start := file.get_buffer(6)
	if start.size() != 6 or start.slice(0, 4).get_string_from_utf8() != MAGIC:
		return {"error": ERR_FILE_CORRUPT}
	var format := start.decode_u16(4)
	if format == 1:
		return _decode_v1(file, full, wrapped)
	if format != FORMAT:
		return {"error": ERR_FILE_UNRECOGNIZED}
	var header := start.duplicate()
	header.append_array(file.get_buffer(HEADER_SIZE - 6))
	if header.size() != HEADER_SIZE:
		return {"error": ERR_FILE_CORRUPT}
	var flags := header.decode_u8(6)
	if (flags & ~(FLAG_COMPRESSED | FLAG_ENCRYPTED)) != 0:
		return {"error": ERR_FILE_UNRECOGNIZED}
	var version := int(header.decode_u32(7))
	var saved_at := int(header.decode_u64(11))
	var raw_size := int(header.decode_u32(19))
	var meta_size := int(header.decode_u32(23))
	var stored_size := int(header.decode_u32(27))
	if raw_size < 1 or raw_size > MAX_BYTES or stored_size < 1 or stored_size > MAX_BYTES:
		return {"error": ERR_FILE_CORRUPT}
	if meta_size < 1 or meta_size > MAX_META_BYTES + 32:
		return {"error": ERR_FILE_CORRUPT}
	var meta_stored := file.get_buffer(meta_size)
	if meta_stored.size() != meta_size:
		return {"error": ERR_FILE_CORRUPT}
	var stored := file.get_buffer(stored_size)
	if stored.size() != stored_size:
		return {"error": ERR_FILE_CORRUPT}
	# The checksum covers the header, up to itself, and both bodies as they sit on disk.
	if _digest([header.slice(0, CHECKSUM_OFFSET), meta_stored, stored]) != header.slice(CHECKSUM_OFFSET, HEADER_SIZE):
		return {"error": ERR_FILE_CORRUPT}
	var encrypted := (flags & FLAG_ENCRYPTED) != 0
	var compressed := (flags & FLAG_COMPRESSED) != 0
	var key := PackedByteArray()
	var meta_bytes := meta_stored
	if encrypted:
		if password.is_empty():
			return {"error": ERR_UNAUTHORIZED, "reason": "missing"}
		key = password.sha256_buffer()
		if _digest([key]) != header.slice(63, 95):
			return {"error": ERR_UNAUTHORIZED, "reason": "wrong"}
		meta_bytes = _decrypt(meta_stored, key, header.slice(31, 47))
		if meta_bytes.is_empty():
			return {"error": ERR_FILE_CORRUPT}
	var meta: Variant = bytes_to_var(meta_bytes)
	if typeof(meta) != TYPE_DICTIONARY:
		return {"error": ERR_FILE_CORRUPT}
	var decoded := {
		"error": OK,
		"version": version,
		"saved_at": saved_at,
		"meta": meta,
		"format": format,
		"encrypted": encrypted,
		"compressed": compressed,
	}
	if not full:
		return decoded
	var raw := stored
	if encrypted:
		raw = _decrypt(stored, key, header.slice(47, 63))
		if raw.is_empty():
			return {"error": ERR_FILE_CORRUPT}
	if compressed:
		raw = raw.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return {"error": ERR_FILE_CORRUPT}
	var sections: Variant = bytes_to_var(raw)
	if typeof(sections) != TYPE_DICTIONARY:
		return {"error": ERR_FILE_CORRUPT}
	decoded["sections"] = sections
	return decoded


## Format 1: magic, format, flags, version, sizes, payload. No metadata or checksum.
func _decode_v1(file: FileAccess, full: bool, wrapped: bool) -> Dictionary:
	var flags := file.get_8()
	if (flags & ~FLAG_COMPRESSED) != 0:
		return {"error": ERR_FILE_UNRECOGNIZED}
	var version := int(file.get_32())
	var raw_size := int(file.get_32())
	var stored_size := int(file.get_32())
	if file.get_error() != OK:
		return {"error": ERR_FILE_CORRUPT}
	if raw_size < 0 or stored_size < 0 or raw_size > MAX_BYTES or stored_size > MAX_BYTES:
		return {"error": ERR_FILE_CORRUPT}
	var stored := file.get_buffer(stored_size)
	if stored.size() != stored_size:
		return {"error": ERR_FILE_CORRUPT}
	var compressed := (flags & FLAG_COMPRESSED) != 0
	var decoded := {
		"error": OK,
		"version": version,
		"saved_at": 0,
		"meta": {},
		"format": 1,
		"encrypted": wrapped,
		"compressed": compressed,
	}
	if not full:
		return decoded
	var raw := stored
	if compressed:
		raw = stored.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return {"error": ERR_FILE_CORRUPT}
	var sections: Variant = bytes_to_var(raw)
	if typeof(sections) != TYPE_DICTIONARY:
		return {"error": ERR_FILE_CORRUPT}
	decoded["sections"] = sections
	return decoded


## AES-256-CBC with PKCS7 padding. Returns an empty array on failure.
func _encrypt(data: PackedByteArray, key: PackedByteArray, iv: PackedByteArray) -> PackedByteArray:
	var padded := data.duplicate()
	var pad := 16 - padded.size() % 16
	var tail := PackedByteArray()
	tail.resize(pad)
	tail.fill(pad)
	padded.append_array(tail)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv) != OK:
		return PackedByteArray()
	var encrypted := aes.update(padded)
	aes.finish()
	return encrypted


## Reverses [method _encrypt]. Returns an empty array on bad length or padding.
func _decrypt(data: PackedByteArray, key: PackedByteArray, iv: PackedByteArray) -> PackedByteArray:
	if data.is_empty() or data.size() % 16 != 0:
		return PackedByteArray()
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, key, iv) != OK:
		return PackedByteArray()
	var plain := aes.update(data)
	aes.finish()
	if plain.is_empty():
		return PackedByteArray()
	var pad := int(plain[plain.size() - 1])
	if pad < 1 or pad > 16 or pad > plain.size():
		return PackedByteArray()
	for index in pad:
		if int(plain[plain.size() - 1 - index]) != pad:
			return PackedByteArray()
	return plain.slice(0, plain.size() - pad)


func _digest(parts: Array) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for part in parts:
		var bytes: PackedByteArray = part
		if not bytes.is_empty():
			context.update(bytes)
	return context.finish()


func _put(target: PackedByteArray, offset: int, bytes: PackedByteArray) -> void:
	for index in bytes.size():
		target[offset + index] = bytes[index]


func _result(error: Error, message: String) -> Dictionary:
	return {"error": error, "message": message}


## A digest of everything a write depends on. The password is hashed, never kept.
func _stamp(version: int, compress: bool, password: String, raw: PackedByteArray, meta: PackedByteArray) -> PackedByteArray:
	var stamp := "%d|%s|%s|%d|" % [version, str(compress), password.sha256_text(), meta.size()]
	return _digest([stamp.to_utf8_buffer(), meta, raw])


func _current_stamp() -> PackedByteArray:
	return _stamp(_game_version(), _flag("save/compress", true), _password(), var_to_bytes(_sections), var_to_bytes(_meta))


func _password() -> String:
	return str(_setting("save/encryption_password", ""))


func _game_version() -> int:
	return int(_number("save/version", 1.0))


func _directory() -> String:
	var dir := str(_setting("save/directory", "user://saves")).strip_edges()
	while dir.ends_with("/") or dir.ends_with("\\"):
		dir = dir.substr(0, dir.length() - 1)
	if dir.is_empty():
		return "user://saves"
	return dir


func _ensure_directory() -> Error:
	var absolute := ProjectSettings.globalize_path(_directory())
	var err := DirAccess.make_dir_recursive_absolute(absolute)
	if err != OK:
		return _fail("Save: couldn't create %s (%s)." % [_directory(), error_string(err)], err)
	return OK


func _file_name(slot: int) -> String:
	return "slot_%d.save" % slot


func _slot_path(directory: String, slot: int, suffix := "") -> String:
	return directory.path_join(_file_name(slot) + suffix)


func _main_path(slot: int) -> String:
	return _slot_path(_directory(), slot)


func _backup_path(slot: int) -> String:
	return _main_path(slot) + ".bak"


func _temp_path(slot: int) -> String:
	return _main_path(slot) + ".tmp"


func _slot_number(file_name: String) -> int:
	# Only slot_N.save and its .bak and temporary files count. A .corrupt file doesn't.
	var base := file_name
	for suffix in [".bak", ".tmp2", ".tmp"]:
		if base.ends_with(suffix):
			base = base.substr(0, base.length() - suffix.length())
			break
	if not base.begins_with("slot_") or not base.ends_with(".save"):
		return -1
	var digits := base.substr("slot_".length(), base.length() - "slot_".length() - ".save".length())
	if digits.is_empty() or not digits.is_valid_int():
		return -1
	var slot := digits.to_int()
	if slot < 0 or str(slot) != digits:
		return -1
	return slot


func _check_slot(slot: int) -> Error:
	if slot < 0:
		return _fail("Save: slot must be 0 or greater.", ERR_INVALID_PARAMETER)
	return OK


func _setting(key: String, default: Variant) -> Variant:
	if ProjectSettings.has_setting(key):
		return ProjectSettings.get_setting(key)
	return default


func _flag(key: String, default: bool) -> bool:
	var value: Variant = _setting(key, default)
	if typeof(value) != TYPE_BOOL:
		return default
	return value


func _number(key: String, default: float) -> float:
	var value: Variant = _setting(key, default)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default
	return float(value)


func _validate(value: Variant, path: String, depth: int) -> Error:
	if depth > MAX_DEPTH:
		return _fail("Save: %s is nested too deeply." % path, ERR_INVALID_DATA)
	var type := typeof(value)
	if type == TYPE_ARRAY:
		for index in value.size():
			var err := _validate(value[index], "%s[%d]" % [path, index], depth + 1)
			if err != OK:
				return err
		return OK
	if type == TYPE_DICTIONARY:
		for key in value.keys():
			var key_err := _validate(key, "%s key" % path, depth + 1)
			if key_err != OK:
				return key_err
			var value_err := _validate(value[key], "%s.%s" % [path, str(key)], depth + 1)
			if value_err != OK:
				return value_err
		return OK
	if _is_plain(type):
		return OK
	return _fail("Save: %s is a %s, which can't be stored." % [path, type_string(type)], ERR_INVALID_DATA)


func _is_plain(type: int) -> bool:
	match type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH, \
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I, \
		TYPE_TRANSFORM2D, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, \
		TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION, TYPE_COLOR, TYPE_PACKED_BYTE_ARRAY, \
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return true
	return false


func _normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var copy := {}
			for key in value.keys():
				var stored_key = key
				if key is String or key is StringName:
					stored_key = String(key)
				copy[stored_key] = _normalize(value[key])
			return copy
		TYPE_ARRAY:
			var copy := []
			for item in value:
				copy.append(_normalize(item))
			return copy
	return value


func _fail(message: String, code: Error) -> Error:
	push_error(message)
	return code
