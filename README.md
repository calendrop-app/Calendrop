# Calendrop

A macOS menu bar app that shows your next Google Calendar meeting and, shortly
before it starts, **cuts in**: it covers every screen until you join the meeting
or deliberately dismiss it.

- Several Google accounts at once; an event you were invited to from more than
  one account appears once.
- The menu bar shows the next meeting and a countdown (`Weekly sync · in 12m`).
- The menu lists today's and tomorrow's meetings, coloured by account. Each
  opens a submenu with its time, place, people and description, and actions to
  join its Meet, Zoom, Teams or Webex link, copy the link, or open the event in
  Google Calendar.
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

A build made without the Google OAuth client (see below) cannot sign in to real
accounts. Its **Add Account…** adds sample accounts instead, with sample
calendars and meetings, so everything else — labels, colours, calendar choice,
the menu and the cut-in — can be tried. Sample accounts stay on this Mac and
never reach the settings shared through iCloud.

## Add Google accounts

Open **Settings → Accounts**, press **Add Account…**, and sign in in the
browser. Repeat for each Google account.

### Building with Google sign-in

Sign-in needs a Google OAuth client embedded in the app. A build without one
offers sample accounts instead (see above). Whoever builds Calendrop sets one up
once:

1. In [Google Cloud Console](https://console.cloud.google.com/), create a
   project and enable the **Google Calendar API**.
2. Configure the OAuth consent screen. While its publishing status is
   **Testing**, only listed test users can sign in and Google expires their
   sign-in after seven days; publish it to **In production** to avoid that
   (unverified apps show a warning and are limited to 100 users).
3. Create an **OAuth client ID** of type **Desktop app**.

Then pass its ID and secret to the build through the environment; `just
bundle` (and `just run`, `just install`) embed them:

```sh
CALENDROP_GOOGLE_CLIENT_ID=… CALENDROP_GOOGLE_CLIENT_SECRET=… just install
```

Keep them out of the repository — for example in a password manager whose CLI
can inject them, such as `op run` for 1Password. Google treats a Desktop
client's secret as non-confidential: the loopback redirect, PKCE and the
user's own consent protect each sign-in.

## Using several Macs

Calendrop keeps two kinds of state apart:

| What | Where | Shared |
| --- | --- | --- |
| Account list, lead time, cut-in style | `~/Library/Mobile Documents/com~apple~CloudDocs/Calendrop/config.json` (iCloud Drive), or `~/Library/Application Support/Calendrop/` without iCloud Drive | yes |
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
