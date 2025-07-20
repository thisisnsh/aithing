//
//  TabAnimationView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/19/25.
//

import SwiftUI

struct TabItem: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
}

struct TabAnimationView: View {
    @State private var tabs: [TabItem] = [
        TabItem(imageName: "star", title: "Tab 1")
    ]
    @State private var focusedIndex: Int = 0
    @State private var showToast = false

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                ForEach(Array(tabs.enumerated()), id: \.1.id) { index, tab in
                    TabViewItem(
                        imageName: tab.imageName,
                        title: tab.title,
                        isFocused: index == focusedIndex
                    )
                    .animation(.easeInOut, value: focusedIndex)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .focusable()
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
                return event
            }
        }
        .overlay(
            Group {
                if showToast {
                    Text("Maximum of 10 tabs reached")
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }, alignment: .center
        )
        .animation(.easeInOut, value: showToast)
    }

    private func addTab() {
        if tabs.count >= 10 {
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
            }
            return
        }
        
        withAnimation {
            let newIndex = tabs.count + 1
            tabs.append(TabItem(imageName: "star", title: "Tab \(newIndex)"))
            focusedIndex = tabs.count - 1
        }
    }
    
    private func closeTab() {
        guard tabs.count > 1 else { return } // Don't remove the last tab

        withAnimation {
            tabs.remove(at: focusedIndex)

            // Adjust focus index safely
            if focusedIndex >= tabs.count {
                focusedIndex = tabs.count - 1
            }
        }
    }

    private func moveFocus(_ direction: Int) {
        withAnimation {
            let newIndex = focusedIndex + direction
            if (0..<tabs.count).contains(newIndex) {
                focusedIndex = newIndex
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let isControlPressed = event.modifierFlags.contains(.control)

            guard isControlPressed else { return }

            switch event.keyCode {
            case 17: // T key
                print("t")
                addTab()
            case 13: // W key
                closeTab()
            case 43: // Left angular arrow
                print("left")
                moveFocus(-1)
            case 47: // Right angular bracket
                print("right")
                moveFocus(1)
            default:
                print(event.keyCode)
                break
            }
    }
}

struct TabViewItem: View {
    let imageName: String
    let title: String
    let isFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: imageName)
                .padding(.leading, 10)

            if isFocused {
                Text(title)
                    .padding(.trailing, 10)
                    .transition(.opacity)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 5)
        .background(Color.blue.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(10)
        .frame(width: isFocused ? 150 : 50)
        .animation(.easeInOut, value: isFocused)
    }
}

#Preview {
    TabAnimationView()
}
