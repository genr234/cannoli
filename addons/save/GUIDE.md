# Save

Slot files for game data, for Godot 4.7+.

Each system hands Save a dictionary. Save writes those dictionaries into a slot file, on request and on a timer. It does not look at the scene tree.

## Setup

Enable **Save** in **Project → Project Settings → Plugins**. This adds a `Save` autoload and these project settings:

| Setting | Default | What it does |
| --- | --- | --- |
| `save/directory` | `user://saves` | Folder for slot files. |
| `save/autosave_enabled` | `true` | Timer, focus loss, pause, and window close. |
| `save/autosave_seconds` | `180` | Seconds between timer writes. |
| `save/compress` | `true` | Zstd compression. Stored in the file, so old files still load if you change it. |
| `save/encryption_password` | empty | Empty means off. A password encrypts the data and metadata with AES-256. It must stay the same for existing saves, and it only stops casual editing. See [Encryption](#encryption). |
| `save/version` | `1` | Written into new files. Raise it when saved data changes shape. |

## Saving a system

Register a function per system. It returns the dictionary that system already knows how to build. Relationships needs no changes:

```gdscript
Save.register_section("relationships", func() -> Dictionary:
	return FactionManager.instance.record_data())

Save.loaded.connect(func(_slot: int) -> void:
	if Save.has_section("relationships"):
		FactionManager.instance.apply_data(Save.get_section("relationships")))

Save.load_slot(1)
```

`loaded` runs before `load_slot` returns. Apply data in that function. Saving from it is fine.

`save` asks every provider for fresh data, then writes the active slot. Small values can live in their own section, with no provider:

```gdscript
Save.set_value("player", "hp", 80)
var hp := Save.get_value("player", "hp", 100)
```

`get_value` returns the default when the key is missing and does not create it. A provider replaces its whole section on the next `save`, so don't also `set_value` inside a section that has one.

## Slots

```gdscript
Save.start_slot(1)   # new game: writes slot_1.save
Save.load_slot(1)
Save.save()
Save.has_slot(1)
Save.list_slots()
Save.delete_slot(1)
Save.get_slot()      # -1 when no slot is active
```

Files are `user://saves/slot_1.save`. Writes go to a temporary file, then replace the real one. The previous file is kept as `slot_1.save.bak`. If the main file is missing or can't be read, Save loads the temporary file when that write finished, otherwise the backup, and writes the main file again.

A main file that can't be read is renamed to `slot_1.save.corrupt` first (replacing an older one), so the good backup isn't rotated out. A slot with only a `.corrupt` file doesn't exist as far as `has_slot` and `list_slots` are concerned. `delete_slot` removes the main file, `.bak`, `.corrupt`, and temporary files.

`start_slot` asks providers and writes immediately. Set up the new game, then call it: providers and `set_value` data are written as they are. Values set while no slot was active are kept. If another slot was active, its data and metadata are dropped first. On failure the previous state comes back.

## Load menus

`get_slot_info` reads a slot's header without decompressing or decoding the data:

```gdscript
Save.set_slot_meta({"chapter": 3, "label": "Forest", "playtime": 5400})   # active slot, saved with it
var info := Save.get_slot_info(1)
# {"slot": 1, "version": 1, "modified": 1760000000, "saved_at": 1760000000,
#  "meta": {"chapter": 3, ...}, "encrypted": false}
```

It returns `{}` when the slot is missing or unreadable, and falls back to the temporary file and backup like `load_slot`. `modified` is the file's time, `saved_at` the time written in it. Metadata is plain data up to 64 KiB, is encrypted when the data is, and counts as a change. Set it before saving; `get_slot_meta` reads it back.

## Autosave

Once a slot is loaded or started, Save writes it when something changed:

- every `save/autosave_seconds` (default 3 minutes)
- when the window loses focus, or the app is paused
- when the window is closed

`save/autosave_enabled` turns those off. `Save.save()` still works.

`Save.block_autosave()` pauses all of them, for a cutscene or a loading screen where providers would return half a game. It counts, so call `Save.unblock_autosave()` once per block. `Save.is_autosave_blocked()` tells you. Manual saves and `Save.quit()` ignore it.

The timer and focus saves run in the background (see below). The pause and window-close saves are synchronous.

## Quitting

Save does not write when the node leaves the tree: autoloads exit after the current scene, so providers that read scene nodes would fail. A quit that comes from code needs to save itself:

```gdscript
Save.quit()      # saves the active slot, then get_tree().quit()
Save.quit(1)     # with an exit code
```

Or call `Save.save()` before `get_tree().quit()`. `Save.quit()` saves whenever a slot is active, whatever `save/autosave_enabled` says. Both wait for a background write that is still running.

## Signals

| Signal | Emitted |
| --- | --- |
| `loaded(slot)` | After `load_slot`. Saving or starting a slot from it is fine. |
| `saved(slot)` | After a write. Skipped when nothing changed. |
| `started(slot)` | After `start_slot` wrote the new slot. |
| `save_failed(slot, error)` | When `save`, `save_async`, autosave, or `start_slot` fails to write. |
| `about_to_save(slot)` | Before providers are asked for data. |

## Async saving

`Save.save_async()` asks providers and serializes on the main thread, then compresses, encrypts, hashes, and writes on a worker thread. It returns `OK` once queued. The result arrives as `saved` or `save_failed` on the main thread. Any other slot call made before then, including `save`, waits for it first. Autosave uses it. Quit paths wait for a running write and then save synchronously.

## Encryption

With a password set, Save encrypts the metadata and the data in memory with AES-256-CBC (key is the SHA-256 of the password, random IV per body, PKCS7 padding). The header stays readable. It holds a hash of the key, so a wrong password gets a clear `ERR_UNAUTHORIZED` ("encrypted and the password doesn't match") instead of looking like corruption. A wrong or missing password never moves a file to `.corrupt` or falls back to a backup.

A plain slot still loads when a password is set, and is encrypted on the next save. An encrypted slot with no password is refused. This is for stopping casual editing, not for secrets: the key is derived from a project setting that ships with the game.

## Versions

Raise `save/version` when the dictionaries change shape, and set a migration once at startup:

```gdscript
Save.set_migration(func(from_version: int, sections: Dictionary) -> Dictionary:
	if from_version < 2 and sections.has("player"):
		sections.player.health = sections.player.get("hp", 100)
		sections.player.erase("hp")
	return sections)
```

A file newer than this project is refused. An older file with no migration is refused. After a migration, the slot is written again at the current version.

## What is stored

Bools, numbers, strings, Godot math types (`Vector2`, `Color`, and the rest), arrays, and dictionaries. Objects, callables, and signals are refused, so a save cannot carry a script.

## File layout

All integers are little-endian. Format 2 (127-byte header):

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 4 | `CNS1` |
| 4 | 2 | format number (2) |
| 6 | 1 | flags: 1 compressed, 2 encrypted |
| 7 | 4 | game version (`save/version`) |
| 11 | 8 | saved at, Unix time |
| 19 | 4 | data size before compression |
| 23 | 4 | metadata size on disk |
| 27 | 4 | data size on disk |
| 31 | 16 | metadata IV (zeros when plain) |
| 47 | 16 | data IV (zeros when plain) |
| 63 | 32 | SHA-256 of the key (zeros when plain) |
| 95 | 32 | SHA-256 of every byte before it, plus the metadata and data as stored |

The metadata bytes follow, then the data bytes. Metadata is a `var_to_bytes` dictionary. Data is the `var_to_bytes` sections, zstd-compressed if flagged, then encrypted if flagged. A checksum mismatch is `ERR_FILE_CORRUPT`; the checksum covers the bytes on disk, so it needs no password.

Format 1 files (0.1.0: no metadata, no checksum, the whole file encrypted by Godot when a password was set) still load, and become format 2 on the next save.

Folder contents for slot 1: `slot_1.save`, `slot_1.save.bak`, `slot_1.save.corrupt`, and `slot_1.save.tmp` or `.tmp2` while a write is in progress.
