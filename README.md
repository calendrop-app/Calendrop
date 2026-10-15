# Calendrop

A macOS menu bar app that shows your next Google Calendar meeting and, shortly
before it starts, **cuts in**: it covers every screen until you join the meeting
or deliberately dismiss it.

- Several Google accounts at once; an event you were invited to from more than
  one account appears once.
- The menu bar shows the next meeting and a countdown (`Weekly sync · in 12m`).
- The menu lists today's and tomorrow's meetings; choosing one opens its Meet,
  Zoom, Teams or Webex link in the browser (or the event page when it has none).
- The cut-in appears `n` minutes before the start (configurable, default 2) on
  every display. Plugging or unplugging a display or changing the resolution
  rebuilds it to fit the new screens.
- It stays until you press **Join Meeting** (or Return) or press and hold the
  small dismiss control in the corner. Escape and ⌘W do nothing.

## Install

Requires macOS 14+ and Swift 6 from Xcode or the Command Line Tools.

```sh
just install   # build Calendrop.app and copy it into /Applications
```

## Try it without Google

```sh
just demo
```

launches Calendrop with `--demo`: the menu fills with sample meetings, and
**Try Cut-in** in the menu shows a single meeting, meetings at the same time, or
meetings close together. Nothing is read from or written to Google, the shared
configuration or the Keychain.

## Set up Google access

1. In [Google Cloud Console](https://console.cloud.google.com/), create a
   project, enable the **Google Calendar API**, and configure the OAuth consent
   screen (add yourself as a test user while the app is in testing).
2. Create an **OAuth client ID** of type **Desktop app**.
3. Open Calendrop's settings, paste the client ID and secret, and press
   **Add Account…** for each Google account.

Google treats the secret of a Desktop client as non-confidential; it alone
grants access to nothing.

## Using several Macs

Calendrop keeps two kinds of state apart:

| What | Where | Shared |
| --- | --- | --- |
| OAuth client, account list, lead time | `~/Library/Mobile Documents/com~apple~CloudDocs/Calendrop/config.json` (iCloud Drive), or `~/Library/Application Support/Calendrop/` without iCloud Drive | yes |
| Refresh tokens | login Keychain, non-synchronizable, this device only | no |

On another Mac the accounts appear as "Sign-in required". Signing in opens the
browser with the account already chosen (`login_hint`), so tokens never travel
between machines.

Because the app is ad-hoc signed, macOS asks for Keychain access again after
each rebuild; choose **Always Allow**.

## Development

Enter the development shell with `nix develop` (or copy `.envrc.sample` to
`.envrc` and `direnv allow`) for `just` and `nixfmt`. Swift itself comes from
Xcode or the Command Line Tools. Then:

```sh
just fmt   # format every source
just ci    # everything CI runs: format check, warnings-as-errors build, tests
just run   # build build/Calendrop.app and launch it
```

The design lives in [docs/concept.md](docs/concept.md), the decisions behind it
in [docs/adr/](docs/adr/), and the behaviour it promises in
[docs/spec/](docs/spec/).

## License

MIT. See [LICENSE](LICENSE).
