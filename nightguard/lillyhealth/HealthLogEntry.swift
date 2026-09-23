//
//  HealthLogEntry.swift
//  nightguard
//
//  Logbook records for the Lilly Health™-style shell. Everything the patient
//  enters by hand lives here; blood glucose keeps flowing from Nightscout.
//

import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct FoodEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var name: String
    var calories: Int
    var meal: MealType
    /// Optional so meals logged before protein tracking still decode.
    var proteinGrams: Int?
}

/// Whether a weigh-in was taken dressed or not; clothed readings run a few pounds heavy.
enum WeighInState: String, Codable, CaseIterable, Identifiable {
    case clothed, unclothed

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct WeightEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var pounds: Double
    var state: WeighInState = .unclothed

    private enum CodingKeys: String, CodingKey {
        case id, date, pounds, state
    }

    init(id: UUID = UUID(), date: Date, pounds: Double, state: WeighInState = .unclothed) {
        self.id = id
        self.date = date
        self.pounds = pounds
        self.state = state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        pounds = try container.decode(Double.self, forKey: .pounds)
        state = try container.decodeIfPresent(WeighInState.self, forKey: .state) ?? .unclothed
    }
}

/// How the daily calorie target is derived.
enum WeightGoal: String, Codable, CaseIterable, Identifiable {
    case maintain, deficit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maintain: return "Maintain weight"
        case .deficit: return "Calorie deficit"
        }
    }
}

/// What a workout is measured by, beyond duration.
enum ActivityMeasure {
    case distance, load, duration
}

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case walk, run, cycling, strength, yoga, swim, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walk: return "Walk"
        case .run: return "Run"
        case .cycling: return "Cycling"
        case .strength: return "Strength"
        case .yoga: return "Yoga"
        case .swim: return "Swim"
        case .other: return "Other"
        }
    }

    var measure: ActivityMeasure {
        switch self {
        case .walk, .run, .cycling: return .distance
        case .strength: return .load
        case .yoga, .swim, .other: return .duration
        }
    }

    /// Best-effort category for a free-text activity name (used for legacy entries).
    static func inferred(from name: String) -> ActivityCategory {
        let lowered = name.lowercased()
        if lowered.contains("walk") || lowered.contains("hike") { return .walk }
        if lowered.contains("run") || lowered.contains("jog") { return .run }
        if lowered.contains("cycl") || lowered.contains("bike") || lowered.contains("spin") { return .cycling }
        if lowered.contains("strength") || lowered.contains("weight") || lowered.contains("lift") { return .strength }
        if lowered.contains("yoga") || lowered.contains("pilates") { return .yoga }
        if lowered.contains("swim") { return .swim }
        return .other
    }
}

struct ActivityEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var name: String
    var minutes: Int
    var category: ActivityCategory
    var miles: Double?
    var weightLbs: Double?

    private enum CodingKeys: String, CodingKey {
        case id, date, name, minutes, category, miles, weightLbs
    }

    init(id: UUID = UUID(), date: Date, name: String, minutes: Int,
         category: ActivityCategory? = nil, miles: Double? = nil, weightLbs: Double? = nil) {
        self.id = id
        self.date = date
        self.name = name
        self.minutes = minutes
        self.category = category ?? ActivityCategory.inferred(from: name)
        self.miles = miles
        self.weightLbs = weightLbs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        name = try container.decode(String.self, forKey: .name)
        minutes = try container.decode(Int.self, forKey: .minutes)
        category = try container.decodeIfPresent(ActivityCategory.self, forKey: .category)
            ?? ActivityCategory.inferred(from: name)
        miles = try container.decodeIfPresent(Double.self, forKey: .miles)
        weightLbs = try container.decodeIfPresent(Double.self, forKey: .weightLbs)
    }

    /// "Run · 3.2 mi · 28 min" / "Strength · 45 lb dumbbells · 45 min"
    var summary: String {
        var parts = [category.title]
        switch category.measure {
        case .distance:
            if let miles = miles { parts.append("\(miles.cleanValue) mi") }
        case .load:
            if let weightLbs = weightLbs { parts.append("\(weightLbs.cleanValue) lb dumbbells") }
        case .duration:
            break
        }
        parts.append("\(minutes) min")
        return parts.joined(separator: " · ")
    }
}

struct SleepEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var hours: Double
}

struct MedicationEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var medication: String
    var doseMg: Double
    var injectionSite: String
}

/// Zepbound® single-dose pen strengths (mg), in titration order.
enum ZepboundDose {
    static let strengthsMg: [Double] = [2.5, 5, 7.5, 10, 12.5, 15]
    static let productName = "Zepbound"
    static let dosingIntervalDays = 7
    static let injectionSites = ["Abdomen", "Thigh", "Upper arm"]
}

extension Double {
    /// "12.5 mg" / "5 mg"
    var mgString: String { "\(cleanValue) mg" }
}
