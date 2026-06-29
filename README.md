# WatchFaceGenerator

A Swift script that generates `.watchface` files from two JSON configs — no Apple Watch required.

## Usage

Run from the project root:

```bash
swift WatchFaceGenerator.swift
```

Generated files are written to `output/`. Copy a verified file into your app's `WatchFaces/` bundle manually.

### Options

| Flag | Description |
|------|-------------|
| `--app <path>` | Path to app identity JSON (default: `app.json`) |
| `--faces <path>` | Path to face catalog JSON (default: `faces.json`) |
| `--app-bundle-id <id>` | Override `bundleID` from `app.json` |
| `--extension-bundle-id <id>` | Override `extensionBundleID` from `app.json` |

**Example — run against a different app:**
```bash
swift WatchFaceGenerator.swift \
  --app my-app.json \
  --app-bundle-id com.example.myapp.watchkitapp \
  --extension-bundle-id com.example.myapp.watchkitapp.WidgetExtension
```

## Config files

The generator uses two separate files so app identity and face layout can evolve independently.

### `app.json` — app identity (you own this per project)

```json
{
  "bundleID": "com.example.app.watchkitapp",
  "extensionBundleID": "com.example.app.watchkitapp.WidgetExtension",
  "complicationType": 56,
  "widgets": {
    "MyWidget": "My Widget Display Name"
  }
}
```

- **`widgets`** — maps widget kind strings (as defined in your WidgetKit extension) to display names shown in the watch face catalog.
- **`complicationType`** — Apple-internal value for WidgetKit complications. Always `56`; do not change.

### `faces.json` — face catalog (reusable across apps)

```json
{
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

- **`complications`** — maps slot names to widget kind strings from the `widgets` catalog in `app.json`.
- **`appleBundleID`** — only needed for bundle-based faces (Chronograph, ModularDuo, NikeCompact). Omit for standard faces.
- **`deviceSize`** — optional, defaults to `8`.
- **`snapshotPath`** / **`noBordersSnapshotPath`** — optional per-face overrides (see Snapshots below).

## Snapshots

The generator resolves preview images by **face type**, not by individual face. Drop one PNG per type into `snapshots/` and every face using that type gets the right preview automatically:

| faceType | File |
|----------|------|
| `whistler-digital` | `snapshots/whistler-digital.png` |
| `whistler-subdials` | `snapshots/whistler-subdials.png` |
| `whistler-analog` | `snapshots/whistler-analog.png` |
| `shark` | `snapshots/shark.png` |
| `victory digital` | `snapshots/victory-digital.png` |
| `shiba` | `snapshots/shiba.png` |
| `blackcomb` | `snapshots/blackcomb.png` |
| `cloudraker` | `snapshots/cloudraker.png` |

The slug is the `faceType` value lowercased with spaces replaced by hyphens. A `-no-borders` variant (e.g. `shark-no-borders.png`) is used for `no_borders_snapshot.png` if present; otherwise the regular image is reused. If neither exists, a 1×1 black placeholder is used silently.

A specific face can still override the type-level image via `snapshotPath` / `noBordersSnapshotPath` in `faces.json`.

## What it generates

| Face | Analytics ID | Style |
|------|-------------|-------|
| Modular | whistler-digital | Digital with 5 complication slots |
| ModularCompact | whistler-subdials | Compact digital with 3 slots |
| Infograph | whistler-analog | Analog with 8 complication slots |
| Chronograph | shark | Bundle-based with 4 slots |
| NikeDigital | victory-digital-r | Nike digital with 3 slots |
| NikeCompact | shiba | Nike compact bundle with 3 slots |
| Meridian | blackcomb | Analog with 4 subdial slots |
| ModularDuo | cloudraker | Bundle-based with 3 slots |

## Notes

- Generated files land in `output/` — never commit or deploy them directly. Review each `.watchface` before copying it into your app bundle.
- Snapshots default to a 1×1 black placeholder until you drop real PNGs into `snapshots/`. The face picker preview will appear blank until then, but the face itself works correctly on device.
- `no_borders_snapshot.png` falls back to the regular snapshot if no `-no-borders` variant is provided — one image per face type is enough to get started.
