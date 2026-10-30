<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/calendrop-app/calendrop-brand/main/logo/calendrop-logo-vertical-dark.svg">
    <img alt="Calendrop" src="https://raw.githubusercontent.com/calendrop-app/calendrop-brand/main/logo/calendrop-logo-vertical.svg" width="240">
  </picture>
</p>

<p align="center">
  <strong>Your next meeting, dropped over every screen.</strong>
</p>

<p align="center">
  <a href="https://calendrop-app.github.io/">Website</a> ·
  <a href="https://calendrop-app.github.io/privacy/">Privacy Policy</a> ·
  <a href="https://calendrop-app.github.io/terms/">Terms of Service</a>
</p>

A macOS menu bar app that shows your next Google Calendar meeting and, shortly
before it starts, **cuts in**: it covers every screen until you join the meeting
or deliberately dismiss it.

https://github.com/user-attachments/assets/3710b75f-57e9-44a7-be7e-d54129cfe9dc

- Several Google accounts at once; an event you were invited to from more than
  one account appears once.
- The menu bar shows the next meeting and a countdown (`Weekly sync · in 12m`).
- The menu lists today's and tomorrow's meetings, coloured by account. Each
  opens a submenu with its time, place, people and description, and actions to
  join its Meet, Zoom, Teams or Webex link, copy the link, or open the event in
  Google Calendar.
- Optionally, a month or a week above the meetings in the menu; choosing a day
  lists its meetings.
- The cut-in appears `n` minutes before the start (configurable, default 2) on
  every display. Plugging or unplugging a display or changing the resolution
  rebuilds it to fit the new screens.
- It stays until you press **Join Meeting** (or Return) or press and hold the
  small dismiss control in the bottom-left corner. In an emergency, ⌃⌥⌘⎋
  (Control-Option-Command-Escape) dismisses it too. Escape alone and ⌘W do
  nothing.

## Inspired by MeetingBar

Calendrop is strongly inspired by [MeetingBar](https://github.com/leits/MeetingBar),
a menu bar app that keeps your next meeting in sight and joins it in one click.

The difference is where the full-screen reminder sits. In MeetingBar it is one
reminder among several: off by default, next to the macOS notifications, with
little to adjust. In Calendrop the cut-in is the app itself, and everything else
is there to make it hard to miss and easy to act on. Calendrop was built as a
separate app for that, and for what MeetingBar 4.11 did not do for us:

- Its Google Calendar connection takes one Google account. Calendrop reads
  several at once and merges them into one timeline.
- Its full-screen reminder appears on one display, and could be left off-screen
  and impossible to close when that display was unplugged. Calendrop's cut-in
  covers every display and is rebuilt whenever the screens change.

## Install

Requires macOS 14+ on Apple silicon. With [Homebrew](https://brew.sh/):

```sh
brew install --cask calendrop-app/tap/calendrop
```

Or download `Calendrop-<version>-macos-arm64.zip`
from [Releases](https://github.com/calendrop-app/Calendrop/releases), unzip it
and move Calendrop.app into /Applications. The app is self-signed, not
notarized, so the first launch has to be allowed in System Settings › Privacy
& Security.

To build it yourself instead, with Xcode (the Command Line Tools cannot compile
its translations):

```sh
just install-macos   # build Calendrop.app and copy it into /Applications
```

## Try it without Google

A build made without the Google OAuth client (see below) cannot sign in to real
accounts. It starts with sample accounts instead, with sample calendars and
meetings, and **Add Account…** adds more, so everything else — labels, colours,
calendar choice, the menu and the cut-in — can be tried. Nothing is saved:
sample accounts and any settings changed are forgotten when Calendrop quits, and
the settings shared through iCloud are never touched.

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
bundle` (and `just run`, `just install-macos`) embed them:

```sh
CALENDROP_GOOGLE_CLIENT_ID=… CALENDROP_GOOGLE_CLIENT_SECRET=… just install-macos
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

Builds are signed with a self-signed identity, "Calendrop Release", when the login
keychain has it, so every build has the same signing requirement. Make it once with
`just release-identity <folder>`, keep the two values it prints, and import them
on each Mac:

```sh
CALENDROP_SIGNING_P12=… CALENDROP_SIGNING_PASSWORD=… just import-identity
```

Without it, builds are signed ad-hoc.

Either way, macOS asks for Keychain access once more after each rebuild or
update, even when it was always allowed: without an Apple team ID in the
signature, it ties that answer to the build itself.

## Release

Publish a GitHub release tagged `vX.Y.Z`. The version comes from the tag alone:
`Resources/Info.plist` keeps `0.0.0`, and the Release workflow writes `X.Y.Z`
into the app it builds. The Release workflow builds the app
from the tag, signed by "Calendrop Release" and with the Google OAuth client
from the environment "release", and attaches the zip to the release. It then
has [the site](https://calendrop-app.github.io/) rebuilt and the
[Homebrew cask](https://github.com/calendrop-app/homebrew-tap) rewritten for the
release, through the tokens in the secrets `SITE_DISPATCH_TOKEN` and
`HOMEBREW_TAP_DISPATCH_TOKEN`.

## Development

Enter the development shell with `nix develop` (or copy `.envrc.sample` to
`.envrc` and `direnv allow`) for `just`, `nixfmt` and `rsvg-convert`. Swift itself comes from
Xcode. Then:

```sh
just fmt   # format every source
just l10n  # add the strings the source uses to the String Catalogs
just ci    # everything CI runs: format check, warnings-as-errors build, catalog check, tests
just run   # build build/Calendrop.app and launch it
```

The design lives in [docs/concept.md](docs/concept.md), the decisions behind it
in [docs/adr/](docs/adr/), and the behaviour it promises in
[docs/spec/](docs/spec/).

## License

MIT. See [LICENSE](LICENSE).
