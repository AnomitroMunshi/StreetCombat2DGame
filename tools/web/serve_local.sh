#!/usr/bin/env bash
# Runs the site in Cloudflare's local simulator (Pages + the R2 function) at
# http://127.0.0.1:8788, after tools/web/deploy.sh local.
set -euo pipefail
cd "$(dirname "$0")"
exec npx --yes wrangler@3.114.17 pages dev --ip 127.0.0.1 --port 8788
