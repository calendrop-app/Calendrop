import CalendropCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Form {
      if model.isDemo {
        Section {
          Label(
            "Demo mode: showing sample meetings. Changes here are not saved, and Google is never contacted.",
            systemImage: "theatermasks")
        }
      }

      Section {
        TextField("Client ID", text: binding(\.clientID))
        SecureField("Client secret", text: binding(\.clientSecret))
      } header: {
        Text("Google OAuth Client")
      } footer: {
        Text(
          "In Google Cloud Console, enable the Google Calendar API and create an OAuth client of type “Desktop app”."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Accounts") {
        ForEach(model.config.accounts, id: \.self) { account in
          AccountRow(account: account, state: model.state(of: account), isBusy: model.isSigningIn) {
            Task { await model.signIn(hint: account) }
          } onRemove: {
            model.remove(account: account)
          }
        }
        Button("Add Account…") {
          Task { await model.signIn(hint: nil) }
        }
        .disabled(model.config.oauthClient == nil || model.isSigningIn)
      }

      Section("Cut-in") {
        Stepper(value: binding(\.leadMinutes), in: 0...30) {
          Text(
            model.config.leadMinutes == 0
              ? "Show when the meeting starts" : "Show \(model.config.leadMinutes) min before the meeting starts")
        }
      }

      Section {
        LabeledContent("Shared settings", value: model.store.url.path)
          .textSelection(.enabled)
      } header: {
        Text("Sync")
      } footer: {
        Text(
          "The client and the account list sync through iCloud Drive. Sign-in tokens stay in this Mac's Keychain, so each Mac signs in to each account once."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      if let error = model.lastError {
        Section {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .textSelection(.enabled)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 560)
    .frame(minHeight: 520)
  }

  private func binding<T>(_ keyPath: WritableKeyPath<SharedConfig, T>) -> Binding<T> {
    Binding(
      get: { model.config[keyPath: keyPath] },
      set: { value in model.updateConfig { $0[keyPath: keyPath] = value } }
    )
  }
}

private struct AccountRow: View {
  let account: String
  let state: AppModel.AccountState
  let isBusy: Bool
  let onSignIn: () -> Void
  let onRemove: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(account)
        switch state {
        case .ok:
          Text("Signed in on this Mac").font(.caption).foregroundStyle(.secondary)
        case .needsSignIn:
          Text("Sign-in required on this Mac").font(.caption).foregroundStyle(.orange)
        case .error(let message):
          Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
        }
      }
      Spacer()
      if state != .ok {
        Button("Sign In…", action: onSignIn).disabled(isBusy)
      }
      Button("Remove", role: .destructive, action: onRemove)
    }
  }
}
