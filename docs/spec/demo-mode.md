# Demo mode

Launched with `--demo`, Calendrop runs on sample meetings instead of Google
Calendar, so its behaviour can be tried without an account.

- The sample schedule fills the menu — a meeting in progress, one without a
  join link, one on the next day — and never cuts in.
- The cut-in is tried from the appearance settings, as in normal use.
- Join links lead to `example.com`, never to a real meeting.
- Demo mode never contacts Google and never reads or writes the shared
  configuration, the Keychain or the record of acknowledged meetings. Settings
  can be changed for the session and are forgotten on quit.
