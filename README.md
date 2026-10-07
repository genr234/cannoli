# Cannoli

Gameplay and editor addons for **Godot 4.7+**. Install only the packages you need; optional integrations activate when their companion addon is present.

| Package | Purpose | Guide |
| --- | --- | --- |
| Relationships | Factions, affinity, emotions, deeds and gossip | [Setup and API](addons/relationships/README.md) |
| Save | Save slots, recovery, migrations and autosave | [Setup and API](addons/save/README.md) |
| Quests | Quest graphs, procedural generation, dialogue and journals | [Setup and API](addons/quests/README.md) |
| Juice | Game feel effects, sequences, camera shakes and springs | [Setup and API](addons/juice/README.md) |
| Behaviors | Behavior trees, utility AI, perception and steering | [Setup and API](addons/behaviors/README.md) |

## Install

1. Download `cannoli_installer.zip` from [Releases](https://github.com/genr234/cannoli/releases) and extract it into your Godot project. The ZIP contains `addons/cannoli_installer`.
2. Enable **Cannoli Installer** in **Project → Project Settings → Plugins**.
3. Open **Project → Tools → Cannoli Installer…**, select a release and the packages you want, then install. The installer enables the selected plugins.
4. Follow the package guide above to add its nodes and resources to your game.

You can also extract individual package ZIPs into your project and enable their plugins manually. Keep the included `LICENSE` files when redistributing. The installer's `main (development)` source follows unreleased code; choose a tagged release for production.

The installer updates by replacing the entire addon folder. Keep local changes in version control. If a rollback fails, its error names the preserved `.old` folder under `addons/.cannoli_staging`; recover or move that folder before retrying.

## Try the demo

Clone this repository and open `project.godot` in Godot 4.7+. Run the project (F6 runs the current scene; F5 runs the demo). Collect coins to preview Juice, then save and load the counter through Save. Demo saves use `user://cannoli_demo`, separate from the default game save directory.

Quests, Relationships and Behaviors editor tools are enabled too; their guides show how to create their resources and scenes. `examples/installer_package` is a development fixture and is excluded from the public package catalog.

## Validate and release

```sh
python3 tools/validate_manifest.py
python3 tools/check_godot.py --godot /path/to/godot
python3 tools/build_release.py dist
```

The Godot check builds the actual release ZIPs and opens disposable projects for every addon alone and all together. It checks clean imports, reopening, resource loading, plugin disable/re-enable, Save autoload ownership, installer recovery, and the demo's save/load flow. Harnesses and logs stay outside the repository and packages.

Before publishing, commit the intended addon code and assets, ensure CI passes, and push a `vX.Y.Z` tag. The release workflow uploads the manifest, package ZIPs and installer ZIP. Use `vX.Y.Z-beta.1` for a prerelease. See [Asset Library publishing](docs/asset-library.md) for the manual listing step.

## License

[MIT](LICENSE), copyright © 2026 genr234.
