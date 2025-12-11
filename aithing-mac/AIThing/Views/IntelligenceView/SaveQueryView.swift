//
//  SaveQueryView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import SwiftUI

extension IntelligenceView {
    func SaveQueryView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(savedQueries.enumerated()), id: \.offset) { index, savedQuery in
                HoverableTabButton(
                    title: savedQuery.title,
                    isActive: true,
                    action: { query = savedQuery.instruction },
                    deleteAction: {
                        savedQueries.remove(at: index)
                        setSavedQueries(value: savedQueries)
                    },
                    image: "apple.intelligence",
                    isDeletable: true,
                    isExpanded: true,
                    fixedSize: true,
                    cornerRadius: 16
                )
                .padding(.bottom, 4)
            }
            if savedQueries.count < 7 {
                HoverableTabButton(
                    title: "Save Query",
                    isActive: false,
                    action: {
                        if !query.isEmpty {
                            savedQueries
                                .append(
                                    SavedQuery(
                                        id: UUID().uuidString,
                                        title: query.count > 32 ? "\(query.prefix(32))..." : query,
                                        instruction: query
                                    )
                                )
                            setSavedQueries(value: savedQueries)
                        }
                    },
                    deleteAction: {},
                    image: "apple.writing.tools",
                    isDeletable: false,
                    isExpanded: true,
                    fixedSize: true,
                    cornerRadius: 16
                )
            }
        }
    }
}

