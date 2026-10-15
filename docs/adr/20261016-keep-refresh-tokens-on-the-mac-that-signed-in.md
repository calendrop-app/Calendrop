# Keep refresh tokens on the Mac that signed in

Status: Accepted

## Context

The user runs Calendrop on more than one Mac and wants the accounts and settings
to follow them. A Google refresh token grants calendar access until it is
revoked, so wherever it is copied to becomes something to protect.

## Decision

Refresh tokens stay in the Keychain of the Mac that signed in and are never
synced. Only the account list and settings are shared between Macs, through
iCloud Drive, and each Mac signs in to each shared account itself.

## Alternatives considered

- Sync the tokens through iCloud Keychain. It needs an Apple Developer team to
  sign the app, and a token leaked from any synced device is valid everywhere.
- Store the tokens in iCloud Drive, encrypted with a passphrase. The passphrase
  becomes one more secret to keep and to type on every Mac, and the token still
  leaves the machine.

## Consequences

- A new Mac needs one browser sign-in per account.
- Losing or wiping a Mac never exposes another Mac's grant.
