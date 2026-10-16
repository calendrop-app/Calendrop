# Read past tomorrow only when nothing is left before it

Status: Accepted

## Context

Calendrop reads today's and tomorrow's meetings every few minutes. When none
is left, the menu has no meeting to show, and the user cannot tell an empty
calendar from one that failed to be read. A meeting further ahead would show
that the calendars are being read.

## Decision

Calendrop reads further ahead only in a refresh that finds nothing left today
or tomorrow, and only to show the first meeting it finds there.

## Alternatives considered

- Always read further ahead. Every refresh would fetch two weeks of events for
  every calendar, although the menu needs them only when the usual window is
  empty.
- Ask each calendar for its single next event. Declined, all-day and cancelled
  events are dropped after fetching, so the first event returned is often not a
  meeting, and the request would have to be repeated until one is.

## Consequences

- A refresh that finds the window empty makes a second request per calendar.
- Meetings read this way never cut in; they come into the usual window before
  they could.
