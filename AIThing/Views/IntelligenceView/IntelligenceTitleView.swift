//
//  IntelligenceTitleView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import SwiftUI

extension IntelligenceView {
    func TitleView() -> some View {
        HStack {
            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverRed ? .red.opacity(0.5) : .red)
                .onTapGesture {
                    selectionEnabled = false
                    close()
                }
                .onHover { hoverRed = $0 }

            TextField("Enter Title", text: $tabTitle)
                .focused($isFocused)
                .onSubmit {
                    isFocused = false
                    Task {
                        if !tabTitle.isEmpty, tabTitle.count < 64, tabTitle != "New Chat" {
                            await setTitle(tabId, tabTitle)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.leading, 8)
                .textFieldStyle(.plain)

            Spacer()

            if let lastUpdated = history?.lastUpdated {
                Text(formatEpochLocal(lastUpdated) ?? "")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
            }
        }
        .frame(height: 16)
    }
}

