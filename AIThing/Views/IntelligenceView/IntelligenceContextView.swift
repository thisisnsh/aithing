//
//  IntelligenceContextView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import AppKit
import SwiftUI

extension IntelligenceView {
    func ContextView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom) {
                if modelContext.count > 0, !isThinking {
                    ForEach(modelContext.indices, id: \.self) { index in
                        let context = modelContext[index]
                        switch context {
                        case .image(let name, let image, _):
                            FilePill(
                                index: index,
                                name: name,
                                image: image,
                                systemName: "photo",
                                big: modelContext.count == 1,
                                onDelete: { index in
                                    modelContext.remove(at: index)
                                },
                                cornerRadius: cornerRadius
                            )

                        case .pdf(let name, _, let images, _):
                            FilePill(
                                index: index,
                                name: name,
                                image: images[0],
                                systemName: "text.page",
                                big: false,
                                onDelete: { index in
                                    modelContext.remove(at: index)
                                },
                                cornerRadius: cornerRadius
                            )

                        case .text(let name, _, let image):
                            FilePill(
                                index: index,
                                name: name,
                                image: image,
                                systemName: "text.alignleft",
                                big: false,
                                onDelete: { index in
                                    modelContext.remove(at: index)
                                },
                                cornerRadius: cornerRadius
                            )
                        }
                    }
                }

                // App Context Button
                if appContextWidth > 0 {
                    VStack {
                        if hoverAppContextEnabled, appContextEnabled {
                            let image = getAppContextBase64(
                                appName: selectedAppName,
                                windowName: selectedWindowName
                            )
                            if let image = image {
                                Image(nsImage: image.screenshot)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(cornerRadius - 8)
                                    .overlay {
                                        RoundedRectangle(
                                            cornerRadius: cornerRadius - 8,
                                            style: .continuous
                                        )
                                        .stroke(Color.white, lineWidth: 2)
                                    }
                                    .frame(width: appContextWidth)
                            } else {
                                Color.clear
                                    .onAppear {
                                        appContext.refresh()
                                        appContextEnabled = false
                                        selectedAppIcon = nil
                                        selectedAppName = ""
                                        selectedWindowName = ""
                                    }
                                    .frame(width: appContextWidth)
                            }
                        }

                        if appContextEnabled {
                            Button(action: {
                                appContextEnabled = false
                                selectedAppIcon = nil
                                selectedAppName = ""
                                selectedWindowName = ""
                            }) {
                                HStack(alignment: .bottom) {
                                    if let icon = selectedAppIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 12, height: 12)
                                    }

                                    Text(appContextText)
                                        .lineLimit(1)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.black)
                                }
                                .padding(8)
                                .padding(.horizontal, 4)
                                .frame(width: appContextWidth)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onHover { hoverAppContextEnabled = $0 }
                        } else {
                            if !appContext.appName.isEmpty {
                                Button(action: {
                                    selectedAppIcon = appContext.appIcon
                                    selectedAppName = appContext.appName
                                    selectedWindowName = appContext.windowName
                                    appContextEnabled = true

                                    // Check if screenshot can not be taken disable the button
                                    if getAppContextBase64(
                                        appName: selectedAppName,
                                        windowName: selectedWindowName
                                    ) == nil {
                                        appContext.refresh()
                                        appContextEnabled = false
                                        selectedAppIcon = nil
                                        selectedAppName = ""
                                        selectedWindowName = ""
                                    }
                                }) {
                                    HStack(alignment: .bottom) {
                                        if let icon = appContext.appIcon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 12, height: 12)
                                        }

                                        Text(appContextText)
                                            .lineLimit(1)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(
                                                hoverAppContextEnabled || appContextEnabled
                                                    ? .black : .white
                                            )
                                    }
                                    .padding(8)
                                    .padding(.horizontal, 4)
                                    .frame(width: appContextWidth)
                                    .background(
                                        hoverAppContextEnabled || appContextEnabled
                                            ? .white : .white.opacity(0.1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onHover {
                                    hoverAppContextEnabled = $0
                                    if !appContextEnabled {
                                        appContext.refresh()
                                        selectedAppIcon = nil
                                        selectedAppName = ""
                                        selectedWindowName = ""
                                    }
                                }
                            }
                        }
                    }
                }

                // Text Selection Button
                Button(action: {
                    // Accessibility trust (prompt once as needed)
                    if !AXIsProcessTrusted() {
                        let opts: NSDictionary = [
                            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
                        ]
                        _ = AXIsProcessTrustedWithOptions(opts)
                        return
                    } else {
                        selectionEnabled.toggle()
                    }

                    if !selectionEnabled {
                        selectedText = ""
                        viewModel.selectedText = ""
                    }                    
                }) {
                    HStack(alignment: .bottom) {
                        Image(
                            systemName: selectionEnabled
                                ? "text.redaction" : "text.alignleft"
                        )
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(
                            hoverSelectionEnabled || selectionEnabled ? .black : .white
                        )

                        Text("Text Selection")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                hoverSelectionEnabled || selectionEnabled ? .black : .white
                            )
                    }
                    .padding(8)
                    .padding(.horizontal, 4)
                    .background(
                        hoverSelectionEnabled || selectionEnabled ? .white : .white.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hoverSelectionEnabled = $0 }

                // MCP Tool Button
                if !allClientTools.isEmpty {
                    Button(action: {
                        showMcpTools.toggle()
                    }) {
                        HStack(alignment: .bottom) {
                            Image(
                                systemName: showMcpTools
                                    ? "hammer.fill" : "hammer"
                            )
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(
                                hoverMcpTools || showMcpTools ? .black : .white
                            )

                            Text("View Tools")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(
                                    hoverMcpTools || showMcpTools ? .black : .white
                                )
                        }
                        .padding(8)
                        .padding(.horizontal, 4)
                        .background(
                            hoverMcpTools || showMcpTools ? .white : .white.opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hoverMcpTools = $0 }
                }

            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, -8)
        .padding(8)
    }
}

