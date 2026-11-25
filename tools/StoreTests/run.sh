#!/bin/bash
# Saved-data upgrade tests (Mac only: SwiftData). For each saved-data version ever shipped,
# writes a store as that version of the app did (old/vN/Models.swift, frozen), then opens it
# with the current app's code and checks every kind of progress survived.
#     tools/StoreTests/run.sh            (from the repository root)
# Exit 0 when all pass. See the steps in Georgian/Data/Models.swift for adding a version.
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
target="$(uname -m)-apple-macos14"

xcrun swiftc -target "$target" -o "$work/check-new" \
    Georgian/Data/Models.swift Georgian/Data/ProgressStore.swift \
    Georgian/Curriculum/*.swift Georgian/Engine/*.swift tools/StoreTests/CheckNew/main.swift

status=0
for v in v1 v2; do
    flag=$(echo "$v" | tr a-z A-Z)
    xcrun swiftc -target "$target" -D "$flag" -o "$work/write-$v" \
        "tools/StoreTests/old/$v/Models.swift" tools/StoreTests/old/stubs.swift tools/StoreTests/WriteOld/main.swift
    mkdir -p "$work/$v"
    "$work/write-$v" "$work/$v/Georgian.store" || { status=1; continue; }
    "$work/check-new" "$work/$v/Georgian.store" "$v" || status=1
done
exit $status
