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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        Text(text).font(.system(size: 10, weight: .medium)).padding(.vertical, 4)
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
