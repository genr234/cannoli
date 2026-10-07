@tool
extends Node
## Lists Cannoli releases, fetches their manifests, and installs or uninstalls packages.

signal sources_loaded(sources: Array, warning: String)
signal manifest_loaded(packages: Array)
## [param fraction] is in 0..1, or negative when progress is unknown.
signal progress(fraction: float, message: String)
signal cancellable_changed(cancellable: bool)
## [param errors] is empty when every package was installed.
signal install_finished(installed: Array, errors: PackedStringArray)
signal install_cancelled
signal uninstalled(pkg: Dictionary)
signal failed(message: String)

signal _download_done(result: int, code: int)

const REPO := "genr234/cannoli"
## Development branch, offered after the releases.
const BRANCH := "main"
const SELF_ID := "cannoli_installer"
## Written into each installed package so the installer knows its version.
const RECORD_FILE := ".cannoli.json"
## Hidden folders are ignored by the editor's filesystem scan.
const STAGING := "res://addons/.cannoli_staging"
const DOWNLOADS := "user://cannoli_downloads"
## Share of the progress bar used by downloads; unpacking fills most of the rest.
const DOWNLOAD_SHARE := 0.7
const RESULT_CANCELLED := -1

var releases_url := "https://api.github.com/repos/%s/releases" % REPO
var branch_manifest_url := "https://raw.githubusercontent.com/%s/%s/packages.json" % [REPO, BRANCH]
var branch_archive_url := "https://github.com/%s/archive/refs/heads/%s.zip" % [REPO, BRANCH]

var _releases_http: HTTPRequest
var _manifest_http: HTTPRequest
var _zip_http: HTTPRequest
var _manifest_source := {}
var _busy := false
var _cancelled := false
var _cancellable := false
var _downloading := false
var _download_offset := 0
var _download_total := 0


func _ready() -> void:
	_releases_http = HTTPRequest.new()
	_releases_http.request_completed.connect(_on_releases_completed)
	add_child(_releases_http)

	_manifest_http = HTTPRequest.new()
	_manifest_http.request_completed.connect(_on_manifest_completed)
	add_child(_manifest_http)

	_zip_http = HTTPRequest.new()
	_zip_http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			_download_done.emit(result, code)
	)
	add_child(_zip_http)

	set_process(false)


func is_busy() -> bool:
	return _busy


# --- Sources -------------------------------------------------------------------


## Lists releases (newest first) followed by the development branch.
func fetch_sources() -> void:
	_releases_http.cancel_request()
	var err := _releases_http.request(releases_url, ["Accept: application/vnd.github+json"])
	if err != OK:
		sources_loaded.emit([branch_source()], "Could not list releases (%s)." % error_string(err))


func branch_source() -> Dictionary:
	return {
		"kind": "branch",
		"ref": BRANCH,
		"label": "%s (development)" % BRANCH,
		"prerelease": true,
		"manifest_url": branch_manifest_url,
		"archive_url": branch_archive_url,
		"assets": {},
	}


func _on_releases_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sources: Array = []
	var warning := ""
	if result != HTTPRequest.RESULT_SUCCESS:
		warning = "Could not list releases: %s." % _result_text(result)
	elif code != 200:
		warning = "Could not list releases: HTTP %d." % code
	else:
		sources = parse_releases(JSON.parse_string(body.get_string_from_utf8()))
	sources.append(branch_source())
	sources_loaded.emit(sources, warning)


## Turns a GitHub releases API response into sources. Releases without a
## packages.json asset are skipped.
static func parse_releases(data: Variant) -> Array:
	var out: Array = []
	if typeof(data) != TYPE_ARRAY:
		return out
	for release: Variant in data:
		if typeof(release) != TYPE_DICTIONARY or release.get("draft", false):
			continue
		var assets := {}
		var raw_assets: Variant = release.get("assets", [])
		if typeof(raw_assets) == TYPE_ARRAY:
			for asset: Variant in raw_assets:
				if typeof(asset) == TYPE_DICTIONARY:
					assets[str(asset.get("name", ""))] = {
						"url": str(asset.get("browser_download_url", "")),
						"size": int(asset.get("size", 0)),
					}
		if not assets.has("packages.json"):
			continue
		var tag := str(release.get("tag_name", ""))
		var prerelease := bool(release.get("prerelease", false))
		out.append({
			"kind": "release",
			"ref": tag,
			"label": tag + (" (pre-release)" if prerelease else ""),
			"prerelease": prerelease,
			"manifest_url": assets["packages.json"].url,
			"assets": assets,
		})
	return out


# --- Manifest ------------------------------------------------------------------


func fetch_manifest(source: Dictionary) -> void:
	_manifest_http.cancel_request()
	_manifest_source = source
	var err := _manifest_http.request(source.manifest_url, ["Cache-Control: no-cache"])
	if err != OK:
		failed.emit("Could not request the package list (%s)." % error_string(err))


func _on_manifest_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Could not fetch the package list: %s." % _result_text(result))
		return
	if code != 200:
		failed.emit("Could not fetch the package list: HTTP %d." % code)
		return
	var parsed: Variant = parse_manifest(JSON.parse_string(body.get_string_from_utf8()))
	if parsed == null:
		failed.emit("The package list is malformed.")
		return

	# Release packages download from their own zip asset, whose size is known.
	var packages: Array = []
	for pkg: Dictionary in parsed:
		pkg["size"] = -1
		pkg["download_url"] = ""
		if _manifest_source.kind == "release":
			var asset: Variant = _manifest_source.assets.get(pkg.id + ".zip")
			if asset == null:
				push_warning("Cannoli: %s has no %s.zip asset, skipping." % [_manifest_source.ref, pkg.id])
				continue
			pkg.size = asset.size
			pkg.download_url = asset.url
		packages.append(pkg)
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
			"version": str(entry.get("version", "")),
			"description": str(entry.get("description", "")),
			"category": str(entry.get("category", "")),
			"url": str(entry.get("url", "")),
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
		and not path.get_file().begins_with(".")
		and not path.begins_with("addons/" + SELF_ID)
	)


# --- Installed state -----------------------------------------------------------


static func is_installed(pkg: Dictionary) -> bool:
	return DirAccess.dir_exists_absolute("res://" + pkg.path)


## The record written at install time, or an empty dictionary if the folder
## wasn't installed by Cannoli.
static func read_record(pkg: Dictionary) -> Dictionary:
	var path := "res://%s/%s" % [pkg.path, RECORD_FILE]
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Compares dotted versions ("1.2.0", "v1.10", "2.0.0-beta"). Returns -1, 0 or 1.
static func compare_versions(a: String, b: String) -> int:
	var a_parts := a.trim_prefix("v").split("-", true, 1)
	var b_parts := b.trim_prefix("v").split("-", true, 1)
	var a_nums := a_parts[0].split(".")
	var b_nums := b_parts[0].split(".")
	for i in maxi(a_nums.size(), b_nums.size()):
		var x := a_nums[i].to_int() if i < a_nums.size() else 0
		var y := b_nums[i].to_int() if i < b_nums.size() else 0
		if x != y:
			return -1 if x < y else 1
	# A pre-release sorts before its release.
	var a_pre := a_parts[1] if a_parts.size() > 1 else ""
	var b_pre := b_parts[1] if b_parts.size() > 1 else ""
	if a_pre == b_pre:
		return 0
	if a_pre.is_empty() or b_pre.is_empty():
		return 1 if a_pre.is_empty() else -1
	return -1 if a_pre < b_pre else 1


# --- Install -------------------------------------------------------------------


## Installs [param packages] from [param source], replacing existing folders.
## Files are unpacked into a staging folder first, so a failed or cancelled
## install leaves the project untouched.
func install(packages: Array, source: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_cancelled = false

	var jobs: Array = []  # {url, file, size, packages}
	if source.kind == "release":
		for pkg: Dictionary in packages:
			jobs.append({
				"url": pkg.download_url,
				"file": DOWNLOADS.path_join(pkg.id + ".zip"),
				"size": pkg.size,
				"packages": [pkg],
			})
	else:
		jobs.append({
			"url": source.archive_url,
			"file": DOWNLOADS.path_join("archive.zip"),
			"size": -1,
			"packages": packages,
		})

	_cleanup()
	DirAccess.make_dir_recursive_absolute(DOWNLOADS)
	_set_cancellable(true)
	if not await _download_all(jobs):
		return
	if not await _stage(jobs, source):
		return
	_set_cancellable(false)
	await _commit(packages)


## Stops a download or unpack in progress. Has no effect once files are being
## moved into the project.
func cancel() -> void:
	if not _cancellable or _cancelled:
		return
	_cancelled = true
	if _downloading:
		_zip_http.cancel_request()
		_download_done.emit(RESULT_CANCELLED, 0)


func _download_all(jobs: Array) -> bool:
	_download_offset = 0
	_download_total = 0
	for job: Dictionary in jobs:
		if job.size <= 0:
			_download_total = 0
			break
		_download_total += job.size

	for job: Dictionary in jobs:
		_zip_http.download_file = job.file
		var err := _zip_http.request(job.url)
		if err != OK:
			_fail("Could not start the download (%s)." % error_string(err))
			return false
		_downloading = true
		set_process(true)
		var response: Array = await _download_done
		set_process(false)
		_downloading = false

		if _cancelled:
			_abort()
			return false
		if response[0] != HTTPRequest.RESULT_SUCCESS:
			_fail("Download failed: %s." % _result_text(response[0]))
			return false
		if response[1] != 200:
			_fail("Download failed: HTTP %d." % response[1])
			return false
		_download_offset += maxi(job.size, 0)
	return true


func _process(_delta: float) -> void:
	var bytes := _download_offset + _zip_http.get_downloaded_bytes()
	var total := _download_total
	if total <= 0 and _download_offset == 0:
		total = _zip_http.get_body_size()
	var message := "Downloading… %s" % String.humanize_size(bytes)
	if total > 0:
		progress.emit(DOWNLOAD_SHARE * minf(float(bytes) / total, 1.0), message)
	else:
		progress.emit(-1.0, message)


func _stage(jobs: Array, source: Dictionary) -> bool:
	progress.emit(DOWNLOAD_SHARE, "Unpacking…")
	for j in jobs.size():
		var job: Dictionary = jobs[j]
		var reader := ZIPReader.new()
		if reader.open(job.file) != OK:
			_fail("The downloaded archive could not be opened.")
			return false

		var writes: Array = []  # [zip entry, staging path]
		var found := {}
		for entry: String in reader.get_files():
			if entry.ends_with("/"):
				continue
			for pkg: Dictionary in job.packages:
				var sub := _path_in_package(entry, pkg.path)
				if not sub.is_empty():
					writes.append([entry, STAGING.path_join(pkg.id).path_join(sub)])
					found[pkg.id] = true
					break

		for pkg: Dictionary in job.packages:
			if not found.has(pkg.id):
				reader.close()
				_fail("“%s” was not found in the downloaded archive." % pkg.name)
				return false

		for i in writes.size():
			var target: String = writes[i][1]
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null:
				reader.close()
				_fail("Could not write %s (%s)." % [target, error_string(FileAccess.get_open_error())])
				return false
			file.store_buffer(reader.read_file(writes[i][0]))
			file.close()
			if i % 25 == 0:
				var done := (j + float(i) / writes.size()) / jobs.size()
				progress.emit(DOWNLOAD_SHARE + (0.9 - DOWNLOAD_SHARE) * done, "Unpacking %s" % writes[i][0].get_file())
				await get_tree().process_frame
				if _cancelled:
					reader.close()
					_abort()
					return false
		reader.close()

		for pkg: Dictionary in job.packages:
			var record := {
				"id": pkg.id,
				"version": pkg.version,
				"source": source.ref,
				"installed_at": Time.get_datetime_string_from_system(true),
			}
			var file := FileAccess.open(STAGING.path_join(pkg.id).path_join(RECORD_FILE), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(record, "\t") + "\n")
				file.close()
	return true


## Maps a zip entry to its path inside the package at [param pkg_path], or ""
## if it belongs elsewhere. Release zips hold "addons/<id>/…"; branch archives
## wrap the repo in a "<repo>-<ref>/" folder.
static func _path_in_package(entry: String, pkg_path: String) -> String:
	var prefix := pkg_path + "/"
	var rel := entry
	if not rel.begins_with(prefix):
		var slash := rel.find("/")
		rel = rel.substr(slash + 1) if slash >= 0 else ""
		if not rel.begins_with(prefix):
			return ""
	var sub := rel.substr(prefix.length())
	if sub.is_empty() or ".." in sub.split("/") or sub.get_file() == RECORD_FILE:
		return ""
	return sub


func _commit(packages: Array) -> void:
	progress.emit(0.9, "Installing…")
	var installed: Array = []
	var errors := PackedStringArray()
	for pkg: Dictionary in packages:
		var error := _swap_in(pkg)
		if error.is_empty():
			installed.append(pkg)
		else:
			errors.append("%s: %s" % [pkg.name, error])

	# Replaced copies go to the trash so local edits can be recovered.
	for pkg: Dictionary in installed:
		var old := STAGING.path_join(pkg.id + ".old")
		if DirAccess.dir_exists_absolute(old):
			var trash_err := OS.move_to_trash(ProjectSettings.globalize_path(old))
			if trash_err != OK:
				errors.append("%s was installed, but its previous version could not be moved to the trash; it is preserved at %s" % [pkg.name, old])
	_cleanup()

	progress.emit(0.95, "Refreshing project…")
	await _rescan()
	for pkg: Dictionary in installed:
		if not pkg.plugin:
			continue
		var cfg: String = "res://%s/plugin.cfg" % pkg.path
		if FileAccess.file_exists(cfg):
			EditorInterface.set_plugin_enabled(cfg, true)
		else:
			push_warning("Cannoli: %s is marked as a plugin but has no plugin.cfg." % pkg.id)

	progress.emit(1.0, "Done.")
	_busy = false
	install_finished.emit(installed, errors)


## Moves the staged copy of [param pkg] into place. Returns an error message,
## or "" on success. On failure the previous version is restored.
func _swap_in(pkg: Dictionary) -> String:
	var target: String = "res://" + pkg.path
	var staged := STAGING.path_join(pkg.id)
	var old := STAGING.path_join(pkg.id + ".old")
	if DirAccess.dir_exists_absolute(old):
		return "a previous recovery copy exists at %s; recover or move it before retrying" % old
	var cfg := target.path_join("plugin.cfg")
	var had_old := DirAccess.dir_exists_absolute(target)
	var was_enabled := had_old and EditorInterface.is_plugin_enabled(cfg)

	if had_old:
		if was_enabled:
			EditorInterface.set_plugin_enabled(cfg, false)
		var err := DirAccess.rename_absolute(target, old)
		if err != OK:
			if was_enabled:
				EditorInterface.set_plugin_enabled(cfg, true)
			return "could not move the old version aside (%s)" % error_string(err)

	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var err := DirAccess.rename_absolute(staged, target)
	if err != OK:
		if had_old:
			var restore_err := DirAccess.rename_absolute(old, target)
			if restore_err != OK:
				return "installation failed (%s) and restoration failed (%s); the previous version is preserved at %s" % [error_string(err), error_string(restore_err), old]
			if was_enabled:
				EditorInterface.set_plugin_enabled(cfg, true)
		return "could not move the new version into place (%s)" % error_string(err)
	return ""


# --- Uninstall -----------------------------------------------------------------


## Disables the package's plugin and moves its folder to the trash.
func uninstall(pkg: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	var target: String = "res://" + pkg.path
	var cfg := target.path_join("plugin.cfg")
	if EditorInterface.is_plugin_enabled(cfg):
		EditorInterface.set_plugin_enabled(cfg, false)
	var err := remove_dir(target)
	if err != OK:
		_busy = false
		failed.emit("Could not remove %s (%s)." % [target, error_string(err)])
		return
	await _rescan()
	_busy = false
	uninstalled.emit(pkg)


# --- Helpers -------------------------------------------------------------------


func _rescan() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	var deadline := Time.get_ticks_msec() + 30000
	await get_tree().process_frame
	while fs.is_scanning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


## Moves [param res_path] to the trash, falling back to deleting it.
static func remove_dir(res_path: String) -> Error:
	if OS.move_to_trash(ProjectSettings.globalize_path(res_path)) == OK:
		return OK
	return delete_recursive(res_path)


static func delete_recursive(path: String) -> Error:
	var dir := DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()
	dir.include_hidden = true
	for file in dir.get_files():
		var err := DirAccess.remove_absolute(path.path_join(file))
		if err != OK:
			return err
	for sub in dir.get_directories():
		var err := delete_recursive(path.path_join(sub))
		if err != OK:
			return err
	return DirAccess.remove_absolute(path)


## Removes the staging folder and downloaded archives.
func _cleanup() -> void:
	# Recovery copies survive failed rollback, cancellation and subsequent installs.
	var staging := DirAccess.open(STAGING)
	if staging != null:
		staging.include_hidden = true
		for folder in staging.get_directories():
			if not folder.ends_with(".old"):
				delete_recursive(STAGING.path_join(folder))
		for file in staging.get_files():
			DirAccess.remove_absolute(STAGING.path_join(file))
		DirAccess.remove_absolute(STAGING)  # Only succeeds when no backups remain.
	if DirAccess.dir_exists_absolute(DOWNLOADS):
		delete_recursive(DOWNLOADS)


func _set_cancellable(value: bool) -> void:
	_cancellable = value
	cancellable_changed.emit(value)


func _fail(message: String) -> void:
	_cleanup()
	_busy = false
	set_process(false)
	_set_cancellable(false)
	failed.emit(message)


func _abort() -> void:
	_cleanup()
	_busy = false
	_set_cancellable(false)
	install_cancelled.emit()


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
