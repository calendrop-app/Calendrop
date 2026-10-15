# Calendrop

A macOS menu bar app that shows your next Google Calendar meeting and, shortly
before it starts, **cuts in**: it covers every screen until you join the meeting
or deliberately dismiss it.

## How it is built

- **Test first.** Red → green → refactor. Write the failing test before the
  code that makes it pass.
- **Each layer holds one thing.** Put a fact in the one layer that owns it,
  and nowhere else.

  | Layer | Holds |
  | --- | --- |
  | `docs/concept.md` | what this is and for whom |
  | `docs/adr/` | one decision and why it was made |
  | `docs/spec/` | the behaviour users and other components can rely on |
  | Tests | the details that pin the behaviour down: rules, boundaries, tables |
  | Code | how it is done |
  | Commits | why a change was made |
  | Comments | why it is not done another way |

  Before writing, fixing or reviewing a record, read `docs/adr/README.md`;
  before writing, fixing or reviewing a spec, read `docs/spec/README.md`.
  Follow their writing order.
- **Logic goes in `CalendropCore`.** Anything that can be decided without AppKit,
  the network or the Keychain — parsing, scheduling, OAuth requests, the
  shared config — lives in `CalendropCore` and is tested there. The `Calendrop` target
  only wires it to the system.
- **Swift comes from Apple.** The Nix dev shell provides `just`, `nixfmt` and
  `rsvg-convert` only; `swift` is Xcode's or the Command Line Tools'. AppKit and SwiftUI do
  not build with the Swift toolchain in nixpkgs.
- **Dependencies are current.** Before adding or bumping one, look up its
  latest release in the registry. Do not copy a version from memory or from
  another repository.

## Quality gate

Run `just ci` before reporting a change as done. CI runs the same recipe.

## Layout

| Path | What lives there |
| --- | --- |
| `Sources/CalendropCore/` | platform-independent logic: models, parsing, scheduling, OAuth, shared config |
| `Sources/Calendrop/` | the AppKit/SwiftUI app: menu bar, cut-in windows, settings, Keychain, network |
| `Tests/CalendropCoreTests/` | tests for `CalendropCore` (swift-testing) |
| `Resources/` | the app bundle's `Info.plist`, the app icon, and in `logo/` the logo SVGs copied from [calendrop-brand](https://github.com/calendrop-app/calendrop-brand) |
| `scripts/` | the self-signed code signing identity: making it and importing it into the keychain |
| `docs/` | concept, ADRs, specs, references |

## Language

- README, docs and commit messages: English
- Code comments, log and error messages: English

## Commits

Scoped Commits:

```
<scope>: <description>

<why this change is needed>
```

- The scope names where the change is, from the table below. Several scopes
  are joined with `, `; a change across the whole tree uses `treewide`.
- The description starts in lower case, has no trailing period, and stays
  within 72 characters.
- The body explains why. The code shows how; the tests show what.
- A release commit is `release: vX.Y.Z`.
- A breaking change says so in the body and carries a `BREAKING CHANGE:`
  trailer.

| Scope | Covers |
| --- | --- |
| `core` | `Sources/CalendropCore/`, `Tests/CalendropCoreTests/` |
| `app` | `Sources/Calendrop/`, `Resources/` |
| `build` | `Package.swift`, `justfile`, `.swift-format`, `scripts/` |
| `docs` | `README.md`, `docs/concept.md` |
| `adr` | `docs/adr/` |
| `spec` | `docs/spec/` |
| `ci` | `.github/` |
| `nix` | `flake.nix`, `flake.lock` |
| `deps` | dependency updates |

Add a row when a new area appears.
