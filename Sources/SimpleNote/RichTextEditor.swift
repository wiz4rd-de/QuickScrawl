import SwiftUI
import AppKit

class RuledTextView: NSTextView {
    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        // Try to get rich text first for bold detection, fall back to plain string
        let pastedAttr: NSAttributedString? = {
            if let rtfData = pb.data(forType: .rtf) {
                return NSAttributedString(rtf: rtfData, documentAttributes: nil)
            }
            if let str = pb.string(forType: .string) {
                return NSAttributedString(string: str)
            }
            return nil
        }()
        guard let source = pastedAttr, let textStorage = self.textStorage else {
            super.paste(sender)
            return
        }

        let fontSize = (self.delegate as? RichTextCoordinator)?.fontSize
            ?? RichTextCoordinator.defaultFontSize
        let baseFont = NSFont(name: "Chalkboard SE", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        let fm = NSFontManager.shared

        // Build sanitized attributed string: keep only bold trait, reset everything else
        let sanitized = NSMutableAttributedString(string: source.string)
        let fullRange = NSRange(location: 0, length: sanitized.length)
        sanitized.addAttribute(.font, value: baseFont, range: fullRange)
        sanitized.addAttribute(.foregroundColor, value: NSColor.black, range: fullRange)

        // Preserve bold from source
        source.enumerateAttribute(.font, in: fullRange, options: []) { value, attrRange, _ in
            if let srcFont = value as? NSFont,
               fm.traits(of: srcFont).contains(.boldFontMask) {
                let boldFont = fm.convert(baseFont, toHaveTrait: .boldFontMask)
                sanitized.addAttribute(.font, value: boldFont, range: attrRange)
            }
        }

        let insertionPoint = selectedRange().location
        if shouldChangeText(in: selectedRange(), replacementString: sanitized.string) {
            textStorage.replaceCharacters(in: selectedRange(), with: sanitized)
            didChangeText()
            setSelectedRange(NSRange(location: insertionPoint + sanitized.length, length: 0))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let font = self.font ?? NSFont.systemFont(ofSize: 18)
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)

        let lineColor = NSColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 0.5)
        lineColor.setStroke()

        let origin = textContainerOrigin
        let width = bounds.width

        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let endY = max(visibleRect.maxY, bounds.height)

        var y = origin.y + lineHeight
        while y <= endY {
            let path = NSBezierPath()
            path.lineWidth = 0.75
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: width, y: y))
            path.stroke()
            y += lineHeight
        }
    }
}

struct RichTextEditor: NSViewRepresentable {
    @ObservedObject var coordinator: RichTextCoordinator

    func makeNSView(context: Context) -> NSScrollView {
        let notepadYellow = NSColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = notepadYellow
        scrollView.drawsBackground = true

        let textView = RuledTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = true
        let defaultSize = coordinator.fontSize
        textView.font = NSFont(name: "Chalkboard SE", size: defaultSize)
            ?? NSFont(name: "Comic Sans MS", size: defaultSize)
            ?? NSFont.systemFont(ofSize: defaultSize)
        textView.backgroundColor = notepadYellow
        textView.drawsBackground = true

        // Make text container track scroll view width for proper wrapping
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.insertionPointColor = .black
        textView.typingAttributes[.foregroundColor] = NSColor.black
        textView.delegate = coordinator
        coordinator.textView = textView

        // Load persisted content
        if let content = PersistenceManager.shared.load() {
            textView.textStorage?.setAttributedString(content)
        }

        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // State lives in NSTextView; nothing to sync from SwiftUI.
    }
}
