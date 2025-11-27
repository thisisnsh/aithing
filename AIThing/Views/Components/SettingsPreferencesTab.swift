//
//  SettingsPreferencesTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct SettingsPreferencesTab: View {
    @EnvironmentObject var screenshotMonitor: ScreenshotMonitor

    @Binding var preferencesShowInScreenshot: Bool
    @Binding var preferencesCaptureFullScreen: Bool

    let setPreferencesShowInScreenshot: (Bool) -> Void
    let setPreferencesCaptureFullScreen: (Bool) -> Void
    let setPanelVisibility: () -> Void

    @State private var outputToken = getOutputToken()
    @State private var cacheMessage = getCacheMessages()
    @State private var useCapturedScreenshots = getUseCapturedScreenshots()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: title("Performance")) {
                VStack(alignment: .leading) {

                    HStack {
                        VStack(alignment: .leading) {
                            Text("5-Minute Prompt Cache")
                                .font(.system(size: 14, weight: .medium))
                            Text(
                                "Reduces processing time and costs for\nfollow-up tasks. [Learn More](https://aithing.dev/features/byok-models#prompt-cache)"
                            )
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: {
                                    cacheMessage
                                },
                                set: { value in
                                    cacheMessage = value
                                    setCacheMessages(value: value)
                                    AnalyticsManager.shared
                                        .customEvent(
                                            view: .SettingsPreferencesTab,
                                            primary: .cacheEnabled,
                                            secondary: "\(value)",
                                            sev: .info
                                        )
                                }
                            )
                        )
                        .toggleStyle(.switch)
                        .tint(.black)
                        .scaleEffect(0.7)
                    }
                    .padding(4)

                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Maximum Output Tokens")
                                .font(.system(size: 14, weight: .medium))
                            Text(
                                "Max number of [tokens](https://docs.anthropic.com/en/docs/about-claude/glossary#tokens) a model can generate\nin a single response."
                            )
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            outputToken -= 1000
                            if outputToken <= 1000 {
                                outputToken = 1000
                            }
                            setOutputToken(value: outputToken)
                            AnalyticsManager.shared
                                .customEvent(
                                    view: .SettingsPreferencesTab,
                                    primary: .outputToken,
                                    secondary: "\(outputToken)",
                                    sev: .info
                                )
                        }) {
                            Image(systemName: "minus")
                                .frame(width: 16, height: 16)
                                .padding(4)
                                .background(.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .padding(4)

                        Text("\(outputToken)")
                            .font(.system(size: 14, weight: .medium))
                            .padding(4)

                        Button(action: {
                            outputToken += 1000
                            if outputToken >= 64000 {
                                outputToken = 64000
                            }
                            setOutputToken(value: outputToken)
                            AnalyticsManager.shared
                                .customEvent(
                                    view: .SettingsPreferencesTab,
                                    primary: .outputToken,
                                    secondary: "\(outputToken)",
                                    sev: .info
                                )
                        }) {
                            Image(systemName: "plus")
                                .frame(width: 16, height: 16)
                                .padding(4)
                                .background(.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .padding(4)

                    }
                    .padding(4)

                }
                .padding(4)
            }

            GroupBox(label: title("Preferences")) {
                VStack(alignment: .leading) {
                    PreferenceToggleRow(
                        isOn: $preferencesShowInScreenshot,
                        iconOn: "",
                        iconOff: "",
                        title: "Show in Screenshot",
                        onChange: { newValue in
                            setPreferencesShowInScreenshot(newValue)
                            setPanelVisibility()
                            AnalyticsManager.shared
                                .customEvent(
                                    view: .SettingsPreferencesTab,
                                    primary: .showInScreenshot,
                                    secondary: "\(newValue)",
                                    sev: .info
                                )
                        }
                    )
                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Use Captured Screenshots")
                                .font(.system(size: 14, weight: .medium))
                            Text(
                                "Allows you to use screenshots captured\nwhile AI Thing is open for queries. [Learn More](https://aithing.dev/features/selective-context#3-use-mac’s-native-screenshot-shortcuts)"
                            )
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: {
                                    useCapturedScreenshots
                                },
                                set: { value in
                                    useCapturedScreenshots = value
                                    setUseCapturedScreenshots(value: value)
                                    if value {
                                        screenshotMonitor.initialize()
                                    } else {
                                        screenshotMonitor.deinitialize()
                                    }
                                    AnalyticsManager.shared
                                        .customEvent(
                                            view: .SettingsPreferencesTab,
                                            primary: .useCapturedScreenshots,
                                            secondary: "\(value)",
                                            sev: .info
                                        )
                                }
                            )
                        )
                        .toggleStyle(.switch)
                        .tint(.black)
                        .scaleEffect(0.7)
                    }
                    .padding(4)

                    Divider()

                    HStack {
                        Text("Theme")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("Dark Translucent")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(4)
                }
                .padding(4)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).padding(.bottom, 4)
    }
}

// Local reusable row
private struct PreferenceToggleRow: View {
    @Binding var isOn: Bool
    let iconOn: String
    let iconOff: String
    let title: String
    let onChange: (Bool) -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(.black)
                .scaleEffect(0.7)
        }
        .padding(4)
        .onChange(of: isOn) { newValue in
            // IMPORTANT: do not toggle again here; just persist.
            onChange(newValue)
        }
    }
}
