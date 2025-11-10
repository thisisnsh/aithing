//
//  SettingsAutomationTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/9/25.
//

import SwiftUI

struct SettingsAutomationTab: View {
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: title("Recurring Automations")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create tasks that run automatically at regular intervals.")
                        .font(.system(size: 14, weight: .medium))
                    Text(
                        "Coming Soon. Stay tuned!"
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .fixedSize(horizontal: false, vertical: false)

            GroupBox(label: title("One-off Automations")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create tasks that automate your workflows once, either at a specific time or on demand.")
                        .font(.system(size: 14, weight: .medium))
                    Text(
                        "Coming Soon. Stay tuned!"
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .fixedSize(horizontal: false, vertical: false)
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).padding(.bottom, 4)
    }
}

