#!/usr/bin/env bash
# Builds the web version and publishes it to Cloudflare (see README.md).
#   tools/web/deploy.sh remote   export, upload the big files to R2, publish Pages
#   tools/web/deploy.sh local    same, into the local simulator (then: tools/web/serve_local.sh)
# Add --no-export to reuse the last build in build/web.
# GODOT=/path/to/godot_console overrides the engine path.
set -euo pipefail

MODE="${1:-}"
[[ "$MODE" == "remote" || "$MODE" == "local" ]] || { echo "usage: $0 remote|local [--no-export]"; exit 2; }
EXPORT=1
[[ "${2:-}" == "--no-export" ]] && EXPORT=0

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$ROOT/tools/web"
GODOT="${GODOT:-/d/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
# Wrangler 3 runs on Node 20 (wrangler 4 needs Node 22); pinned so deploys behave the same.
WRANGLER=(npx --yes wrangler@3.114.17)
BUCKET="gully-fight-game"
PROJECT="gully-fight"
WEB="$ROOT/build/web"
SITE="$ROOT/build/site"
LOCAL_FLAG=()
[[ "$MODE" == "local" ]] && LOCAL_FLAG=(--local)

if [[ $EXPORT == 1 ]]; then
	echo "== Exporting the web build"
	rm -rf "$WEB" && mkdir -p "$WEB"
	touch "$ROOT/build/.gdignore"  # keep Godot from importing its own output
	"$GODOT" --headless --path "$ROOT" --export-release "Web" "$WEB/index.html" 2>&1 | grep -iE "error" || true
fi
[[ -f "$WEB/index.pck" && -f "$WEB/index.wasm" ]] || { echo "no build in $WEB"; exit 1; }

echo "== Staging the small files for Pages"
rm -rf "$SITE" && mkdir -p "$SITE"
for f in "$WEB"/*; do
	case "$(basename "$f")" in
		index.pck|index.wasm|*.import) ;;
		*) cp "$f" "$SITE/" ;;
	esac
done
# Only the two big files go through the function; everything else is static.
printf '{"version":1,"include":["/index.pck","/index.wasm"],"exclude":[]}\n' > "$SITE/_routes.json"
gzip -9 -c "$WEB/index.wasm" > "$ROOT/build/index.wasm.gz"

cd "$KIT"
if [[ "$MODE" == "remote" ]]; then
	echo "== Making sure the bucket and the Pages project exist"
	"${WRANGLER[@]}" r2 bucket create "$BUCKET" 2>&1 | grep -viE "already exists" || true
	"${WRANGLER[@]}" pages project create "$PROJECT" --production-branch main 2>&1 | grep -viE "already exists" || true
fi

echo "== Uploading the engine and the game data to R2 ($MODE)"
"${WRANGLER[@]}" r2 object put "$BUCKET/index.wasm" "${LOCAL_FLAG[@]}" --file "$ROOT/build/index.wasm.gz" \
	--content-type application/wasm --content-encoding gzip
"${WRANGLER[@]}" r2 object put "$BUCKET/index.pck" "${LOCAL_FLAG[@]}" --file "$WEB/index.pck" \
	--content-type application/octet-stream

if [[ "$MODE" == "remote" ]]; then
	echo "== Publishing the page"
	"${WRANGLER[@]}" pages deploy --project-name "$PROJECT" --branch main --commit-dirty=true
else
	echo "== Local data ready: run tools/web/serve_local.sh and open http://127.0.0.1:8788"
fi
