import UserNotifications
import os

// MARK: - Protocol (enables test injection)
protocol NotificationScheduling {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func authorizationStatus() async -> UNAuthorizationStatus
}

extension UNUserNotificationCenter: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

@Observable @MainActor
final class NotificationService {
    private(set) var isAuthorized = false
    private let center: any NotificationScheduling
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons",
        category: "NotificationService"
    )

    init(center: any NotificationScheduling = UNUserNotificationCenter.current()) {
        self.center = center
        Task { await checkAuthorizationStatus() }
    }

    /// Requests permission. Returns true if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            return granted
        } catch {
            logger.error("Permission request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Schedules one notification per month for the next 12 months.
    /// Safe to call multiple times — cancels existing seasonal notifications first.
    func scheduleMonthlyNotifications(for region: GrowingRegion) async {
        let identifiers = (1...12).map { "seasonal-month-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let calendar = Calendar.current
        let now = Date()

        for offset in 0..<12 {
            guard let targetDate = calendar.date(byAdding: .month, value: offset, to: now) else { continue }
            let month = calendar.component(.month, from: targetDate)
            let year  = calendar.component(.year,  from: targetDate)

            let items = ProduceDataService.shared.inSeason(region: region, month: month)
            guard !items.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "What's In Season This Month"
            content.body  = notificationBody(items: items, region: region)
            content.sound = .default

            var components = DateComponents()
            components.year  = year
            components.month = month
            components.day   = 1
            components.hour  = 9
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "seasonal-month-\(month)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                logger.error("Failed to schedule month \(month): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancelAllNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: (1...12).map { "seasonal-month-\($0)" })
    }

    func checkAuthorizationStatus() async {
        isAuthorized = await center.authorizationStatus() == .authorized
    }

    // Internal so it can be tested without going through the full schedule path
    func notificationBody(items: [ProduceItem], region: GrowingRegion) -> String {
        let names = items.prefix(3).map(\.name)
        let remaining = max(0, items.count - 3)
        var body = names.joined(separator: ", ")
        if remaining > 0 { body += ", and \(remaining) more" }
        body += " are in season in \(region.displayName)."
        return body
    }
}
