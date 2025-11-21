//
//  ToolsView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/13/25.
//

import MCP
import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var mcpManager: MCPManager

    let cornerRadius: CGFloat

    @State private var tools: [String: [Tool]] = [:]
    @State private var currentClient: String = ""
    @State private var toolsText = "Loading tools..."

    var body: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .glassEffect(
                        .regular.tint(.black),
                        in: RoundedRectangle(cornerRadius: cornerRadius)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white.opacity(0.1))
            }

            if tools.isEmpty {
                Text(toolsText)
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                toolsView
            }

        }
        .onAppear {
            AnalyticsManager.shared.screenView(screenName: .ToolsView)
            Task {
                tools = await mcpManager.getAllTools()
                currentClient = tools.keys.first ?? ""
                if tools.isEmpty {
                    toolsText = "Enable agents in Settings"
                }
                AnalyticsManager.shared
                    .customEvent(
                        view: .ToolsView,
                        primary: .count,
                        secondary: "\(tools.count)",
                        sev: .info
                    )
            }
        }
    }

    private var toolsView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(Array(tools.keys), id: \.self) { currentClient in
                    if let currentTools = tools[currentClient] {
                        ForEach(currentTools, id: \.self) { tool in
                            ChatBubble(
                                item: ChatItem(
                                    role: .assistant,
                                    payload:
                                        .file(
                                            text: "\(currentClient): \(tool.name)",
                                            skipNextMessages: false,
                                            content: tool.description
                                        )
                                )
                            )
                            .padding(.leading, -24)
                            .padding(.trailing, 8)
                        }
                    } else {
                        if tools.isEmpty {
                            Text("Enable agents in Settings")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

}

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
