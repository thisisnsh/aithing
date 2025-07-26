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
    var getExtraSize: () -> CGFloat

    @State private var allClientTools: [String: [[String: Any]]] = [:]

    @State private var focusedIndex: Int = 0
    @State private var showToast = false
    @State private var showHelp = false
    @State private var tabs: [TabItem] = []

    @State private var maxTabs: Int = 5

    private var helpText: String {
        return """
            ## Help Sheet

            | Command | Description |   | Command | Description | 
            | ------- | ----------- | - | ------- | ----------- | 
            | ` Control (⌃) + Space ` | Show/Hide AI Thing | | ` Control (⌃) + H ` | Show Help | 
            | ` Control (⌃) + N `     | New Tab            | | ` Control (⌃) + W ` | Close Tab | 
            | ` Control (⌃) + > `     | Move to Right Tab  | | ` Control (⌃) + < ` | Move to Left Tab  |
            """
    }

    var body: some View {
        ZStack {
            HStack(alignment: .top, spacing: 8) {
                ForEach(tabs.indices, id: \.self) { index in
                    tabView(at: index)
                }
            }
        }
        .frame(width: CGFloat(640) + CGFloat((tabs.count - 1)) * CGFloat(72))
        .background(Color.clear)
        .overlay(
            Group {
                if showToast || showHelp {
                    MarkdownText(text: showHelp ? helpText : "Maximum of \(maxTabs) tabs reached")
                        .padding()
                        .background(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white, lineWidth: 1.5)
                        }
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .transition(.opacity)
                        .zIndex(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(16)
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
                    case 4:  // H key
                        onHelp()
                        return nil
                    case 45:  // N key
                        addTab()
                        return nil
                    case 13:  // W key
                        closeTab()
                        return nil
                    case 43:  // Left angular arrow
                        moveFocus(-1)
                        return nil
                    case 47:  // Right angular bracket
                        moveFocus(1)
                        return nil
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

    private func onHelp() {
        showHelp = true
        let extraHeight = getExtraSize()
        onSizeChange(200)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showHelp = false
            onSizeChange(extraHeight)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedIndex = newIndex
                }
            }
        }
    }

    @ViewBuilder
    private func tabView(at index: Int) -> some View {
        let isFocusedBinding = Binding(
            get: { focusedIndex == index },
            set: { if $0 { focusedIndex = index } }
        )

        TabView(
            isFocused: isFocusedBinding,
            allClientTools: allClientTools,
            onHelp: { self.onHelp() },
            onSizeChange: { extraHeight in
                onSizeChange(extraHeight)
            }
        )
        .environmentObject(mcp)
        .animation(.easeInOut, value: focusedIndex)
    }

}
