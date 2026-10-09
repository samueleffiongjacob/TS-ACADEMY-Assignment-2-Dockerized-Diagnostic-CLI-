#!/usr/bin/env bash
# =============================================================================
# health-check.sh - Verify that the diagnostic tool inside the image is healthy.
#
# Usage (inside the container image):
#   docker run --rm --entrypoint /app/health-check.sh diagnostic-tool
#
# Exit codes: 0 = healthy, 1 = something is wrong
# =============================================================================

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$DIR/diagnostic.sh"
STATUS=0

check() {
    # check "description" command...
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "OK   - $desc"
    else
        echo "FAIL - $desc"
        STATUS=1
    fi
}

check "diagnostic.sh exists"        test -f "$TOOL"
check "diagnostic.sh is executable" test -x "$TOOL"
check "'help' command works"        "$TOOL" help
check "'system' command works"      "$TOOL" system
check "'disk' command works"        "$TOOL" disk

if [[ $STATUS -eq 0 ]]; then
    echo "OK - diagnostic tool is healthy"
else
    echo "FAIL - diagnostic tool is unhealthy"
fi
exit "$STATUS"
