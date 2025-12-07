//
//  AutomationTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/9/25.
//

import SwiftUI

struct AutomationTab: View {
    // MARK: - Environment Objects
    @EnvironmentObject var automationManager: AutomationManager

    // MARK: - Constants
    let maxAutomationCount = 10

    // MARK: - State
    @State var automations: [Automation] = []

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(
                label: Text("Automations")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.bottom, 4)
            ) {
                VStack(alignment: .leading) {
                    ForEach(automations) { automation in
                        AutomationRow(
                            automation: automation,
                            onToggle: {
                                automationManager.createAutomation(
                                    id: automation.id,
                                    title: automation.title,
                                    instructions: automation.instructions,
                                    executeTime: automation.executeTime,
                                    recurrence: automation.recurrence,
                                    enabled: !automation.enabled
                                )
                                automations = automationManager.listAutomations()
                            },
                            onRemove: {
                                automationManager.removeAutomation(id: automation.id)
                                automations = automationManager.listAutomations()
                            }
                        )
                        .environmentObject(automationManager)
                        Divider()
                    }

                    Text(
                        """
                        Learn what you can do with [Automations](https://aithing.dev/features/automations).
                        """
                    )
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
                    .foregroundStyle(.secondary)

                }
                .padding(4)
            }
            .onAppear {
                automations = automationManager.listAutomations()
            }

            GroupBox(
                label: Text("Create Automations (Max \(maxAutomationCount))")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.bottom, 4)
            ) {
                VStack(alignment: .leading) {
                    if automations.count < maxAutomationCount {
                        GroupBox {
                            AddAutomationForm(
                                automations: $automations
                            ).environmentObject(automationManager)
                        }
                    }
                }
                .padding(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AutomationRow: View {
    // MARK: - Constants
    let automation: Automation
    let onToggle: () -> Void
    let onRemove: () -> Void

    // MARK: - State
    @State var isHovered = false

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    RowTitle(automation.title)
                    RowSub(automation.instructions)
                    Text("Executes: \(automation.executeTime)")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.5)
                    if !automation.recurrence.isOneOff {
                        RowSub("Recurs every: \(recurrenceString(automation.recurrence))")
                    } else {
                        RowSub("One-time")
                    }
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { automation.enabled },
                        set: { _ in onToggle() }
                    )
                )
                .toggleStyle(.switch)
                .tint(.black)
                .scaleEffect(0.7)
            }

            if isHovered {
                Button(action: onRemove) {
                    Text("Remove")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(4)
        .contentShape(Rectangle())
        .onHover { hover in
            withAnimation {
                isHovered = hover
            }
        }
    }

    private func recurrenceString(_ recurrence: Automation.Recurrence) -> String {
        var parts: [String] = []
        if recurrence.days > 0 {
            parts.append("\(recurrence.days) day\(recurrence.days == 1 ? "" : "s")")
        }
        if recurrence.hours > 0 {
            parts.append("\(recurrence.hours) hour\(recurrence.hours == 1 ? "" : "s")")
        }
        if recurrence.minutes > 0 {
            parts.append("\(recurrence.minutes) min\(recurrence.minutes == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

private struct AddAutomationForm: View {
    // MARK: - Environment Objects
    @EnvironmentObject var automationManager: AutomationManager

    // MARK: - Bindings
    @Binding var automations: [Automation]

    // MARK: - State
    @State var title: String = ""
    @State var instructions: String = ""
    @State var executeTime: Date = Date()
    @State var recurrence: Automation.Recurrence = Automation.Recurrence(
        minutes: 0,
        hours: 0,
        days: 0
    )
    @State var executeTimeString: String = ""
    @State var days: String = "0"
    @State var hours: String = "0"
    @State var minutes: String = "0"

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading) {

            HStack {
                Text("Title")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)
                TextField("Ex: Daily Email Summary", text: $title)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
            }
            .padding(.bottom, 8)

            HStack {
                Text("Instructions")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)
                TextField("Ex: Summarize emails I received today", text: $instructions)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
            }
            .padding(.bottom, 8)

            HStack {
                Text("Date & Time")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)

                TextField("YYYY-MM-DD HH:MM", text: $executeTimeString)
                    .onSubmit(validateTime)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 8)
            .fixedSize(horizontal: true, vertical: false)

            HStack {
                Text("Repeat Every")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)

                TextField("", text: $days)
                    .onSubmit(validateDate)
                    .padding(.horizontal, 8)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                Text("Days")
                    .font(.system(size: 10, weight: .medium))

                TextField("", text: $hours)
                    .onSubmit(validateDate)
                    .padding(.horizontal, 8)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                Text("Hours")
                    .font(.system(size: 10, weight: .medium))

                TextField("", text: $minutes)
                    .onSubmit(validateDate)
                    .padding(.horizontal, 8)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                Text("Minutes")
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.bottom, 8)
            .fixedSize(horizontal: true, vertical: false)

            Button {
                validateDate()
                validateTime()

                automationManager.createAutomation(
                    id: UUID().uuidString,
                    title: title,
                    instructions: instructions,
                    executeTime: executeTime,
                    recurrence: recurrence,
                    enabled: true
                )
                automations = automationManager.listAutomations()

                title = ""
                instructions = ""
                executeTime = Date()
                recurrence = Automation.Recurrence(minutes: 0, hours: 0, days: 0)

                executeTimeString = ""

                days = "0"
                hours = "0"
                minutes = "0"
            } label: {
                Text("+ Add Automation")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .padding(4)
        .onAppear {
            executeTimeString = dateFormatter.string(from: executeTime)
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private func validateTime() {
        if let validDate = dateFormatter.date(from: executeTimeString) {
            executeTime = validDate
        } else {
            executeTime = Date()
            executeTimeString = dateFormatter.string(from: executeTime)
        }
    }

    private func validateDate() {
        if let minutes = Int(minutes) {
            if minutes < 0 || minutes > 59 {
                self.minutes = "0"
            }
        } else {
            self.minutes = "0"
        }

        if let hours = Int(hours) {
            if hours < 0 || hours > 23 {
                self.hours = "0"
            }
        } else {
            self.hours = "0"
        }

        if let days = Int(days) {
            if days < 0 || days > 30 {
                self.days = "0"
            }
        } else {
            self.days = "0"
        }

        recurrence = .init(minutes: Int(minutes)!, hours: Int(hours)!, days: Int(days)!)
    }
}

