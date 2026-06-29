# WatchFaceGenerator

A Swift script that generates `.watchface` files from code — no Apple Watch required.

## Usage

Run from the project root:

```bash
swift WatchFaceGenerator.swift
```

Generated files are written to `Scripts/output/`. Copy a verified file into your app's `WatchFaces/` bundle manually.

## What it generates

| Face | Analytics ID | Style |
|------|-------------|-------|
| Modular | whistler-digital | Digital with 5 complication slots |
| ModularCompact | whistler-subdials | Compact digital with 3 slots |
| Infograph | whistler-analog | Analog with 8 complication slots |
| Chronograph | shark | Bundle-based with 4 slots |
| NikeDigital | victory-digital-r | Nike digital with 3 slots |
| NikeCompact | shiba | Nike compact bundle with 3 slots |

## Customising

Each `.watchface` is defined by a `FaceConfiguration` in the `configurations` array at the bottom of `WatchFaceGenerator.swift`. To change which widget occupies a slot, swap the `PickleRiteWidget` value for that slot.

```swift
FaceConfiguration(
    name: "Modular",
    analyticsID: "whistler-digital",
    faceType: "whistler-digital",
    customization: ["color": "multicolor", "numerals": "style 1", "background": "style 1"],
    complications: [
        "top left":      .submit,
        "center":        .dink,
        "bottom left":   .net,
        "bottom center": .missedReturn,
        "bottom right":  .lob
    ]
)
```

## Notes

- `snapshot.png` and `no_borders_snapshot.png` inside each generated `.watchface` are 1×1 black placeholders. To restore real snapshots, extract them from the originals:
  ```bash
  unzip -p "WatchFaces/Modular.watchface" snapshot.png > Scripts/output/snapshot.png
  ```
- Never overwrite production `WatchFaces/` assets directly — always review generated output first.
