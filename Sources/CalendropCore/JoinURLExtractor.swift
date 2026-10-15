import Foundation

public enum JoinURLExtractor {
  /// Video-conference URL shapes recognised inside free text (location, description).
  private static let patterns: [NSRegularExpression] = [
    #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#,
    #"https://([a-z0-9-]+\.)?zoom\.us/(j|my|w|s)/[^\s"'<>]+"#,
    #"https://teams\.microsoft\.com/l/meetup-join/[^\s"'<>]+"#,
    #"https://teams\.live\.com/meet/[^\s"'<>]+"#,
    #"https://([a-z0-9-]+\.)?webex\.com/(meet|join|[a-z0-9-]+/j\.php)[^\s"'<>]*"#,
    #"https://app\.slack\.com/huddle/[^\s"'<>]+"#,
    #"https://whereby\.com/[^\s"'<>]+"#,
  ].map { try! NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

  /// Picks the join URL in order of reliability: Google Meet's own field, the
  /// conference data's video entry point, then the first known link in the texts.
  public static func extract(hangoutLink: String?, videoEntryPoints: [String], texts: [String]) -> URL? {
    if let link = hangoutLink, let url = URL(string: link) { return url }
    if let first = videoEntryPoints.lazy.compactMap(URL.init(string:)).first { return first }
    for text in texts {
      let decoded = text.replacingOccurrences(of: "&amp;", with: "&")
      let range = NSRange(decoded.startIndex..., in: decoded)
      let matches = patterns.compactMap { $0.firstMatch(in: decoded, range: range) }
      if let earliest = matches.min(by: { $0.range.location < $1.range.location }),
        let r = Range(earliest.range, in: decoded),
        let url = URL(string: String(decoded[r]))
      {
        return url
      }
    }
    return nil
  }
}
