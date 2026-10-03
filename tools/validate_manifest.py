#!/usr/bin/env python3
"""Checks packages.json against the addons in the repo.

Usage: tools/validate_manifest.py [repo_root]
Exits non-zero and prints every problem found.
"""

import configparser
import json
import re
import sys
from pathlib import Path

SELF_ID = "cannoli_installer"
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$")
ID_RE = re.compile(r"^[a-z0-9_]+$")


def plugin_cfg_version(path: Path) -> str | None:
    parser = configparser.ConfigParser()
    parser.read(path, encoding="utf-8")
    raw = parser.get("plugin", "version", fallback=None)
    return raw.strip().strip('"') if raw is not None else None


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        manifest = json.loads((root / "packages.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"packages.json: {exc}"]

    packages = manifest.get("packages")
    if not isinstance(packages, list):
        return ["packages.json: \"packages\" must be a list"]

    by_id: dict[str, dict] = {}
    for index, pkg in enumerate(packages):
        where = f"packages[{index}]"
        if not isinstance(pkg, dict):
            errors.append(f"{where}: must be an object")
            continue
        pkg_id = pkg.get("id")
        if not isinstance(pkg_id, str) or not ID_RE.match(pkg_id):
            errors.append(f"{where}: id must be lowercase letters, digits and underscores")
            continue
        where = pkg_id
        if pkg_id in by_id:
            errors.append(f"{where}: duplicate id")
        if pkg_id == SELF_ID:
            errors.append(f"{where}: the installer must not be listed")
        by_id[pkg_id] = pkg

        for field in ("name", "description", "version", "path"):
            if not isinstance(pkg.get(field), str) or not pkg[field]:
                errors.append(f"{where}: missing \"{field}\"")
        version = pkg.get("version", "")
        if isinstance(version, str) and version and not VERSION_RE.match(version):
            errors.append(f"{where}: version \"{version}\" is not semver (x.y.z)")

        path = pkg.get("path", "")
        if isinstance(path, str) and path:
            if path != f"addons/{pkg_id}":
                errors.append(f"{where}: path should be \"addons/{pkg_id}\"")
            folder = root / path
            if not folder.is_dir() or not any(p.is_file() for p in folder.rglob("*")):
                errors.append(f"{where}: {path} is missing or empty")
            cfg = folder / "plugin.cfg"
            if pkg.get("plugin"):
                if not cfg.is_file():
                    errors.append(f"{where}: \"plugin\" is true but {path}/plugin.cfg is missing")
                elif plugin_cfg_version(cfg) != version:
                    errors.append(
                        f"{where}: plugin.cfg version \"{plugin_cfg_version(cfg)}\" "
                        f"doesn't match manifest version \"{version}\""
                    )
            elif cfg.is_file():
                errors.append(f"{where}: has a plugin.cfg; set \"plugin\": true")

        deps = pkg.get("dependencies", [])
        if not isinstance(deps, list) or not all(isinstance(d, str) for d in deps):
            errors.append(f"{where}: dependencies must be a list of ids")
        for key in ("category", "url"):
            if key in pkg and not isinstance(pkg[key], str):
                errors.append(f"{where}: \"{key}\" must be a string")

    for pkg_id, pkg in by_id.items():
        for dep in pkg.get("dependencies", []) or []:
            if dep not in by_id:
                errors.append(f"{pkg_id}: unknown dependency \"{dep}\"")
            elif dep == pkg_id:
                errors.append(f"{pkg_id}: depends on itself")

    # Cycle detection (depth-first, colouring nodes).
    state: dict[str, int] = {}

    def visit(pkg_id: str, trail: list[str]) -> None:
        state[pkg_id] = 1
        for dep in by_id[pkg_id].get("dependencies", []) or []:
            if dep not in by_id or dep == pkg_id:
                continue
            if state.get(dep) == 1:
                cycle = trail[trail.index(dep):] + [dep] if dep in trail else [pkg_id, dep]
                errors.append("dependency cycle: " + " -> ".join(cycle))
            elif dep not in state:
                visit(dep, trail + [dep])
        state[pkg_id] = 2

    for pkg_id in by_id:
        if pkg_id not in state:
            visit(pkg_id, [pkg_id])

    listed = {pkg.get("path") for pkg in by_id.values()}
    addons = root / "addons"
    if addons.is_dir():
        for folder in sorted(addons.iterdir()):
            rel = f"addons/{folder.name}"
            if folder.is_dir() and folder.name != SELF_ID and not folder.name.startswith(".") and rel not in listed:
                errors.append(f"{rel}: not listed in packages.json")

    return errors


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
    errors = validate(root)
    for error in errors:
        print(f"error: {error}")
    if errors:
        return 1
    print(f"packages.json OK ({root})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
