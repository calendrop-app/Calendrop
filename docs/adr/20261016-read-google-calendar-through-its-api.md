# Read Google Calendar through its API

Status: Accepted; who provides the OAuth client is superseded by
`20261016-ship-the-google-oauth-client-inside-the-app.md`

## Context

Calendrop has to know every meeting of several Google accounts and the link that
joins each one. macOS can already mirror Google calendars into its own
Calendar store, which apps read through EventKit without signing in to
anything.

## Decision

Calendrop signs in to each Google account itself and reads events from the Google
Calendar API.

## Alternatives considered

- Read the macOS Calendar store through EventKit. It needs no OAuth client and
  no sign-in, but it syncs on its own schedule, so a meeting added minutes
  before it starts may never cut in, and it drops Google's conference data,
  leaving the join link to be guessed from free text.

## Consequences

- The user creates an OAuth client in Google Cloud Console once.
- Each account is signed in to through the browser.
- Join links come from Google's own conference fields first.
