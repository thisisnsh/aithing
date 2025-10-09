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
    let expandSize: () -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    private func updatePassthrough(inside: Bool) {
        setPanelPassthrough(!inside)
    }

    @State private var text: String = ""

    @State private var inputHeight: CGFloat = 48
    @State private var imageName: String = "Logo"
    @State private var title: String = "AI Thing"

    @State private var query: String = ""
    @State private var seenCommands: Set<String> = []
    @State private var showDragIcon: Bool = false

    @State private var expanded = false
    @State private var collapseWork: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputView()
                .frame(
                    width: expanded ? 304 : 32,
                    height: expanded ? 48 : 32,
                    alignment: .topLeading
                )
                .animation(.easeInOut(duration: 0.25), value: expanded)
                .background(.ultraThinMaterial)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: getCornerRadius())
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .cornerRadius(getCornerRadius())
                .shadow(radius: 4)
                .onHover { inside in updatePassthrough(inside: inside) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)  // anchor left
        .padding(8)
        .background(Color.clear)  // keep outer background inert
        .contentShape(Rectangle())
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
            expandSize()
        }
        .onAppear {
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
        HStack(spacing: 8) {
            LogoShape()
                .fill(.white)
                .scaledToFit()
                .frame(width: expanded ? 0 : 16)
                .opacity(expanded ? 0 : 1)

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
                    .onChange(of: query) { x in }
                    .opacity(1)
                    .frame(width: 254)
                    .padding(.vertical, 8)
                    .padding(.leading, -8)

                    if query.isEmpty {
                        Text("Ask on AI Thing...")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, -2)
                            .allowsHitTesting(false)
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
                        .padding(.vertical, 2)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 18, height: 18)
            }
        }
        .padding(.vertical, expanded ? 0 : 8)
        .padding(.horizontal, expanded ? 16 : 8)
    }

    private func getCornerRadius() -> CGFloat {
        return 32
    }
}
