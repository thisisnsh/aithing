//
//  FloatingTextBoxView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct FloatingTextBoxView: View {
    var onClose: () -> Void
    @State private var query = ""
    @State private var selectedOption = "Sonnet 4"
    @State private var aiResponse: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        ZStack {
            BlurredBackground()
                .contentShape(Rectangle())  // ✅ clickable for dragging

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Sonnet 4") { selectedOption = "Sonnet 4" }
                    } label: {
                        Text(selectedOption)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .regular))
                            .padding(.horizontal, 2)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 100)

                    FocusableTextField(
                        text: $query,
                        onCommit: {
                            Task {
                                await handleQuery()
                            }
                        }
                    )
                    .frame(height: 32)

                    Button(action: {
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                if !aiResponse.isEmpty || isLoading {
                    Divider().background(Color.white.opacity(0.3))

                    ScrollView {
                        Text(aiResponse.isEmpty ? "Thinking..." : aiResponse)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(minHeight: 100, maxHeight: 200)
                    .background(Color.black.opacity(0.3))
                }
            }

        }
        .frame(width: 640)
        .background(Color.clear)  // make the full panel draggable
        .overlay(
            Group {
                if isLoading {
                    AnimatedGradientBorder(cornerRadius: 32, lineWidth: 2)
                }
            }
        ).cornerRadius(32)
        .onExitCommand(perform: onClose)
    }

    func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        aiResponse = ""  // clear old response
        await callAI(query: trimmed)
        isLoading = false
    }

    func callAI(query: String) async {
        // Simulate delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        aiResponse = "This is the response to: \"\(query)\""
    }
}
