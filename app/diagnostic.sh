#!/usr/bin/env bash
# =============================================================================
# diagnostic.sh - Dockerized diagnostic CLI
#
# Commands:
#   diagnostic system          show system information
#   diagnostic network <host>  resolve and check a host
#   diagnostic disk            show disk usage
#   diagnostic help            show usage
#
# Exit codes:
#   0 = success
#   1 = operational / runtime failure (e.g. host cannot be resolved)
#   2 = invalid command or input
#
# Only Linux basics are used (/proc, df, uname, getent) so it runs on a small
# Alpine image with nothing but bash installed.
# =============================================================================

set -u

readonly PROG="diagnostic"
readonly EXIT_OK=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2

# ---- Output helpers ---------------------------------------------------------

usage() {
    cat <<USAGE
Usage: ${PROG} <command> [arguments]

Commands:
  system            Show system information (host, OS, kernel, CPU, memory)
  network <host>    Resolve a hostname/IP and check that it is reachable
  disk              Show disk usage for all mounted filesystems
  help              Show this help message

Exit codes: 0 = success, 1 = runtime failure, 2 = invalid command or input

Examples:
  ${PROG} system
  ${PROG} network localhost
  ${PROG} disk
USAGE
}

# die_usage MESSAGE : print an error plus a hint, exit with code 2
die_usage() {
    echo "Error: $1" >&2
    echo "Run '${PROG} help' to see the available commands." >&2
    exit "$EXIT_USAGE"
}

# ---- Validation -------------------------------------------------------------

is_valid_ipv4() {
    local ip="$1" octet
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    local IFS=.
    for octet in $ip; do
        (( 10#$octet <= 255 )) || return 1
    done
    return 0
}

is_valid_host() {
    local host="$1"
    (( ${#host} >= 1 && ${#host} <= 253 )) || return 1
    if [[ "$host" =~ ^[0-9.]+$ ]]; then
        is_valid_ipv4 "$host"; return
    fi
    if [[ "$host" == *:* ]]; then
        [[ "$host" =~ ^[0-9A-Fa-f:]+$ ]]; return
    fi
    [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

# ---- Command: system --------------------------------------------------------

cmd_system() {
    local os="Linux" model cores uptime_secs

    # Operating system name from the standard os-release file.
    if [[ -r /etc/os-release ]]; then
        os="$( . /etc/os-release; echo "${PRETTY_NAME:-${NAME:-Linux}}" )"
    fi

    # CPU model and core count (fall back to the architecture name).
    model="$(grep -m1 -i 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')"
    cores="$(nproc 2>/dev/null || echo '?')"

    # Uptime is read from /proc/uptime (seconds since boot), because
    # `uptime -p` is not available on minimal images.
    if [[ -r /proc/uptime ]]; then
        uptime_secs="$(awk '{print int($1)}' /proc/uptime)"
    else
        uptime_secs=0
    fi

    echo "=== System Information ==="
    echo "Hostname         : $(uname -n)"
    echo "Current user     : $(id -un 2>/dev/null || echo unknown)"
    echo "Date/time        : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Operating system : ${os}"
    echo "Kernel           : $(uname -sr)"
    echo "Architecture     : $(uname -m)"
    echo "CPU              : ${model:-unknown} (${cores} cores)"
    printf 'Uptime           : %dd %dh %dm\n' \
        $((uptime_secs / 86400)) $(((uptime_secs % 86400) / 3600)) $(((uptime_secs % 3600) / 60))
    echo "--- Memory ---"
    if [[ -r /proc/meminfo ]]; then
        awk '/^MemTotal|^MemAvailable/ {printf "%-14s %8.0f MB\n", $1, $2/1024}' /proc/meminfo
    else
        echo "unavailable"
    fi
    return "$EXIT_OK"
}

# ---- Command: network -------------------------------------------------------

cmd_network() {
    local host="${1:-}" resolved ping_out

    [[ -n "$host" ]] || die_usage "'network' requires a host. Example: ${PROG} network localhost"
    is_valid_host "$host" || die_usage "Invalid host: '$host'"

    echo "=== Network Check: $host ==="

    # Resolve with the system resolver (/etc/hosts + DNS).
    resolved="$(getent ahosts "$host" 2>/dev/null | awk 'NR==1 {print $1}')"
    if [[ -z "$resolved" ]]; then
        echo "Could not resolve '$host'" >&2
        return "$EXIT_FAIL"
    fi
    echo "Resolved address : $resolved"

    # Ping once. A container without ICMP permission is reported as a warning,
    # not as a failure of the host.
    if command -v ping >/dev/null 2>&1; then
        if ping_out="$(timeout 5 ping -c 1 -W 2 "$host" 2>&1)"; then
            echo "Ping             : reply received"
        elif grep -qiE 'permission denied|operation not permitted|not permitted' <<<"$ping_out"; then
            echo "Ping             : skipped (ICMP not permitted in this container)"
        else
            echo "Ping             : no reply from $host" >&2
            return "$EXIT_FAIL"
        fi
    else
        echo "Ping             : skipped (ping not installed)"
    fi
    return "$EXIT_OK"
}

# ---- Command: disk ----------------------------------------------------------

cmd_disk() {
    echo "=== Disk Usage ==="
    if ! df -h; then
        echo "Error: could not read disk information" >&2
        return "$EXIT_FAIL"
    fi
    return "$EXIT_OK"
}

# ---- Entry point ------------------------------------------------------------

main() {
    if [[ $# -eq 0 ]]; then
        usage >&2
        exit "$EXIT_USAGE"
    fi

    local command="$1"
    shift

    case "$command" in
        help|-h|--help)
            usage
            ;;
        system)
            [[ $# -eq 0 ]] || die_usage "'system' takes no arguments"
            cmd_system
            ;;
        network)
            [[ $# -le 1 ]] || die_usage "'network' takes exactly one host"
            cmd_network "$@"
            ;;
        disk)
            [[ $# -eq 0 ]] || die_usage "'disk' takes no arguments"
            cmd_disk
            ;;
        *)
            die_usage "Unknown command: '$command'"
            ;;
    esac
}

main "$@"
exit $?
