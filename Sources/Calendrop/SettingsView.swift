import AppKit
import CalendropCore
import SwiftUI

/// Laid out like the settings of Kanaemi and Arto: a sidebar of pages with About
/// at the bottom, and pages of grouped boxes whose rows carry the label and its
/// description on the left and the control on the right. Every change applies at
/// once; there is no Save button.
struct SettingsView: View {
  @ObservedObject var model: AppModel
  /// Shows the cut-in full screen with sample meetings.
  let onTry: (SampleCalendar.Scenario) -> Void
  @State private var page: SettingsPage = .general

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        List(selection: $page) {
          ForEach(SettingsPage.mainPages) { page in
            Label(page.title, systemImage: page.symbol).tag(page)
          }
        }
        List(selection: $page) {
          Label(SettingsPage.about.title, systemImage: SettingsPage.about.symbol).tag(SettingsPage.about)
        }
        .frame(height: 44)
        .scrollDisabled(true)
      }
      .navigationSplitViewColumnWidth(200)
    } detail: {
      SettingsPageView(title: page.title) {
        switch page {
        case .general: GeneralPage(model: model)
        case .appearance: AppearancePage(model: model, onTry: onTry)
        case .accounts: AccountsPage(model: model)
        case .sync: SyncPage(model: model)
        case .about: AboutPage()
        }
      }
    }
  }
}

enum SettingsPage: String, Identifiable, Hashable {
  case general, appearance, accounts, sync, about

  static let mainPages: [SettingsPage] = [.general, .appearance, .accounts, .sync]

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: "General"
    case .appearance: "Appearance"
    case .accounts: "Accounts"
    case .sync: "Sync"
    case .about: "About Calendrop"
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape"
    case .appearance: "paintpalette"
    case .accounts: "person.2"
    case .sync: "icloud"
    case .about: "info.circle"
    }
  }
}

// MARK: - Pages

private struct GeneralPage: View {
  @ObservedObject var model: AppModel

  var body: some View {
    SettingsGroup("Cut-in") {
      SettingsRow(
        "Show before a meeting",
        description: "How long before the start the cut-in covers every screen.",
        reset: model.config.leadMinutes == SharedConfig().leadMinutes
          ? nil
          : ResetLink(label: minutes(SharedConfig().leadMinutes)) {
            model.updateConfig { $0.setLeadMinutes(SharedConfig().leadMinutes) }
          }
      ) {
        let lead = Binding(
          get: { model.config.leadMinutes },
          set: { v in model.updateConfig { $0.setLeadMinutes(v) } })
        HStack(spacing: 6) {
          TextField("", value: lead, format: .number)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 48)
          Stepper("", value: lead, in: SharedConfig.leadMinutesRange)
            .labelsHidden()
          Text(model.config.leadMinutes == 1 ? "minute" : "minutes")
            .foregroundStyle(.secondary)
        }
        .help("0 shows the cut-in when the meeting starts.")
      }
      SettingsRow(
        "Meetings without a video link",
        description:
          "Also cut in for meetings with nothing to join, such as in-person ones. Their cut-in closes with OK."
      ) {
        Toggle("", isOn: binding(\.cutInWithoutJoinLink))
          .toggleStyle(.switch)
          .labelsHidden()
      }
    }
  }

  private func minutes(_ n: Int) -> String {
    n == 0 ? "At the start" : n == 1 ? "1 minute" : "\(n) minutes"
  }

  private func binding<T>(_ keyPath: WritableKeyPath<SharedConfig, T>) -> Binding<T> {
    Binding(get: { model.config[keyPath: keyPath] }, set: { v in model.updateConfig { $0[keyPath: keyPath] = v } })
  }
}

private struct SyncPage: View {
  @ObservedObject var model: AppModel

  var body: some View {
    SettingsGroup(
      "Shared settings",
      note:
        "Accounts and settings live in the file below. On iCloud Drive it follows you to every Mac signed in to the same iCloud. Sign-in tokens never leave this Mac's Keychain, so each Mac signs in to each account once."
    ) {
      if let url = model.store.location {
        SettingsRow("Settings file", description: url.path) {
          Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
          }
          .disabled(!FileManager.default.fileExists(atPath: url.path))
        }
      } else {
        SettingsRow(
          "Settings file", description: "None — these settings are not saved and are forgotten when Calendrop quits."
        ) { EmptyView() }
      }
    }
  }
}

private struct AboutPage: View {
  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development build"
  }

  var body: some View {
    VStack(spacing: 10) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 112, height: 112)
      Text("Calendrop").font(.system(size: 28, weight: .bold))
      Text("Version \(version)").foregroundStyle(.secondary)
      Text("Cuts in on every screen before your next meeting.")
        .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)

    SettingsGroup("Links") {
      SettingsRow("Source code", description: "github.com/calendrop-app/Calendrop") {
        Link("Open", destination: URL(string: "https://github.com/calendrop-app/Calendrop")!)
      }
    }

    Text("Alisue · MIT License")
      .font(.callout)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
  }
}

// MARK: - Building blocks

private struct SettingsPageView<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: 0) {
      Text(title)
        .font(.system(size: 20, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .frame(height: 56)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          content
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct SettingsGroup<Content: View, Footer: View>: View {
  let title: String
  let note: String?
  @ViewBuilder let content: Content
  @ViewBuilder let footer: Footer

  init(
    _ title: String, note: String? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder footer: () -> Footer = { EmptyView() }
  ) {
    self.title = title
    self.note = note
    self.content = content()
    self.footer = footer()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 16, weight: .bold))
      if let note {
        Text(note)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      // Every row draws a hairline above itself; shifting the stack up by the
      // hairline's height and clipping hides the first one.
      VStack(spacing: 0) { content }
        .padding(.top, -1)
        .padding(.horizontal, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
      footer
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }
}

struct ResetLink {
  let label: String
  let action: () -> Void
}

struct SettingsRow<Control: View>: View {
  let label: String
  let description: String?
  let descriptionColor: Color
  let reset: ResetLink?
  @ViewBuilder let control: Control

  init(
    _ label: String, description: String? = nil, descriptionColor: Color = .secondary, reset: ResetLink? = nil,
    @ViewBuilder control: () -> Control
  ) {
    self.label = label
    self.description = description
    self.descriptionColor = descriptionColor
    self.reset = reset
    self.control = control()
  }

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      row
    }
  }

  private var row: some View {
    VStack(alignment: .trailing, spacing: 4) {
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 2) {
          Text(label)
          if let description {
            Text(description)
              .font(.callout)
              .foregroundStyle(descriptionColor)
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 12)
        control
      }
      if let reset {
        Button("Reset to “\(reset.label)”", action: reset.action)
          .buttonStyle(.link)
          .font(.callout)
      }
    }
    .padding(.vertical, 12)
  }
}

struct SettingsWarning: View {
  let message: String
  var symbol = "exclamationmark.triangle"

  var body: some View {
    Label(message, systemImage: symbol)
      .font(.callout)
      .textSelection(.enabled)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.14)))
  }
}
