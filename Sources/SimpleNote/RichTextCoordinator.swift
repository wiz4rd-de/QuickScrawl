import AppKit
import SwiftUI

final class RichTextCoordinator: NSObject, ObservableObject, NSTextViewDelegate {
    weak var textView: NSTextView?

    private var saveWorkItem: DispatchWorkItem?

    static let defaultFontSize: CGFloat = 18
    @Published var fontSize: CGFloat = RichTextCoordinator.defaultFontSize

    // Published state for toolbar feedback
    @Published var isBold = false
    @Published var isUnderline = false
    @Published var isStrikethrough = false
    @Published var activeColor: NSColor = .black
    @Published var alwaysOnTop = false

    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        textView?.window?.level = alwaysOnTop ? .floating : .normal
    }

    private var defaultFont: NSFont {
        NSFont(name: "Chalkboard SE", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }

    // MARK: - Font size zoom

    func increaseFontSize() {
        fontSize = min(fontSize + 2, 72)
        applyFontSizeToAll()
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 2, 10)
        applyFontSizeToAll()
    }

    func resetFontSize() {
        fontSize = RichTextCoordinator.defaultFontSize
        applyFontSizeToAll()
    }

    private func applyFontSizeToAll() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        if fullRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: fullRange, options: []) { value, attrRange, _ in
                let font = (value as? NSFont) ?? self.defaultFont
                let resized = NSFontManager.shared.convert(font, toSize: self.fontSize)
                textStorage.addAttribute(.font, value: resized, range: attrRange)
            }
            textStorage.endEditing()
        }
        // Update typing attributes too
        var attrs = textView.typingAttributes
        let typingFont = (attrs[.font] as? NSFont) ?? defaultFont
        attrs[.font] = NSFontManager.shared.convert(typingFont, toSize: fontSize)
        textView.typingAttributes = attrs
        textView.font = defaultFont
        textView.needsDisplay = true
        textView.didChangeText()
    }

    // MARK: - Formatting

    func toggleBold() {
        toggleFontTrait(.boldFontMask)
        updateFormattingState()
    }

    func toggleUnderline() {
        toggleStyleAttribute(.underlineStyle, onValue: NSUnderlineStyle.single.rawValue)
        updateFormattingState()
    }

    func toggleStrikethrough() {
        toggleStyleAttribute(.strikethroughStyle, onValue: NSUnderlineStyle.single.rawValue)
        updateFormattingState()
    }

    func setColor(_ color: NSColor) {
        guard let textView else { return }
        textView.insertionPointColor = color
        let range = textView.selectedRange()
        if range.length > 0 {
            textView.textStorage?.addAttribute(.foregroundColor, value: color, range: range)
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            attrs[.foregroundColor] = color
            textView.typingAttributes = attrs
        }
        activeColor = color
    }

    // MARK: - Formatting state

    func updateFormattingState() {
        guard let textView else { return }
        let attrs: [NSAttributedString.Key: Any]
        let range = textView.selectedRange()
        if range.length > 0, let textStorage = textView.textStorage {
            attrs = textStorage.attributes(at: range.location, effectiveRange: nil)
        } else {
            attrs = textView.typingAttributes
        }

        let font = (attrs[.font] as? NSFont) ?? defaultFont
        let traits = NSFontManager.shared.traits(of: font)
        isBold = traits.contains(.boldFontMask)
        isUnderline = ((attrs[.underlineStyle] as? Int) ?? 0) != 0
        isStrikethrough = ((attrs[.strikethroughStyle] as? Int) ?? 0) != 0
        activeColor = (attrs[.foregroundColor] as? NSColor) ?? .black
    }

    // MARK: - Private helpers

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let fm = NSFontManager.shared

        if range.length == 0 {
            let currentFont = (textView.typingAttributes[.font] as? NSFont) ?? defaultFont
            let isActive = fm.traits(of: currentFont).contains(trait)
            let newFont = isActive ? fm.convert(currentFont, toNotHaveTrait: trait) : fm.convert(currentFont, toHaveTrait: trait)
            var attrs = textView.typingAttributes
            attrs[.font] = newFont
            textView.typingAttributes = attrs
            return
        }

        let startFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? defaultFont
        let isActive = fm.traits(of: startFont).contains(trait)

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            let font = (value as? NSFont) ?? self.defaultFont
            let newFont = isActive ? fm.convert(font, toNotHaveTrait: trait) : fm.convert(font, toHaveTrait: trait)
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        textView.didChangeText()
    }

    private func toggleStyleAttribute(_ key: NSAttributedString.Key, onValue: Int) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()

        if range.length == 0 {
            let current = (textView.typingAttributes[key] as? Int) ?? 0
            var attrs = textView.typingAttributes
            if current != 0 {
                attrs.removeValue(forKey: key)
            } else {
                attrs[key] = onValue
            }
            textView.typingAttributes = attrs
            return
        }

        let current = textStorage.attribute(key, at: range.location, effectiveRange: nil) as? Int ?? 0
        let isActive = current != 0

        textStorage.beginEditing()
        if isActive {
            textStorage.removeAttribute(key, range: range)
        } else {
            textStorage.addAttribute(key, value: onValue, range: range)
        }
        textStorage.endEditing()
        textView.didChangeText()
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        scheduleSave()
        updateFormattingState()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateFormattingState()
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let tv = self?.textView, let storage = tv.textStorage else { return }
            PersistenceManager.shared.save(storage)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    /// Force an immediate save (used on quit / resign active).
    func saveNow() {
        saveWorkItem?.cancel()
        guard let storage = textView?.textStorage else { return }
        PersistenceManager.shared.save(storage)
    }
}
