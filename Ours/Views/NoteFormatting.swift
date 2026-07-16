import SwiftUI

// Markdown-lite for note text blocks.
//
// Stored as plain text so sync and older app versions are unaffected:
//   ## Rubrik      →  bold, slightly larger line
//   - punkt        →  bullet line
//   **fet**        →  bold inline
//   *kursiv*       →  italic inline
//
// While editing you see the raw markers in a normal TextEditor (identical
// keyboard behavior to before). When you tap away, the text renders formatted.

enum NoteMarkdown {

    static func render(_ raw: String, baseSize: CGFloat) -> AttributedString {
        var result = AttributedString()
        let lines = raw.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            var content = line
            var isHeading = false
            var isBullet  = false
            if line.hasPrefix("## ") {
                isHeading = true
                content = String(line.dropFirst(3))
            } else if line.hasPrefix("- ") {
                isBullet = true
                content = String(line.dropFirst(2))
            }

            var attr = (try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )) ?? AttributedString(content)

            if isHeading {
                attr.font = .system(size: baseSize + 3, weight: .bold, design: .rounded)
            } else if isBullet {
                attr = AttributedString("•  ") + attr
            }

            result += attr
            if i < lines.count - 1 { result += AttributedString("\n") }
        }
        return result
    }

    // True when the text contains any formatting markers — plain text renders
    // identically either way, but this lets callers skip work if they want.
    static func hasFormatting(_ raw: String) -> Bool {
        raw.contains("**") || raw.contains("## ") || raw.contains("\n- ") ||
        raw.hasPrefix("- ") || raw.contains("*")
    }
}

// A note editor with fixed height (keyboard-safe), formatted display when idle,
// and a formatting bar above the keyboard while editing (iOS 18+).
struct FormattableNoteEditor: View {
    @Binding var text: String
    let placeholder: String
    var fontSize: CGFloat = 14
    var height: CGFloat = 160

    @State private var isEditing = false

    var body: some View {
        if isEditing {
            editor
        } else {
            display
        }
    }

    // MARK: Display mode

    private var display: some View {
        ScrollView(showsIndicators: false) {
            Group {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: fontSize, design: .rounded))
                        .foregroundColor(.white.opacity(0.22))
                } else {
                    Text(NoteMarkdown.render(text, baseSize: fontSize))
                        .font(.system(size: fontSize, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 8)
            .padding(.leading, 5)
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture { isEditing = true }
    }

    // MARK: Edit mode

    @ViewBuilder
    private var editor: some View {
        if #available(iOS 18.0, *) {
            FormattingTextEditor(text: $text, fontSize: fontSize,
                                 height: height, isEditing: $isEditing)
        } else {
            PlainNoteEditor(text: $text, fontSize: fontSize,
                            height: height, isEditing: $isEditing)
        }
    }
}

// iOS 17 fallback: same editor, no formatting bar.
private struct PlainNoteEditor: View {
    @Binding var text: String
    let fontSize: CGFloat
    let height: CGFloat
    @Binding var isEditing: Bool
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: fontSize, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .scrollContentBackground(.hidden)
            .frame(height: height)
            .focused($focused)
            .onAppear { focused = true }
            .onChange(of: focused) { _, f in if !f { isEditing = false } }
    }
}

// iOS 18+: selection-aware editor with the formatting bar above the keyboard.
@available(iOS 18.0, *)
private struct FormattingTextEditor: View {
    @Binding var text: String
    let fontSize: CGFloat
    let height: CGFloat
    @Binding var isEditing: Bool
    @FocusState private var focused: Bool
    @State private var selection: TextSelection? = nil

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .font(.system(size: fontSize, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .scrollContentBackground(.hidden)
            .frame(height: height)
            .focused($focused)
            .onAppear { focused = true }
            .onChange(of: focused) { _, f in if !f { isEditing = false } }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button { toggleWrap("**") } label: {
                        Image(systemName: "bold")
                    }
                    Button { toggleWrap("*") } label: {
                        Image(systemName: "italic")
                    }
                    Button { toggleLinePrefix("## ") } label: {
                        Image(systemName: "textformat.size")
                    }
                    Button { toggleLinePrefix("- ") } label: {
                        Image(systemName: "list.bullet")
                    }
                    Spacer()
                    Button("Klar") { focused = false }
                        .fontWeight(.semibold)
                }
            }
    }

    // Range of the current selection, or the cursor as an empty range at the end.
    private func selectedRange() -> Range<String.Index> {
        if let sel = selection, case .selection(let range) = sel.indices {
            return range
        }
        return text.endIndex..<text.endIndex
    }

    // Wrap the selection in a marker (or unwrap if already wrapped).
    // With no selection, inserts a marker pair and puts the cursor inside it.
    private func toggleWrap(_ marker: String) {
        let range = selectedRange()
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let selected = String(text[range])
        let m = marker.count

        if selected.hasPrefix(marker), selected.hasSuffix(marker), selected.count >= 2 * m {
            let inner = String(selected.dropFirst(m).dropLast(m))
            text.replaceSubrange(range, with: inner)
            moveCursor(to: lower + inner.count)
        } else {
            text.replaceSubrange(range, with: marker + selected + marker)
            moveCursor(to: lower + m + selected.count)
        }
    }

    // Toggle a prefix ("## " or "- ") on the line the cursor is on.
    private func toggleLinePrefix(_ prefix: String) {
        let range = selectedRange()
        let lineStart = text[..<range.lowerBound].lastIndex(of: "\n")
            .map { text.index(after: $0) } ?? text.startIndex
        let startOffset = text.distance(from: text.startIndex, to: lineStart)
        let cursorOffset = text.distance(from: text.startIndex, to: range.lowerBound)

        if text[lineStart...].hasPrefix(prefix) {
            let end = text.index(lineStart, offsetBy: prefix.count)
            text.removeSubrange(lineStart..<end)
            moveCursor(to: max(startOffset, cursorOffset - prefix.count))
        } else {
            text.insert(contentsOf: prefix, at: lineStart)
            moveCursor(to: cursorOffset + prefix.count)
        }
    }

    private func moveCursor(to offset: Int) {
        let clamped = min(max(offset, 0), text.count)
        let idx = text.index(text.startIndex, offsetBy: clamped)
        selection = TextSelection(insertionPoint: idx)
    }
}
