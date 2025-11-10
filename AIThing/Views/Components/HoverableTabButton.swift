//
//  HoverableTabButton.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/2/25.
//

import SwiftUI

struct HoverableTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    let deleteAction: () -> Void
    var image: String? = nil
    var isDeletable: Bool = true
    var isExpanded: Bool = true
    var rotateImage: Angle = Angle(degrees: 0)
    var fixedSize = false
    var cornerRadius: CGFloat = 8

    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        if #available(macOS 26.0, *) {
            HoverView()
                .glassEffect(
                    isActive || isHovered ? .regular.interactive() : .identity,
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .padding(.horizontal, 8)
                .onHover { hovering in
                    hoverTask?.cancel()  // cancel any pending hover change
                    hoverTask = Task { @MainActor in
                        // delay a bit before applying the hover state
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovered = hovering
                        }
                    }
                }
        } else {
            HoverView()
                .background(isActive || isHovered ? Color.white.opacity(0.1) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .padding(.horizontal, 8)
                .onHover { hovering in
                    hoverTask?.cancel()  // cancel any pending hover change
                    hoverTask = Task { @MainActor in
                        // delay a bit before applying the hover state
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovered = hovering
                        }
                    }
                }
        }
    }

    private func HoverView() -> some View {
        HStack(spacing: 8) {
            ButtonView()
            // Trash button (shown only when hovered)
            if isDeletable, isHovered, isExpanded {
                DeleteButtonView().padding(.trailing, 8)
            }
        }
        .contentShape(Rectangle())
        .fixedSize(horizontal: fixedSize, vertical: false)
    }

    private func ButtonView() -> some View {
        Button(action: action) {
            HStack {
                if let image = image {
                    Image(systemName: image)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .rotationEffect(rotateImage)
                }

                if isExpanded {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private func DeleteButtonView() -> some View {
        Button(action: deleteAction) {
            Image(systemName: "trash.fill")
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}
