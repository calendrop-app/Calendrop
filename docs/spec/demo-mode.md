# Demo mode

Launched with `--demo`, Calendrop runs on a schedule of sample meetings instead of
Google Calendar, so its behaviour can be tried without an OAuth client or an
account.

- The sample schedule is laid out relative to launch: the first cut-in appears
  within a minute, and a meeting from a second account joins it shortly after.
  The menu shows a meeting in progress, one without a join link and one on the
  next day.
- The schedule can be restarted from the menu to watch the cut-ins again.
- Join links lead to `example.com`, never to a real meeting.
- Demo mode never contacts Google and never reads or writes the shared
  configuration, the Keychain or the record of acknowledged meetings. Settings
  can be changed for the session and are forgotten on quit.
