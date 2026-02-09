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
                value: carbonSavedKg / 0.39, // ~0.39 kg CO2 per mile for avg car (EPA 2024: 8.89 kg/gal, 22.8 mpg)
                unit: "mi"
            ),
            CarbonEquivalent(
                description: "Smartphone charges",
                value: carbonSavedKg / 0.006, // ~0.006 kg CO2 per full charge (US-avg grid)
                unit: "charges"
            ),
            CarbonEquivalent(
                description: "Hours of LED lighting saved",
                value: carbonSavedKg / 0.004, // ~0.004 kg CO2 per hour for a 10W LED (EIA 2023 grid avg)
                unit: "hrs"
            ),
            CarbonEquivalent(
                description: "Tree seedlings grown for a year",
                value: carbonSavedKg / 22.0, // ~22 kg CO2 absorbed per young seedling per year (EPA urban tree: 60 kg; 22 kg conservative for seedlings)
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
