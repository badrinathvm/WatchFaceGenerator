# snapshots/

One PNG per watch face type. The generator automatically picks up any file named
`<faceType-slug>.png` and `<faceType-slug>-no-borders.png`.

The slug is the `faceType` value from `faces.json` lowercased with spaces replaced by hyphens.

## Expected files

| faceType in faces.json | Snapshot file                   | No-borders file                     |
|------------------------|---------------------------------|-------------------------------------|
| `whistler-digital`     | `whistler-digital.png`          | `whistler-digital-no-borders.png`   |
| `whistler-subdials`    | `whistler-subdials.png`         | `whistler-subdials-no-borders.png`  |
| `whistler-analog`      | `whistler-analog.png`           | `whistler-analog-no-borders.png`    |
| `shark`                | `shark.png`                     | `shark-no-borders.png`              |
| `victory digital`      | `victory-digital.png`           | `victory-digital-no-borders.png`    |
| `shiba`                | `shiba.png`                     | `shiba-no-borders.png`              |
| `blackcomb`            | `blackcomb.png`                 | `blackcomb-no-borders.png`          |
| `cloudraker`           | `cloudraker.png`                | `cloudraker-no-borders.png`         |

If a no-borders variant is absent, the regular snapshot is reused.
If neither exists, a 1×1 black placeholder is used and the generator continues without error.

## Per-face override

A specific face can still override the type-level image by setting `snapshotPath`
and/or `noBordersSnapshotPath` in `faces.json`.
