//
//  ContentView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/19/25.
//

import SwiftUI

struct TabItem: Identifiable {
    let id = UUID()
}

struct ContentView: View {
    @EnvironmentObject var mcp: MCPManager

    var onClose: () -> Void
    var onSizeChange: (CGFloat) -> Void

    @State private var allClientTools: [String: [[String: Any]]] = [:]

    @State private var focusedIndex: Int = 0
    @State private var showToast = false
    @State private var tabs: [TabItem] = []

    @State private var maxTabs: Int = 5
    
    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 8) {
                ForEach(tabs.indices, id: \.self) { index in
                    let isFocusedBinding = Binding(
                        get: { focusedIndex == index },
                        set: { if $0 { focusedIndex = index } }
                    )

                    TabView(
                        index: index,
                        isFocused: isFocusedBinding,
                        allClientTools: allClientTools,
                        onClose: onClose,
                        onSizeChange: onSizeChange
                    )
                    .environmentObject(mcp)
                    .animation(.easeInOut, value: focusedIndex)
                }
            }
        }
        .frame(width: 1000)
        .background(Color.clear)
        .overlay(
            Group {
                if showToast {
                    Text("Maximum of \(maxTabs) tabs reached")
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .transition(.opacity)
                        .zIndex(1)
                }
            },
            alignment: .center
        )
        .animation(.easeInOut, value: showToast)
        .onAppear {
            addTab()

            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.control) {
                    switch event.keyCode {
                    case 45:  // N key
                        addTab()
                    case 13:  // W key
                        closeTab()
                    case 43:  // Left angular arrow
                        moveFocus(-1)
                    case 47:  // Right angular bracket
                        moveFocus(1)
                    default:
                        break
                    }
                }
                return event
            }
        }
        .task {
            await loadAllClientTools()
        }
    }

    private func loadAllClientTools() async {
        await withTaskGroup(of: (String, [[String: Any]]).self) { group in
            for (clientName, _) in mcp.clients {
                group.addTask {
                    let tools = await mcp.getTools(clientName: clientName)
                    return (clientName, tools)
                }
            }

            for await (clientName, tools) in group {
                allClientTools[clientName] = tools
            }
        }
    }
    private func addTab() {
        if tabs.count >= maxTabs {
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
            }
            return
        }

        withAnimation {
            tabs.append(TabItem())
            focusedIndex = tabs.count - 1
        }
    }

    private func closeTab() {
        guard tabs.count > 1 else { return }  // Don't remove the last tab

        withAnimation {
            tabs.remove(at: focusedIndex)

            // Adjust focus index safely
            if focusedIndex >= tabs.count {
                focusedIndex = tabs.count - 1
            }
        }
    }

    private func moveFocus(_ direction: Int) {
        withAnimation {
            let newIndex = focusedIndex + direction
            if (0..<tabs.count).contains(newIndex) {
                focusedIndex = -1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    focusedIndex = newIndex
                }
            }
        }
    }
}
