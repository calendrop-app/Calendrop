# Cut-in

Calendrop interrupts the user before each meeting by covering every screen.

## When it appears

- A configurable number of minutes before a meeting starts (zero means at the
  start).
- Still within a few minutes after the start, so a Mac that wakes from sleep
  just after a meeting began interrupts too.
- Once per occurrence of a meeting. A meeting the user joined or dismissed —
  from the cut-in or the menu — does not cut in again, also after a relaunch.
- Meetings that become due while a cut-in is showing join it.

Declined events, all-day events and cancelled events never cut in.

## What it covers

- Every connected display, above full-screen apps, the Dock and the menu bar,
  on every Space.
- When displays are connected, disconnected or change resolution, the cut-in
  is rebuilt to cover exactly the screens that exist now.

## How it ends

Only by the user:

- **Join** opens the meeting's video link in the default browser, or the event
  page when the meeting has no link. Return triggers it.
- **Dismiss** is a small control that must be pressed and held.

Escape and closing shortcuts do nothing. A cut-in that has appeared stays even
after the meeting is well under way.
