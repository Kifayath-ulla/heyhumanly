#!/usr/bin/env bash
# Deploys heyhumanly.com. Refuses to deploy if the site would link to a release that isn't published.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-versions.py
python3 scripts/check-release-links.py
python3 scripts/build-site.py
git diff --quiet -- site || { echo "site/ changed after rebuilding; commit it first."; exit 1; }
npx wrangler deploy -c wrangler.prod.jsonc
