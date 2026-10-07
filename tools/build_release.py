#!/usr/bin/env python3
"""Builds the release assets the installer downloads.

Usage: tools/build_release.py OUT_DIR [repo_root]

Writes to OUT_DIR:
  packages.json            copy of the manifest
  <id>.zip                 one per package, containing addons/<id>/...
  cannoli_installer.zip    the installer, containing addons/cannoli_installer/...
"""

import json
import shutil
import sys
import zipfile
from pathlib import Path

SELF_ID = "cannoli_installer"
# Editor/OS clutter that shouldn't ship.
SKIP_NAMES = {".DS_Store", "Thumbs.db"}
SKIP_SUFFIXES = (".import", ".tmp")


def zip_folder(root: Path, rel_folder: str, out: Path) -> None:
    folder = root / rel_folder
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        license_path = root / "LICENSE"
        for path in [license_path, *sorted(folder.rglob("*"))]:
            if path == folder / "LICENSE":
                continue  # The canonical root license is already included above.
            if not path.is_file() or path.name in SKIP_NAMES or path.name.endswith(SKIP_SUFFIXES):
                continue
            # Fixed timestamps keep the zips reproducible.
            name = f"{rel_folder}/LICENSE" if path == license_path else path.relative_to(root).as_posix()
            info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())


def build(out: Path, root: Path) -> None:
    if not (root / "LICENSE").is_file():
        raise ValueError("A LICENSE file is required for release packages")
    manifest = json.loads((root / "packages.json").read_text(encoding="utf-8"))
    out.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "packages.json", out / "packages.json")

    for pkg in manifest["packages"]:
        zip_folder(root, pkg["path"], out / f"{pkg['id']}.zip")
        print(f"built {pkg['id']}.zip")
    zip_folder(root, f"addons/{SELF_ID}", out / f"{SELF_ID}.zip")
    print(f"built {SELF_ID}.zip")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    root = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent
    build(Path(sys.argv[1]), root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
