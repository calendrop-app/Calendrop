# Cut-in

Calendrop interrupts the user before each meeting by covering every screen.

## When it appears

- A configurable number of minutes before a meeting starts (zero means at the
  start).
- Still within a few minutes after the start, so a Mac that wakes from sleep
  just after a meeting began interrupts too.
- Once per occurrence of a meeting. A meeting the user joined, skipped or
  dismissed — from the cut-in or the menu — does not cut in again, also after a
  relaunch.

Declined events, all-day events and cancelled events never cut in.

## Meetings close together

One cut-in shows every meeting that is due, and every meeting that starts close
to the first one or overlaps it, each with its own countdown and join button,
so a conflict is visible at once instead of as a series of interruptions.

- Joining one meeting also skips the meetings that overlap it: the user has
  chosen.
- A later meeting that does not overlap the joined one cuts in again before it
  starts.
- Meetings that become due while a cut-in is showing join it.

## What it covers

- Every connected display, above full-screen apps, the Dock and the menu bar,
  on every Space.
- When displays are connected, disconnected or change resolution, the cut-in
  is rebuilt to cover exactly the screens that exist now.

## How it looks

The user picks one of the preset styles or a custom one with their own
background, text and button colours and font. Settings preview the style live
and can show it full screen with sample meetings, which never count as real
meetings.

## How it ends

Only by the user:

- **Join** opens the meeting's video link in the default browser, or the event
  page when the meeting has no link. With a single meeting, Return triggers it.
- **Dismiss** is a small control that must be pressed and held. It settles
  every meeting on the cut-in.

Escape and closing shortcuts do nothing. A cut-in that has appeared stays even
after the meeting is well under way.
