# Publishing the installer on the Godot Asset Library

Listing **Cannoli Installer** lets people get it from the editor's AssetLib tab instead of downloading a zip. Submitting needs a godotengine.org account, so it's a manual step: go to <https://godotengine.org/asset-library/asset/submit> and fill in the form with the values below.

## Before submitting

- [x] MIT license is included in the repository and release ZIPs.
- [ ] Tag a release (e.g. `v1.1.0`) so the Releases page and the default install source exist.
- [x] `assets/icon.png` is tracked. Verify the public icon URL after pushing.

## Form values

| Field | Value |
| --- | --- |
| Asset name | Cannoli Installer |
| Category | Tools |
| Godot version | 4.7 |
| Version | `1.1.0` (from `addons/cannoli_installer/plugin.cfg`) |
| Repository host | GitHub |
| Repository URL | `https://github.com/genr234/cannoli` |
| Issues URL | `https://github.com/genr234/cannoli/issues` |
| Download commit | Full hash of the release commit (`git rev-parse v1.1.0`) |
| Icon URL | `https://raw.githubusercontent.com/genr234/cannoli/main/assets/icon.png` |
| License | MIT |

**Description:**

> Pick the Cannoli addons you want from a checklist and install them straight from GitHub. Dependencies are selected automatically, installed packages can be updated or uninstalled later, and the installer can remove itself when you're done.
>
> After installing, enable "Cannoli Installer" in Project Settings → Plugins.

## Updating the listing

For each new installer version, bump `version` in `addons/cannoli_installer/plugin.cfg`, tag a release, then edit the asset on the Asset Library with the new version and download commit. Edits are reviewed by moderators before they go live.

## What users download

The Asset Library downloads the repository archive at the chosen commit, so it contains every package, not just the installer. Godot's install dialog shows the file tree, and users should keep only `addons/cannoli_installer`. Mention this in the description if moderators or users find it confusing.

You could hide the other folders from the archive with `export-ignore` rules in `.gitattributes`. **Don't**: the installer's "main (development)" source downloads that same archive, so it would stop finding packages.
