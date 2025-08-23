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

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
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

            if !compact {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct PDFContextView: View {
    let image: NSImage
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if isZoomed {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { Color.black.opacity(0.5) }
                        .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 16 : 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: isZoomed ? 16 : 8).stroke(
                                Color.white,
                                lineWidth: 1
                            )
                        }
                        .padding(.top, 8)
                        .rotationEffect(.degrees(-8))

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { Color.black.opacity(0.5) }
                        .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 16 : 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: isZoomed ? 16 : 8).stroke(
                                Color.white,
                                lineWidth: 1
                            )
                        }
                        .padding(.top, 8)
                        .rotationEffect(.degrees(8))
                }

                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 16 : 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: isZoomed ? 16 : 8).stroke(
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

            if !compact {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct TextContextView: View {
    let name: String
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Text(isZoomed ? name : name.components(separatedBy: ".").last ?? name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(isZoomed ? 4 : 2)
                .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 180, alignment: .center)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 16 : 8))
                .overlay {
                    RoundedRectangle(cornerRadius: isZoomed ? 16 : 8).stroke(
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

            if !compact {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
