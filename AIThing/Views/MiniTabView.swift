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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 32).overlay(alignment: .bottom) {
                if showDragIcon {
                    Image(systemName: "square.grid.3x2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .shadow(color: .black, radius: 1)
                        .onHover { inside in
                            if inside {
                                NSCursor.openHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                            updatePassthrough(inside: inside)
                        }
                }
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                inputView()
                    .onHover { inside in
                        updatePassthrough(inside: inside)
                    }
            }
            .background(.ultraThinMaterial)
            .frame(
                height: 48,
                alignment: .topLeading
            )
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: getCornerRadius())
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .cornerRadius(getCornerRadius())
            .shadow(radius: 4)

            .padding(.bottom, 8)

        }
        .onHover { inside in
            showDragIcon = inside
        }
    }

    private func inputView() -> some View {
        HStack(spacing: 8) {
            LogoShape()
                .fill(.white)
                .scaledToFit()
                .frame(width: 32)
                .onTapGesture {
                    query = onClick()
                    expanded = true
                }

            if expanded {
                ZStack(alignment: .leading) {
                    InputTextView(
                        text: $query,  // .constant(text),
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
                    .frame(width: 200)

                    if query.isEmpty {
                        Text("Ask anything...")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                }

                Button(
                    action: {
                        onClose()
                    }
                ) {
                    Image(systemName: "x.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 18, height: 18)
            }
        }
        .frame(height: 48 - 16)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private func getCornerRadius() -> CGFloat {
        return 32
    }
}
