# PRD — Lilly Health Dashboard: Calories, Weight & Activity Breakdown

**Source signal:** App Store review, "Calories, weight, breakdown" (4★)
**Product:** Lilly Health™-style GLP-1 companion (demo build on the nightguard iOS/watchOS codebase)
**Repo:** COG-GTM/nightguard · module `nightguard/lillyhealth/`
**Status:** Draft — generated from an App Store review by an event-driven Devin session

---

## 1. The signal

A verified user left a four-star review asking for four concrete things:

| # | Review ask | Product requirement |
|---|---|---|
| R1 | "meal breakdown by protein" | Per-meal macro capture, starting with protein grams, and a daily protein total against a target |
| R2 | "clothed/unclothed weight options" | Weight entries record a clothing state so trend lines compare like with like |
| R3 | "weight goals — maintaining weight or a calorie deficit" | An explicit goal mode that drives the calorie target and the dashboard copy |
| R4 | "activity categories such as miles and dumbbells" | Activity entries carry a category with a category-appropriate measure (distance in miles, weight lifted, or duration) |

The reviewer is already logging daily. Every ask is about **fidelity of the existing logbook**, not new surfaces — which keeps the change inside the data model and the five entry forms.

## 2. Goals / non-goals

**Goals**
- Capture protein, clothing state, goal mode and activity category at entry time with no extra taps for users who don't care.
- Surface each new dimension where the user already looks: Home "Today" card, Logbook → Entries, Logbook → Trends.
- Keep everything on-device and synthetic; no account, no backend, no Lilly system.

**Non-goals**
- Full macro tracking (carbs/fat), barcode scanning or a food database.
- HealthKit read/write for weight, nutrition or workouts (follow-up; today `AppleHealthService` only writes blood glucose).
- Changing the Nightscout glucose path.

## 3. Current implementation (what exists today)

The Lilly Health shell is `LillyRootTabView` (Home · Logbook · Explore · Care · More), installed as the app root in `SceneDelegate`. State lives in one observable store.

| Concern | File |
|---|---|
| Entry models (`FoodEntry`, `WeightEntry`, `ActivityEntry`, `SleepEntry`, `MedicationEntry`), `ZepboundDose` | `nightguard/lillyhealth/HealthLogEntry.swift` |
| Persistence + queries + demo seed (`HealthLogStore`, `Snapshot` Codable, `UserDefaults` key `lillyHealth.logbook`) | `nightguard/lillyhealth/HealthLogStore.swift` |
| Entry forms (`LogFoodView`, `LogWeightView`, `LogActivityView`, …) | `nightguard/lillyhealth/LillyLogSheets.swift` |
| Today dashboard, calorie ring, streak | `nightguard/lillyhealth/LillyHomeView.swift` |
| Trends + Entries | `nightguard/lillyhealth/LillyLogbookView.swift` |
| Visual system (Lilly red, serif display, cards, week strip) | `nightguard/lillyhealth/LillyTheme.swift` |
| Glucose, alarms, stats, prefs (original nightguard) | `nightguard/views/*`, reachable from **More** and the Blood Glucose chip |
| Unit tests | `nightguardTests/HealthLogStoreTest.swift` |

Today `FoodEntry` is `(date, name, calories, meal)`, `WeightEntry` is `(date, pounds)` and `ActivityEntry` is `(date, name, minutes)` — none of the four asks can be expressed.

## 4. Requirements

### R1 — Protein breakdown
- Add `proteinGrams: Int?` to `FoodEntry`. Optional so existing `Snapshot` JSON decodes unchanged (Codable gives `nil` for a missing key — no migration needed).
- `LogFoodView`: a protein field beside calories, numeric pad, skippable.
- `HealthLogStore.protein(on:)` mirroring `calories(on:)`; `proteinTarget` persisted alongside `calorieTarget`, default 100 g.
- Home "Today" card: a second progress bar for protein under calories.
- Logbook → Entries, Food card: show `"420 cal · 38g protein"` per meal and in the day total.

### R2 — Clothing state on weight
- Add `enum WeighInState: String, Codable { case clothed, unclothed }` and `state: WeighInState` on `WeightEntry` (default `.unclothed`, again decodes from old JSON).
- `LogWeightView`: two-option segmented control, sticky to the last choice used.
- Weight trend (`LillyLineChart` in `LillyLogbookView`) plots one state at a time so a clothed weigh-in cannot look like a gain; a small toggle picks the series.

### R3 — Goal mode
- Add `enum WeightGoal: String, Codable { case maintain, deficit }` persisted in the store `Snapshot`.
- **More → Goals**: pick the mode; in `.deficit`, the calorie target is derived (default −500 cal/day from maintenance) and the user can still override; in `.maintain`, the target is maintenance.
- Home hero and calorie card copy follow the mode ("500 under maintenance today" vs "on target").

### R4 — Activity categories
- Add `enum ActivityCategory: String, Codable, CaseIterable { case walk, run, cycling, strength, yoga, swim, other }`, each declaring its measure: distance (miles), load (lbs × reps × sets), or duration only.
- `ActivityEntry` gains `category: ActivityCategory`, `miles: Double?`, `weightLbs: Double?`.
- `LogActivityView`: the existing suggestion chips become the category picker and swap the secondary field — miles for walk/run/cycling, weight for strength, duration only otherwise.
- Logbook → Entries, Activity card: `"Run · 3.2 mi · 28 min"`, `"Strength · 45 lb dumbbells · 45 min"`.

## 5. Constraints

- **iOS 15 deployment target** (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`): no Swift Charts; extend the hand-rolled `LillyLineChart`.
- **Schema compatibility**: every new field is optional or has a default, since `HealthLogStore.load()` silently drops a snapshot that fails to decode — a breaking change would wipe a demo device's logbook.
- **New files must be registered** in `nightguard.xcodeproj/project.pbxproj` (build file + file reference + group + Sources phase) or they won't compile into the target; prefer extending the existing `lillyhealth/` files.
- **Test target**: `HealthLogEntry.swift` and `HealthLogStore.swift` are compiled into `nightguardTests` — keep them UIKit-free.
- Builds require macOS + Xcode; Linux sessions can only do source-level work.

## 6. Acceptance criteria

1. A meal logged with 38 g protein shows `38g` in the Food card and rolls into a daily protein total on Home.
2. A clothed weigh-in is visibly distinguished in Entries and does not disturb the unclothed trend line.
3. Switching to a deficit goal changes the daily calorie target and the Home copy.
4. A 3.2-mile run and a 45-lb dumbbell session are both loggable and render with their own units.
5. A device holding pre-change logbook JSON opens without data loss.
6. `HealthLogStoreTest` covers protein totals, clothing-state filtering, goal-derived targets and category measures.

## 7. Demo flow

```
App Store review  →  event-driven trigger  →  review analysis  →  this PRD
                  →  Devin implementation session  →  PR on COG-GTM/nightguard  →  updated app
```

---

*Synthetic demo artifact. Not affiliated with Eli Lilly and Company; no real patient, prescription or pharmacy data is involved, and nothing here is medical advice.*
