# WatchFaceGenerator

A Swift script that generates `.watchface` files from an interactive wizard — no Apple Watch required.

## Installation

### Homebrew (recommended)

```bash
brew tap badrinathvm/tap
brew trust badrinathvm/tap
brew install watchface-generator
```

### Manual

Clone the repo and run the script directly with Swift:

```bash
git clone https://github.com/badrinathvm/WatchFaceGenerator.git
cd WatchFaceGenerator
swift WatchFaceGenerator.swift
```

## Usage

### Default — wizard + generate

```bash
watchface-generator
```

Runs an interactive setup wizard asking for your bundle IDs, widget catalog, and slot assignments, then generates `.watchface` files immediately. No config files needed.

### Save config for reuse

```bash
watchface-generator --init
```

Same wizard, but writes `app.json` and `faces.json` to disk instead of generating. On subsequent runs, pass `--app` and `--faces` to skip the wizard:

```bash
watchface-generator --app app.json --faces faces.json
```

### Inline — no wizard, no files

```bash
watchface-generator \
  --app-bundle-id com.example.myapp.watchkitapp \
  --extension-bundle-id com.example.myapp.watchkitapp.WidgetExtension \
  --widget ServeWidget "Serve Error" \
  --widget SubmitWidget "Submit Session" \
  --face Modular "top left=SubmitWidget,center=ServeWidget"
```

### All options

| Flag | Description |
|------|-------------|
| `--init` | Wizard → write `app.json` + `faces.json`, then exit |
| `--app <path>` | Load app identity from a saved JSON file |
| `--faces <path>` | Load face catalog from a saved JSON file |
| `--app-bundle-id <id>` | Override bundle ID inline |
| `--extension-bundle-id <id>` | Override extension bundle ID inline |
| `--widget <kind> <name>` | Add a widget inline (repeatable) |
| `--face <name> "slot=kind,..."` | Assign widgets to a face template inline (repeatable) |
| `--version` | Print version and exit |

Generated files are written to `output/`. Copy a verified `.watchface` into your app's `WatchFaces/` bundle manually.

## Wizard

The wizard asks questions in order:

1. **App Bundle ID** — your app's main bundle identifier
2. **Extension Bundle ID** — your WidgetKit extension identifier (defaults to `<bundleID>.WidgetExtension`)
3. **Widget catalog** — add widget kinds and display names one by one
4. **Face configuration** — for each of the 8 built-in face types, choose:
   - `R` — randomly distribute your widgets across slots
   - `S` — assign each slot manually
   - `N` — skip this face

## Config files

When using `--init`, two files are written. These are **not** committed to the repo — they're per-project and listed in `.gitignore`.

### `app.json` — app identity

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

### `faces.json` — face catalog

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

- **`appleBundleID`** — only needed for bundle-based faces (Chronograph, ModularDuo, NikeCompact).
- **`deviceSize`** — optional, defaults to `8`.
- **`snapshotPath`** / **`noBordersSnapshotPath`** — optional per-face snapshot overrides.

## Snapshots

Drop one PNG per face type into `snapshots/` and every face of that type gets the right preview automatically:

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

The slug is the `faceType` lowercased with spaces replaced by hyphens. A `-no-borders` variant (e.g. `shark-no-borders.png`) is used for `no_borders_snapshot.png` if present; otherwise the regular image is reused. If neither exists, a 1×1 black placeholder is used silently.

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
- `complicationType: 56` is the Apple-internal value for WidgetKit complications. Do not change it.
