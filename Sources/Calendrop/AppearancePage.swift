import CalendropCore
import SwiftUI

/// Picks the cut-in's look: a preset or a custom theme, previewed live and tried
/// full screen.
struct AppearancePage: View {
  @ObservedObject var model: AppModel
  let onTry: (SampleCalendar.Scenario) -> Void
  @State private var previewScenario: SampleCalendar.Scenario = .single

  private var appearance: CutinAppearance { model.config.appearance }

  var body: some View {
    SettingsGroup("Style", note: "Applies to every cut-in, on every Mac that shares these settings.") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
        ForEach(CutinPreset.allCases, id: \.self) { preset in
          StyleCard(title: preset.title, theme: preset.theme, selected: appearance.style == .preset(preset)) {
            model.updateConfig { $0.appearance.style = .preset(preset) }
          }
        }
        StyleCard(title: "Custom", theme: appearance.custom, selected: appearance.style == .custom) {
          model.updateConfig { $0.appearance.style = .custom }
        }
      }
      .padding(.vertical, 14)
    }

    SettingsGroup("Preview") {
      VStack(alignment: .leading, spacing: 12) {
        Picker("", selection: $previewScenario) {
          ForEach(SampleCalendar.Scenario.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        CutinMiniature(
          meetings: previewScenario.meetings(now: Date(), leadTime: 90),
          theme: appearance.theme,
          accounts: model.config.accounts)
      }
      .padding(.vertical, 14)
    } footer: {
      Button {
        onTry(previewScenario)
      } label: {
        Label("Try Full Screen", systemImage: "play.rectangle")
      }
      .help("Shows the cut-in on every screen. Join or hold the corner control to close it.")
    }

    SettingsGroup("Motion") {
      SettingsRow(
        "Drop in from the top",
        description:
          "When off, the cut-in appears at once. With Reduce Motion on in System Settings, it fades in instead."
      ) {
        Toggle(
          "",
          isOn: Binding(
            get: { appearance.dropsIn }, set: { on in model.updateConfig { $0.appearance.dropsIn = on } })
        )
        .toggleStyle(.switch)
        .labelsHidden()
      }
    }

    if appearance.style == .custom {
      CustomThemeGroup(model: model)
    } else {
      SettingsGroup("Custom") {
        SettingsRow(
          "Start from this style",
          description: "Copy the selected preset into the custom style and adjust its colours and font."
        ) {
          Button("Customize…") { model.updateConfig { $0.appearance.customize() } }
        }
      }
    }
  }
}

private struct CustomThemeGroup: View {
  @ObservedObject var model: AppModel

  var body: some View {
    SettingsGroup("Custom") {
      SettingsRow("Background", description: "The gradient from the top of the screen to the bottom.") {
        HStack(spacing: 8) {
          ColorPicker("Top", selection: color(\.backgroundTop), supportsOpacity: false).labelsHidden()
          ColorPicker("Bottom", selection: color(\.backgroundBottom), supportsOpacity: false).labelsHidden()
        }
      }
      SettingsRow("Background opacity", description: "Lower lets the screen underneath show through.") {
        HStack {
          Slider(value: binding(\.backgroundOpacity), in: CutinTheme.opacityRange).frame(width: 160)
          Text(model.config.appearance.custom.backgroundOpacity, format: .percent.precision(.fractionLength(0)))
            .monospacedDigit()
            .frame(width: 44, alignment: .trailing)
        }
      }
      SettingsRow("Text") {
        ColorPicker("Text", selection: color(\.text), supportsOpacity: false).labelsHidden()
      }
      SettingsRow("Join button", description: "Its label turns dark or light to stay readable.") {
        ColorPicker("Join button", selection: color(\.accent), supportsOpacity: false).labelsHidden()
      }
      SettingsRow("Font") {
        Picker("", selection: binding(\.fontDesign)) {
          ForEach(CutinFontDesign.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }
    }
  }

  private func binding<T>(_ keyPath: WritableKeyPath<CutinTheme, T>) -> Binding<T> {
    Binding(
      get: { model.config.appearance.custom[keyPath: keyPath] },
      set: { v in model.updateConfig { $0.appearance.custom[keyPath: keyPath] = v } })
  }

  private func color(_ keyPath: WritableKeyPath<CutinTheme, ThemeColor>) -> Binding<Color> {
    Binding(
      get: { Color(model.config.appearance.custom[keyPath: keyPath]) },
      set: { v in model.updateConfig { $0.appearance.custom[keyPath: keyPath] = ThemeColor(v) } })
  }
}

/// An option card in the style of Arto's: a swatch of the theme above its name,
/// outlined in the accent colour when selected.
private struct StyleCard: View {
  let title: String
  let theme: CutinTheme
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack {
          LinearGradient(
            colors: [Color(theme.backgroundTop), Color(theme.backgroundBottom)], startPoint: .top, endPoint: .bottom)
          VStack(spacing: 6) {
            Text("1:30")
              .font(.system(size: 20, weight: .bold))
              .fontDesign(theme.fontDesign.swiftUI)
              .foregroundStyle(Color(theme.text))
            Capsule()
              .fill(Color(theme.accent))
              .frame(width: 44, height: 12)
          }
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        Text(title)
          .font(.callout.weight(selected ? .semibold : .regular))
          .foregroundStyle(selected ? Color.accentColor : .primary)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.08) : .clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }
}

/// The real cut-in, laid out for a typical screen and scaled down to fit the page.
private struct CutinMiniature: View {
  let meetings: [Meeting]
  let theme: CutinTheme
  let accounts: [AccountSettings]
  private let screen = CGSize(width: 1440, height: 900)

  var body: some View {
    GeometryReader { proxy in
      let scale = proxy.size.width / screen.width
      CutinView(meetings: meetings, theme: theme, accounts: accounts, onJoin: { _ in }, onDismiss: {})
        .frame(width: screen.width, height: screen.height)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }
    .aspectRatio(screen.width / screen.height, contentMode: .fit)
    .background(Color.black.opacity(0.2))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .allowsHitTesting(false)
    .accessibilityLabel("Preview of the cut-in")
  }
}

extension CutinFontDesign {
  var title: String {
    switch self {
    case .standard: "Standard"
    case .rounded: "Rounded"
    case .serif: "Serif"
    case .monospaced: "Mono"
    }
  }
}
