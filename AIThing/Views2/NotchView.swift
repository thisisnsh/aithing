//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

struct NotchView: View {
    let updateWindowSize: (WindowSize) -> (CGFloat, CGFloat)

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var windowSize = WindowSize.alpha

    var body: some View {
        ZStack {
            NotchShape(width: width, height: height, cornerRadius: 16)
                .fill(.black)

            HStack(spacing: 0) {

                if windowSize.rawValue >= WindowSize.gamma.rawValue {
                    VStack {
                        HStack {
                            Circle()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(.red)
                                .onTapGesture {
                                    windowSize = WindowSize.alpha
                                    (width, height) = updateWindowSize(windowSize)
                                }

                            Circle()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(.yellow)
                                .onTapGesture {
                                    windowSize = WindowSize.alpha
                                    (width, height) = updateWindowSize(windowSize)
                                }

                            Circle()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(.green)
                                .onTapGesture {
                                    if windowSize == WindowSize.delta {
                                        windowSize = WindowSize.gamma
                                        (width, height) = updateWindowSize(windowSize)
                                    } else {
                                        windowSize = WindowSize.delta
                                        (width, height) = updateWindowSize(windowSize)
                                    }

                                }

                            Text("Some Window Title")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.leading, 8)

                            Spacer()
                        }

                        VStack {
                            Text(
                                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
                            )
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.vertical, 16)

                        VStack {
                            HStack {
                                HStack {
                                    Text("Selected Text")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.black)
                                    Image(systemName: "xmark.circle")
                                        .resizable()
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(.black)
                                }
                                .padding(4)
                                .padding(.horizontal, 4)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                HStack {
                                    Text("Some Image")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.black)
                                    Image(systemName: "xmark.circle")
                                        .resizable()
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(.black)
                                }
                                .padding(4)
                                .padding(.horizontal, 4)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                Spacer()
                            }

                            HStack {
                                Text("Ask anything on AI Thing...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                            }
                            .padding(.vertical, 8)

                        }
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, 8)
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
                                windowSize = WindowSize.gamma
                                (width, height) = updateWindowSize(windowSize)
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
            windowSize = WindowSize.alpha
            (width, height) = updateWindowSize(windowSize)
        }
        .onHover { hovering in
            if windowSize != WindowSize.gamma {
                if hovering {
                    if windowSize == WindowSize.alpha {
                        windowSize = WindowSize.beta
                        (width, height) = updateWindowSize(WindowSize.beta)
                    }
                } else {
                    if windowSize == WindowSize.beta {
                        windowSize = WindowSize.alpha
                        (width, height) = updateWindowSize(WindowSize.alpha)
                    }
                }
            }
        }
    }
}
