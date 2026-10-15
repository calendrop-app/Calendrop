import Foundation

/// Google Calendar stores event descriptions as a small subset of HTML. The menu
/// and the cut-in show them as plain lines.
public enum PlainText {
  public static func fromHTML(_ html: String) -> String {
    var text = html
    text = replace(#"<a\b[^>]*href\s*=\s*"([^"]*)"[^>]*>(.*?)</a>"#, in: text) { groups in
      let (target, label) = (groups[0], strip(groups[1]))
      return label.isEmpty || label == target ? target : "\(label) (\(target))"
    }
    text = replace(#"<br\s*/?>|</?p\b[^>]*>|</div>|</li>"#, in: text) { _ in "\n" }
    text = strip(text)
    text = decodeEntities(text)
    let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
    var collapsed: [String] = []
    for line in lines where !(line.isEmpty && (collapsed.last?.isEmpty ?? true)) {
      collapsed.append(line)
    }
    return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func strip(_ text: String) -> String {
    replace(#"<[^>]+>"#, in: text) { _ in "" }
  }

  private static func decodeEntities(_ text: String) -> String {
    var result = replace(#"&#(x[0-9a-fA-F]+|[0-9]+);"#, in: text) { groups in
      let code = groups[0]
      let value = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
      return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? ""
    }
    for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'")] {
      result = result.replacingOccurrences(of: entity, with: character)
    }
    // Last, so "&amp;lt;" becomes "&lt;" rather than "<".
    return result.replacingOccurrences(of: "&amp;", with: "&")
  }

  private static func replace(_ pattern: String, in text: String, with transform: ([String]) -> String) -> String {
    let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    var result = ""
    var cursor = text.startIndex
    for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
      guard let range = Range(match.range, in: text) else { continue }
      let groups = (1..<match.numberOfRanges).map { i in
        Range(match.range(at: i), in: text).map { String(text[$0]) } ?? ""
      }
      result += text[cursor..<range.lowerBound] + transform(groups)
      cursor = range.upperBound
    }
    return result + text[cursor...]
  }
}
