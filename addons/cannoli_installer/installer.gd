@tool
extends Node
## Fetches the Cannoli manifest and installs packages from the GitHub archive.

signal manifest_loaded(packages: Array)
## [param fraction] is in 0..1, or negative when progress is unknown.
signal progress(fraction: float, message: String)
signal installed(packages: Array)
signal failed(message: String)

const REPO := "genr234/cannoli"
## Branch or tag to install from.
const REF := "main"
const SELF_ID := "cannoli_installer"
const TMP_ZIP := "user://cannoli_download.zip"

## Share of the progress bar used by the download; extraction fills the rest.
const DOWNLOAD_SHARE := 0.7

var manifest_url := "https://raw.githubusercontent.com/%s/%s/packages.json" % [REPO, REF]
var archive_url := "https://github.com/%s/archive/%s.zip" % [REPO, REF]

var _manifest_http: HTTPRequest
var _zip_http: HTTPRequest
var _busy := false


func _ready() -> void:
	_manifest_http = HTTPRequest.new()
	_manifest_http.request_completed.connect(_on_manifest_completed)
	add_child(_manifest_http)

	_zip_http = HTTPRequest.new()
	_zip_http.download_file = TMP_ZIP
	add_child(_zip_http)

	set_process(false)


func is_busy() -> bool:
	return _busy


func fetch_manifest() -> void:
	_manifest_http.cancel_request()
	var err := _manifest_http.request(manifest_url, ["Cache-Control: no-cache"])
	if err != OK:
		failed.emit("Could not request the package list (%s)." % error_string(err))


static func is_installed(pkg: Dictionary) -> bool:
	return DirAccess.dir_exists_absolute("res://" + pkg.path)


## Installs [param packages] (dictionaries from the manifest), replacing existing folders.
func install(packages: Array) -> void:
	if _busy:
		return
	_busy = true

	if FileAccess.file_exists(TMP_ZIP):
		DirAccess.remove_absolute(TMP_ZIP)

	var err := _zip_http.request(archive_url)
	if err != OK:
		_fail("Could not start the download (%s)." % error_string(err))
		return

	progress.emit(-1.0, "Downloading…")
	set_process(true)
	var response: Array = await _zip_http.request_completed
	set_process(false)

	var result: int = response[0]
	var code: int = response[1]
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Download failed: %s." % _result_text(result))
		return
	if code != 200:
		_fail("Download failed: HTTP %d." % code)
		return

	await _extract(packages)


func _process(_delta: float) -> void:
	var bytes := _zip_http.get_downloaded_bytes()
	var total := _zip_http.get_body_size()
	var message := "Downloading… %s" % String.humanize_size(bytes)
	if total > 0:
		progress.emit(DOWNLOAD_SHARE * bytes / total, message)
	else:
		progress.emit(-1.0, message)


func _extract(packages: Array) -> void:
	progress.emit(DOWNLOAD_SHARE, "Extracting…")

	var reader := ZIPReader.new()
	if reader.open(TMP_ZIP) != OK:
		_fail("The downloaded archive could not be opened.")
		return

	# GitHub archives wrap everything in a "<repo>-<ref>/" folder; strip it.
	var writes: Array = []  # [zip entry, project-relative path]
	var found := {}
	for entry: String in reader.get_files():
		if entry.ends_with("/"):
			continue
		var slash := entry.find("/")
		if slash < 0:
			continue
		var rel := entry.substr(slash + 1)
		if ".." in rel.split("/"):
			continue
		for pkg: Dictionary in packages:
			if rel.begins_with(pkg.path + "/"):
				writes.append([entry, rel])
				found[pkg.id] = true
				break

	for pkg: Dictionary in packages:
		if not found.has(pkg.id):
			reader.close()
			_fail("“%s” was not found in the downloaded archive." % pkg.name)
			return

	# Replace existing copies so stale files don't linger.
	for pkg: Dictionary in packages:
		var dir: String = "res://" + pkg.path
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var cfg := dir.path_join("plugin.cfg")
		if EditorInterface.is_plugin_enabled(cfg):
			EditorInterface.set_plugin_enabled(cfg, false)
		var err := remove_dir(dir)
		if err != OK:
			reader.close()
			_fail("Could not remove the old %s (%s)." % [dir, error_string(err)])
			return

	for i in writes.size():
		var entry: String = writes[i][0]
		var target: String = "res://" + writes[i][1]
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			reader.close()
			_fail("Could not write %s (%s)." % [target, error_string(FileAccess.get_open_error())])
			return
		file.store_buffer(reader.read_file(entry))
		file.close()
		if i % 25 == 0:
			var fraction := DOWNLOAD_SHARE + (0.95 - DOWNLOAD_SHARE) * i / writes.size()
			progress.emit(fraction, "Extracting %s" % writes[i][1])
			await get_tree().process_frame

	reader.close()
	DirAccess.remove_absolute(TMP_ZIP)

	progress.emit(0.95, "Refreshing project…")
	await _rescan()

	for pkg: Dictionary in packages:
		if not pkg.plugin:
			continue
		var cfg: String = "res://%s/plugin.cfg" % pkg.path
		if FileAccess.file_exists(cfg):
			EditorInterface.set_plugin_enabled(cfg, true)
		else:
			push_warning("Cannoli: %s is marked as a plugin but has no plugin.cfg." % pkg.id)

	progress.emit(1.0, "Done.")
	_busy = false
	installed.emit(packages)


func _rescan() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	var deadline := Time.get_ticks_msec() + 30000
	await get_tree().process_frame
	while fs.is_scanning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _on_manifest_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Could not fetch the package list: %s." % _result_text(result))
		return
	if code != 200:
		failed.emit("Could not fetch the package list: HTTP %d." % code)
		return
	var packages: Variant = parse_manifest(JSON.parse_string(body.get_string_from_utf8()))
	if packages == null:
		failed.emit("The package list is malformed.")
		return
	manifest_loaded.emit(packages)


## Returns the validated package list, or null if [param data] isn't a manifest.
static func parse_manifest(data: Variant) -> Variant:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("packages")) != TYPE_ARRAY:
		return null
	var out: Array = []
	var seen := {}
	for entry: Variant in data.packages:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("id", ""))
		var path := str(entry.get("path", ""))
		if id.is_empty() or id == SELF_ID or seen.has(id):
			continue
		if not _is_safe_path(path):
			push_warning("Cannoli: skipping %s, invalid path \"%s\"." % [id, path])
			continue
		var deps: Array = []
		var raw_deps: Variant = entry.get("dependencies", [])
		if typeof(raw_deps) == TYPE_ARRAY:
			for dep: Variant in raw_deps:
				deps.append(str(dep))
		seen[id] = true
		out.append({
			"id": id,
			"name": str(entry.get("name", id)),
			"description": str(entry.get("description", "")),
			"path": path,
			"dependencies": deps,
			"plugin": bool(entry.get("plugin", false)),
		})
	return out


static func _is_safe_path(path: String) -> bool:
	return (
		path.begins_with("addons/")
		and path.length() > "addons/".length()
		and path.simplify_path() == path
		and not ".." in path.split("/")
		and not "\\" in path
		and not path.begins_with("addons/" + SELF_ID)
	)


## Moves [param res_path] to the trash, falling back to deleting it.
static func remove_dir(res_path: String) -> Error:
	if OS.move_to_trash(ProjectSettings.globalize_path(res_path)) == OK:
		return OK
	return _delete_recursive(res_path)


static func _delete_recursive(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()
	dir.include_hidden = true
	for file in dir.get_files():
		var err := DirAccess.remove_absolute(path.path_join(file))
		if err != OK:
			return err
	for sub in dir.get_directories():
		var err := _delete_recursive(path.path_join(sub))
		if err != OK:
			return err
	return DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_busy = false
	set_process(false)
	failed.emit(message)


static func _result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE:
			return "could not connect (are you online?)"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed"
		HTTPRequest.RESULT_TIMEOUT:
			return "timed out"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "too many redirects"
		_:
			return "error %d" % result
