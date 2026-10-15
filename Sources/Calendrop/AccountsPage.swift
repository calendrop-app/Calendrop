import CalendropCore
import SwiftUI

/// A one-line summary per account; each account's settings open in a sheet, so the
/// page stays a list however many accounts there are.
struct AccountsPage: View {
  @ObservedObject var model: AppModel
  @State private var editing: EditedAccount?

  var body: some View {
    if let notice = model.sourceNotice {
      SettingsWarning(message: notice, symbol: "info.circle")
    }

    SettingsGroup(
      "Accounts", note: "Calendrop reads the calendars you choose for each account. Sign-in happens in your browser."
    ) {
      if model.config.accounts.isEmpty {
        SettingsRow("No accounts yet", description: "Add an account to see its meetings.") { EmptyView() }
      }
      ForEach(model.config.accounts) { account in
        AccountSummaryRow(model: model, account: account) { editing = EditedAccount(email: account.email) }
      }
    } footer: {
      HStack(spacing: 8) {
        Button {
          Task { await model.refresh() }
        } label: {
          Label(model.isRefreshing ? "Refreshing…" : "Refresh Now", systemImage: "arrow.clockwise")
        }
        .disabled(model.isRefreshing || model.config.accounts.isEmpty)
        Button {
          Task { await model.signIn(hint: nil) }
        } label: {
          Label(model.isSigningIn ? "Waiting for the sign-in to finish…" : "Add Account…", systemImage: "plus")
        }
        .disabled(model.isSigningIn)
      }
    }
    .sheet(item: $editing) { edited in
      AccountSheet(model: model, email: edited.email) { editing = nil }
    }

    if let error = model.lastError {
      SettingsWarning(message: error)
    }
  }
}

private struct EditedAccount: Identifiable {
  var email: String
  var id: String { email }
}

private struct AccountSummaryRow: View {
  @ObservedObject var model: AppModel
  let account: AccountSettings
  let open: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      Button(action: open) {
        HStack(spacing: 12) {
          Circle().fill(Color(account.color)).frame(width: 12, height: 12)
          VStack(alignment: .leading, spacing: 2) {
            Text(account.displayName)
            Text(summary)
              .font(.callout)
              .foregroundStyle(model.state(of: account.email) == .ok ? .secondary : Color.orange)
          }
          Spacer(minLength: 12)
          Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  private var summary: String {
    var parts = [account.label == nil ? nil : account.email].compactMap { $0 }
    switch model.state(of: account.email) {
    case .needsSignIn: parts.append("Sign-in required")
    case .error: parts.append("Could not read calendars")
    case .ok:
      if let all = model.calendars[account.email], !all.isEmpty {
        parts.append("\(all.filter(account.uses).count) of \(all.count) calendars")
      }
    }
    return parts.isEmpty ? account.email : parts.joined(separator: " · ")
  }
}

/// Everything about one account, opened from its row.
private struct AccountSheet: View {
  @ObservedObject var model: AppModel
  let email: String
  let close: () -> Void
  @State private var confirmingRemoval = false

  var body: some View {
    VStack(spacing: 0) {
      if let account = model.config.account(email) {
        HStack(spacing: 10) {
          Circle().fill(Color(account.color)).frame(width: 14, height: 14)
          VStack(alignment: .leading, spacing: 2) {
            Text(account.displayName).font(.system(size: 17, weight: .bold))
            Text(account.email).font(.callout).foregroundStyle(.secondary)
          }
          Spacer()
          Button("Done", action: close).keyboardShortcut(.defaultAction)
        }
        .padding(20)
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            AccountGroup(model: model, account: account) { confirmingRemoval = true }
          }
          .padding(20)
        }
        .confirmationDialog("Remove \(account.displayName)?", isPresented: $confirmingRemoval) {
          Button("Remove Account", role: .destructive) {
            close()
            model.remove(account: email)
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text(
            "Its meetings stop appearing and cutting in on every Mac that shares these settings. You can add it again later by signing in."
          )
        }
      }
    }
    .frame(width: 540, height: 560)
  }
}

private struct AccountGroup: View {
  @ObservedObject var model: AppModel
  let account: AccountSettings
  let remove: () -> Void

  var body: some View {
    let state = model.state(of: account.email)
    SettingsGroup("Display") {
      SettingsRow("Label", description: "Shown in the menu and on the cut-in instead of the address.") {
        TextField(
          "",
          text: Binding(
            get: { account.label ?? "" }, set: { v in model.updateAccount(account.email) { $0.label = v } }),
          prompt: Text(account.email)
        )
        .frame(width: 200)
      }
      SettingsRow("Colour") {
        ColourSwatches(selection: account.color) { colour in
          model.updateAccount(account.email) { $0.color = colour }
        }
      }
    }
    if state != .ok {
      SettingsGroup("Sign-in") {
        SettingsRow(
          "Sign-in", description: status(state), descriptionColor: state == .needsSignIn ? .orange : .red
        ) {
          Button("Sign In…") { Task { await model.signIn(hint: account.email) } }
            .disabled(model.isSigningIn)
        }
      }
    }
    SettingsGroup("Calendars", note: "The calendars Calendrop reads for this account.") {
      CalendarRows(model: model, account: account)
    }
    SettingsGroup("Remove") {
      SettingsRow("Remove account", description: "Stops its meetings on every Mac that shares these settings.") {
        Button("Remove…", role: .destructive, action: remove)
      }
    }
  }

  private func status(_ state: AppModel.AccountState) -> String {
    switch state {
    case .ok: ""
    case .needsSignIn: "Sign-in required on this Mac"
    case .error(let message): message
    }
  }
}

/// One switch per calendar of the account. Until the user flips one, the switches
/// mirror what is ticked in Google Calendar.
private struct CalendarRows: View {
  @ObservedObject var model: AppModel
  let account: AccountSettings

  var body: some View {
    let all = model.calendars[account.email] ?? []
    if all.isEmpty {
      SettingsRow("Calendars", description: "Listed once the account's calendars have been read.") { EmptyView() }
    } else {
      ForEach(all) { calendar in
        SettingsRow(
          calendar.name,
          description: calendar.isPrimary ? "Main calendar" : nil
        ) {
          Toggle(
            "",
            isOn: Binding(
              get: { account.uses(calendar) },
              set: { on in model.updateAccount(account.email) { $0.setCalendar(calendar, used: on, among: all) } })
          )
          .toggleStyle(.switch)
          .labelsHidden()
        }
      }
      if account.calendarIDs != nil {
        SettingsRow("Calendar choice", description: "Other calendars are turned on here.") {
          Button("Use Only the Main Calendar") { model.updateAccount(account.email) { $0.calendarIDs = nil } }
        }
      }
    }
  }
}

private struct ColourSwatches: View {
  let selection: ThemeColor
  let choose: (ThemeColor) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(AccountPalette.colors, id: \.self) { colour in
        Button {
          choose(colour)
        } label: {
          Circle()
            .fill(Color(colour))
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(Color.primary.opacity(colour == selection ? 0.8 : 0), lineWidth: 2).padding(-3))
        }
        .buttonStyle(.plain)
        .help(colour.hex)
      }
      ColorPicker(
        "", selection: Binding(get: { Color(selection) }, set: { choose(ThemeColor($0)) }), supportsOpacity: false
      )
      .labelsHidden()
    }
  }
}
