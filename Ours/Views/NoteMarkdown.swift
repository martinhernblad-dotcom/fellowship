import Foundation

// Pure, UIKit-free model + markdown serialization for note text blocks.
// Kept separate from the editor so it can be unit-tested on its own.
//
// Storage dialect (what lands in Firestore's plain-text field):
//   **bold**            inline bold
//   _italic_            inline italic
//   "## " line prefix   heading line
//   "- "  line prefix   bullet line
//   \                   escapes a following * _ \ or a line-leading # / -
//
// A note is an ordered list of lines; each line has a kind and inline spans.

struct NoteSpan: Equatable {
    var text: String
    var bold: Bool
    var italic: Bool
}

enum NoteLineKind: Equatable { case normal, heading, bullet }

struct NoteLine: Equatable {
    var kind: NoteLineKind
    var spans: [NoteSpan]
}

enum NoteMarkdown {

    // MARK: Parse markdown → model

    static func parse(_ markdown: String) -> [NoteLine] {
        markdown.components(separatedBy: "\n").map(parseLine)
    }

    private static func parseLine(_ line: String) -> NoteLine {
        if line.hasPrefix("## ") {
            return NoteLine(kind: .heading, spans: parseInline(String(line.dropFirst(3))))
        }
        if line.hasPrefix("- ") {
            return NoteLine(kind: .bullet, spans: parseInline(String(line.dropFirst(2))))
        }
        return NoteLine(kind: .normal, spans: parseInline(line))
    }

    private static func parseInline(_ s: String) -> [NoteSpan] {
        var spans: [NoteSpan] = []
        var bold = false, italic = false
        var buf = ""
        var i = s.startIndex

        func flush() {
            if !buf.isEmpty {
                spans.append(NoteSpan(text: buf, bold: bold, italic: italic))
                buf = ""
            }
        }

        while i < s.endIndex {
            let c = s[i]
            if c == "\\" {
                let n = s.index(after: i)
                if n < s.endIndex {
                    buf.append(s[n]); i = s.index(after: n); continue
                } else {
                    buf.append("\\"); i = n; continue
                }
            }
            if c == "*", s[i...].hasPrefix("**") {
                flush(); bold.toggle(); i = s.index(i, offsetBy: 2); continue
            }
            if c == "_" {
                flush(); italic.toggle(); i = s.index(after: i); continue
            }
            buf.append(c); i = s.index(after: i)
        }
        flush()
        if spans.isEmpty { spans = [NoteSpan(text: "", bold: false, italic: false)] }
        return spans
    }

    // MARK: Render model → markdown

    static func render(_ lines: [NoteLine]) -> String {
        lines.map(renderLine).joined(separator: "\n")
    }

    private static func renderLine(_ line: NoteLine) -> String {
        let body = line.spans.map(renderSpan).joined()
        switch line.kind {
        case .heading: return "## " + body
        case .bullet:  return "- " + body
        case .normal:
            // Escape so a literal "## "/"- " at line start isn't read as structural.
            if body.hasPrefix("## ") || body.hasPrefix("- ") { return "\\" + body }
            return body
        }
    }

    private static func renderSpan(_ span: NoteSpan) -> String {
        var t = escapeInline(span.text)
        if span.italic { t = "_" + t + "_" }
        if span.bold   { t = "**" + t + "**" }
        return t
    }

    private static func escapeInline(_ s: String) -> String {
        var out = ""
        for c in s {
            if c == "\\" || c == "*" || c == "_" { out.append("\\") }
            out.append(c)
        }
        return out
    }
}
