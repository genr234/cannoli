# Save

Save slots, autosave, recovery and migrations for **Godot 4.7+**. Each system supplies a dictionary; Save handles the files.

[![Download Save](download.svg)](https://github.com/genr234/cannoli/releases/download/latest-build/save.zip)

[Full guide →](GUIDE.md) · [Cannoli →](https://github.com/genr234/cannoli)

## Install

Extract the ZIP into your project and enable **Save** in **Project → Project Settings → Plugins**. This adds the `Save` autoload.

## Get started

```gdscript
Save.set_value("player", "hp", 100)
Save.start_slot(1)  # Write a new slot after setting up the game.
Save.set_value("player", "hp", 80)
Save.save()
Save.load_slot(1)
var hp := Save.get_value("player", "hp", 100)
```

For scene data, register providers with `Save.register_section()` and restore it from the `loaded` signal. A provider replaces its entire section when saving.

| Feature | Details |
| --- | --- |
| Slots | Metadata for load menus, backups and corrupt-file recovery |
| Autosave | Timer, focus loss, pause and window close; async writes |
| Storage | Compression, optional encryption and version migrations |

Files default to `user://saves`. Configure them under **Project Settings → Save**. Set up a new game before calling `start_slot()`; use `Save.quit()` when quitting from code. Encryption deters casual editing; the password ships with the game.

See the guide for [providers](GUIDE.md#saving-a-system), [settings](GUIDE.md#setup), [autosave](GUIDE.md#autosave) and [migrations](GUIDE.md#versions).

[MIT](LICENSE).
