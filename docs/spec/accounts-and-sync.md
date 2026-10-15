# Accounts and sync

Calendrop reads the meetings of any number of Google accounts and shares its setup
between the user's Macs.

## Accounts

- Signing in happens in the default browser; nothing has to be configured
  first. Calendrop only ever asks for read-only calendar access and the account's
  email address.
- Each account has a label and a colour that the menu, the cut-in and settings
  show in place of its address.
- Meetings come from the calendars the user chose for each account. Until the
  user chooses, those ticked in Google Calendar are used.
- Removing an account asks for confirmation first, since it removes the
  account from every Mac that shares the configuration.
- An event visible through several accounts is shown once.
- Google Meet links and Google Calendar event pages open as the account the
  meeting came from, even when the browser defaults to another Google account.
- An account whose grant is missing or revoked is shown as needing sign-in;
  its meetings disappear until it is signed in again. When the network is
  unavailable, the meetings last fetched are kept.

## Shared configuration

Calendrop keeps its configuration in `Calendrop/config.json` on iCloud Drive, or in
`~/Library/Application Support/Calendrop/config.json` when iCloud Drive is off.
Every Mac reading the same file shows the same accounts and settings; edits
made on one Mac reach the others on the next refresh.

The file is a JSON object. Every key is optional and unknown keys are ignored:

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `accounts` | array of objects | `[]` | The accounts to read; see below |
| `leadMinutes` | integer | `2` | Minutes before the start that the cut-in appears |
| `cutInWithoutJoinLink` | boolean | `false` | Whether meetings without a video link cut in too |
| `appearance` | object | the Midnight preset | How the cut-in looks; see below |

`accounts` holds one object per account:

| Key | Type | Meaning |
| --- | --- | --- |
| `email` | string | The account's address; required |
| `label` | string | Shown instead of the address |
| `color` | string | `#RRGGBB`; a colour not yet used by another account when missing |
| `calendarIDs` | array of strings | Google Calendar IDs to read; when missing, those ticked in Google Calendar |

An entry may also be a bare address string, as older versions wrote. An entry
that cannot be read is skipped without affecting the others.

`appearance` holds:

| Key | Type | Meaning |
| --- | --- | --- |
| `style` | string | `midnight`, `daylight`, `sunset`, `ocean`, `monochrome`, or `custom` |
| `custom` | object | The custom style, kept while a preset is selected |
| `dropsIn` | boolean | Whether the cut-in falls in from the top; `true` when missing |

`custom` holds `backgroundTop`, `backgroundBottom`, `text` and `accent` as
`#RRGGBB` colours, `backgroundOpacity` as a number from `0.6` to `1`, and
`fontDesign` as `standard`, `rounded`, `serif` or `monospaced`. A missing or
unrecognised value falls back to the Midnight preset's.

The file never holds a token. A listed account that has not been signed in on
the current Mac is shown as needing sign-in, and signing in preselects it.
