# Accounts and sync

Calendrop reads the meetings of any number of Google accounts and shares its setup
between the user's Macs.

## Accounts

- Signing in happens in the default browser. Calendrop only ever asks for
  read-only calendar access and the account's email address.
- Meetings come from the calendars the user has selected in Google Calendar.
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
| `clientID` | string | `""` | Client ID of a Google OAuth client of type "Desktop app" |
| `clientSecret` | string | `""` | That client's secret |
| `accounts` | array of strings | `[]` | Email addresses of the accounts to read, in lower case |
| `leadMinutes` | integer | `2` | Minutes before the start that the cut-in appears |

The file never holds a token. A listed account that has not been signed in on
the current Mac is shown as needing sign-in, and signing in preselects it.
