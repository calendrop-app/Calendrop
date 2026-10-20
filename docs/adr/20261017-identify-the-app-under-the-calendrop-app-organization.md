# Identify the app under the calendrop-app organization

Status: Accepted

## Context

The app was identified as `com.lambdalisue.calendrop`, a name in its author's
personal namespace, while the project is owned by the calendrop-app
organization. macOS keys an app's preferences, its Keychain access and its menu
bar permission on that identifier, so changing it later means moving every
user's data along with it. Nobody uses the app yet.

## Decision

The app is identified as `io.github.calendrop-app.calendrop`, in the namespace
of the organization that owns the project. Nothing kept under the former
identifier is carried over.

## Alternatives considered

- Keep `com.lambdalisue.calendrop`. The identifier would keep naming one person
  as the project's owner after the project has moved to the organization.
- Carry the sign-ins and settings over from the former identifier. It keeps code
  for data that no user has.

## Consequences

- Whoever ran an earlier build signs in again and sets the app up again.
