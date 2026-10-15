# Run `nix develop` (or use direnv) first so just and nixfmt are on PATH. Swift
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

# Assemble build/Calendrop.app (release build, ad-hoc signed).
bundle:
    swift build -c release
    rm -rf {{ bundle }}
    mkdir -p {{ bundle }}/Contents/MacOS
    cp "$(swift build -c release --show-bin-path)/{{ app_name }}" {{ bundle }}/Contents/MacOS/{{ app_name }}
    cp Resources/Info.plist {{ bundle }}/Contents/Info.plist
    # The Google OAuth client comes from the environment so it never lands in the
    # repository. Without it the app offers sample accounts instead of Google sign-in.
    if [[ -n "${CALENDROP_GOOGLE_CLIENT_ID:-}" && -n "${CALENDROP_GOOGLE_CLIENT_SECRET:-}" ]]; then \
      plutil -insert CalendropGoogleClientID -string "$CALENDROP_GOOGLE_CLIENT_ID" {{ bundle }}/Contents/Info.plist; \
      plutil -insert CalendropGoogleClientSecret -string "$CALENDROP_GOOGLE_CLIENT_SECRET" {{ bundle }}/Contents/Info.plist; \
    else \
      echo "warning: CALENDROP_GOOGLE_CLIENT_ID / CALENDROP_GOOGLE_CLIENT_SECRET not set; this build offers sample accounts instead of Google sign-in" >&2; \
    fi
    codesign --force --sign - {{ bundle }}

# Build the bundle and launch it.
run: bundle
    open {{ bundle }}

# Copy the bundle into /Applications.
install: bundle
    rm -rf /Applications/{{ app_name }}.app
    cp -R {{ bundle }} /Applications/{{ app_name }}.app
