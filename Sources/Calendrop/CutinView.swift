import CalendropCore
import SwiftUI

struct CutinView: View {
  let meetings: [Meeting]
  let onJoin: (Meeting) -> Void
  let onDismiss: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      LinearGradient(
        colors: [Color(red: 0.10, green: 0.09, blue: 0.22), Color(red: 0.02, green: 0.02, blue: 0.05)],
        startPoint: .top, endPoint: .bottom
      )
      .opacity(0.96)
      .ignoresSafeArea()

      VStack(spacing: 48) {
        if let first = meetings.first {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            CountdownHeader(start: first.start, now: context.date)
          }
        }
        // Overlapping meetings on a small screen must not push a join button off-screen.
        ViewThatFits(in: .vertical) {
          meetingList
          ScrollView { meetingList.frame(maxWidth: .infinity) }
        }
      }
      .padding(64)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HoldToDismissButton(action: onDismiss)
        .padding(28)
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
  }

  private var meetingList: some View {
    VStack(spacing: 28) {
      ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
        MeetingCard(meeting: meeting, isPrimary: index == 0, onJoin: onJoin)
      }
    }
  }
}

private struct CountdownHeader: View {
  let start: Date
  let now: Date

  var body: some View {
    let remaining = start.timeIntervalSince(now)
    VStack(spacing: 4) {
      Text(remaining > 0 ? "Meeting starts in" : "Meeting started")
        .font(.system(size: 28, weight: .medium))
        .foregroundStyle(.white.opacity(0.7))
      Text(remaining > 0 ? Countdown.clock(remaining) : "\(Countdown.clock(-remaining)) ago")
        .font(.system(size: 120, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(remaining > 0 ? .white : Color(red: 1, green: 0.45, blue: 0.4))
    }
  }
}

private struct MeetingCard: View {
  let meeting: Meeting
  let isPrimary: Bool
  let onJoin: (Meeting) -> Void

  private static let timeFormat: Date.FormatStyle = .dateTime.hour().minute()

  var body: some View {
    VStack(spacing: 14) {
      Text(meeting.title)
        .font(.system(size: isPrimary ? 48 : 32, weight: .semibold))
        .multilineTextAlignment(.center)
        .lineLimit(2)
      Text(
        "\(meeting.start.formatted(Self.timeFormat)) – \(meeting.end.formatted(Self.timeFormat))  ·  \(meeting.account)"
      )
      .font(.system(size: 18))
      .foregroundStyle(.white.opacity(0.6))
      joinButton
        .padding(.top, 8)
    }
    .frame(maxWidth: 900)
  }

  @ViewBuilder private var joinButton: some View {
    let button = Button {
      onJoin(meeting)
    } label: {
      Label(
        meeting.joinURL == nil ? "Open in Calendar" : "Join Meeting",
        systemImage: meeting.joinURL == nil ? "calendar" : "video.fill"
      )
      .font(.system(size: isPrimary ? 26 : 20, weight: .bold))
      .padding(.horizontal, isPrimary ? 56 : 36)
      .padding(.vertical, isPrimary ? 20 : 14)
      .background(Capsule().fill(Color.accentColor))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    if isPrimary {
      button.keyboardShortcut(.defaultAction)
    } else {
      button
    }
  }
}

/// Small and slow on purpose: the cut-in should end by joining, so dismissing takes
/// a deliberate press-and-hold on a corner target.
private struct HoldToDismissButton: View {
  let action: () -> Void
  @State private var progress: CGFloat = 0
  private let holdDuration = 1.5

  var body: some View {
    VStack(spacing: 6) {
      ZStack {
        Circle().stroke(.white.opacity(0.25), lineWidth: 2)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white.opacity(0.6))
      }
      .frame(width: 24, height: 24)
      Text("Hold to dismiss")
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.4))
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
