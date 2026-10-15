# Run `nix develop` (or use direnv) first so just, nixfmt and rsvg-convert are on PATH. Swift
# itself comes from Xcode or the Command Line Tools.

set shell := ["bash", "-euo", "pipefail", "-c"]

app_name := "Calendrop"
bundle := "build/" + app_name + ".app"

# The Command Line Tools ship swift-testing outside the default search paths,
# so point the compiler, linker and loader at them. Xcode needs none of this.
clt := "/Library/Developer/CommandLineTools"
clt_dev := clt + "/Library/Developer"
test_flags := if `xcode-select -p` == clt { "-Xswiftc -F -Xswiftc " + clt_dev + "/Frameworks -Xlinker -F -Xlinker " + clt_dev + "/Frameworks -Xlinker -rpath -Xlinker " + clt_dev + "/Frameworks -Xlinker -rpath -Xlinker " + clt_dev + "/usr/lib" } else { "" }

swift_sources := "Package.swift Sources Tests"

# List the recipes.
default:
    @just --list

# Format every source.
fmt:
    swift format --in-place --recursive {{ swift_sources }}
    nix fmt flake.nix

# Check formatting without changing files.
fmt-check:
    swift format lint --strict --recursive {{ swift_sources }}
    nixfmt --check flake.nix

# Build with every warning as an error.
lint:
    swift build -Xswiftc -warnings-as-errors

# Run the tests.
test:
    swift test {{ test_flags }}

# Everything CI runs.
ci: fmt-check lint test

# Assemble build/Calendrop.app (release build, signed; see import-identity).
bundle:
    swift build -c release
    rm -rf {{ bundle }}
    mkdir -p {{ bundle }}/Contents/MacOS {{ bundle }}/Contents/Resources
    cp "$(swift build -c release --show-bin-path)/{{ app_name }}" {{ bundle }}/Contents/MacOS/{{ app_name }}
    cp Resources/Info.plist {{ bundle }}/Contents/Info.plist
    # The app icon Finder and the Dock show. At 32 pixels and below the plate holds
    # the logo drawn for small sizes, which stays legible.
    iconset="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$iconset"; \
    for size in 16 32 128 256 512; do \
      for scale in 1 2; do \
        pixels=$((size * scale)); art=Resources/app-icon.svg; \
        if (( pixels <= 32 )); then art=Resources/app-icon-small.svg; fi; \
        name="icon_${size}x${size}"; if (( scale == 2 )); then name="$name@2x"; fi; \
        rsvg-convert -w "$pixels" -h "$pixels" -o "$iconset/$name.png" "$art"; \
      done; \
    done; \
    iconutil -c icns -o {{ bundle }}/Contents/Resources/AppIcon.icns "$iconset"; \
    rm -rf "$(dirname "$iconset")"
    # The menu bar icon: the logo's small symbol, a template image macOS tints.
    rsvg-convert -w 16 -h 16 -o {{ bundle }}/Contents/Resources/MenuBarIcon.png Resources/logo/calendrop-icon-small-mono-black.svg
    rsvg-convert -w 32 -h 32 -o {{ bundle }}/Contents/Resources/MenuBarIcon@2x.png Resources/logo/calendrop-icon-small-mono-black.svg
    # The Google OAuth client comes from the environment so it never lands in the
    # repository. Without it the app offers sample accounts instead of Google sign-in.
    if [[ -n "${CALENDROP_GOOGLE_CLIENT_ID:-}" && -n "${CALENDROP_GOOGLE_CLIENT_SECRET:-}" ]]; then \
      plutil -insert CalendropGoogleClientID -string "$CALENDROP_GOOGLE_CLIENT_ID" {{ bundle }}/Contents/Info.plist; \
      plutil -insert CalendropGoogleClientSecret -string "$CALENDROP_GOOGLE_CLIENT_SECRET" {{ bundle }}/Contents/Info.plist; \
    else \
      echo "warning: CALENDROP_GOOGLE_CLIENT_ID / CALENDROP_GOOGLE_CLIENT_SECRET not set; this build offers sample accounts instead of Google sign-in" >&2; \
    fi
    # Signed by the "Calendrop Release" identity when the keychain has it, so every
    # build has the same signing requirement (just import-identity).
    if security find-certificate -c "Calendrop Release" >/dev/null 2>&1; then \
      codesign --force --sign "Calendrop Release" {{ bundle }}; \
    else \
      echo "warning: no \"Calendrop Release\" in the keychain; signing ad-hoc (see just import-identity)" >&2; \
      codesign --force --sign - {{ bundle }}; \
    fi

# Build the bundle and launch it.
run: bundle
    open {{ bundle }}

# Make the self-signed identity every build is signed with, into a new folder.
release-identity folder:
    scripts/release-identity.sh {{ folder }}

# Import that identity, given as CALENDROP_SIGNING_P12 and CALENDROP_SIGNING_PASSWORD, into the login keychain.
import-identity:
    scripts/import-identity.sh

# Copy the bundle into /Applications.
install: bundle
    rm -rf /Applications/{{ app_name }}.app
    cp -R {{ bundle }} /Applications/{{ app_name }}.app
