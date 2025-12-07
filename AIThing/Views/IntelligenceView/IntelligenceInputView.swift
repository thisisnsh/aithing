//
//  IntelligenceInputView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import SwiftUI

extension IntelligenceView {
    func InputView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showMcpTools {
                ToolsView(
                    allClientTools: $allClientTools,
                    cornerRadius: cornerRadius - 4
                )
            } else {
                ZStack(alignment: .leading) {

                    if !isThinking, !isDropping, !showGetStarted {
                        InputTextView(
                            text: $query,
                            seenCommands: .constant([]),
                            size: $textSize,
                            isNotEditable: isThinking || isDropping,
                            onCommit: { Task { await handleQuery() } },
                            onCommandTyped: { _ in },
                            onCommandRemoved: { _ in },
                            onDebouncedTextChange: { _ in },
                            onSpillover: { count in
                                if count >= 2 && count <= 5 {
                                    inputHeight = CGFloat(count) * baseHeight
                                } else if count > 5 {
                                    inputHeight = 5 * baseHeight
                                } else {
                                    inputHeight = baseHeight
                                }
                            }
                        )
                    }

                    if query.isEmpty || isDropping || isThinking || showGetStarted {
                        Text(
                            showGetStarted
                                ? getStarted
                                : (isThinking
                                    ? isThinkingText
                                    : (isDropping
                                        ? "Drop files here..." : "Ask anything on AI Thing..."))
                        )
                        .foregroundColor(isDropping ? .blue : .white.opacity(0.6))
                        .font(.system(size: textSize, weight: .medium))
                        .padding(.top, 2)
                        .padding(.leading, 5)
                        .allowsHitTesting(showGetStarted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: inputHeight)
            }
        }
        .padding(.vertical, showMcpTools ? 0 : 8)
        .padding(.bottom, 40)
        .padding(8)
        .overlay(
            Group {
                if isThinking {
                    AnimatedGradientBorder(
                        cornerRadius: cornerRadius - 4,
                        lineWidth: 1.5,
                        color: .white
                    )
                } else if isDropping {
                    AnimatedGradientBorder(
                        cornerRadius: cornerRadius - 4,
                        lineWidth: 1.5,
                        color: .blue
                    )
                }
            }
        )
    }
}
