import SwiftUI
import AppKit

struct FormatToolbar: View {
    @ObservedObject var coordinator: RichTextCoordinator

    var body: some View {
        HStack(spacing: 12) {
            formatButton(icon: "bold", isActive: coordinator.isBold) {
                coordinator.toggleBold()
            }
            formatButton(icon: "underline", isActive: coordinator.isUnderline) {
                coordinator.toggleUnderline()
            }
            formatButton(icon: "strikethrough", isActive: coordinator.isStrikethrough) {
                coordinator.toggleStrikethrough()
            }

            Divider().frame(height: 28)

            colorButton(.black, nsColor: .black)
            colorButton(.red, nsColor: .red)
            colorButton(.green, nsColor: .green)
            colorButton(.blue, nsColor: .blue)

            Spacer()

            Text("\(Int(coordinator.fontSize))px")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)

            formatButton(icon: "pin.fill", isActive: coordinator.alwaysOnTop) {
                coordinator.toggleAlwaysOnTop()
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func formatButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
    }

    private func colorButton(_ color: Color, nsColor: NSColor) -> some View {
        let isActive = colorsMatch(coordinator.activeColor, nsColor)
        return Button {
            coordinator.setColor(nsColor)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: isActive ? 3 : 0)
                        .frame(width: 32, height: 32)
                )
        }
    }

    private func colorsMatch(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let a = a.usingColorSpace(.sRGB), let b = b.usingColorSpace(.sRGB) else {
            return false
        }
        return abs(a.redComponent - b.redComponent) < 0.1
            && abs(a.greenComponent - b.greenComponent) < 0.1
            && abs(a.blueComponent - b.blueComponent) < 0.1
    }
}
