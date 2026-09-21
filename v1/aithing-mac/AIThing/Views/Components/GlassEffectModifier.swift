//
//  GlassEffectModifier.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import SwiftUI

// MARK: - Glass Effect Types

/// Defines the style of glass effect to apply
enum GlassStyle {
    case regular
    case regularInteractive
    case regularTintedBlack
    case conditionalInteractive(isActive: Bool)
    case identity
}

// MARK: - View Modifier

/// A view modifier that applies glass effect on macOS 26.0+ or a fallback background on earlier versions.
struct GlassEffectModifier<S: Shape>: ViewModifier {
    let shape: S
    let style: GlassStyle
    let fallbackColor: Color
    let fallbackOpacity: Double
    
    init(
        shape: S,
        style: GlassStyle = .regular,
        fallbackColor: Color = .white,
        fallbackOpacity: Double = 0.1
    ) {
        self.shape = shape
        self.style = style
        self.fallbackColor = fallbackColor
        self.fallbackOpacity = fallbackOpacity
    }
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            applyGlassEffect(to: content)
        } else {
            content
                .background(fallbackColor.opacity(fallbackOpacity))
                .clipShape(shape)
        }
    }
    
    @available(macOS 26.0, *)
    @ViewBuilder
    private func applyGlassEffect(to content: Content) -> some View {
        switch style {
        case .regular:
            content.glassEffect(.regular, in: shape)
        case .regularInteractive:
            content.glassEffect(.regular.interactive(), in: shape)
        case .regularTintedBlack:
            content.glassEffect(.regular.tint(.black), in: shape)
        case .conditionalInteractive(let isActive):
            if isActive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.identity, in: shape)
            }
        case .identity:
            content.glassEffect(.identity, in: shape)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a glass effect with the specified shape on macOS 26.0+, or a fallback background on earlier versions.
    func glassBackground<S: Shape>(
        _ shape: S,
        style: GlassStyle = .regular,
        fallbackColor: Color = .white,
        fallbackOpacity: Double = 0.1
    ) -> some View {
        modifier(GlassEffectModifier(
            shape: shape,
            style: style,
            fallbackColor: fallbackColor,
            fallbackOpacity: fallbackOpacity
        ))
    }
    
    /// Applies a glass effect with a rounded rectangle on macOS 26.0+, or a fallback background on earlier versions.
    func glassBackground(
        cornerRadius: CGFloat,
        style: GlassStyle = .regular,
        fallbackColor: Color = .white,
        fallbackOpacity: Double = 0.1
    ) -> some View {
        glassBackground(
            RoundedRectangle(cornerRadius: cornerRadius),
            style: style,
            fallbackColor: fallbackColor,
            fallbackOpacity: fallbackOpacity
        )
    }
}

// MARK: - Glass Background Shape

/// A shape that displays with glass effect on macOS 26.0+ or a solid fill on earlier versions.
struct GlassBackgroundShape: View {
    let cornerRadius: CGFloat
    let tintBlack: Bool
    
    init(cornerRadius: CGFloat, tintBlack: Bool = false) {
        self.cornerRadius = cornerRadius
        self.tintBlack = tintBlack
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .glassEffect(
                    tintBlack ? .regular.tint(.black) : .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.white.opacity(0.1))
        }
    }
}

// MARK: - Glass Background for Custom Shapes

/// Creates a glass-backed view using a custom shape on macOS 26.0+ or a material fallback.
struct GlassCustomShape<S: Shape>: View {
    let shape: S
    let tintBlack: Bool
    let strokeColor: Color?
    let strokeWidth: CGFloat
    let overlayContent: AnyView?
    
    init(
        shape: S,
        tintBlack: Bool = false,
        strokeColor: Color? = nil,
        strokeWidth: CGFloat = 1,
        overlayContent: AnyView? = nil
    ) {
        self.shape = shape
        self.tintBlack = tintBlack
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.overlayContent = overlayContent
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            Group {
                if let strokeColor = strokeColor {
                    shape
                        .stroke(strokeColor, lineWidth: strokeWidth)
                } else {
                    shape
                }
            }
            .overlay(overlayContent)
            .glassEffect(
                tintBlack ? .regular.tint(.black) : .regular,
                in: shape
            )
        } else {
            shape
                .fill(.ultraThickMaterial)
                .shadow(color: strokeColor?.opacity(0.5) ?? .clear, radius: strokeWidth > 0 ? 1 : 0)
                .overlay(overlayContent)
        }
    }
}

