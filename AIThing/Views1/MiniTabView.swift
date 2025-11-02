//
//  MiniTabView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/27/25.
//

import SwiftUI
import os

struct MiniTabView: View {
    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "MiniTabView")

    var onClick: () -> String
    var onClose: () -> Void
    let onSetting: () -> Void
    let expandSize: (_ response: Bool) -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    private func updatePassthrough(inside: Bool) {
        setPanelPassthrough(!inside)
    }

    private let miniWidth: CGFloat = 16
    private let miniHeight: CGFloat = 16
    private let miniWidthExpanded: CGFloat = 320
    private let miniHeightExpanded: CGFloat = 320

    @State private var text: String = ""

    @State private var inputHeight: CGFloat = 48
    @State private var imageName: String = "Logo"
    @State private var title: String = "AI Thing"

    @State private var query: String = ""
    @State private var seenCommands: Set<String> = []
    @State private var showDragIcon: Bool = false

    @State private var expanded = false
    @State private var collapseWork: DispatchWorkItem?

    @State private var showResponseArea = false
    @State private var isThinkingBlinking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputView()
            if expanded, showResponseArea {
                responseView()
            }
        }
        .background(.ultraThinMaterial)
        .frame(width: .infinity, height: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.25), value: expanded)
        .overlay(
            RoundedRectangle(cornerRadius: getCornerRadius())
                .stroke(Color.white, lineWidth: 1.5)
        )
        .cornerRadius(getCornerRadius())
        .shadow(radius: 4)
        .padding(8)
        .onHover { inside in
            if expanded { return }

            // Debounced collapse to prevent flicker on tiny exits
            if inside {
                collapseWork?.cancel()
                withAnimation(.easeInOut(duration: 0.25)) {
                    expanded = true
                }
            } else {
                let w = DispatchWorkItem {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expanded = false
                    }
                }
                collapseWork?.cancel()
                collapseWork = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: w)
            }
        }
        .onChange(of: expanded) { newValue in
            expandSize(false)
        }
        .onAppear {
            // Auto close after 5 seconds of inaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !expanded {
                    onClose()
                }
            }
        }
        .onExitCommand {
            onClose()
        }
    }

    private func inputView() -> some View {
        HStack(spacing: 0) {
            if expanded {
                ZStack(alignment: .leading) {
                    InputTextView(
                        text: $query,
                        seenCommands: $seenCommands,
                        size: .constant(18),
                        isNotEditable: false,
                        onCommit: {},
                        onCommandTyped: { x in },
                        onCommandRemoved: { x in },
                        onDebouncedTextChange: { x in },
                        onSpillover: { x in }
                    )
                    .onChange(of: query) { x in
                        showResponseArea = true
                        expandSize(true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .padding(.leading, 16)

                    if query.isEmpty {
                        Text("Ask on AI Thing...")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, -6)
                            .allowsHitTesting(false)
                            .padding(8)
                            .padding(.leading, 16)
                    }
                }

                Button(
                    action: {
                        onSetting()
                        AnalyticsManager.shared.customEvent(type: .action, primary: "settings")
                    }
                ) {
                    Image(systemName: "gearshape.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 18, height: 18)
                .padding(8)
                .padding(.trailing, 16)
            } else {
                LogoShape()
                    .fill(.white)
                    .scaledToFit()
                    .padding(2)
            }
        }
        .frame(
            width: expanded ? miniWidthExpanded : miniWidth,
            height: expanded ? inputHeight : miniHeight,
        )
        .onHover { inside in updatePassthrough(inside: inside) }
    }

    private func responseView() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    Text("Thinking...")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .opacity(isThinkingBlinking ? 1 : 0.4)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                            ) {
                                isThinkingBlinking.toggle()
                            }
                        }

                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ViewHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .frame(width: miniWidthExpanded, height: miniHeightExpanded - inputHeight)
            .background(Color.black.opacity(0.3))
        }
        .onHover { inside in updatePassthrough(inside: inside) }
    }

    private func getCornerRadius() -> CGFloat {
        return showResponseArea ? 24 : 32
    }
}
