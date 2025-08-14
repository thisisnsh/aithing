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
    @StateObject private var loginManager = LoginManager()
    @EnvironmentObject var screenshotManager: ScreenshotManager
    @StateObject private var firestoreManager = FirestoreManager()

    var onClose: () -> Void
    var updatePanelSizeFromDefault: (CGFloat) -> Void
    var updatePanelSizeFromCurrent: (CGFloat) -> Void
    var getExtraSize: () -> CGFloat
    var setPanelVisibility: () -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    @State private var agents: [AgentEntry] = []
    @State private var allClientTools: [String: [[String: Any]]] = [:]

    @State private var focusedIndex: Int = 0

    @State private var tabs: [TabItem] = []
    @State private var maxTabs: Int = 3
    @State private var width: CGFloat = 640 + 48

    @State private var showSettings = false

    @State private var showToast = false
    @State private var toastText: String = ""
    @State private var toastColor: Color = .white

    @State private var showHelp = false

    private var helpText: String {
        return """
            ## Help: 

            | Command | Description |   | Command | Description | 
            | ------- | ----------- | - | ------- | ----------- | 
            | ` Control (⌃) + Space ` | Show/Hide AI Thing | | ` Control (⌃) + ? ` | Show/Hide Help    | 
            | ` Control (⌃) + N `     | New Tab            | | ` Control (⌃) + W ` | Close Tab         |
            | ` Control (⌃) + S `     | Show/Hide Settings | | ` Control (⌃) + H ` | Show/Hide History |
            | ` Control (⌃) + > `     | Move to Right Tab  | | ` Control (⌃) + < ` | Move to Left Tab  |

            Still Stuck? Check http://aithing.dev 
            """
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(width: 40)
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    tabView(at: index, tab: tab)
                }
                Color.clear.frame(width: 72)
            }
            if showSettings {
                Settings()
            }
            if showHelp {
                Help()
            }
            if showToast {
                Toast()
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
        .onChange(of: showSettings) { newValue in
            updatePanelSizeFromCurrent(showSettings ? 500 : -500)
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
        toastText = "Waking up Agents..."
        showToast = true

        var failure = ""

        let disconnectRc = await mcp.disconnect()
        if !disconnectRc.isEmpty {
            toastColor = .red
            toastText = "Failed to wake up agents: \(disconnectRc)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
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
                failure += "\n\n\(name): \(connectRc)"
            }
        }

        if !failure.isEmpty {
            toastColor = .red
            toastText = "Failed to wake up agents\n" + failure
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (failure.isEmpty ? 2 : 5)) {
            showToast = false
            toastColor = .white
        }
    }

    func Settings() -> some View {
        SettingsView(
            isPresented: $showSettings,
            setPanelVisibility: { self.setPanelVisibility() },
            setPanelPassthrough: { self.setPanelPassthrough($0) }
        )
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white, lineWidth: 1.5)
        }
        .cornerRadius(24)
        .zIndex(1)
        .frame(width: 600, height: 500)
        .padding(.leading, CGFloat(48 + focusedIndex * 72))
        .padding(.trailing, CGFloat(80 + (tabs.count - 1 - focusedIndex) * 72))
        .padding(.top, 96)
        .environmentObject(loginManager)
        .environmentObject(firestoreManager)
    }

    private func Help() -> some View {
        MarkdownText(text: helpText)
            .padding()
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white, lineWidth: 1.5)
            }
            .cornerRadius(24)
            .zIndex(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.leading, CGFloat(48 + focusedIndex * 72))
            .padding(.trailing, CGFloat(80 + (tabs.count - 1 - focusedIndex) * 72))
            .padding(.top, 96)
    }

    private func Toast() -> some View {
        MarkdownText(text: toastText)
            .padding()
            .background(.ultraThinMaterial)
            .overlay {
                AnimatedGradientBorder(
                    cornerRadius: 24,
                    lineWidth: 1.5,
                    color: toastColor
                )
            }
            .cornerRadius(24)
            .zIndex(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.leading, CGFloat(48 + focusedIndex * 72))
            .padding(.trailing, CGFloat(80 + (tabs.count - 1 - focusedIndex) * 72))
            .padding(.top, 96)
    }

    private func onSetting() {
        showSettings.toggle()
        showHelp = false
    }

    private func onHelp() {
        showHelp.toggle()
        showSettings = false
    }

    private func addTab() {
        screenshotManager.cancelScreenshot()

        if tabs.count >= maxTabs {
            toastColor = .red
            toastText = "Maximum of \(maxTabs) tabs reached"
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
            }
            return
        }

        tabs.append(TabItem())
        focusedIndex = tabs.count - 1
    }

    private func closeTab() {
        screenshotManager.cancelScreenshot()

        let indexToRemove = focusedIndex

        if tabs.count == 1 { addTab() }  // Don't remove the last =tab

        tabs.remove(at: indexToRemove)

        // Adjust focus index safely
        if focusedIndex >= tabs.count {
            focusedIndex = tabs.count - 1
        }
    }

    private func moveFocus(_ direction: Int) {
        screenshotManager.cancelScreenshot()

        let count = tabs.count
        guard count > 0 else { return }

        let newIndex = (focusedIndex + direction + count) % count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Increase height to max while switching
            // It will be resized when tab in focus
            if count > 1 {
                updatePanelSizeFromDefault(1000)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            focusedIndex = newIndex
        }
    }

    @ViewBuilder
    private func tabView(at index: Int, tab: TabItem) -> some View {
        let isFocusedBinding = Binding(
            get: { focusedIndex == index },
            set: { if $0 { focusedIndex = index } }
        )
        TabView(
            isFocused: isFocusedBinding,
            tabId: tab.id,
            allTabs: $tabs,
            allClientTools: $allClientTools,
            showSettings: $showSettings,
            onSetting: { self.onSetting() },
            onHelp: { self.onHelp() },
            updatePanelSizeFromDefault: { extraHeight in
                updatePanelSizeFromDefault(extraHeight)
            },
            updatePanelSizeFromCurrent: { height in
                updatePanelSizeFromCurrent(height)
            },
            setPanelPassthrough: { self.setPanelPassthrough($0) }
        )
        .environmentObject(mcp)
        .environmentObject(loginManager)
        .environmentObject(screenshotManager)
        .environmentObject(firestoreManager)
    }

}
