# Read the days the menu calendar shows only while it shows them

Status: Accepted

## Context

The menu can show a month or a week. Calendrop's regular refresh reads only
today and tomorrow, every few minutes, because cut-ins need nothing further
(20261016-read-past-tomorrow-only-when-nothing-is-left-before-it.md). A month
shown in the menu covers up to six weeks, and the user can page to any other.

## Decision

Calendrop reads the days the menu calendar shows when the menu opens or is
paged, and keeps them apart from the regular refresh, which still reads today
and tomorrow alone and still decides every cut-in.

## Alternatives considered

- Widen the regular refresh to the shown month. Every refresh would fetch six
  weeks of events for every calendar, although the menu is open for a few
  seconds at a time, and paging to another month would still need a read of
  its own.
- Keep what was read for each period between openings. A meeting added or
  moved since would show stale until the cache was dropped, and deciding when
  to drop it costs more than reading again.

## Consequences

- Opening the menu with the calendar shown makes one request per calendar, and
  so does each page.
- A day past tomorrow is unknown, not empty, until its read finishes or fails.
- Today and tomorrow come from the regular refresh, so the calendar and the
  cut-ins never disagree about them.
