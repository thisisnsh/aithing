//
//  SettingsPreferencesTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct SettingsPreferencesTab: View {
    @Binding var preferencesShowInScreenshot: Bool
    @Binding var preferencesCaptureFullScreen: Bool

    let setPreferencesShowInScreenshot: (Bool) -> Void
    let setPreferencesCaptureFullScreen: (Bool) -> Void
    let setPanelVisibility: () -> Void

    @State private var outputToken = getOutputToken()
    @State private var cacheMessage = getCacheMessages()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: title("Performance")) {
                VStack(alignment: .leading) {

                    HStack {
                        VStack(alignment: .leading) {
                            Text("5-Minute Prompt Cache")
                                .font(.system(size: 14, weight: .medium))
                            Text(
                                "Reduces processing time and costs for\nfollow-up tasks. Learn More."
                            )
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { cacheMessage },
                                set: { value in
                                    print(value)
                                    cacheMessage = value
                                    setCacheMessages(value: value)
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
                            outputToken -= 1024
                            if outputToken <= 1024 {
                                outputToken = 1024
                            }
                            setOutputToken(value: outputToken)
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
                            outputToken += 1024
                            if outputToken >= 102400 {
                                outputToken = 102400
                            }
                            setOutputToken(value: outputToken)
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

            GroupBox(label: title("Look & Feel")) {
                VStack(alignment: .leading) {
                    PreferenceToggleRow(
                        isOn: $preferencesShowInScreenshot,
                        iconOn: "eye.fill",
                        iconOff: "eye.slash.fill",
                        title: "Show in Screenshot",
                        onChange: { newValue in
                            setPreferencesShowInScreenshot(newValue)
                            setPanelVisibility()

                            if newValue {
                                AnalyticsManager.shared.selectItem(
                                    itemID: "preference_show_in_screenshot_true",
                                    itemName: "preference_show_in_screenshot_true"
                                )
                            } else {
                                AnalyticsManager.shared.selectItem(
                                    itemID: "preference_show_in_screenshot_false",
                                    itemName: "preference_show_in_screenshot_false"
                                )
                            }
                        }
                    )
                    Divider()

                    PreferenceToggleRow(
                        isOn: $preferencesCaptureFullScreen,
                        iconOn: "camera.metering.matrix",
                        iconOff: "camera.metering.spot",
                        title: "Capture Entire Screen on @this",
                        onChange: { newValue in
                            setPreferencesCaptureFullScreen(newValue)

                            if newValue {
                                AnalyticsManager.shared.selectItem(
                                    itemID: "preference_capture_full_screen_true",
                                    itemName: "preference_capture_full_screen_true"
                                )
                            } else {
                                AnalyticsManager.shared.selectItem(
                                    itemID: "preference_capture_full_screen_false",
                                    itemName: "preference_capture_full_screen_false"
                                )
                            }
                        }
                    )
                    Divider()

                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("Theme")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("Dark Translucent")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .opacity(0.5)
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
            Image(systemName: isOn ? iconOn : iconOff)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
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
