# Concept

This document describes what Calendrop is for and the ideas every design decision
rests on. It is rewritten in place as the concept evolves; decisions built on
it are recorded as ADRs.

## What it is

A macOS menu bar app that keeps the next meeting in sight and, shortly before
it starts, takes over every screen until the user either joins it or
deliberately chooses not to.

## Who it is for

People whose day is split across several Google accounts — a company account,
a client's, a personal one — who sink into focused work and miss the start of
meetings because a notification banner is too easy to ignore.

## Principles

- **Interrupt for real.** A reminder that can be dismissed by reflex is not a
  reminder. The cut-in covers everything, on every display, and ending it
  without joining takes intent.
- **Joining is the easy path.** The largest target on the cut-in is the one
  that opens the meeting.
- **Every account, one timeline.** Meetings from all accounts merge into one
  list; the same event seen through two accounts is one meeting.
- **Follow the desk as it changes.** Docking, undocking and switching
  resolution never leave a screen uncovered.
- **Credentials stay where they were granted.** Settings follow the user
  between Macs; sign-in tokens never leave the Mac that obtained them.

## What it does not do

- Edit, create or respond to calendar events. Calendrop only reads.
- Read calendars other than Google Calendar.
- Run on anything but macOS.
- Notify through Notification Center; the cut-in replaces that.
