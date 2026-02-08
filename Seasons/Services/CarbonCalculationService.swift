import Foundation

struct CarbonEquivalent {
    let description: String
    let value: Double
    let unit: String
}

enum CarbonCalculationService {
    /// Calculates CO2 saved (in kg) by choosing local seasonal produce over imported.
    static func carbonSaved(produce: ProduceItem, quantityKg: Double) -> Double {
        produce.carbonSavingsPerKg * quantityKg
    }

    /// Provides real-world equivalencies for a given CO2 savings amount (in kg).
    static func equivalencies(carbonSavedKg: Double) -> [CarbonEquivalent] {
        [
            CarbonEquivalent(
                description: "Miles not driven",
                value: carbonSavedKg / 0.404, // ~0.404 kg CO2 per mile for avg car
                unit: "mi"
            ),
            CarbonEquivalent(
                description: "Smartphone charges",
                value: carbonSavedKg / 0.008, // ~0.008 kg CO2 per full charge
                unit: "charges"
            ),
            CarbonEquivalent(
                description: "Hours of LED lighting saved",
                value: carbonSavedKg / 0.005, // ~0.005 kg CO2 per hour for a 10W LED
                unit: "hrs"
            ),
            CarbonEquivalent(
                description: "Tree seedlings grown for a year",
                value: carbonSavedKg / 10.0, // ~10 kg CO2 absorbed per tree seedling per year (EPA)
                unit: "trees"
            ),
            CarbonEquivalent(
                description: "Minutes of hot shower",
                value: carbonSavedKg / 0.045, // ~0.045 kg CO2 per minute of hot shower
                unit: "min"
            )
        ]
    }

    /// Formats a carbon amount for display.
    static func formattedCarbon(_ kg: Double) -> String {
        if kg < 1.0 {
            return String(format: "%.0f g", kg * 1000)
        } else {
            return String(format: "%.1f kg", kg)
        }
    }
}
