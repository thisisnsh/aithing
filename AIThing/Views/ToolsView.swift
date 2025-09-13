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

    let setPanelPassthrough: (_ enabled: Bool) -> Void
    private func updatePassthrough(inside: Bool) { setPanelPassthrough(!inside) }

    @State private var tools: [String: [Tool]] = [:]
    @State private var currentClient: String = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            toolsView
        }
        .onAppear {
            Task {
                tools = await mcpManager.getAllTools()

                currentClient = tools.keys.first ?? ""
            }
        }
        .onHover(perform: updatePassthrough)
    }

    private var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 16)

                ForEach(Array(tools.keys.enumerated()), id: \.offset) { (i, client) in
                    HoverableToolButton(
                        title: client,
                        isActive: currentClient == client,
                        action: { currentClient = client }
                    )
                }

                if tools.isEmpty {
                    Text("No tools added yet")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                Color.clear.frame(height: 16)
            }
        }
        .frame(width: 160)
        .background(Color.gray.opacity(0.08))
    }

    private var toolsView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let currentTools = tools[currentClient] {
                    ForEach(currentTools, id: \.self) { tool in
                        ChatBubble(
                            item: ChatItem(
                                role: .usage,
                                payload: .text("\(tool.name):\n\n\(tool.description)")
                            )
                        )
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
            .padding(16)
        }
        .frame(width: 480)
        .background(Color.black.opacity(0.2))
    }

}

struct HoverableToolButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Main clickable area
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        isActive
                            ? Color.black.opacity(0.5)
                            : (isHovered ? Color.black.opacity(0.1) : .clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
