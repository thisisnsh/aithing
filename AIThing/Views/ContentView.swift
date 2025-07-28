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
    var resizePanel: (CGFloat) -> Void
    var incrementSizePanel: (CGFloat) -> Void
    var getExtraSize: () -> CGFloat

    @State private var allClientTools: [String: [[String: Any]]] = [:]

    @State private var focusedIndex: Int = 0
    @State private var showToast = false
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var tabs: [TabItem] = []
    @State private var agents: [AgentEntry] = []

    @State private var maxTabs: Int = 5
    @State private var width: CGFloat = 640 + 48

    @State private var toastText: String = ""
    private var helpText: String {
        return """
            ## Help Sheet

            | Command | Description |   | Command | Description | 
            | ------- | ----------- | - | ------- | ----------- | 
            | ` Control (⌃) + Space ` | Show/Hide AI Thing | | | | 
            | ` Control (⌃) + N `     | New Tab            | | ` Control (⌃) + W ` | Close Tab |
            | ` Control (⌃) + S `     | Show/Hide Settings | | ` Control (⌃) + H ` | Show Help |
            | ` Control (⌃) + > `     | Move to Right Tab  | | ` Control (⌃) + < ` | Move to Left Tab  |
            """
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(width: 40)
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    tabView(at: index)
                }
                Color.clear.frame(width: 72)
            }
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .background(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                    .cornerRadius(24)
                    .zIndex(1)
                    .frame(width: 600, height: 500)
                    .padding(.leading, 48)
                    .padding(.trailing, 80)
                    .padding(.top, 16)
            }
            if showToast || showHelp {
                MarkdownText(text: showHelp ? helpText : toastText)
                    .padding()
                    .background(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                    .cornerRadius(24)
                    .zIndex(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.leading, 48)
                    .padding(.trailing, 80)
                    .padding(.top, 16)
            }
        }
        .frame(width: CGFloat(640 + 48) + CGFloat((tabs.count)) * CGFloat(72))
        .background(Color.clear)
        .onAppear {
            addTab()

            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.control) {
                    switch event.keyCode {
                    case 1:  // S key
                        onSetting()
                        return nil
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
        .onChange(of: showSettings) {
            incrementSizePanel(showSettings ? 500 : -500)
            Task {
                await loadAllClientTools()
            }
        }
        .task {
            await loadAllClientTools()
        }
    }

    private func loadAllClientTools() async {
        let newAgents = getAgentEntries()
        var allMatch = true

        if agents.count == newAgents.count {
            for (i, agent) in newAgents.enumerated() {
                let existing = agents[i]
                if existing.id != agent.id || existing.isEnabled != agent.isEnabled {
                    allMatch = false
                    break
                }
            }
        } else {
            allMatch = false
        }

        if allMatch {
            return
        }

        agents = newAgents
        toastText = "💤 Waking up Agents..."
        showToast = true

        var failure = ""

        let disconnectRc = await mcp.disconnect()
        if !disconnectRc.isEmpty {
            toastText = "❌ Failed to wake up agents: \(disconnectRc)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
            }
            return
        }

        allClientTools.removeAll()

        for agent in agents {
            if !agent.isEnabled {
                continue
            }

            let name: String
            let connectRc: String

            switch agent.entry {
            case let .url(n, url):
                name = n
                connectRc = await mcp.connect(clientName: name, url: url, authToken: nil)

            case let .urlWithToken(n, url, token):
                name = n
                connectRc = await mcp.connect(clientName: name, url: url, authToken: token)

            case let .command(n, command, arguments):
                name = n
                connectRc = await mcp.connect(clientName: name, command: command, args: arguments)
            }

            if connectRc.isEmpty {
                let tools = await mcp.getTools(clientName: name)
                allClientTools[name] = tools
            } else {
                failure += "\n\n- \(name): \(connectRc)"
            }
        }

        if !failure.isEmpty {
            toastText = "❌ Failed to wake up agents\n" + failure
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (failure.isEmpty ? 2 : 5)) {
            showToast = false
        }
    }

    private func onSetting() {
        showSettings.toggle()
    }

    private func onHelp() {
        showHelp = true
        incrementSizePanel(200)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showHelp = false
            incrementSizePanel(-200)
        }
    }

    private func addTab() {
        if tabs.count >= maxTabs {
            toastText = "Maximum of \(maxTabs) tabs reached"
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
        let indexToRemove = focusedIndex

        if tabs.count == 1 { addTab() }  // Don't remove the last =tab

        withAnimation {
            tabs.remove(at: indexToRemove)

            // Adjust focus index safely
            if focusedIndex >= tabs.count {
                focusedIndex = tabs.count - 1
            }
        }
    }

    private func moveFocus(_ direction: Int) {
        withAnimation {
            let count = tabs.count
            guard count > 0 else { return }

            let newIndex = (focusedIndex + direction + count) % count
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Increase height to max while switching
                // It will be resized when tab in focus
                resizePanel(1000)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focusedIndex = newIndex
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
            allClientTools: $allClientTools,
            onHelp: { self.onHelp() },
            resizePanel: { extraHeight in
                resizePanel(extraHeight)
            },
            incrementSizePanel: { height in
                incrementSizePanel(height)
            }
        )
        .environmentObject(mcp)
        .animation(.easeInOut, value: focusedIndex)
    }

}
