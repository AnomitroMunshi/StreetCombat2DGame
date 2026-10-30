#!/usr/bin/env bash
# Full style census: every style against every other, one Godot process per
# style, all in parallel at low priority, then a win-rate table.
# Usage: GODOT=/path/to/godot tools/balance/run_census.sh [out_dir]
# Environment passed through to census.gd: CENSUS_SEEDS, CENSUS_AI,
# CENSUS_DIFF, CENSUS_RDIFF, CENSUS_RIVALS (see census.gd). STYLES limits the
# measured styles (comma-separated).
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${1:-docs/reviews/balance/latest}"
mkdir -p "$OUT"
STYLES="${STYLES:-boxing,muay_thai,kung_fu,bangla_maar,karate,taekwondo,kickboxing,capoeira,jeet_kune_do}"
if [ -z "${CENSUS_SEEDS:-}" ]; then
	# 96 seeds (24 gave +-10 point swings between seed sets). Starting sides
	# are mirrored and add no information.
	export CENSUS_SEEDS="$(seq -s, 11 13 1246)"
fi
start=$(date +%s)
for st in ${STYLES//,/ }; do
	CENSUS_STYLE="$st" CENSUS_OUT="$OUT/$st.json" nice -n 10 "$GODOT" --headless --path . \
		-s tools/balance/census.gd > "$OUT/$st.log" 2>&1 &
done
wait
echo "census finished in $(( $(date +%s) - start ))s"
python tools/balance/summarize.py "$OUT" | tee "$OUT/summary.md"
