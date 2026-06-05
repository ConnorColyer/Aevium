# Aevium

## Project notes

- Main app entry: `Aevium/App/AeviumApp.swift`
- Data layer: `Aevium/Data/*`
- UI layer: `Aevium/UI/*`
- View model: `Aevium/ViewModels/AeviumMarketViewModel.swift`
- Optional project regeneration script: `generate_project.rb`

## Live data

- Crypto uses Binance public endpoints and works without a key.
- Equities use Finnhub's free tier. Add the key in Aevium settings; it is stored locally in the macOS Keychain and is not written into the repository.
- The app stores viewport-aware line data in SQLite with WAL mode and rolls old dense points into coarser local aggregates.

## Versioning

Use Git tags for versions instead of separate folders/branches:

1. Commit changes to `main`.
2. Run `./scripts/release.sh 0.1.0`.
3. The script pushes `main`, creates tag `v0.1.0`, and pushes the tag.
