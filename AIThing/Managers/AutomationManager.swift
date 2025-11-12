//
//  AutomationManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/10/25.
//

import Foundation

struct Automation: Codable, Identifiable {
    let id: String
    var title: String
    var instructions: String
    var executeTime: Date
    var recurrence: Recurrence
    var enabled: Bool

    struct Recurrence: Codable {
        var minutes: Int
        var hours: Int
        var days: Int

        var isOneOff: Bool {
            minutes == 0 && hours == 0 && days == 0
        }

        var timeInterval: TimeInterval? {
            guard !isOneOff else { return nil }
            return TimeInterval(minutes * 60 + hours * 3600 + days * 86400)
        }
    }
}

@MainActor
class AutomationManager: ObservableObject {
    @Published private(set) var automations: [Automation] = []

    private let storageKey = "automations_storage_11_10_25"
    private var timers: [String: Timer] = [:]
    var onExecute: ((Automation) async -> Void)?

    init(onExecute: @escaping (Automation) -> Void) {
        self.onExecute = onExecute
        loadAutomations()
        scheduleAllAutomations()
    }

    deinit {
        // Synchronously cancel all timers - deinit can't be async
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
    }

    // MARK: - CRUD Operations

    /// Creates or updates an automation (idempotent by id)
    func createAutomation(
        id: String,
        title: String,
        instructions: String,
        executeTime: Date,
        recurrence: Automation.Recurrence,
        enabled: Bool
    ) {
        // Remove existing automation with same id if exists
        var ind = 0
        if let index = automations.firstIndex(where: { $0.id == id }) {
            ind = index
            automations.remove(at: index)
            cancelTimer(for: id)
        }

        let automation = Automation(
            id: id,
            title: title,
            instructions: instructions,
            executeTime: executeTime,
            recurrence: recurrence,
            enabled: enabled
        )

        automations.insert(automation, at: ind)
        saveAutomations()
        scheduleAutomation(automation)
    }

    /// Lists all automations
    func listAutomations() -> [Automation] {
        return automations
    }

    /// Removes an automation by id
    func removeAutomation(id: String) {
        guard let index = automations.firstIndex(where: { $0.id == id }) else {
            return
        }

        automations.remove(at: index)
        cancelTimer(for: id)
        saveAutomations()
    }

    // MARK: - Storage

    private func saveAutomations() {
        guard let encoded = try? JSONEncoder().encode(automations) else {
            print("Failed to encode automations")
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    private func loadAutomations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Automation].self, from: data)
        else {
            return
        }
        automations = decoded
    }

    // MARK: - Scheduling

    private func scheduleAllAutomations() {
        for automation in automations {
            scheduleAutomation(automation)
        }
    }

    private func scheduleAutomation(_ automation: Automation) {
        // Cancel existing timer if any
        cancelTimer(for: automation.id)

        if !automation.enabled { return }

        let now = Date()

        // For one-off tasks
        if automation.recurrence.isOneOff {
            if automation.executeTime > now {
                let timeInterval = automation.executeTime.timeIntervalSince(now)
                let timer = Timer(timeInterval: timeInterval, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.executeAutomation(automation)
                        self.removeAutomation(id: automation.id)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                timers[automation.id] = timer
            } else {
                // Execute immediately if time has passed
                executeAutomation(automation)
                removeAutomation(id: automation.id)
            }
            return
        }

        // For recurring tasks
        guard let interval = automation.recurrence.timeInterval else { return }

        // Calculate initial delay
        var initialDelay: TimeInterval
        if automation.executeTime > now {
            initialDelay = automation.executeTime.timeIntervalSince(now)
        } else {
            // Calculate next execution based on interval
            let timeSinceExecution = now.timeIntervalSince(automation.executeTime)
            let missedCycles = floor(timeSinceExecution / interval)
            let nextExecution = automation.executeTime.addingTimeInterval(
                (missedCycles + 1) * interval
            )
            initialDelay = nextExecution.timeIntervalSince(now)
        }

        // Schedule initial execution
        let initialTimer = Timer(timeInterval: initialDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.executeAutomation(automation)
                self.scheduleRecurringTimer(automation, interval: interval)
            }
        }
        RunLoop.main.add(initialTimer, forMode: .common)
        timers[automation.id] = initialTimer
    }

    private func scheduleRecurringTimer(_ automation: Automation, interval: TimeInterval) {
        cancelTimer(for: automation.id)

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.executeAutomation(automation)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[automation.id] = timer
    }

    private func executeAutomation(_ automation: Automation) {
        if !automation.enabled { return }

        // Call the parent's callback function
        Task {
            await onExecute?(automation)
        }
    }

    private func cancelTimer(for id: String) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    private func cancelAllTimers() {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
    }
}
