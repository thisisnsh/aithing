//
//  ResizeViews.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

extension NotchView {
    func ResizeViewX() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .frame(width: 8)
                .onHover { inside in
                    resizeHoverTask?.cancel()
                    resizeHoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        if inside {
                            showResizeX = inside
                        } else {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 3,
                                execute: {
                                    showResizeX = inside
                                }
                            )
                        }

                        if inside {
                            NSCursor.resizeLeftRight.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }

            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.3))
                .padding(.horizontal, 2)
                .frame(width: 8, height: 64)
                .opacity(showResizeX ? 1 : 0)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            NSCursor.resizeLeftRight.set()
                            let rawX = value.translation.width * -1
                            smoothedX += (rawX - smoothedX) * alpha
                            let roundedX = (smoothedX / pixelStep).rounded() * pixelStep
                            if roundedX != lastAppliedX {
                                lastAppliedX = roundedX
                                let size = CGSize(width: roundedX, height: 0)
                                (width, height) = modifyWindowSize(size, windowSize)
                            }

                        }
                        .onEnded { _ in
                            smoothedX = 0
                            lastAppliedX = 0
                            NSCursor.arrow.set()
                        }
                )
        }
        .padding(.vertical, 32)
    }

    func ResizeViewY() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .frame(height: 8)
                .onHover { inside in
                    resizeHoverTask?.cancel()
                    resizeHoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        if inside {
                            showResizeY = inside
                        } else {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 3,
                                execute: {
                                    showResizeY = inside
                                }
                            )
                        }

                        if inside {
                            NSCursor.resizeUpDown.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }

            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.3))
                .padding(.vertical, 2)
                .frame(width: 64, height: 8)
                .opacity(showResizeY ? 1 : 0)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            NSCursor.resizeUpDown.set()
                            let rawY = value.translation.height
                            smoothedY += (rawY - smoothedY) * alpha
                            let roundedY = (smoothedY / pixelStep).rounded() * pixelStep
                            if roundedY != lastAppliedY {
                                lastAppliedY = roundedY
                                let size = CGSize(width: 0, height: roundedY)
                                (width, height) = modifyWindowSize(size, windowSize)                                
                            }
                        }
                        .onEnded { _ in
                            smoothedY = 0
                            lastAppliedY = 0                            
                            NSCursor.arrow.set()
                        }
                )

        }
        .padding(.horizontal, 32)
        .padding(.bottom, -8)
    }
}

