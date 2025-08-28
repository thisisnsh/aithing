//
//  ContextView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
//

import SwiftUI

struct ImageContextView: View {
    let image: NSImage
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var trashShow = false

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 16 : 8))
                .overlay {
                    RoundedRectangle(cornerRadius: isZoomed ? 16 : 8).stroke(
                        Color.white,
                        lineWidth: 1
                    )
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2))
                    { onTap() }
                }
                .padding(.top, 8)

            if !compact && trashShow {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onHover { inside in
            trashShow = inside
        }
    }
}

struct PDFContextView: View {
    let image: NSImage
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var trashShow = false

    var body: some View {
        ZStack {
            ZStack {
                if isZoomed {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { Color.black.opacity(0.5) }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.white,
                                lineWidth: 1
                            )
                        }
                        .padding(.top, 4)
                        .rotationEffect(.degrees(-4))

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { Color.black.opacity(0.5) }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.white,
                                lineWidth: 1
                            )
                        }
                        .padding(.top, 4)
                        .rotationEffect(.degrees(4))
                }

                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).stroke(
                            Color.white,
                            lineWidth: 1
                        )
                    }
                    .onTapGesture {
                        withAnimation(
                            .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
                        ) { onTap() }
                    }
                    .padding(.top, 8)
            }

            if !compact && trashShow {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onHover { inside in
            trashShow = inside
        }
    }
}

struct TextContextView: View {
    let name: String
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var trashShow = false

    var body: some View {
        ZStack {
            Text(
                isZoomed ? name : name.components(separatedBy: ".").last ?? name
            )
            .font(.system(size: 14, weight: .medium))
            .lineLimit(isZoomed ? 4 : 2)
            .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 180, alignment: .center)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(
                    Color.white,
                    lineWidth: 1
                )
            }
            .onTapGesture {
                withAnimation(
                    .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
                ) { onTap() }
            }
            .padding(.top, 8)

            if !compact && trashShow {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onHover { inside in
            trashShow = inside
        }
    }
}
