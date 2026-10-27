#!/usr/bin/env bash
# Runs every headless test. Usage: GODOT=/path/to/godot tests/run_all.sh
# Each test is time-limited so a hang fails instead of blocking.
# Progress goes to the terminal and to tests/last_run.log, one line per
# suite as it finishes ("[3/19] music  PASS  14s  (3 passed, 0 failed)"),
# so a run can be followed with: tail -f tests/last_run.log
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="tests/last_run.log"
: > "$LOG"
say() { echo "$1" | tee -a "$LOG"; }
SUITES=(core knockdown jump music announcer input controls stun bangla flow match ai_finisher finisher_contact
	double_kick ai_defense movement styles training rounds)
total=${#SUITES[@]}
failed=0
passed_n=0
failed_n=0
start=$(date +%s)
say "Running $total test suites (headless, started $(date +%H:%M:%S))"
# Parse/import check first: any script error fails the run.
import_errors=$("$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Failed to load")
if [ -n "$import_errors" ]; then
	echo "$import_errors" | sed 's/^/      /' | tee -a "$LOG"
	say "[import] FAIL"
	failed=1
else
	say "[import] ok"
fi
i=0
for t in "${SUITES[@]}"; do
	i=$((i + 1))
	t0=$(date +%s)
	limit=300
	[ "$t" = "finisher_contact" ] && limit=900  # every style finisher x every case
	out=$(timeout $limit "$GODOT" --headless --path . -s "tests/test_$t.gd" 2>&1)
	code=$?
	result=$(echo "$out" | grep -E "^RESULT" | tail -1)
	if [ $code -ne 0 ] || [ -z "$result" ] || echo "$result" | grep -q FAIL; then
		failed=1
		failed_n=$((failed_n + 1))
		status="FAIL"
	else
		passed_n=$((passed_n + 1))
		status="PASS"
	fi
	say "$(printf '[%d/%d] %-16s %s  %3ds  (%d passed, %d failed)' $i $total "$t" "$status" $(( $(date +%s) - t0 )) $passed_n $failed_n)"
	if [ "$status" = "FAIL" ]; then
		echo "$out" | grep -E "FAIL|SCRIPT ERROR|Parse Error" | head -20 | sed 's/^/      /' | tee -a "$LOG"
		[ $code -eq 124 ] && say "      (timed out after $limit s)"
	fi
done
mins=$(( ($(date +%s) - start) / 60 ))
secs=$(( ($(date +%s) - start) % 60 ))
if [ $failed -eq 0 ]; then
	say "ALL TESTS PASSED  ($passed_n/$total in ${mins}m ${secs}s)"
else
	say "SOME TESTS FAILED  ($failed_n of $total failed, ${mins}m ${secs}s)"
fi
exit $failed
