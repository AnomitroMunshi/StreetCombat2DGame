#!/usr/bin/env bash
# Runs every headless test. Usage: GODOT=/path/to/godot tests/run_all.sh
# Each test is time-limited so a hang fails instead of blocking.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
failed=0
# Parse/import check first: any script error fails the run.
if "$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Failed to load" ; then
	echo "=== import: FAIL"
	failed=1
else
	echo "=== import: ok"
fi
for t in core input controls stun bangla flow match ai_finisher finisher_contact double_kick ai_defense movement styles training; do
	out=$(timeout 300 "$GODOT" --headless --path . -s "tests/test_$t.gd" 2>&1)
	code=$?
	echo "$out" | grep -E "FAIL|SCRIPT ERROR|Parse Error" | head -20
	result=$(echo "$out" | grep -E "^RESULT" | tail -1)
	echo "=== $t: exit $code ${result}"
	if [ $code -ne 0 ] || [ -z "$result" ] || echo "$result" | grep -q FAIL; then
		failed=1
	fi
done
if [ $failed -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit $failed
