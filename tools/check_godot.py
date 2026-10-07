#!/usr/bin/env python3
"""Validate release ZIPs in disposable Godot projects (no tests ship in addons).

Usage: python3 tools/check_godot.py --godot /path/to/godot
Checks clean import, resource loading, plugin lifecycle and installer recovery.
"""
import argparse
import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

from build_release import build
from validate_manifest import validate

HARNESS = '''@tool
extends EditorPlugin

func _enter_tree() -> void:
    _run.call_deferred()

func _run() -> void:
    # Let editor initialization finish before changing plugin state.
    await get_tree().create_timer(1.0).timeout
    var plugins: Array = JSON.parse_string(FileAccess.get_file_as_string("res://smoke_plugins.json"))
    for cfg: String in plugins:
        assert(EditorInterface.is_plugin_enabled(cfg), "Plugin did not enable: " + cfg)
    var resources: Array = JSON.parse_string(FileAccess.get_file_as_string("res://smoke_resources.json"))
    for path: String in resources:
        assert(load(path) != null, "Resource did not load: " + path)
    for cfg: String in plugins:
        EditorInterface.set_plugin_enabled(cfg, false)
    await get_tree().process_frame
    if plugins.has("res://addons/save/plugin.cfg"):
        assert(not ProjectSettings.has_setting("autoload/Save"), "Save autoload was left behind")
        ProjectSettings.set_setting("autoload/Save", "*res://foreign_save.gd")
        var save_plugin = load("res://addons/save/plugin.gd").new()
        assert(not save_plugin._is_own_autoload("*res://foreign_save.gd"), "Foreign autoload was claimed")
        save_plugin._exit_tree()
        assert(ProjectSettings.get_setting("autoload/Save") == "*res://foreign_save.gd", "Foreign autoload was removed")
        ProjectSettings.set_setting("autoload/Save", null)
        save_plugin.free()
    for cfg: String in plugins:
        EditorInterface.set_plugin_enabled(cfg, true)
        assert(EditorInterface.is_plugin_enabled(cfg), "Plugin did not re-enable: " + cfg)
    if plugins.has("res://addons/save/plugin.cfg"):
        var save_plugin = load("res://addons/save/plugin.gd").new()
        var uid := ResourceLoader.get_resource_uid("res://addons/save/save.gd")
        assert(save_plugin._is_own_autoload("*" + ResourceUID.id_to_text(uid)), "Save UID was not recognized")
        save_plugin.free()
    if plugins.has("res://addons/cannoli_installer/plugin.cfg"):
        _check_recovery()
    await get_tree().process_frame
    await get_tree().process_frame
    ProjectSettings.save()
    print("CANNOLI_SMOKE_OK")
    get_tree().quit()

func _check_recovery() -> void:
    var installer = load("res://addons/cannoli_installer/installer.gd").new()
    var pkg := {"id": "smoke_target", "path": "addons/smoke_target"}
    var old: String = installer.STAGING.path_join("smoke_target.old")
    var target := "res://addons/smoke_target"
    DirAccess.make_dir_recursive_absolute(old)
    var file := FileAccess.open(old.path_join("valuable.txt"), FileAccess.WRITE)
    file.store_string("original")
    file.close()
    installer._cleanup()
    assert(FileAccess.get_file_as_string(old.path_join("valuable.txt")) == "original", "Cleanup deleted a recovery copy")
    assert(not installer._swap_in(pkg).is_empty(), "Existing recovery copy was overwritten")
    installer.delete_recursive(old)
    DirAccess.make_dir_recursive_absolute(target)
    file = FileAccess.open(target.path_join("valuable.txt"), FileAccess.WRITE)
    file.store_string("original")
    file.close()
    assert(not installer._swap_in(pkg).is_empty(), "Missing staged package should fail")
    assert(FileAccess.get_file_as_string(target.path_join("valuable.txt")) == "original", "Rollback did not restore the original")
    var staged: String = installer.STAGING.path_join("smoke_target")
    DirAccess.make_dir_recursive_absolute(staged)
    file = FileAccess.open(staged.path_join("valuable.txt"), FileAccess.WRITE)
    file.store_string("replacement")
    file.close()
    assert(installer._swap_in(pkg).is_empty(), "Successful swap failed")
    assert(FileAccess.get_file_as_string(target.path_join("valuable.txt")) == "replacement", "Replacement was not installed")
    assert(FileAccess.get_file_as_string(old.path_join("valuable.txt")) == "original", "Original backup was not retained")
    installer.delete_recursive(target)
    installer.delete_recursive(old)
    installer._cleanup()
    installer.free()
'''


def run(godot: str, project: Path, label: str, *args: str, marker: str = "") -> None:
    try:
        result = subprocess.run(
            [godot, "--headless", "--path", str(project), *args],
            capture_output=True, text=True, timeout=120,
        )
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b"") + (exc.stderr or b"")
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (project / f"{label}.log").write_text(output)
        raise RuntimeError(f"{label} timed out in {project}\n{output}") from exc
    output = result.stdout + result.stderr
    (project / f"{label}.log").write_text(output)
    # Godot can return zero even when GDScript fails. Inspect diagnostics too.
    if result.returncode or "ERROR:" in output or "SCRIPT ERROR:" in output or "leaked at exit" in output or (marker and marker not in output):
        raise RuntimeError(f"{label} failed in {project}\n{output}")
    print(f"  {label}: OK", flush=True)


def check(godot: str, artifacts: Path, workspace: Path, ids: list[str], label: str) -> None:
    project = workspace / label
    project.mkdir()
    for pkg_id in ids:
        with zipfile.ZipFile(artifacts / f"{pkg_id}.zip") as archive:
            archive.extractall(project)
    plugins = [f"res://addons/{pkg_id}/plugin.cfg" for pkg_id in ids]
    enabled = ", ".join(json.dumps(cfg) for cfg in plugins)
    config = f'config_version=5\n[application]\nconfig/name="Cannoli smoke {label}"\n[editor_plugins]\nenabled=PackedStringArray({enabled})\n'
    (project / "project.godot").write_text(config)
    print(label, flush=True)
    run(godot, project, "clean-import", "--editor", "--quit")
    run(godot, project, "reopen", "--editor", "--quit")
    resources = ["res://" + path.relative_to(project).as_posix() for path in sorted((project / "addons").rglob("*")) if path.suffix in (".gd", ".tscn", ".tres")]
    (project / "smoke_resources.json").write_text(json.dumps(resources))
    (project / "smoke_plugins.json").write_text(json.dumps(plugins))
    harness = project / "addons" / "smoke_harness"
    harness.mkdir()
    (harness / "plugin.cfg").write_text('[plugin]\nname="Release smoke"\nversion="1.0.0"\nscript="plugin.gd"\n')
    (harness / "plugin.gd").write_text(HARNESS)
    (project / "foreign_save.gd").write_text("extends Node\n")
    config = (project / "project.godot").read_text().replace('enabled=PackedStringArray(', 'enabled=PackedStringArray("res://addons/smoke_harness/plugin.cfg", ')
    (project / "project.godot").write_text(config)
    run(godot, project, "lifecycle", "--editor", marker="CANNOLI_SMOKE_OK")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    errors = validate(root)
    if errors:
        raise RuntimeError("\n".join(errors))
    with tempfile.TemporaryDirectory(prefix="cannoli-release-check-") as temp:
        workspace = Path(temp)
        artifacts = workspace / "dist"
        build(artifacts, root)
        ids = [pkg["id"] for pkg in json.loads((root / "packages.json").read_text())["packages"]]
        ids.append("cannoli_installer")
        for pkg_id in ids:
            check(args.godot, artifacts, workspace, [pkg_id], pkg_id)
        check(args.godot, artifacts, workspace, ids, "all-packages")
    print("All Godot release checks passed.")


if __name__ == "__main__":
    main()
