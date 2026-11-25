import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                DiagnosticsLogger.shared.log(.auth, "Local notification permission granted=\(granted)")
                return granted
            } catch {
                DiagnosticsLogger.shared.log(.error, "Notification permission error: \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func scheduleGoalReminder(goalID: UUID, title: String, weekday: Int, hour: Int) async {
        let granted = await requestPermissionIfNeeded()
        guard granted else { return }

        let identifier = "run.goal.\(goalID.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "RUN Goal Check-In"
        content.body = "Keep going toward your goal: \(title)"
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = min(7, max(1, weekday))
        comps.hour = min(23, max(0, hour))
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
        DiagnosticsLogger.shared.log(.lifecycle, "Scheduled reminder for goal \(title)")
    }

    func cancelGoalReminder(goalID: UUID) {
        let identifier = "run.goal.\(goalID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func sendGearRetirementAlertIfNeeded(
        gearID: UUID,
        gearName: String,
        currentText: String,
        maxText: String
    ) async {
        let key = "run.gear.retirementNotified.\(gearID.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let granted = await requestPermissionIfNeeded()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Gear Retirement Alert"
        content.body = "\(gearName) has reached \(currentText) (limit: \(maxText)). Consider inspecting or retiring it."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "run.gear.retire.\(gearID.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(true, forKey: key)
        DiagnosticsLogger.shared.log(.lifecycle, "Sent retirement alert for gear \(gearName)")
    }
}
