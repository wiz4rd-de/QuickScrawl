import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = RichTextCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            FormatToolbar(coordinator: coordinator)
            Divider()
            RichTextEditor(coordinator: coordinator)
        }
        .navigationTitle("SimpleNote")
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            coordinator.saveNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            coordinator.saveNow()
        }
        .background(
            // Keyboard shortcuts for font size zoom
            Group {
                Button("") { coordinator.increaseFontSize() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("") { coordinator.decreaseFontSize() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("") { coordinator.resetFontSize() }
                    .keyboardShortcut("0", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }
}
