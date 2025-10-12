//
//  ContextView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
//

import SwiftUI

struct ImageContextView: View {
    let name: String
    let image: NSImage
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var trashShow = false
    @State private var nameShow = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)

                if !compact && trashShow {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.red)
                            .padding(2)
                            .background(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !compact && nameShow {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .padding(4)
            }
        }
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
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.3)) {
                trashShow = inside
                nameShow = inside
            }
        }
        .padding(.top, 8)
    }
}

struct PDFContextView: View {
    let name: String
    let image: NSImage
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var trashShow = false
    @State private var nameShow = false

    var body: some View {
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
                    .rotationEffect(.degrees(4))
            }

            VStack(spacing: 0) {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)

                    if !compact && trashShow {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 12, height: 12)
                                .foregroundStyle(.red)
                                .padding(2)
                                .background(.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                if !compact && nameShow {
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(2)
                        .padding(4)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 16 : 8))
            .overlay {
                RoundedRectangle(cornerRadius: isZoomed ? 16 : 8).stroke(
                    Color.white,
                    lineWidth: 1
                )
            }
        }
        .onTapGesture {
            withAnimation(
                .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
            ) { onTap() }
        }
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.3)) {
                trashShow = inside
                nameShow = inside
            }
        }
        .padding(.top, 8)
    }
}

struct TextContextView: View {
    let name: String
    let compact: Bool
    let isZoomed: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var trashShow = false
    @State private var nameShow = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(
                    isZoomed ? name : name.components(separatedBy: ".").last ?? name
                )
                .font(.system(size: 14, weight: .medium))
                .lineLimit(isZoomed ? 4 : 2)
                .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 180, alignment: .center)

                if !compact && trashShow {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.red)
                            .padding(2)
                            .background(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !compact && nameShow {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(2)
                    .padding(4)
            }
        }
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
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.3)) {
                trashShow = inside
                nameShow = inside
            }
        }
        .padding(.top, 8)
    }
}
