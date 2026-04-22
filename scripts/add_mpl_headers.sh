#!/usr/bin/env bash
# Prepend the MPL-2.0 boilerplate to every tracked Swift source file that
# does not already carry the notice. Idempotent.
set -euo pipefail

cd "$(dirname "$0")/.."

HEADER='// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

'

added=0
skipped=0
while IFS= read -r -d '' file; do
    if head -n 5 "$file" | grep -q "Mozilla Public License"; then
        skipped=$((skipped + 1))
        continue
    fi
    tmp="$(mktemp)"
    printf '%s' "$HEADER" > "$tmp"
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
    added=$((added + 1))
done < <(find OpenVibbleApp OpenVibbleAppTests OpenVibbleDesktop OpenVibbleLiveActivity Packages Shared \
    -name "*.swift" -not -path "*/.build/*" -not -path "*/.swiftpm/*" -print0)

echo "Added header to $added file(s); $skipped already had one."
