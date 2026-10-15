# Demo mode

Launched with `--demo`, Calendrop runs on sample meetings instead of Google
Calendar, so its behaviour can be tried without an account.

- The sample schedule fills the menu — a meeting in progress, one without a
  join link, one on the next day — and never cuts in by itself.
- Cut-ins appear when the user picks a scenario from the menu: a single
  meeting, meetings at the same time, or meetings close together. A scenario
  is due at once and then behaves as real meetings do, including a later
  meeting cutting in again after the first is joined. Picking a scenario again
  starts it over.
- Join links lead to `example.com`, never to a real meeting.
- Demo mode never contacts Google and never reads or writes the shared
  configuration, the Keychain or the record of acknowledged meetings. Settings
  can be changed for the session and are forgotten on quit.
