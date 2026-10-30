#!/usr/bin/env bash
# Runs every headless test. Usage: GODOT=/path/to/godot tests/run_all.sh
# Suites are independent Godot processes, so they run in parallel: JOBS at a
# time (default 8, or JOBS=1 for one after another), at low CPU priority so the
# machine stays responsive. The long finisher-contact suite is split by style
# (ONLY_STYLE) into shards that run in parallel too. Each suite is
# time-limited so a hang fails instead of blocking.
# Progress goes to the terminal and to tests/last_run.log, one line per suite
# as it finishes ("[3/39] music  PASS  14s  (3 passed, 0 failed)"), so a run
# can be followed with: tail -f tests/last_run.log
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
JOBS="${JOBS:-8}"
LOG="tests/last_run.log"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT
: > "$LOG"
say() { echo "$1" | tee -a "$LOG"; }

SUITES=(core knockdown jump music announcer input controls stun bangla flow match ai_finisher
	double_kick x_moves x_ui_ai x_impact x_flinch ai_defense movement styles new_styles agile_styles capoeira_ai
	style_expansion expansion_visuals training rounds guard ai_signature stage difficulty settings)
# finisher_contact, one shard per style (the slowest suite by far).
CONTACT_STYLES=(boxing taekwondo muay_thai karate kung_fu kickboxing capoeira jeet_kune_do bangla_maar)
for st in "${CONTACT_STYLES[@]}"; do
	SUITES+=("finisher_contact:$st")
done
total=${#SUITES[@]}
start=$(date +%s)
say "Running $total test suites (headless, $JOBS in parallel, started $(date +%H:%M:%S))"

# Parse/import check first, alone: any script error fails the run.
import_errors=$(nice -n 10 "$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Failed to load")
failed=0
if [ -n "$import_errors" ]; then
	echo "$import_errors" | sed 's/^/      /' | tee -a "$LOG"
	say "[import] FAIL"
	failed=1
else
	say "[import] ok"
fi

# One suite: runs it and records "<exit code> <seconds>" next to its output.
run_suite() {
	local id="$1" name="${1%%:*}" shard="" limit=300 t0
	[[ "$1" == *:* ]] && shard="${1#*:}"
	[ "$name" = "finisher_contact" ] && limit=600
	t0=$(date +%s)
	# Fixed 60 FPS: unthrottled headless frames draw at random rates, and
	# drawn-pose contact checks then depend on where the last frame landed.
	ONLY_STYLE="$shard" timeout $limit nice -n 10 "$GODOT" --headless --path . --fixed-fps 60 \
		-s "tests/test_$name.gd" > "$OUT_DIR/${id//:/_}.out" 2>&1
	echo "$? $(( $(date +%s) - t0 ))" > "$OUT_DIR/${id//:/_}.done"
}

passed_n=0
failed_n=0
reported=0
declare -A shown=()
report_finished() {
	local id key code secs result status
	for id in "${SUITES[@]}"; do
		key="${id//:/_}"
		[ -n "${shown[$key]:-}" ] && continue
		[ -f "$OUT_DIR/$key.done" ] || continue
		shown[$key]=1
		read -r code secs < "$OUT_DIR/$key.done"
		result=$(grep -E "^RESULT" "$OUT_DIR/$key.out" | tail -1)
		if [ "$code" -ne 0 ] || [ -z "$result" ] || echo "$result" | grep -q FAIL; then
			failed=1
			failed_n=$((failed_n + 1))
			status="FAIL"
		else
			passed_n=$((passed_n + 1))
			status="PASS"
		fi
		reported=$((reported + 1))
		say "$(printf '[%d/%d] %-30s %s  %3ds  (%d passed, %d failed)' $reported $total "$id" "$status" "$secs" $passed_n $failed_n)"
		if [ "$status" = "FAIL" ]; then
			grep -E "FAIL|SCRIPT ERROR|Parse Error" "$OUT_DIR/$key.out" | head -20 | sed 's/^/      /' | tee -a "$LOG"
			[ "$code" -eq 124 ] && say "      (timed out)"
		fi
	done
}

# Longest first, so the contact shards never end up running last on their own.
ORDER=()
for id in "${SUITES[@]}"; do [[ "$id" == finisher_contact:* ]] && ORDER+=("$id"); done
for id in "${SUITES[@]}"; do [[ "$id" != finisher_contact:* ]] && ORDER+=("$id"); done
for id in "${ORDER[@]}"; do
	while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do
		sleep 0.5
		report_finished
	done
	run_suite "$id" &
done
while [ "$(jobs -rp | wc -l)" -gt 0 ]; do
	sleep 0.5
	report_finished
done
wait
report_finished

mins=$(( ($(date +%s) - start) / 60 ))
secs=$(( ($(date +%s) - start) % 60 ))
if [ $failed -eq 0 ]; then
	say "ALL TESTS PASSED  ($passed_n/$total in ${mins}m ${secs}s)"
else
	say "SOME TESTS FAILED  ($failed_n of $total failed, ${mins}m ${secs}s)"
fi
exit $failed
