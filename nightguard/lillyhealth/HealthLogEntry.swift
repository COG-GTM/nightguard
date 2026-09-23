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
}

struct WeightEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var pounds: Double
}

struct ActivityEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var name: String
    var minutes: Int
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
