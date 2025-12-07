//
//  AutomationManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/10/25.
//

import Foundation

// MARK: - Automation Manager

/// Manages the lifecycle of automated tasks including creation, scheduling, and execution.
///
/// This manager handles:
/// - CRUD operations for automations
/// - Persistent storage in UserDefaults
/// - Timer-based scheduling for one-off and recurring tasks
/// - Execution callbacks when automations trigger
@MainActor
class AutomationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The list of all automations
    @Published private(set) var automations: [Automation] = []
    
    // MARK: - Private Properties
    
    /// Storage key for persisting automations
    private let storageKey = "automations_storage_11_10_25"
    
    /// Active timers keyed by automation ID
    private var timers: [String: Timer] = [:]
    
    /// Callback invoked when an automation executes
    var onExecute: ((Automation) async -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new automation manager with an execution callback.
    ///
    /// - Parameter onExecute: Callback invoked when an automation triggers
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
    
    /// Creates or updates an automation.
    ///
    /// If an automation with the same ID exists, it will be replaced.
    /// The automation will be immediately scheduled if enabled.
    ///
    /// - Parameter config: The automation configuration
    func createAutomation(config: AutomationConfig) {        
        // Remove existing automation with same id if exists
        var insertIndex = 0
        if let index = automations.firstIndex(where: { $0.id == config.id }) {
            insertIndex = index
            automations.remove(at: index)
            cancelTimer(for: config.id)
        }
        
        let automation = Automation(
            id: config.id,
            title: config.title,
            instructions: config.instructions,
            executeTime: config.executeTime,
            recurrence: config.recurrence,
            enabled: config.enabled
        )
        
        automations.insert(automation, at: insertIndex)
        saveAutomations()
        scheduleAutomation(automation)
    }
    
    /// Creates or updates an automation using individual parameters.
    ///
    /// Convenience method that wraps parameters in an `AutomationConfig`.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the automation
    ///   - title: Display title for the automation
    ///   - instructions: Instructions/prompt to execute when triggered
    ///   - executeTime: Date/time when the automation should first execute
    ///   - recurrence: Recurrence schedule for the automation
    ///   - enabled: Whether the automation is enabled
    func createAutomation(
        id: String,
        title: String,
        instructions: String,
        executeTime: Date,
        recurrence: Automation.Recurrence,
        enabled: Bool
    ) {
        let config = AutomationConfig(
            id: id,
            title: title,
            instructions: instructions,
            executeTime: executeTime,
            recurrence: recurrence,
            enabled: enabled
        )
        createAutomation(config: config)
    }
    
    /// Lists all automations.
    ///
    /// - Returns: Array of all automations
    func listAutomations() -> [Automation] {
        automations
    }
    
    /// Removes an automation by ID.
    ///
    /// Cancels any scheduled timer and removes from storage.
    ///
    /// - Parameter id: The automation ID to remove
    func removeAutomation(id: String) {
        guard let index = automations.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        automations.remove(at: index)
        cancelTimer(for: id)
        saveAutomations()
    }
    
    // MARK: - Storage
    
    /// Saves automations to persistent storage.
    private func saveAutomations() {
        guard let encoded = try? JSONEncoder().encode(automations) else {
            logger.error("Failed to encode automations")
            return
        }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
    
    /// Loads automations from persistent storage.
    private func loadAutomations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Automation].self, from: data)
        else {
            return
        }
        automations = decoded
    }
    
    // MARK: - Scheduling
    
    /// Schedules all loaded automations.
    private func scheduleAllAutomations() {
        for automation in automations {
            scheduleAutomation(automation)
        }
    }
    
    /// Schedules a single automation based on its configuration.
    ///
    /// - Parameter automation: The automation to schedule
    private func scheduleAutomation(_ automation: Automation) {
        // Cancel existing timer if any
        cancelTimer(for: automation.id)
        
        guard automation.enabled else { return }
        
        let now = Date()
        
        // For one-off tasks
        if automation.recurrence.isOneOff {
            scheduleOneOffAutomation(automation, now: now)
            return
        }
        
        // For recurring tasks
        scheduleRecurringAutomation(automation, now: now)
    }
    
    /// Schedules a one-off automation.
    ///
    /// - Parameters:
    ///   - automation: The automation to schedule
    ///   - now: The current time
    private func scheduleOneOffAutomation(_ automation: Automation, now: Date) {
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
    }
    
    /// Schedules a recurring automation.
    ///
    /// - Parameters:
    ///   - automation: The automation to schedule
    ///   - now: The current time
    private func scheduleRecurringAutomation(_ automation: Automation, now: Date) {
        guard let interval = automation.recurrence.timeInterval else { return }
        
        // Calculate initial delay
        let initialDelay = calculateInitialDelay(
            executeTime: automation.executeTime,
            interval: interval,
            now: now
        )
        
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
    
    /// Calculates the initial delay for a recurring automation.
    ///
    /// - Parameters:
    ///   - executeTime: The scheduled execution time
    ///   - interval: The recurrence interval
    ///   - now: The current time
    /// - Returns: Time interval until first execution
    private func calculateInitialDelay(
        executeTime: Date,
        interval: TimeInterval,
        now: Date
    ) -> TimeInterval {
        if executeTime > now {
            return executeTime.timeIntervalSince(now)
        }
        
        // Calculate next execution based on interval
        let timeSinceExecution = now.timeIntervalSince(executeTime)
        let missedCycles = floor(timeSinceExecution / interval)
        let nextExecution = executeTime.addingTimeInterval((missedCycles + 1) * interval)
        return nextExecution.timeIntervalSince(now)
    }
    
    /// Sets up the repeating timer for a recurring automation.
    ///
    /// - Parameters:
    ///   - automation: The automation to schedule
    ///   - interval: The recurrence interval
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
    
    /// Executes an automation by invoking the callback.
    ///
    /// - Parameter automation: The automation to execute
    private func executeAutomation(_ automation: Automation) {
        guard automation.enabled else { return }
        
        // Call the parent's callback function
        Task {
            await onExecute?(automation)
        }
    }
    
    /// Cancels the timer for a specific automation.
    ///
    /// - Parameter id: The automation ID
    private func cancelTimer(for id: String) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }
}
