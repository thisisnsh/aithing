//
//  ContextGridView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
//

import SwiftUI

private struct GridSpanKey: LayoutValueKey {
    static let defaultValue: Int = 1
}

struct MasonryGrid: Layout {
    func makeCache(subviews: Subviews) -> Void? {
        return nil
    }

    let columns: Int
    let columnWidth: CGFloat
    let spacing: CGFloat

    init(columns: Int = 6, columnWidth: CGFloat = 90, spacing: CGFloat = 8) {
        self.columns = columns
        self.columnWidth = columnWidth
        self.spacing = spacing
    }

    struct ItemPlacement {
        var origin: CGPoint
        var size: CGSize
        var span: Int
        var startCol: Int
    }

    // Compute placements once to use for both size & placement
    private func computePlacements(subviews: Subviews, proposal: ProposedViewSize) -> (
        CGSize, [ItemPlacement]
    ) {
        var colHeights = Array(repeating: CGFloat(0), count: columns)
        let totalWidth = CGFloat(columns) * columnWidth + CGFloat(max(0, columns - 1)) * spacing
        var placements: [ItemPlacement] = []
        placements.reserveCapacity(subviews.count)

        for subview in subviews {
            // Default span from layout value
            var span = max(1, min(subview[GridSpanKey.self], columns))

            // Measure size first to check height
            let widthForSpan = CGFloat(span) * columnWidth + CGFloat(max(0, span - 1)) * spacing
            let size = subview.sizeThatFits(.init(width: widthForSpan, height: nil))

            // 👈 Override span rules if height < 90
            if size.height < 40 {
                if subview[GridSpanKey.self] > 1 {  // zoomed
                    span = min(6, columns)
                } else {
                    span = min(3, columns)
                }
            }

            let widthForFinalSpan =
                CGFloat(span) * columnWidth + CGFloat(max(0, span - 1)) * spacing
            let finalSize = subview.sizeThatFits(.init(width: widthForFinalSpan, height: nil))
            let itemSize = CGSize(width: widthForFinalSpan, height: finalSize.height)

            // Find best start col
            var bestStart = 0
            var bestY = CGFloat.infinity
            for start in 0...(columns - span) {
                let y = colHeights[start..<(start + span)].max() ?? 0
                if y < bestY {
                    bestY = y
                    bestStart = start
                }
            }

            let x = CGFloat(bestStart) * (columnWidth + spacing)
            let y = bestY
            placements.append(
                .init(origin: CGPoint(x: x, y: y), size: itemSize, span: span, startCol: bestStart)
            )

            let newHeight = y + itemSize.height + spacing
            for c in bestStart..<(bestStart + span) {
                colHeights[c] = newHeight
            }
        }

        let totalHeight = (colHeights.max() ?? 0) - spacing
        return (CGSize(width: totalWidth, height: max(0, totalHeight)), placements)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void?) -> CGSize
    {
        let (size, _) = computePlacements(subviews: subviews, proposal: proposal)
        return size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void?
    ) {
        let (_, placements) = computePlacements(subviews: subviews, proposal: proposal)

        for (i, placement) in placements.enumerated() {
            let frameOrigin = CGPoint(
                x: bounds.minX + placement.origin.x,
                y: bounds.minY + placement.origin.y
            )
            subviews[i].place(
                at: frameOrigin,
                proposal: .init(width: placement.size.width, height: placement.size.height)
            )
        }
    }
}

struct ContextGridView: View {
    @Binding var modelContext: [DroppedContent]
    @Binding var modelContextZoomed: [Bool]

    var onTap: (_ index: Int) -> Void
    var onDelete: (_ index: Int) -> Void
    var updatePassthrough: (_ inside: Bool) -> Void

    var body: some View {
        MasonryGrid(columns: 6, columnWidth: 90, spacing: 8) {
            ForEach(modelContext.indices, id: \.self) { index in
                let context = modelContext[index]
                let zoomed = index < modelContextZoomed.count && modelContextZoomed[index]

                cellView(for: context, index: index)
                    .onHover { inside in
                        updatePassthrough(inside)
                    }
                    .layoutValue(key: GridSpanKey.self, value: zoomed ? 2 : 1)
                    .shadow(radius: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Small helper to simplify the type the compiler must infer
    @ViewBuilder
    private func cellView(for context: DroppedContent, index: Int) -> some View {
        switch context {
        case .image(_, let image, _):
            ImageContextView(
                image: image,
                compact: false,
                isZoomed: safeZoomed(at: index),
                onTap: { onTap(index) },
                onDelete: { onDelete(index) }
            )

        case .pdf(_, _, let images, _):
            // Defensive: ensure images array isn’t empty
            if let first = images.first {
                PDFContextView(
                    image: first,
                    compact: false,
                    isZoomed: safeZoomed(at: index),
                    onTap: { onTap(index) },
                    onDelete: { onDelete(index) }
                )
            } else {
                // Fallback placeholder avoids optional unwrap noise in the main builder
                Color.clear.frame(height: 1)
            }

        case .text(let name, _):
            TextContextView(
                name: name,
                compact: false,
                isZoomed: safeZoomed(at: index),
                onTap: { onTap(index) },
                onDelete: { onDelete(index) }
            )
        }
    }

    private func safeZoomed(at index: Int) -> Bool {
        (index < modelContextZoomed.count) ? modelContextZoomed[index] : false
    }
}
