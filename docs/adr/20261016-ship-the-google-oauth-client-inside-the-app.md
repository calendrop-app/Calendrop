# Ship the Google OAuth client inside the app

Status: Accepted; supersedes who provides the OAuth client in
`20261016-read-google-calendar-through-its-api.md`

## Context

Reading Google Calendar requires an OAuth client to identify the app on
Google's consent screen. Asking each user to create one in Google Cloud Console
and paste its ID and secret puts sign-in out of reach of anyone but a
developer.

## Decision

The maintainer's OAuth client of type "Desktop app" is embedded in the app
when it is built. Users only sign in through the browser.

## Alternatives considered

- Let each user bring their own client. It keeps the maintainer out of the
  picture, but almost no user can complete the setup.
- Read calendars through EventKit and need no client at all. Rejected for the
  reasons in `20261016-read-google-calendar-through-its-api.md`.

## Consequences

- The client's ID and secret can be extracted from the app. Google treats a
  Desktop client's secret as non-confidential; each grant is protected by the
  loopback redirect, PKCE and the user's consent, not by the secret.
- A build made without the client cannot add Google accounts.
- How many people may sign in, and whether Google shows an unverified-app
  warning, depends on the publishing and verification status of the
  maintainer's client.
