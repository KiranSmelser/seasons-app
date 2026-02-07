# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Seasons** is an iOS app that helps users eat more sustainably by showing what produce is in season locally, suggesting recipes with seasonal ingredients, and estimating carbon savings from choosing local produce.

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (iOS 17+)
- **Persistence:** SwiftData (for CarbonLog entries)
- **Location:** CoreLocation (maps coordinates to US growing regions)
- **Architecture:** MVVM with @Observable
- **Data:** Bundled JSON files (no backend, fully offline)
- **Project Generation:** XcodeGen (`project.yml` → `Seasons.xcodeproj`)
- **No external dependencies** — all Apple-native frameworks

## Build & Run

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Build
xcodebuild -scheme Seasons -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -scheme Seasons -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test
xcodebuild -scheme Seasons -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SeasonsTests/SeasonsTests/testCarbonSavedCalculation test
```

## Architecture

### Data Flow

`Bundled JSON` → `DataService (singleton)` → `ViewModel (@Observable)` → `View (SwiftUI)`

`CoreLocation` → `LocationService` → `GrowingRegion enum` → filters produce by region + month

`CarbonLog (@Model)` ← `SwiftData` ← `CarbonDashboardView` (persisted across launches)

### Key Patterns

- **Models** (`Seasons/Models/`): Plain `Codable` structs for `ProduceItem` and `Recipe`. `CarbonLog` is a SwiftData `@Model` for persistence. `GrowingRegion` is an enum with coordinate-to-region mapping.
- **Services** (`Seasons/Services/`): Singletons that load bundled JSON and provide query methods. `LocationService` is `@Observable` and wraps `CLLocationManager`.
- **ViewModels** (`Seasons/ViewModels/`): `@Observable` classes that combine services with UI state. Each major tab has its own ViewModel.
- **Views** (`Seasons/Views/`): Organized by tab — `Seasonal/`, `Recipes/`, `Carbon/`.

### Data Files

- `Seasons/Data/seasonal_produce.json` — Produce items with `seasonsByRegion` mapping (region → array of month numbers 1-12)
- `Seasons/Data/recipes.json` — Recipes with ingredients that reference produce by `produceId`

### 7 US Growing Regions

northeast, southeast, midwest, greatPlains, southwest, pacificNorthwest, california — mapped from GPS coordinates via bounding boxes in `GrowingRegion.from(coordinate:)`.

## Branching

- `main` — production/release branch
- `dev` — active development
