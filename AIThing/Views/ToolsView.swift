//
//  ToolsView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/13/25.
//

import MCP
import SwiftUI

struct ToolsView: View {
    // MARK: - Bindings
    @Binding var allClientTools: [String: [Tool]]

    // MARK: - Constants
    let cornerRadius: CGFloat

    // MARK: - State
    @State var tools: [String: [Tool]] = [:]
    @State var expandedHeadings: Set<String> = []
    @State var expandedNames: Set<String> = []

    // MARK: - Computed Properties
    private var sortedHeadings: [String] {
        tools.keys.sorted()
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            if tools.isEmpty {
                VStack {
                    Text("Enable agents in Settings")
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedHeadings, id: \.self) { heading in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedHeadings.contains(heading) },
                                set: { newValue in
                                    if newValue {
                                        expandedHeadings.insert(heading)
                                    } else {
                                        expandedHeadings.remove(heading)
                                    }
                                }
                            )
                        ) {
                            if let items = tools[heading] {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(items.enumerated()), id: \.offset) {
                                        index,
                                        item in
                                        let name = item.name
                                        let description = item.description

                                        // Unique ID per name within heading
                                        let nameID = "\(heading)-\(index)"

                                        Divider()

                                        // Second level: name collapsible
                                        DisclosureGroup(
                                            isExpanded: Binding(
                                                get: { expandedNames.contains(nameID) },
                                                set: { newValue in
                                                    if newValue {
                                                        expandedNames.insert(nameID)
                                                    } else {
                                                        expandedNames.remove(nameID)
                                                    }
                                                }
                                            )
                                        ) {
                                            if !description.isEmpty {
                                                HStack {
                                                    Text("\(description)")
                                                        .font(
                                                            .system(
                                                                size: 10,
                                                                weight: .medium,
                                                                design: .monospaced
                                                            )
                                                        )
                                                        .foregroundColor(.secondary)
                                                        .padding(.top, 2)
                                                    Spacer()
                                                }
                                                .padding(.leading, 16)
                                            }
                                        } label: {
                                            Text("\(formatNameString(name))")
                                                .font(
                                                    .system(
                                                        size: 10,
                                                        weight: .medium,
                                                        design: .monospaced
                                                    )
                                                )
                                                .padding(.leading, 4)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.leading, 8)
                            }
                        } label: {
                            Text(heading)
                                .font(.system(size: 12, weight: .medium))
                                .bold()
                                .padding(.leading, 4)
                        }
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 300)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            Task {
                for t in allClientTools.keys {
                    tools[formatManagedString(t)] = allClientTools[t]
                }                
            }
        }
    }

    func formatManagedString(_ input: String) -> String {
        var trimmed = input
        if !trimmed.hasPrefix("managed_") {
            return input
        }

        if trimmed == "managed_aithing_github" {
            trimmed = "managed_github"
        } else if trimmed == "managed_aithing_google" {
            trimmed = "managed_google"
        }

        // 1. Remove the "managed_" prefix if it exists
        trimmed.removeFirst("managed_".count)

        // 2. Split by underscore
        let parts = trimmed.split(separator: "_")

        // 3. Capitalize each word
        let capitalizedParts = parts.map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }

        // 4. Join with spaces
        return capitalizedParts.joined(separator: " ")
    }

    func formatNameString(_ input: String) -> String {
        var trimmed = input

        // 2. Split by underscore
        let parts = trimmed.split(separator: "_")

        // 3. Capitalize each word
        let capitalizedParts = parts.map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }

        // 4. Join with spaces
        return capitalizedParts.joined(separator: " ")
    }
}

