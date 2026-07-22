import SwiftUI
import UIKit

// Live rich-text editor for note blocks. Renders bold/italic/heading/bullet
// as you type — no markers ever visible — and serializes to the markdown
// dialect in NoteMarkdown for storage/sync.
//
// Formatting is tracked with custom attributes (the source of truth), not by
// reading font traits back — SF Rounded has no italic variant, so a trait
// round-trip would silently drop italic. The font is derived from these
// attributes purely for presentation.

private extension NSAttributedString.Key {
    static let noteBold    = NSAttributedString.Key("fellowshipNoteBold")
    static let noteItalic  = NSAttributedString.Key("fellowshipNoteItalic")
    static let noteHeading = NSAttributedString.Key("fellowshipNoteHeading")
    static let noteBullet  = NSAttributedString.Key("fellowshipNoteBullet")
}

// MARK: - UIKit ↔ model bridge

enum NoteFormat {
    static let textColor  = UIColor(white: 1, alpha: 0.85)
    static let cursorTint = UIColor(red: 0xD0/255, green: 0x8A/255, blue: 0x62/255, alpha: 1)
    static let bulletPrefix = "•\u{00A0}"

    // Rounded design for upright text; the real italic face when slanted, so
    // italic is actually visible (SF Rounded can't slant).
    static func font(size: CGFloat, bold: Bool, italic: Bool, heading: Bool) -> UIFont {
        let s = heading ? size + 3 : size
        let wantBold = bold || heading
        var traits: UIFontDescriptor.SymbolicTraits = []
        if wantBold { traits.insert(.traitBold) }
        if italic {
            traits.insert(.traitItalic)
            var desc = UIFont.italicSystemFont(ofSize: s).fontDescriptor
            if let t = desc.withSymbolicTraits(traits) { desc = t }
            return UIFont(descriptor: desc, size: s)
        } else {
            var desc = UIFont.systemFont(ofSize: s, weight: .regular).fontDescriptor
            if let rounded = desc.withDesign(.rounded) { desc = rounded }
            if !traits.isEmpty, let t = desc.withSymbolicTraits(traits) { desc = t }
            return UIFont(descriptor: desc, size: s)
        }
    }

    static func baseAttrs(size: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: font(size: size, bold: false, italic: false, heading: false),
         .foregroundColor: textColor]
    }

    // Build the attributes for one span, tagging its formatting.
    private static func spanAttrs(_ span: NoteSpan, size: CGFloat, heading: Bool) -> [NSAttributedString.Key: Any] {
        var a: [NSAttributedString.Key: Any] = [
            .font: font(size: size, bold: span.bold, italic: span.italic, heading: heading),
            .foregroundColor: textColor]
        if heading { a[.noteHeading] = true }
        if span.bold { a[.noteBold] = true }
        if span.italic { a[.noteItalic] = true }
        return a
    }

    // Model → attributed string for display/editing.
    static func attributed(from lines: [NoteLine], size: CGFloat) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let newline = NSAttributedString(string: "\n", attributes: baseAttrs(size: size))

        for (i, line) in lines.enumerated() {
            let heading = line.kind == .heading
            if line.kind == .bullet {
                var a = baseAttrs(size: size)
                a[.noteBullet] = true
                out.append(NSAttributedString(string: bulletPrefix, attributes: a))
            }
            for span in line.spans where !span.text.isEmpty {
                out.append(NSAttributedString(string: span.text,
                                              attributes: spanAttrs(span, size: size, heading: heading)))
            }
            if i < lines.count - 1 { out.append(newline) }
        }
        return out
    }

    // Attributed string → model for serialization.
    static func lines(from attr: NSAttributedString) -> [NoteLine] {
        let ns = attr.string as NSString
        var result: [NoteLine] = []
        var start = 0

        func processParagraph(_ range: NSRange) {
            var kind: NoteLineKind = .normal
            var content = range
            if range.length > 0 {
                let first = attr.attributes(at: range.location, effectiveRange: nil)
                if first[.noteHeading] != nil {
                    kind = .heading
                } else if first[.noteBullet] != nil {
                    kind = .bullet
                    var skip = 0
                    while skip < range.length,
                          attr.attributes(at: range.location + skip, effectiveRange: nil)[.noteBullet] != nil {
                        skip += 1
                    }
                    content = NSRange(location: range.location + skip, length: range.length - skip)
                }
            }
            let spans = spansIn(attr, range: content, heading: kind == .heading)
            result.append(NoteLine(kind: kind,
                                   spans: spans.isEmpty ? [NoteSpan(text: "", bold: false, italic: false)] : spans))
        }

        var i = 0
        let len = ns.length
        while i < len {
            if ns.character(at: i) == 10 {
                processParagraph(NSRange(location: start, length: i - start))
                start = i + 1
            }
            i += 1
        }
        processParagraph(NSRange(location: start, length: len - start))
        return result
    }

    private static func spansIn(_ attr: NSAttributedString, range: NSRange, heading: Bool) -> [NoteSpan] {
        guard range.length > 0 else { return [] }
        let ns = attr.string as NSString
        var spans: [NoteSpan] = []
        attr.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            let bold = heading ? false : (attrs[.noteBold] as? Bool ?? false)
            let italic = attrs[.noteItalic] as? Bool ?? false
            let text = ns.substring(with: r)
            if var last = spans.last, last.bold == bold, last.italic == italic {
                last.text += text
                spans[spans.count - 1] = last
            } else {
                spans.append(NoteSpan(text: text, bold: bold, italic: italic))
            }
        }
        return spans
    }
}

// MARK: - UITextView wrapper

private struct RichNoteEditor: UIViewRepresentable {
    @Binding var markdown: String
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = NoteFormat.textColor
        tv.tintColor = NoteFormat.cursorTint
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.keyboardDismissMode = .interactive
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tv.typingAttributes = NoteFormat.baseAttrs(size: fontSize)
        tv.delegate = context.coordinator
        tv.inputAccessoryView = context.coordinator.makeToolbar()
        tv.attributedText = NoteFormat.attributed(from: NoteMarkdown.parse(markdown), size: fontSize)
        context.coordinator.textView = tv
        context.coordinator.lastMarkdown = markdown
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Only rebuild on an external change, and never while the user is typing.
        guard markdown != context.coordinator.lastMarkdown, !tv.isFirstResponder else { return }
        tv.attributedText = NoteFormat.attributed(from: NoteMarkdown.parse(markdown), size: fontSize)
        context.coordinator.lastMarkdown = markdown
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichNoteEditor
        weak var textView: UITextView?
        var lastMarkdown = ""
        private var keyboardFrame: CGRect = .zero
        private var keyboardObserver: NSObjectProtocol?

        init(_ parent: RichNoteEditor) {
            self.parent = parent
            super.init()
            keyboardObserver = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil, queue: .main
            ) { [weak self] note in
                if let f = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    self?.keyboardFrame = f
                }
            }
        }

        deinit {
            if let keyboardObserver { NotificationCenter.default.removeObserver(keyboardObserver) }
        }

        func textViewDidChange(_ tv: UITextView) {
            let md = NoteMarkdown.render(NoteFormat.lines(from: tv.attributedText))
            lastMarkdown = md
            parent.markdown = md
            // Keep the caret visible inside the editor while typing.
            tv.scrollRangeToVisible(tv.selectedRange)
        }

        // MARK: Keyboard avoidance
        //
        // SwiftUI's automatic keyboard avoidance only tracks SwiftUI focus, not
        // UIKit first responders — so we scroll the enclosing List ourselves
        // when editing starts, after the keyboard has raised the safe area.

        func textViewDidBeginEditing(_ tv: UITextView) {
            scrollCardAboveKeyboard(tv, delay: 0.4)
        }

        private func scrollCardAboveKeyboard(_ tv: UITextView, delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak tv] in
                guard let self, let tv, tv.isFirstResponder else { return }
                // Outermost enclosing scroll view = the List's collection view.
                var view: UIView? = tv.superview
                var outer: UIScrollView?
                while let current = view {
                    if let sv = current as? UIScrollView { outer = sv }
                    view = current.superview
                }
                guard let scrollView = outer else { return }

                // How much of the scroll view the keyboard (incl. toolbar) covers.
                // scrollRectToVisible alone treats the area under the keyboard as
                // visible, so compute the overlap and scroll manually.
                let kbInView = scrollView.convert(self.keyboardFrame, from: nil)
                let kbOverlap = max(0, scrollView.bounds.maxY - kbInView.minY)
                let bottomInset = max(scrollView.adjustedContentInset.bottom, kbOverlap)
                let topInset = scrollView.adjustedContentInset.top

                let rect = tv.convert(tv.bounds, to: scrollView).insetBy(dx: 0, dy: -24)
                let visibleTop = scrollView.contentOffset.y + topInset
                let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height - bottomInset

                if rect.maxY > visibleBottom {
                    let target = rect.maxY - (scrollView.bounds.height - bottomInset)
                    scrollView.setContentOffset(CGPoint(x: 0, y: max(target, -topInset)), animated: true)
                } else if rect.minY < visibleTop {
                    scrollView.setContentOffset(CGPoint(x: 0, y: max(rect.minY - topInset, -topInset)), animated: true)
                }
            }
        }

        // MARK: Toolbar

        func makeToolbar() -> UIToolbar {
            let bar = UIToolbar()
            bar.barStyle = .black
            bar.tintColor = .white
            bar.sizeToFit()
            func btn(_ symbol: String, _ action: Selector) -> UIBarButtonItem {
                UIBarButtonItem(image: UIImage(systemName: symbol), style: .plain, target: self, action: action)
            }
            bar.items = [
                btn("bold", #selector(toggleBold)),
                btn("italic", #selector(toggleItalic)),
                btn("textformat.size", #selector(toggleHeading)),
                btn("list.bullet", #selector(toggleBullet)),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(dismissKeyboard)),
            ]
            return bar
        }

        @objc private func dismissKeyboard() { textView?.resignFirstResponder() }

        @objc private func toggleBold()   { toggleFlag(.noteBold) }
        @objc private func toggleItalic() { toggleFlag(.noteItalic) }

        // Toggle a bold/italic flag over the selection, rebuilding fonts from
        // the resulting per-run flag set so presentation matches storage.
        private func toggleFlag(_ key: NSAttributedString.Key) {
            guard let tv = textView else { return }
            let range = tv.selectedRange

            if range.length == 0 {
                var ta = tv.typingAttributes
                let on = (ta[key] as? Bool ?? false) == false
                if on { ta[key] = true } else { ta[key] = nil }
                let bold = (ta[.noteBold] as? Bool ?? false)
                let italic = (ta[.noteItalic] as? Bool ?? false)
                let heading = (ta[.noteHeading] as? Bool ?? false)
                ta[.font] = NoteFormat.font(size: parent.fontSize, bold: bold, italic: italic, heading: heading)
                tv.typingAttributes = ta
                return
            }

            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            var allOn = true
            m.enumerateAttribute(key, in: range) { v, _, stop in
                if (v as? Bool) != true { allOn = false; stop.pointee = true }
            }
            let on = !allOn
            m.enumerateAttributes(in: range, options: []) { attrs, r, _ in
                var bold = attrs[.noteBold] as? Bool ?? false
                var italic = attrs[.noteItalic] as? Bool ?? false
                let heading = attrs[.noteHeading] as? Bool ?? false
                if key == .noteBold { bold = on }
                if key == .noteItalic { italic = on }
                if on { m.addAttribute(key, value: true, range: r) } else { m.removeAttribute(key, range: r) }
                m.addAttribute(.font,
                               value: NoteFormat.font(size: parent.fontSize, bold: bold, italic: italic, heading: heading),
                               range: r)
            }
            tv.attributedText = m
            tv.selectedRange = range
            textViewDidChange(tv)
        }

        @objc private func toggleHeading() {
            guard let tv = textView else { return }
            let para = (tv.text as NSString).paragraphRange(for: tv.selectedRange)
            let sel = tv.selectedRange

            guard para.length > 0 else {
                var ta = tv.typingAttributes
                let on = (ta[.noteHeading] as? Bool ?? false) == false
                if on { ta[.noteHeading] = true } else { ta[.noteHeading] = nil }
                let italic = ta[.noteItalic] as? Bool ?? false
                ta[.font] = NoteFormat.font(size: parent.fontSize, bold: on, italic: italic, heading: on)
                tv.typingAttributes = ta
                return
            }

            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            let isHeading = m.attribute(.noteHeading, at: para.location, effectiveRange: nil) != nil
            let on = !isHeading
            m.enumerateAttributes(in: para, options: []) { attrs, r, _ in
                let italic = attrs[.noteItalic] as? Bool ?? false
                if on { m.addAttribute(.noteHeading, value: true, range: r) } else { m.removeAttribute(.noteHeading, range: r) }
                m.addAttribute(.font,
                               value: NoteFormat.font(size: parent.fontSize, bold: on, italic: italic, heading: on),
                               range: r)
            }
            tv.attributedText = m
            tv.selectedRange = sel
            textViewDidChange(tv)
        }

        @objc private func toggleBullet() {
            guard let tv = textView else { return }
            let ns = tv.text as NSString
            let para = ns.paragraphRange(for: tv.selectedRange)
            let sel = tv.selectedRange
            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            let hasBullet = para.length > 0 && m.attribute(.noteBullet, at: para.location, effectiveRange: nil) != nil

            if hasBullet {
                var skip = 0
                while skip < para.length,
                      m.attribute(.noteBullet, at: para.location + skip, effectiveRange: nil) != nil {
                    skip += 1
                }
                m.deleteCharacters(in: NSRange(location: para.location, length: skip))
                tv.attributedText = m
                let newLoc = max(para.location, sel.location - skip)
                tv.selectedRange = NSRange(location: min(newLoc, m.length), length: 0)
            } else {
                var a = NoteFormat.baseAttrs(size: parent.fontSize)
                a[.noteBullet] = true
                let prefix = NSAttributedString(string: NoteFormat.bulletPrefix, attributes: a)
                m.insert(prefix, at: para.location)
                tv.attributedText = m
                tv.selectedRange = NSRange(location: min(sel.location + prefix.length, m.length), length: 0)
            }
            textViewDidChange(tv)
        }
    }
}

// MARK: - Public editor (same API as before)

struct FormattableNoteEditor: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 14
    var height: CGFloat = 160

    var body: some View {
        ZStack(alignment: .topLeading) {
            RichNoteEditor(markdown: $text, fontSize: fontSize)
                .frame(height: height)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize, design: .rounded))
                    .foregroundColor(.white.opacity(0.22))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
    }
}
