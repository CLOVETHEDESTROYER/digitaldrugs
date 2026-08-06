//
//  RitualNotificationManager.swift
//  DigitalDrug
//

import Foundation
import UIKit
import UserNotifications

@MainActor
final class RitualNotificationManager: ObservableObject {
    private enum Keys {
        static let dailyEnabled = "ritualReminderDailyEnabled"
        static let challengeEnabled = "ritualReminderChallengeEnabled"
        static let hour = "ritualReminderHour"
        static let minute = "ritualReminderMinute"
    }

    private let dailyIdentifier = "zenwave.daily-ritual-reminder"
    private let challengeIdentifier = "zenwave.challenge-ritual-reminder"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isDailyReminderEnabled: Bool
    @Published private(set) var isChallengeReminderEnabled: Bool
    @Published private(set) var reminderHour: Int?
    @Published private(set) var reminderMinute: Int?

    init() {
        let defaults = UserDefaults.standard
        isDailyReminderEnabled = defaults.bool(forKey: Keys.dailyEnabled)
        isChallengeReminderEnabled = defaults.bool(forKey: Keys.challengeEnabled)
        reminderHour = defaults.object(forKey: Keys.hour) as? Int
        reminderMinute = defaults.object(forKey: Keys.minute) as? Int

        Task {
            await refreshAuthorizationStatus()
        }
    }

    var statusLabel: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Allowed"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Asked"
        @unknown default:
            return "Unknown"
        }
    }

    var reminderTimeLabel: String {
        guard let reminderHour, let reminderMinute else {
            return "Choose a time"
        }

        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var selectedReminderDate: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = reminderHour ?? Calendar.current.component(.hour, from: Date())
        components.minute = reminderMinute ?? Calendar.current.component(.minute, from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }

    func requestPermissionAndSchedule(date: Date, includeChallengeReminder: Bool) async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            setReminderTime(date)
            setChallengeReminderEnabled(includeChallengeReminder)
            setDailyReminderEnabled(granted)
            AppLog.info("Notification permission requested. granted=\(granted)")
        } catch {
            AppLog.error("Notification permission request failed: \(error.localizedDescription)")
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus

        if authorizationStatus == .denied {
            isDailyReminderEnabled = false
            isChallengeReminderEnabled = false
            persist()
            cancelAllReminders()
        }
    }

    func setReminderTime(_ date: Date) {
        reminderHour = Calendar.current.component(.hour, from: date)
        reminderMinute = Calendar.current.component(.minute, from: date)
        persist()
        rescheduleIfPossible()
    }

    func setDailyReminderEnabled(_ isEnabled: Bool) {
        isDailyReminderEnabled = isEnabled
        persist()
        rescheduleIfPossible()
    }

    func setChallengeReminderEnabled(_ isEnabled: Bool) {
        isChallengeReminderEnabled = isEnabled
        persist()
        rescheduleIfPossible()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func rescheduleIfPossible() {
        cancelAllReminders()

        guard isDailyReminderEnabled,
              authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral,
              let reminderHour,
              let reminderMinute else {
            return
        }

        scheduleReminder(
            identifier: dailyIdentifier,
            title: "Your ZenWave ritual is ready.",
            body: "Choose a state, settle in, and keep your practice path moving.",
            hour: reminderHour,
            minute: reminderMinute
        )

        if isChallengeReminderEnabled {
            scheduleReminder(
                identifier: challengeIdentifier,
                title: "Continue your Astral Path practice.",
                body: "Your next challenge day is waiting when you are ready.",
                hour: reminderHour,
                minute: (reminderMinute + 7) % 60
            )
        }
    }

    private func scheduleReminder(identifier: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.error("Notification schedule failed: \(identifier), error=\(error.localizedDescription)")
            } else {
                AppLog.info("Notification scheduled: \(identifier)")
            }
        }
    }

    private func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyIdentifier, challengeIdentifier])
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(isDailyReminderEnabled, forKey: Keys.dailyEnabled)
        defaults.set(isChallengeReminderEnabled, forKey: Keys.challengeEnabled)
        if let reminderHour {
            defaults.set(reminderHour, forKey: Keys.hour)
        } else {
            defaults.removeObject(forKey: Keys.hour)
        }
        if let reminderMinute {
            defaults.set(reminderMinute, forKey: Keys.minute)
        } else {
            defaults.removeObject(forKey: Keys.minute)
        }
    }
}
