# Aevium

dont open source ts alex 🙏 
sending to the main man - alex
## CSV format

Expected columns:

`symbol,date,open,high,low,close,volume`

Accepted date formats:

- `yyyy-MM-dd`
- `yyyyMMdd`

## Project notes

- Main app entry: `Aevium/App/AeviumApp.swift`
- Data layer: `Aevium/Data/*`
- UI layer: `Aevium/UI/*`
- View model: `Aevium/ViewModels/DashboardViewModel.swift`
- Optional project regeneration script: `generate_project.rb`

## Versioning

Use Git tags for versions instead of separate folders/branches:

1. Commit changes to `main`.
2. Run `./scripts/release.sh 0.1.0`.
3. The script pushes `main`, creates tag `v0.1.0`, and pushes the tag.
