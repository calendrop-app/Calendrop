# Accounts and sync

Calendrop reads the meetings of any number of Google accounts and shares its setup
between the user's Macs.

## Accounts

- Signing in happens in the default browser; nothing has to be configured
  first. Calendrop asks only to see the account's list of calendars and their
  events. A sign-in that leaves either out is turned back with an explanation.
- A sign-in left unfinished in the browser can be cancelled, and starting
  another one replaces it.
- Each account has a label and a colour that the menu, the cut-in and settings
  show in place of its address.
- Meetings come from the calendars the user chose for each account. Until the
  user chooses, only the account's main calendar is used.
- Removing an account asks for confirmation first, since it removes the
  account from every Mac that shares the configuration.
- An event visible through several accounts is shown once.
- Google Meet links and Google Calendar event pages open as the account the
  meeting came from, even when the browser defaults to another Google account.
- When macOS asks whether Calendrop may use its Keychain, it asks once for all
  accounts, and at most once per launch.
- An account whose grant is missing or revoked is shown as needing sign-in;
  its meetings disappear until it is signed in again. When the network is
  unavailable, the meetings last fetched are kept.

## Staying current

- Calendrop reads today's and tomorrow's meetings, and reads them again every
  few minutes, when the Mac wakes, and when the user asks from the menu.
- The menu says how many calendars it read and how long ago every account was
  last read, so an empty list can be told apart from one that was never read.
  When nothing is left today or tomorrow, the menu says so in those words.
- When nothing is left today or tomorrow, Calendrop also looks further ahead
  and shows the first meeting it finds there, or the last day it looked
  through. It does neither while an account cannot be read, since that
  account might hold an earlier meeting.

## Shared configuration

Calendrop keeps its configuration in `Calendrop/config.json` on iCloud Drive, or in
`~/Library/Application Support/Calendrop/config.json` when iCloud Drive is off.
Every Mac reading the same file shows the same accounts and settings; edits
made on one Mac reach the others on the next refresh.

The file is a JSON object. Every key is optional and unknown keys are ignored:

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `accounts` | array of objects | `[]` | The accounts to read; see below |
| `leadMinutes` | integer | `2` | Minutes before the start that the cut-in appears, from 0 to 120; values outside are clamped |
| `cutInWithoutJoinLink` | boolean | `false` | Whether meetings without a video link cut in too |
| `cutInWithoutAcceptance` | boolean | `true` | Whether meetings answered "maybe" to, or not answered, cut in too |
| `appearance` | object | the Midnight preset | How the cut-in looks; see below |
| `showMeetingTitleInMenuBar` | boolean | `true` | Whether the menu bar shows the meeting title alongside the countdown |
| `menuCalendar` | string | `hidden` | The calendar above the menu's meetings: `month`, `week`, or `hidden` for none; an unrecognised value counts as `hidden` |

`accounts` holds one object per account:

| Key | Type | Meaning |
| --- | --- | --- |
| `email` | string | The account's address; required |
| `label` | string | Shown instead of the address |
| `color` | string | `#RRGGBB`; a colour not yet used by another account when missing |
| `calendarIDs` | array of strings | Google Calendar IDs to read; when missing, the account's main calendar only |

An entry that cannot be read is skipped without affecting the others.

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
