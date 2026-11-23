#!/usr/bin/env bash
# Deploys heyhumanly.com. Refuses to deploy if the site would link to a release that isn't published.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-versions.py
python3 scripts/check-release-links.py
python3 scripts/build-site.py
if ! git diff --quiet HEAD -- site || [ -n "$(git ls-files --others --exclude-standard site)" ]; then
  echo "site/ differs from the committed version after rebuilding; commit it first."; exit 1
fi
npx wrangler deploy -c wrangler.prod.jsonc
