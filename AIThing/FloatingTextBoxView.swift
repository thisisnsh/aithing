//
//  FloatingTextBoxView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct FloatingTextBoxView: View {
    var onClose: () -> Void
    var onSizeChange: (Bool) -> Void  // 👈 Callback to AppDelegate

    @State private var query = ""
    @State private var selectedOption = "Local"
    @State private var aiResponse: String = ""
    @State private var isLoading: Bool = false
    @State private var showResponseArea = false

    @State private var selectedAI = "Sonnet 4"

    var body: some View {
        ZStack {
            BlurredBackground()
                .contentShape(Rectangle())  // ✅ clickable for dragging

            VStack(spacing: 0) {

                HStack(spacing: 8) {
                    Menu {
                        Button("Local") { selectedOption = "Local" }
                            .keyboardShortcut("l", modifiers: [.command])  // ⌘L

                        Button("Global") { selectedOption = "Global" }
                            .keyboardShortcut("g", modifiers: [.command])  // ⌘G

                    } label: {
                        Text(selectedOption)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .regular))
                            .padding(.horizontal, 2)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 64)
                    .opacity(0.5)

                    FocusableTextField(
                        text: $query,
                        onCommit: {
                            Task {
                                await handleQuery()
                            }
                        }
                    )

                    Button(action: handleClose) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(0.5)
                }
                .frame(height: 32)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)

                if showResponseArea {
                    ScrollView {
                        Text(isLoading ? "Thinking..." : aiResponse)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .frame(width: 640, height: showResponseArea ? 248 : 48)
        .background(Color.clear)  // make the full panel draggable
        .overlay(
            Group {
                if isLoading {
                    AnimatedGradientBorder(cornerRadius: showResponseArea ? 24 : 32, lineWidth: 2)
                }
            }
        )
        .cornerRadius(showResponseArea ? 24 : 32)
        .onExitCommand(perform: handleClose)
    }

    func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        showResponseArea = true
        aiResponse = ""
        onSizeChange(true)

        await callAI(query: trimmed)

        isLoading = false
    }

    func callAI(query: String) async {
        // use selectedOption
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        aiResponse = "This is the response to: \"\(query)\""
    }

    func handleClose() {
        query = ""
        aiResponse = ""
        isLoading = false
        showResponseArea = false
        onSizeChange(false)
        onClose()
    }
}
