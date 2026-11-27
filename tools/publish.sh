#!/bin/sh
# Rebuild the bundle from committed+staged question files only, stage it, and verify nothing unfinished slipped in
# (other agents may be rebuilding the shared bundle at the same moment). Usage: sh tools/publish.sh
cd "$(dirname "$0")/.."
for i in 1 2 3 4 5 6; do
  TRACKED_ONLY=1 node tools/build.js >/dev/null && git add data/questions.bundle.js data/families.js index.html
  bad=$(git show :data/questions.bundle.js | grep '^// ---- ' | sed 's/.*---- //' | while read f; do git ls-files --error-unmatch "data/questions/$f" >/dev/null 2>&1 || echo "$f"; done | wc -l)
  [ "$bad" -eq 0 ] && { echo "bundle clean"; exit 0; }
  sleep 1
done
echo "could not get a clean bundle"; exit 1
