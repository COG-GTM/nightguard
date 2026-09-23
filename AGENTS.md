# AGENTS.md — Guide for AI software engineering agents

Nightguard is a native **Swift iOS + watchOS** app that displays blood glucose values from a
[Nightscout](https://nightscout.github.io) server and alarms when they leave the configured range.
This fork (`COG-GTM/nightguard`, upstream `nightscout/nightguard`, default branch `master`) is
used for Devin demos. It is AGPL-3.0 licensed — keep the license header style on new files.

## Layout

| Path | What lives there |
|------|------------------|
| `nightguard/app/` | App entry, `ChartScene` / `ChartPainter` (SpriteKit glucose chart) |
| `nightguard/domain/` | Domain model: `BloodSugar`, `AlarmRule`, `Units`, `treatment/` (`Treatment` base class + `CarbCorrectionTreatment`, `MealBolusTreatment`, `CorrectionBolusTreatment`, `BolusWizardTreatment`, `TreatmentsStream`) |
| `nightguard/external/` | Integrations: `NightscoutService` (REST client), `NightscoutCacheService`, `AppleHealthService` (HealthKit write-sync of glucose), `AlarmNotificationService`, `PredictionService`, `WatchService` |
| `nightguard/repository/` | Persistence: `UserDefaultsRepository` (typed `UserDefaultsValue`s), `NightscoutDataRepository`, `StatisticsRepository`, `SharedUserDefaultsRepository` (app-group defaults shared with watch/widget) |
| `nightguard/viewmodel/MainViewModel.swift` | Single `ObservableObject` driving the main screen: 30 s refresh timer, Nightscout fetches, alarm evaluation, treatments ingestion (`TreatmentsStream.singleton.addNewJsonTreatments`), HealthKit sync trigger |
| `nightguard/views/` | SwiftUI views (`MainView`, `PrefsView`, `prefs/`, `stats/`, `duration/`) — the UIKit storyboard was converted, see `SWIFTUI_CONVERSION.md` |
| `nightguard/watch/` | WatchConnectivity messages shared with the watch app |
| `nightguard WatchKit App/`, `nightguard Complication/`, `nightguard Widget Extension/` | watchOS app, complication and widget targets |
| `nightguardTests/`, `nightguardUITests/` | XCTest unit tests (`AlarmRuleTest`, `BloodSugarArrayTest`, `ChartPainterTest`, `NightscoutServiceTest`, `PredictionServiceTest`, …) and UI tests; `nightguard.xctestplan` wires them into the `nightguard` scheme |
| `fastlane/` | Screenshot / release lanes (`fastlaneAll.sh`, `fastlaneRelease.sh`, `fastlaneScreenshots.sh`) |

## Build and test

Requires macOS + Xcode. Dependencies are CocoaPods (`pod install`, then open `nightguard.xcworkspace`).
The README describes a local `.env` (`SHARED_SECRET` for legacy receipt validation); it is
git-ignored and no `.env.example` is checked in — create it by hand if a build step asks for it.

```bash
pod install
xcodebuild -workspace nightguard.xcworkspace -scheme nightguard \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -workspace nightguard.xcworkspace -scheme nightguard \
  -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan nightguard test
```

On a Linux box there is no toolchain: reason from source, keep changes small, and state in the PR
that the build was not run.

## Conventions

- Singletons: services and repositories expose `static let singleton`; call them, don't instantiate.
- Settings are typed `UserDefaultsValue<T>` entries on `UserDefaultsRepository` (e.g.
  `appleHealthLastSyncDate`, `units`, `treatments`). Add a new key there rather than reading
  `UserDefaults.standard` directly.
- Code that only exists in the phone target is fenced with `#if MAIN_APP` (see `AppLogger` use in
  `AppleHealthService`).
- Glucose units: values are stored in mg/dL and converted for display via `UnitsConverter`
  (`UserDefaultsRepository.units`).
- Treatments arrive from Nightscout `/api/v1/treatments` as JSON dictionaries and are mapped by
  `eventType` in `TreatmentsStream.treatment(from:timestamp:)`; unknown event types are dropped.
- Add unit tests under `nightguardTests/` mirroring the existing `<Type>Test.swift` naming.
- Commit messages must contain `feature` or `bug`; PR descriptions end with `Devin-Org: engineering`.

## Where the HealthKit integration is today

`AppleHealthService` writes **blood glucose only**: it back-fills from
`UserDefaultsRepository.appleHealthLastSyncDate`, builds `HKQuantitySample`s of type
`.bloodGlucose`, and saves them. Authorization is requested for that single type from
`views/prefs/DisplayOptionsSectionView.swift`; `MainViewModel` calls `sync()` after each refresh.
Insulin (`HKQuantityTypeIdentifier.insulinDelivery`) and carbohydrates
(`.dietaryCarbohydrates`) are parsed into `Treatment` subclasses but never written to HealthKit —
that is upstream issue [#330](https://github.com/nightscout/nightguard/issues/330).

## The Lilly Health demo shell (`nightguard/lillyhealth/`)

This fork ships a second, Lilly Health–style front end layered on top of the original app. It is a
**synthetic demo** — no Lilly systems, no real patient, prescription or pharmacy data.

- `SceneDelegate` installs `LillyRootTabView` (Home · Logbook · Explore · Care · More) as the root in
  light mode; the original `RootTabView` and its dark screens stay in the codebase and are reachable
  from **More** and the Home "Blood Glucose" chip (each wrapped with `.preferredColorScheme(.dark)`).
- `HealthLogEntry.swift` holds the entry models (`FoodEntry`, `WeightEntry`, `ActivityEntry`,
  `SleepEntry`, `MedicationEntry`) and `ZepboundDose` demo constants; `HealthLogStore.swift` is the
  single `ObservableObject` (JSON `Snapshot` in `UserDefaults` key `lillyHealth.logbook`, synthetic
  seed data, daily rollups, dose/streak math). Both are UIKit-free so they compile into
  `nightguardTests` (`HealthLogStoreTest.swift`).
- `LillyTheme.swift` is the visual system (Lilly red, serif display font, paper background, cards).
- Store schema changes must stay backward compatible — `load()` drops a snapshot that fails to
  decode, which would wipe a demo device's logbook. New fields get a default or are optional.
- New Swift files must be added to `nightguard.xcodeproj/project.pbxproj` (build file, file
  reference, `lillyhealth` group, Sources phase) or they silently don't compile into the target.
- iOS 15 deployment target: no Swift Charts — extend the hand-rolled `LillyLineChart`.

## Demo: event-driven review → PRD → PR

```
App Store review → event trigger → review analysis → PRD → Devin session → PR → updated app
```

The product signal is the App Store review *"Calories, weight, breakdown"*; the repo-grounded PRD it
produces is `docs/PRD-LILLY-HEALTH-DASHBOARD.md` (protein per meal, clothed/unclothed weigh-ins,
maintain vs. deficit goal, activity categories with miles and dumbbell load). Hand that PRD to a
Devin session to implement the four requirements against `nightguard/lillyhealth/`.

Prompts for the live run — the first two are Ask Devin questions, the third is a full session:

1. *"In COG-GTM/nightguard, how does the Lilly Health logbook store food, weight and activity entries today?"*
2. *"An App Store review asks for protein per meal, clothed/unclothed weigh-ins, a maintain-vs-deficit goal and activity categories — which of those can the current models express?"*
3. *"Implement `docs/PRD-LILLY-HEALTH-DASHBOARD.md` in `nightguard/lillyhealth/` — keep the `HealthLogStore` snapshot backward compatible, update the entry forms, Home and Logbook, extend `HealthLogStoreTest`, and open a PR."*

## Demo: Ask Devin kickoff (issue #330)

Progressive prompts for a live demo. The first two are lightweight Ask Devin questions; the third
asks for a plan and should be handed to a full Devin session.

1. *"How does Nightguard currently sync data to Apple Health, and which Nightscout treatment types does it already parse?"*
2. *"What would need to change to also log insulin and carbs from those treatments to HealthKit, and what's the smallest safe version of that?"*
3. *"Write a concrete implementation plan for nightscout/nightguard#330 — authorization, sample types, dedup against `appleHealthLastSyncDate`, prefs toggle, and unit tests — then open a PR."*
