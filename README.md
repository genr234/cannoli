# Cannoli

Modular gameplay and editor addons for **Godot 4.7+**. Pick what you need; companion addons integrate automatically.

[![Download Cannoli Installer](assets/download-installer.svg)](https://github.com/genr234/cannoli/releases/download/latest-build/cannoli_installer.zip)

Downloads follow the latest `main` build that passed CI. [Tagged releases →](https://github.com/genr234/cannoli/releases)

| Addon & guide | What it does | Download |
| --- | --- | --- |
| [Relationships](addons/relationships/README.md) | Factions, affinity, emotions and gossip | [![Download ZIP](https://img.shields.io/badge/Download-ZIP-efad66?style=flat-square&labelColor=482d20)](https://github.com/genr234/cannoli/releases/download/latest-build/relationships.zip) |
| [Save](addons/save/README.md) | Save slots, recovery, migrations and autosave | [![Download ZIP](https://img.shields.io/badge/Download-ZIP-efad66?style=flat-square&labelColor=482d20)](https://github.com/genr234/cannoli/releases/download/latest-build/save.zip) |
| [Quests](addons/quests/README.md) | Quest graphs, generation, dialogue and journals | [![Download ZIP](https://img.shields.io/badge/Download-ZIP-efad66?style=flat-square&labelColor=482d20)](https://github.com/genr234/cannoli/releases/download/latest-build/quests.zip) |
| [Juice](addons/juice/README.md) | Effects, sequences, camera shakes and springs | [![Download ZIP](https://img.shields.io/badge/Download-ZIP-efad66?style=flat-square&labelColor=482d20)](https://github.com/genr234/cannoli/releases/download/latest-build/juice.zip) |
| [Behaviors](addons/behaviors/README.md) | Behavior trees, utility AI, perception and steering | [![Download ZIP](https://img.shields.io/badge/Download-ZIP-efad66?style=flat-square&labelColor=482d20)](https://github.com/genr234/cannoli/releases/download/latest-build/behaviors.zip) |

## Install

1. Download the installer above and extract it into your Godot project.
2. Enable **Cannoli Installer** in **Project → Project Settings → Plugins**.
3. Open **Project → Tools → Cannoli Installer…**, choose a release and your addons, then install.

Prefer manual setup? Extract individual addon ZIPs and enable them in **Plugins**. Updates replace addon folders, so keep local changes in version control.

## Validate and release

```sh
python3 tools/validate_manifest.py
python3 tools/check_godot.py --godot /path/to/godot
python3 tools/build_release.py dist
```

Every push to `main` refreshes the download ZIPs after CI passes. Push a `vX.Y.Z` tag for a versioned release. See [Asset Library publishing](docs/asset-library.md) for listing instructions.

## License

[MIT](LICENSE) © 2026 genr234. Keep included licenses when redistributing.
