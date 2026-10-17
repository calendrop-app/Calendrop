# Translate the interface with String Catalogs

Status: Accepted

## Context

Calendrop's interface is to be offered in English and Japanese, with more
languages possible later. Calendrop is built with SwiftPM, not an Xcode project,
and its logic and its tests live in `CalendropCore`, apart from the app.

## Decision

The interface's words are written in English in the source and translated in
String Catalogs (`.xcstrings`): one for the app, one for `CalendropCore`. The
catalogs are kept in step with the source from the strings the compiler reports,
and macOS picks the language as it does for any app.

## Alternatives considered

- Every translation written beside the English where it is used. A missing
  translation fails to compile, but adding a language means changing every
  message in the source.
- One key-value file per language read by Calendrop's own code, as Arto does with
  rust-i18n. It reinvents what macOS already does for an app bundle: choosing the
  language, plural rules, and the per-app language in System Settings.

## Consequences

- Adding a language adds translations to the catalogs; the code stays as it is.
- Building with translations needs Xcode: the Command Line Tools and SwiftPM's
  native build system copy a catalog without compiling it.
- A string the source uses but a catalog lacks shows in English, so the quality
  gate checks that the catalogs match the source and are fully translated.
