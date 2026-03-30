#!/bin/bash
# Smart monitor hotplug for Asahi/Fairydust kernel
#
# Problem: Asahi DRM reports DP-1 as "connected" with valid EDID even when
# the display link is broken (ghost connector after power events). This makes
# Hyprland create a 0x0 framebuffer, which kills Waybar.
#
# Solution: DP-1 is disabled in monitors.conf. This script:
#   1. Polls DRM sysfs for connector status changes
#   2. On "connected" — enables DP-1, then verifies resolution via JSON API
#   3. If 0x0 (ghost) — immediately rolls back and retries with backoff
#   4. Listens to Hyprland IPC as a safety net for Waybar restarts
#
# Logs: journalctl --user -t monitor-hotplug

exec > >(systemd-cat -t monitor-hotplug) 2>&1

set -euo pipefail

# --- Config ---
DRM_STATUS="/sys/class/drm/card2-DP-1/status"
MONITOR_RULE="DP-1,3840x2160@30,2560x0,1"
POLL_INTERVAL=5
SETTLE_TIME=2
MAX_RETRIES=3
RETRY_BACKOFF=10  # seconds between retries after ghost detection

# --- State ---
dp1_enabled=false
ghost_retries=0
last_drm_status=""

log() { echo "[$(date '+%F %T')] $*"; }

# --- Waybar ---
restart_waybar() {
    log "Restarting Waybar"
    killall -q waybar || true
    sleep 0.5
    waybar &
    disown
}

# --- Resolution check via JSON API (reliable parsing) ---
get_dp1_resolution() {
    hyprctl monitors -j 2>/dev/null \
        | python3 -c "
import sys, json
for m in json.load(sys.stdin):
    if m['name'] == 'DP-1':
        print(m['width'], m['height'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# --- Enable DP-1 with 0x0 guard ---
enable_dp1() {
    if $dp1_enabled; then
        return
    fi

    # Respect retry backoff after ghost detection
    if (( ghost_retries >= MAX_RETRIES )); then
        log "Ghost detected $ghost_retries times — waiting for disconnect before retrying"
        return
    fi

    log "DP-1 connected — attempting to enable (attempt $((ghost_retries + 1))/$MAX_RETRIES)"
    hyprctl keyword monitor "$MONITOR_RULE" >/dev/null

    sleep "$SETTLE_TIME"

    local res
    if ! res=$(get_dp1_resolution); then
        log "DP-1 not listed after enable — disabling"
        hyprctl keyword monitor "DP-1,disable" >/dev/null
        (( ghost_retries++ )) || true
        restart_waybar
        return
    fi

    local width height
    read -r width height <<< "$res"

    if (( width == 0 || height == 0 )); then
        log "DP-1 has ${width}x${height} resolution (ghost) — disabling"
        hyprctl keyword monitor "DP-1,disable" >/dev/null
        (( ghost_retries++ )) || true
        restart_waybar

        # Schedule a retry after backoff
        if (( ghost_retries < MAX_RETRIES )); then
            log "Will retry in ${RETRY_BACKOFF}s"
            ( sleep "$RETRY_BACKOFF"; enable_dp1 ) &
        fi
        return
    fi

    log "DP-1 enabled at ${width}x${height}"
    dp1_enabled=true
    ghost_retries=0
    restart_waybar
}

# --- Disable DP-1 ---
disable_dp1() {
    if ! $dp1_enabled; then
        # Reset ghost counter on genuine disconnect so retries work next plug
        ghost_retries=0
        return
    fi
    log "DP-1 disconnected — disabling"
    hyprctl keyword monitor "DP-1,disable" >/dev/null
    dp1_enabled=false
    ghost_retries=0
    restart_waybar
}

# --- Periodic health check: catch 0x0 even if we missed the event ---
health_check() {
    if ! $dp1_enabled; then
        return
    fi
    local res
    if ! res=$(get_dp1_resolution); then
        log "Health check: DP-1 disappeared — disabling"
        hyprctl keyword monitor "DP-1,disable" >/dev/null
        dp1_enabled=false
        restart_waybar
        return
    fi
    local width height
    read -r width height <<< "$res"
    if (( width == 0 || height == 0 )); then
        log "Health check: DP-1 degraded to ${width}x${height} — disabling"
        hyprctl keyword monitor "DP-1,disable" >/dev/null
        dp1_enabled=false
        restart_waybar
    fi
}

# --- DRM sysfs poller ---
poll_drm() {
    local poll_count=0
    while true; do
        if [[ -f "$DRM_STATUS" ]]; then
            local status
            status=$(< "$DRM_STATUS")

            # Only act on state changes (or first run)
            if [[ "$status" != "$last_drm_status" ]]; then
                last_drm_status="$status"
                case "$status" in
                    connected)    enable_dp1 ;;
                    disconnected) disable_dp1 ;;
                    *)            log "Unknown DRM status: $status" ;;
                esac
            fi

            # Health check every 6th poll (~30s)
            (( poll_count++ )) || true
            if (( poll_count % 6 == 0 )); then
                health_check
            fi
        fi
        sleep "$POLL_INTERVAL"
    done
}

# --- Hyprland IPC listener (safety net for Waybar) ---
listen_socket() {
    local sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

    # Reconnect loop in case Hyprland restarts
    while true; do
        if [[ -S "$sock" ]]; then
            log "Connected to Hyprland IPC"
            socat -U - UNIX-CONNECT:"$sock" 2>/dev/null | while read -r line; do
                case "$line" in
                    monitoradded*|monitorremoved*)
                        log "Hyprland event: $line"
                        sleep 2
                        restart_waybar
                        ;;
                esac
            done
            log "Hyprland IPC disconnected — reconnecting in 5s"
        fi
        sleep 5
    done
}

# --- Cleanup on exit ---
cleanup() {
    log "Shutting down"
    kill 0 2>/dev/null
    wait 2>/dev/null
}
trap cleanup EXIT

# --- Main ---
log "Monitor hotplug script started (PID $$)"
log "Watching: $DRM_STATUS"
log "Monitor rule: $MONITOR_RULE"

poll_drm &
listen_socket &

wait
