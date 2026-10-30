import CalendropCore
import SwiftUI

/// What the menu's calendar shows. The status bar controller fills in the colours as
/// meetings are read and follows the selection to list that day's meetings.
@MainActor
final class MenuCalendarState: ObservableObject {
  let calendar: MenuCalendar
  let today: Date
  @Published var selection: Date
  /// The account colours of each shown day's meetings; a day not read yet has none.
  @Published var colours: [Date: [Color]] = [:]

  init(calendar: MenuCalendar, today: Date) {
    self.calendar = calendar
    self.today = calendar.calendar.startOfDay(for: today)
    selection = self.today
  }

  var days: [Date] { calendar.days(showing: selection) }
}

/// A month or a week, with one header for paging both: the period's name, then
/// previous, Today and next, always in the same place.
struct MenuCalendarView: View {
  @ObservedObject var state: MenuCalendarState

  private var calendar: Calendar { state.calendar.calendar }

  var body: some View {
    VStack(spacing: 2) {
      header
      Grid(horizontalSpacing: 0, verticalSpacing: 1) {
        GridRow {
          ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
            Text(verbatim: symbol)
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity)
          }
        }
        ForEach(Array(stride(from: 0, to: state.days.count, by: 7)), id: \.self) { row in
          GridRow {
            ForEach(state.days[row..<row + 7], id: \.self) { day in
              DayCell(
                day: day,
                isToday: day == state.today,
                isSelected: calendar.isDate(day, inSameDayAs: state.selection),
                isOutside: state.calendar.isOutsidePeriod(day, showing: state.selection),
                colours: state.colours[day] ?? []
              ) { state.selection = day }
            }
          }
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 2)
    .padding(.bottom, 4)
  }

  private var header: some View {
    let isMonth = state.calendar.span == .month
    return HStack(spacing: 2) {
      Text(verbatim: title)
        .font(.system(size: 13, weight: .semibold))
        .monospacedDigit()
        // Starts where the menu's section headers and titles do.
        .padding(.leading, 15)
      Spacer(minLength: 8)
      // One fixed box for every control, so the chevrons and the word line up
      // whatever the language.
      PageButton(systemImage: "chevron.left", help: isMonth ? "Previous Month" : "Previous Week") {
        state.selection = state.calendar.moved(state.selection, by: -1)
      }
      Button("Today") { state.selection = state.today }
        .buttonStyle(HeaderButtonStyle())
        .disabled(state.selection == state.today)
      PageButton(systemImage: "chevron.right", help: isMonth ? "Next Month" : "Next Week") {
        state.selection = state.calendar.moved(state.selection, by: 1)
      }
    }
    .frame(height: 26)
  }

  private var title: String {
    switch state.calendar.span {
    case .month:
      return state.selection.formatted(.dateTime.year().month(.wide))
    case .week:
      let days = state.days
      return (days.first!..<days.last!).formatted(.interval.month(.abbreviated).day())
    }
  }

  /// The very short weekday names, from the calendar's first weekday.
  private var weekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return Array(symbols[first...] + symbols[..<first])
  }
}

private struct PageButton: View {
  let systemImage: String
  let help: LocalizedStringKey
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .buttonStyle(HeaderButtonStyle())
    .help(help)
    .accessibilityLabel(help)
  }
}

private struct HeaderButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @State private var hovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12))
      .padding(.horizontal, 6)
      .frame(minWidth: 22, minHeight: 22, maxHeight: 22)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 5)
          .fill(Color.primary.opacity(configuration.isPressed ? 0.2 : hovering && isEnabled ? 0.1 : 0))
      )
      .opacity(isEnabled ? 1 : 0.4)
      .onHover { hovering = $0 }
  }
}

private struct DayCell: View {
  let day: Date
  let isToday: Bool
  let isSelected: Bool
  let isOutside: Bool
  let colours: [Color]
  let select: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: select) {
      VStack(spacing: 1) {
        Text(day.formatted(.dateTime.day()))
          .font(.system(size: 12, weight: isToday ? .semibold : .regular))
          .monospacedDigit()
          .foregroundStyle(
            isToday ? AnyShapeStyle(.white) : isOutside ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary)
          )
          .frame(width: 20, height: 20)
          .background(Circle().fill(isToday ? Color.red : .clear))
        HStack(spacing: 2) {
          ForEach(Array(colours.prefix(3).enumerated()), id: \.offset) { _, colour in
            Circle().fill(colour).frame(width: 4, height: 4)
          }
        }
        .frame(height: 4)
        .opacity(isOutside ? 0.5 : 1)
      }
      .frame(maxWidth: .infinity, minHeight: 32)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.primary.opacity(isSelected || hovering ? 0.08 : 0))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, lineWidth: isSelected ? 1.5 : 0)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
