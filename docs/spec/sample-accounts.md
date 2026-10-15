# Sample accounts

A build made without the Google OAuth client cannot sign in to Google. Instead
of leaving accounts unusable, it offers sample accounts, so everything else can
be tried.

- It starts with two labelled sample accounts already set up, and **Add
  Account** skips the browser and adds more. Each has a main calendar and
  others to opt into, and sample meetings, among them one in progress, one
  without a video link, one answered "maybe", one not answered and one on the
  next day.
- Sample accounts behave as real ones do: labels, colours, calendar choice,
  removal, the menu and the cut-in all work on them.
- Join links lead to `example.com`, never to a real meeting.
- The build never contacts Google and saves nothing: its accounts and any
  settings changed are forgotten when Calendrop quits, and the configuration shared
  through iCloud Drive is never read or written.
- The menu and settings say that the accounts are samples and why.
