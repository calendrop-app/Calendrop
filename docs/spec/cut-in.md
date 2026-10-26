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

Declined events, all-day events and cancelled events never cut in. Meetings
without a video link, such as in-person ones, cut in only when the user turned
that on in settings. Meetings the user answered "maybe" to or has not answered
cut in unless the user turned that off, and are marked as such on the cut-in
and in the menu. An event seen through several accounts counts as accepted
when any of them accepted it.

## Meetings close together

One cut-in shows every meeting that is due, and every meeting that starts close
to the first one or overlaps it, each with its own countdown and join button,
so a conflict is visible at once instead of as a series of interruptions.

- Joining one meeting also skips the meetings that overlap it: the user has
  chosen.
- A later meeting that does not overlap the joined one cuts in again before it
  starts.
- Meetings that become due while a cut-in is showing join it.

## During a call

While any app uses the microphone or the camera, the user counts as in a call,
and a cut-in that comes due then takes the form chosen in settings:

- full screen, as at any other time;
- compact: a card on every screen, at the top centre unless the user picked
  another edge or corner, clear of the menu bar and the Dock, with the same join buttons
  and the same press-and-hold to dismiss, that never takes the keyboard from
  the call;
- not shown at all.

When the call ends, a cut-in held back as a card or not shown covers every
screen if the user turned that on, and otherwise stays as it was. Meetings that
are over by then are dropped rather than shown. A meeting that comes due after
the call always cuts in full screen, and a cut-in already covering the screens
stays so when a call starts.

## What it covers

- Every connected display, above full-screen apps, the Dock and the menu bar,
  on every Space. Compact cards also appear on every display and Space, above
  full-screen apps.
- When displays are connected, disconnected or change resolution, the cut-in
  is rebuilt to cover exactly the screens that exist now.

## How it looks

Each meeting on the cut-in shows its time, its account and calendar, where it
is, who else is invited and the start of its description.

When it appears, the cut-in falls in from the top of the screen, unless the
user turned that off; with Reduce Motion on it fades in instead. The compact
card likewise slides in from the nearer top or bottom edge. Rebuilding either
for a display change does not replay the entrance.

The user picks one of the preset styles or a custom one with their own
background, text and button colours and font. Settings preview the style live
and can show it full screen or as the compact card with sample meetings, which
never count as real
meetings. One trial carries long titles in many scripts, to check how they
wrap and shorten. A real meeting that comes due during a trial replaces it.

## How it ends

Only by the user:

- **Join** opens the meeting's video link in the default browser. A meeting
  without a link offers **OK** instead, which only closes the cut-in. With a
  single meeting, Return triggers either.
- **Dismiss** is a small control that must be pressed and held. It settles
  every meeting on the cut-in. It sits in the corner that stays on screen even
  if a change of resolution went unnoticed, so the cut-in can always be closed.
- **Emergency key**: pressing Control, Option, Command and Escape together
  dismisses a full-screen cut-in the same way, for when the on-screen controls
  cannot be reached.

Escape alone and closing shortcuts do nothing. A cut-in that has appeared stays even
after the meeting is well under way.
