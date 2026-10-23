# Parrot production icon sources

The approved identity is the half-body parrot on a white rounded tile, with a
restrained blue fill. The eye, beak channel and wing separation reveal the tile.
The menu bar uses the same silhouette as a monochrome template with transparent
cutouts, colored by AppKit.

- `AppIcon.generated.png`: immutable original generated app-icon source.
- `MenuBar.generated.png`: immutable original black menu-template source.
- `prompts.json`: exact Image Gen prompts, color intent and source SHA-256 hashes.

The prompt targets are `#3F719B` and `#FFFFFF`; actual sampled medians are about
`#3D719E` and `#FDFDFD`. The generated PNGs are authoritative. Keep their bytes
unchanged; do not repaint or resave them.

Run `python3 scripts/export-icons.py` on macOS with Pillow and `iconutil` to
recreate `Resources/AppIcon-1024.png`, `Resources/AppIcon.icns`,
`Resources/MenuBarIconTemplate.png`, and `docs/screenshots/` review previews.
The exporter cleans alpha at 8/247, trims transparent margins, fits the app
tile to an 832 px safe area on a 1024 px canvas, and resamples native sizes.
It does not redraw or recolor the artwork.

Exploration variants, prior identities and machine-specific review files are
kept outside the published production source set.
