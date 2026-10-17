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

# Swift Build compiles the String Catalogs; SwiftPM's native build system copies a
# catalog as it is, leaving every language but English out. Named here so CI, whose
# toolchain may still default to the native one, builds the same way.
build_system := "--build-system swiftbuild"

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
    swift build {{ build_system }} -Xswiftc -warnings-as-errors

# Run the tests.
test:
    swift test {{ build_system }} {{ test_flags }}

# The String Catalogs, each with the sources whose strings it holds.
catalogs := "Sources/CalendropCore/Localizable.xcstrings=Sources/CalendropCore Resources/Localizable.xcstrings=Sources/Calendrop"

# Where the compiler writes the strings each source file uses, as
# <file>.stringsdata. Its own scratch path keeps the flags below from rebuilding
# the ordinary build.
l10n_build := ".build/l10n"

# Add the strings the source uses to the String Catalogs, and mark those it no longer uses stale.
l10n: _strings
    just _sync-catalogs .

# Fail when a String Catalog lacks a string the source uses or holds one it no longer uses.
l10n-check: _strings
    copy="$(mktemp -d)"; \
    for entry in {{ catalogs }}; do mkdir -p "$copy/$(dirname "${entry%%=*}")"; cp "${entry%%=*}" "$copy/${entry%%=*}"; done; \
    just _sync-catalogs "$copy"; \
    for entry in {{ catalogs }}; do \
      if ! cmp -s "${entry%%=*}" "$copy/${entry%%=*}"; then \
        echo "error: ${entry%%=*} is out of step with the source; run just l10n" >&2; exit 1; \
      fi; \
    done

# The native build system, deprecated as it is, because it writes where it is told:
# Swift Build passes its own path to the compiler instead, and that path differs
# between Xcode releases.
_strings:
    swift build --build-system native --scratch-path {{ l10n_build }} -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$PWD/{{ l10n_build }}/strings"

# Every target writes into one folder, so the files are told apart by the source
# file they come from; a file left by a deleted source is never read.
_sync-catalogs root:
    for entry in {{ catalogs }}; do \
      data=(); \
      while IFS= read -r source; do \
        file="{{ l10n_build }}/strings/$(basename "${source%.swift}").stringsdata"; \
        if [[ -f "$file" ]]; then data+=("$file"); fi; \
      done < <(find "${entry#*=}" -name '*.swift'); \
      if (( ${#data[@]} == 0 )); then echo "error: the compiler wrote no strings for ${entry#*=}" >&2; exit 1; fi; \
      xcrun xcstringstool sync "{{ root }}/${entry%%=*}" --stringsdata "${data[@]}"; \
    done

# Everything CI runs.
ci: fmt-check lint l10n-check test

# Assemble build/Calendrop.app (release build, signed; see import-identity).
bundle:
    swift build {{ build_system }} -c release
    rm -rf {{ bundle }}
    mkdir -p {{ bundle }}/Contents/MacOS {{ bundle }}/Contents/Resources
    cp "$(swift build {{ build_system }} -c release --show-bin-path)/{{ app_name }}" {{ bundle }}/Contents/MacOS/{{ app_name }}
    cp Resources/Info.plist {{ bundle }}/Contents/Info.plist
    # The interface's translations: the app's String Catalog compiled into the
    # bundle's own .lproj folders, and CalendropCore's resource bundle, where its
    # Bundle.module looks. Only Xcode compiles a catalog; the Command Line Tools copy
    # it as it is, which would leave every language but English out.
    xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory {{ bundle }}/Contents/Resources
    core="$(swift build {{ build_system }} -c release --show-bin-path)/Calendrop_CalendropCore.bundle"; \
    if [[ -z "$(find "$core" -name ja.lproj)" ]]; then \
      echo "error: $core holds no compiled translations; build with Xcode's toolchain (xcode-select)" >&2; exit 1; \
    fi; \
    cp -R "$core" {{ bundle }}/Contents/Resources/
    # The version comes from the release tag, given as CALENDROP_VERSION, so it
    # is never kept by hand; without it the bundle keeps Info.plist's 0.0.0.
    if [[ -n "${CALENDROP_VERSION:-}" ]]; then \
      plutil -replace CFBundleShortVersionString -string "$CALENDROP_VERSION" {{ bundle }}/Contents/Info.plist; \
      plutil -replace CFBundleVersion -string "$CALENDROP_VERSION" {{ bundle }}/Contents/Info.plist; \
    fi
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
    # CalendropCore's resource bundle is signed first, as a bundle inside the app.
    identity=-; \
    if security find-certificate -c "Calendrop Release" >/dev/null 2>&1; then \
      identity="Calendrop Release"; \
    else \
      echo "warning: no \"Calendrop Release\" in the keychain; signing ad-hoc (see just import-identity)" >&2; \
    fi; \
    codesign --force --sign "$identity" {{ bundle }}/Contents/Resources/Calendrop_CalendropCore.bundle; \
    codesign --force --sign "$identity" {{ bundle }}

# Zip the bundle into build/package for a release. ditto keeps the signature
# intact; the name says the CPU, as a zip does not.
package: bundle
    mkdir -p build/package
    version="$(plutil -extract CFBundleShortVersionString raw {{ bundle }}/Contents/Info.plist)"; \
    ditto -c -k --keepParent {{ bundle }} "build/package/{{ app_name }}-$version-macos-$(uname -m).zip"

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
