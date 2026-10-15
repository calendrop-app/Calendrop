#!/usr/bin/env bash
# Make the self-signed identity every build of Calendrop is signed with, as
# CALENDROP_SIGNING_P12 (identity.p12 in base64) and CALENDROP_SIGNING_PASSWORD, so
# that every build has the same signing requirement. It does not keep Keychain
# access across builds: without an Apple team ID, macOS ties "Always Allow" to
# the build itself. Run once; keep both values where import-identity.sh can be
# given them on each Mac.
#
#   release-identity.sh <folder to create>
set -euo pipefail

out="$1"
"$(dirname "$0")/make-identity.sh" "Calendrop Release" "$out"
/usr/bin/base64 -i "$out/identity.p12" >"$out/identity.p12.base64"
cat <<EOF
Keep these somewhere safe, then delete $out:
  CALENDROP_SIGNING_P12       the content of $out/identity.p12.base64
  CALENDROP_SIGNING_PASSWORD  the content of $out/password
EOF
