import CalendropCore
import SwiftUI

struct CutinView: View {
  let meetings: [Meeting]
  let theme: CutinTheme
  let onJoin: (Meeting) -> Void
  let onDismiss: () -> Void

  var body: some View {
    let palette = CutinPalette(theme)
    ZStack(alignment: .topTrailing) {
      LinearGradient(
        colors: [Color(theme.backgroundTop), Color(theme.backgroundBottom)],
        startPoint: .top, endPoint: .bottom
      )
      .opacity(theme.backgroundOpacity)
      .ignoresSafeArea()

      Group {
        if meetings.count == 1, let only = meetings.first {
          SingleMeetingView(meeting: only, onJoin: onJoin)
        } else {
          MeetingChoiceView(meetings: meetings, onJoin: onJoin)
        }
      }
      .padding(64)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HoldToDismissButton(action: onDismiss)
        .padding(28)
    }
    .foregroundStyle(palette.text)
    .fontDesign(theme.fontDesign.swiftUI)
    .environment(\.colorScheme, theme.backgroundTop.isLight ? .light : .dark)
    .environment(\.cutinPalette, palette)
  }
}

/// The theme's colours as SwiftUI needs them, shared with every part of the cut-in.
struct CutinPalette {
  var text: Color
  var accent: Color
  /// Readable on `accent`.
  var accentLabel: Color
  /// For a meeting that has already started; stays readable on light and dark backgrounds.
  var late: Color

  init(_ theme: CutinTheme) {
    text = Color(theme.text)
    accent = Color(theme.accent)
    accentLabel = theme.accent.isLight ? .black : .white
    late =
      theme.backgroundTop.isLight ? Color(red: 0.78, green: 0.18, blue: 0.12) : Color(red: 1, green: 0.45, blue: 0.4)
  }
}

private struct CutinPaletteKey: EnvironmentKey {
  static let defaultValue = CutinPalette(CutinPreset.allCases[0].theme)
}

extension EnvironmentValues {
  var cutinPalette: CutinPalette {
    get { self[CutinPaletteKey.self] }
    set { self[CutinPaletteKey.self] = newValue }
  }
}

extension Color {
  init(_ rgb: ThemeColor) {
    self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
  }
}

extension ThemeColor {
  init(_ color: Color) {
    let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
    self.init(red: Double(ns.redComponent), green: Double(ns.greenComponent), blue: Double(ns.blueComponent))
  }
}

extension CutinFontDesign {
  var swiftUI: Font.Design {
    switch self {
    case .standard: .default
    case .rounded: .rounded
    case .serif: .serif
    case .monospaced: .monospaced
    }
  }
}

private struct SingleMeetingView: View {
  @Environment(\.cutinPalette) private var palette
  let meeting: Meeting
  let onJoin: (Meeting) -> Void

  var body: some View {
    VStack(spacing: 48) {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = meeting.start.timeIntervalSince(context.date)
        VStack(spacing: 4) {
          Text(remaining > 0 ? "Meeting starts in" : "Meeting started")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(palette.text.opacity(0.7))
          Text(remaining > 0 ? Countdown.clock(remaining) : "\(Countdown.clock(-remaining)) ago")
            .font(.system(size: 120, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(remaining > 0 ? palette.text : palette.late)
        }
      }
      VStack(spacing: 14) {
        Text(meeting.title)
          .font(.system(size: 48, weight: .semibold))
          .multilineTextAlignment(.center)
          .lineLimit(2)
        Text("\(CutinStyle.timeRange(meeting))  ·  \(meeting.account)")
          .font(.system(size: 18))
          .foregroundStyle(palette.text.opacity(0.6))
        JoinButton(meeting: meeting, large: true, onJoin: onJoin)
          .keyboardShortcut(.defaultAction)
          .padding(.top, 8)
      }
      .frame(maxWidth: 900)
    }
  }
}

/// Several meetings at once: none is singled out, since which one to attend is
/// exactly the choice the user has to make.
private struct MeetingChoiceView: View {
  @Environment(\.cutinPalette) private var palette
  let meetings: [Meeting]
  let onJoin: (Meeting) -> Void

  private var hasConflict: Bool {
    meetings.indices.contains { i in meetings[(i + 1)...].contains { $0.overlaps(meetings[i]) } }
  }

  var body: some View {
    VStack(spacing: 36) {
      VStack(spacing: 10) {
        Text(hasConflict ? "Meetings overlap" : "Meetings close together")
          .font(.system(size: 52, weight: .bold))
        Text(
          hasConflict
            ? "Choose the one to join. The ones overlapping it are skipped."
            : "Join the first one. The next will cut in again before it starts."
        )
        .font(.system(size: 20))
        .foregroundStyle(palette.text.opacity(0.65))
      }
      // Many meetings on a small screen must not push a join button off-screen.
      ViewThatFits(in: .vertical) {
        rows
        ScrollView { rows }
      }
      .frame(maxWidth: 1000)
    }
  }

  private var rows: some View {
    VStack(spacing: 14) {
      ForEach(meetings) { meeting in
        MeetingRow(
          meeting: meeting,
          overlapping: meetings.contains { $0.id != meeting.id && $0.overlaps(meeting) },
          onJoin: onJoin)
      }
    }
  }
}

private struct MeetingRow: View {
  @Environment(\.cutinPalette) private var palette
  let meeting: Meeting
  let overlapping: Bool
  let onJoin: (Meeting) -> Void

  var body: some View {
    HStack(spacing: 28) {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = meeting.start.timeIntervalSince(context.date)
        VStack(alignment: .leading, spacing: 4) {
          Text(remaining > 0 ? "in \(Countdown.clock(remaining))" : "\(Countdown.clock(-remaining)) ago")
            .font(.system(size: 30, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(remaining > 0 ? palette.text : palette.late)
          Text(CutinStyle.timeRange(meeting))
            .font(.system(size: 15))
            .foregroundStyle(palette.text.opacity(0.6))
        }
        .frame(width: 170, alignment: .leading)
      }
      VStack(alignment: .leading, spacing: 6) {
        Text(meeting.title)
          .font(.system(size: 26, weight: .semibold))
          .lineLimit(2)
        HStack(spacing: 8) {
          Text(meeting.account)
            .foregroundStyle(palette.text.opacity(0.6))
          if overlapping {
            Text("Overlaps")
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(Capsule().fill(palette.late.opacity(0.25)))
              .foregroundStyle(palette.late)
          }
        }
        .font(.system(size: 15))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      JoinButton(meeting: meeting, large: false, onJoin: onJoin)
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
    .background(RoundedRectangle(cornerRadius: 18).fill(palette.text.opacity(0.07)))
    .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.text.opacity(0.12)))
  }
}

private struct JoinButton: View {
  @Environment(\.cutinPalette) private var palette
  let meeting: Meeting
  let large: Bool
  let onJoin: (Meeting) -> Void

  var body: some View {
    Button {
      onJoin(meeting)
    } label: {
      Label(
        meeting.joinURL == nil ? "Open Event" : "Join",
        systemImage: meeting.joinURL == nil ? "calendar" : "video.fill"
      )
      .font(.system(size: large ? 26 : 20, weight: .bold))
      .padding(.horizontal, large ? 56 : 30)
      .padding(.vertical, large ? 20 : 14)
      .background(Capsule().fill(palette.accent))
      .foregroundStyle(palette.accentLabel)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .fixedSize()
  }
}

private enum CutinStyle {
  private static let timeFormat: Date.FormatStyle = .dateTime.hour().minute()

  static func timeRange(_ meeting: Meeting) -> String {
    "\(meeting.start.formatted(timeFormat)) – \(meeting.end.formatted(timeFormat))"
  }
}

/// Small and slow on purpose: the cut-in should end by joining, so dismissing takes
/// a deliberate press-and-hold on a corner target.
private struct HoldToDismissButton: View {
  @Environment(\.cutinPalette) private var palette
  let action: () -> Void
  @State private var progress: CGFloat = 0
  private let holdDuration = 1.5

  var body: some View {
    VStack(spacing: 6) {
      ZStack {
        Circle().stroke(palette.text.opacity(0.25), lineWidth: 2)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(palette.text, style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(palette.text.opacity(0.6))
      }
      .frame(width: 24, height: 24)
      Text("Hold to dismiss")
        .font(.system(size: 10))
        .foregroundStyle(palette.text.opacity(0.4))
    }
    .contentShape(Rectangle())
    .onLongPressGesture(
      minimumDuration: holdDuration,
      maximumDistance: 12,
      perform: action,
      onPressingChanged: { pressing in
        withAnimation(pressing ? .linear(duration: holdDuration) : .easeOut(duration: 0.2)) {
          progress = pressing ? 1 : 0
        }
      }
    )
    .help("Press and hold to dismiss without joining")
  }
}
