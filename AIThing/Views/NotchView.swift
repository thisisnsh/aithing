//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

struct NotchView: View {
    @StateObject var mcpManager = MCPManager()
    @StateObject var loginManager = LoginManager()
    @StateObject var firestoreManager = FirestoreManager()

    let updateWindowSize: (WindowSize) -> (CGFloat, CGFloat)

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var windowSize = WindowSize.alpha

    @State private var tabId = UUID()

    var body: some View {
        ZStack {
            NotchShape(width: width, height: height, cornerRadius: 16)
                .fill(.black)

            HStack(spacing: 0) {
                if windowSize.rawValue >= WindowSize.gamma.rawValue {
                    IntelligenceView(
                        isFocused: .constant(true),
                        tabId: tabId,
                        tabHistory: nil,
                        allTabs: .constant([]),
                        allClientTools: .constant([:]),
                        managedModels: .constant([]),
                        resizeAlpha: resizeAlpha,
                        resizeBeta: resizeBeta,
                        resizeGamma: resizeGamma,
                        resizeDelta: resizeDelta,
                        toggleGammaDelta: toggleGammaDelta,
                        reconnectManagedAgents: {}
                    )
                    .environmentObject(mcpManager)
                    .environmentObject(loginManager)
                    .environmentObject(firestoreManager)
                }

                VStack(alignment: .center, spacing: 0) {
                    LogoShape()
                        .fill(.white)
                        .scaledToFit()
                        .frame(height: 32)
                        .padding(.top, 8)

                    if windowSize.rawValue >= WindowSize.beta.rawValue {
                        Divider().padding(.vertical, 8)

                        Image(systemName: "plus.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .onTapGesture {
                                resizeGamma()
                            }
                            .padding(.top, 8)
                    }

                    Spacer()
                }
                .frame(width: 60)
            }
            .padding(.vertical, 24)
        }
        .frame(width: width, height: height)
        .onAppear {
            resizeAlpha()
        }
        .onHover { hovering in
            if windowSize != WindowSize.gamma {
                if hovering {
                    if windowSize == WindowSize.alpha {
                        resizeBeta()
                    }
                } else {
                    if windowSize == WindowSize.beta {
                        resizeAlpha()
                    }
                }
            }
        }
    }

    private func resizeAlpha() {
        windowSize = WindowSize.alpha
        (width, height) = updateWindowSize(windowSize)
    }

    private func resizeBeta() {
        windowSize = WindowSize.beta
        (width, height) = updateWindowSize(windowSize)
    }

    private func resizeGamma() {
        windowSize = WindowSize.gamma
        (width, height) = updateWindowSize(windowSize)
    }

    private func resizeDelta() {
        windowSize = WindowSize.delta
        (width, height) = updateWindowSize(windowSize)
    }

    private func toggleGammaDelta() {
        if windowSize == WindowSize.delta {
            resizeGamma()
        } else {
            resizeDelta()
        }
    }
}
