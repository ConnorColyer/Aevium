# Aevium

Aevium is a macOS SwiftUI app focused on phase 1 and 2 of your roadmap:

1. High-volume market data ingestion.
2. Clean, futuristic, minimalist data exploration.

Phase 3 (prediction AI) is intentionally deferred.

## Run

1. Open [Aevium.xcodeproj](/Users/c/Documents/Projects/Software/Aevium/Aevium%200.0.10/Aevium.xcodeproj) in Xcode.
2. Select the `Aevium` scheme.
3. Build and run on `My Mac`.

## What is included

- Streaming CSV ingestion (chunked file read, batched writes, progress tracking).
- Local SQLite store with indexes + upsert semantics.
- Dashboard with:
  - Dataset-level stats.
  - Symbol explorer.
  - Price chart + recent OHLCV rows.
- Bundled sample dataset at `Aevium/Resources/SampleMarketData.csv`.

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
