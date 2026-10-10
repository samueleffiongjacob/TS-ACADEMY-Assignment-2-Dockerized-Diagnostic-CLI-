#!/usr/bin/env bash
# =============================================================================
# test.sh - Tests for the diagnostic-tool Docker image.
#
# Builds the image, runs the CLI in containers and checks exit codes and output.
# Usage: ./test.sh          (requires Docker)
# Exit : 0 = all tests passed, 1 = at least one failed, 2 = Docker missing
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="diagnostic-tool-test"
PASSED=0
FAILED=0

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is required to run these tests." >&2
    exit 2
fi

# Remove the test image when the script ends, however it ends.
cleanup() { docker image rm "$IMAGE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# run_test NAME EXPECTED_EXIT_CODE EXPECTED_TEXT COMMAND...
#   EXPECTED_TEXT is matched case-insensitively; pass "" to skip the text check.
run_test() {
    local name="$1" want_rc="$2" want_text="$3" out rc
    shift 3
    out="$("$@" 2>&1)"
    rc=$?

    if [[ $rc -ne $want_rc ]]; then
        echo "FAIL: $name (exit code $rc, expected $want_rc)"
        echo "      output: $out" | head -5
        FAILED=$((FAILED + 1))
    elif [[ -n "$want_text" ]] && ! grep -qi -- "$want_text" <<<"$out"; then
        echo "FAIL: $name (output does not contain '$want_text')"
        FAILED=$((FAILED + 1))
    else
        echo "PASS: $name"
        PASSED=$((PASSED + 1))
    fi
}

echo "Building image '$IMAGE' ..."
if ! docker build -q -t "$IMAGE" "$SCRIPT_DIR" >/dev/null; then
    echo "FAIL: docker build failed" >&2
    exit 1
fi
echo

run_test "help prints usage"                   0 "Usage"            docker run --rm "$IMAGE" help
run_test "no argument falls back to help (CMD)" 0 "Usage"           docker run --rm "$IMAGE"
run_test "system shows kernel information"     0 "Kernel"           docker run --rm "$IMAGE" system
run_test "disk shows filesystem table"         0 "Filesystem"       docker run --rm "$IMAGE" disk
run_test "invalid command exits with 2"        2 "Unknown command"  docker run --rm "$IMAGE" not-a-command
run_test "network without host exits with 2"   2 "requires a host"  docker run --rm "$IMAGE" network
run_test "network with invalid host exits 2"   2 "Invalid host"     docker run --rm "$IMAGE" network 'bad_host!'
run_test "system rejects extra arguments"      2 "no arguments"     docker run --rm "$IMAGE" system extra
run_test "health-check script reports healthy" 0 "healthy"          docker run --rm --entrypoint /app/health-check.sh "$IMAGE"

echo
echo "Passed: $PASSED   Failed: $FAILED"
[[ $FAILED -eq 0 ]]

echo "Finished - final exit code: $?"