# WatchFaceGenerator

A Swift script that generates `.watchface` files from a JSON config — no Apple Watch required.

## Usage

Run from the project root:

```bash
swift WatchFaceGenerator.swift
```

Generated files are written to `output/`. Copy a verified file into your app's `WatchFaces/` bundle manually.

### Options

| Flag | Description |
|------|-------------|
| `--config <path>` | Path to JSON config file (default: `watchface-config.json`) |
| `--app-bundle-id <id>` | Override `appBundleID` from config |
| `--extension-bundle-id <id>` | Override `extensionBundleID` from config |

**Example — run against a different app:**
```bash
swift WatchFaceGenerator.swift \
  --config my-app-config.json \
  --app-bundle-id com.example.myapp.watchkitapp \
  --extension-bundle-id com.example.myapp.watchkitapp.WidgetExtension
```

## Config file

All face definitions, widget catalog, and bundle IDs live in `watchface-config.json`:

```json
{
  "appBundleID": "com.example.app.watchkitapp",
  "extensionBundleID": "com.example.app.watchkitapp.WidgetExtension",
  "complicationType": 56,
  "widgets": {
    "MyWidget": "My Widget Display Name"
  },
  "faces": [
    {
      "name": "Modular",
      "analyticsID": "whistler-digital",
      "faceType": "whistler-digital",
      "customization": { "color": "multicolor" },
      "complications": {
        "top left": "MyWidget",
        "center":   "MyWidget"
      }
    }
  ]
}
```

- **`widgets`** — maps widget kind strings (as defined in your WidgetKit extension) to display names shown in the watch face catalog.
- **`complications`** — maps slot names to widget kind strings from the `widgets` catalog.
- **`appleBundleID`** — only needed for bundle-based faces (Chronograph, NikeCompact). Omit for standard faces.
- **`deviceSize`** — optional, defaults to `8`.
- **`snapshotPath`** — optional path to a PNG used as the face picker preview (relative to project root). Falls back to a 1×1 black placeholder if omitted or missing.
- **`noBordersSnapshotPath`** — optional path to the borderless variant. Falls back to `snapshotPath` if omitted.

To populate snapshots from existing `.watchface` files:
```bash
unzip -p "WatchFaces/Modular.watchface" snapshot.png > snapshots/Modular.png
unzip -p "WatchFaces/Modular.watchface" no_borders_snapshot.png > snapshots/Modular_no_borders.png
```

## What it generates

| Face | Analytics ID | Style |
|------|-------------|-------|
| Modular | whistler-digital | Digital with 5 complication slots |
| ModularCompact | whistler-subdials | Compact digital with 3 slots |
| Infograph | whistler-analog | Analog with 8 complication slots |
| Chronograph | shark | Bundle-based with 4 slots |
| NikeDigital | victory-digital-r | Nike digital with 3 slots |
| NikeCompact | shiba | Nike compact bundle with 3 slots |

## Notes

- `snapshot.png` and `no_borders_snapshot.png` inside each generated `.watchface` are 1×1 black placeholders. To restore real snapshots, extract them from the originals:
  ```bash
  unzip -p "WatchFaces/Modular.watchface" snapshot.png > output/snapshot.png
  ```
- Never overwrite production `WatchFaces/` assets directly — always review generated output first.
