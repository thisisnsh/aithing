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
        VStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: isZoomed ? 200 : 50, alignment: .leading)
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
        VStack {
            ZStack {
                if isZoomed {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: isZoomed ? 200 : 50, alignment: .leading)
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
                        .frame(height: isZoomed ? 200 : 50, alignment: .leading)
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
                    .frame(height: isZoomed ? 200 : 50, alignment: .leading)
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
        VStack {
            Text(isZoomed ? name : name.components(separatedBy: ".").last ?? name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(isZoomed ? 4 : 2)
                .frame(width: isZoomed ? 200 : 50, height: isZoomed ? 200 : 50, alignment: .center)
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
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
