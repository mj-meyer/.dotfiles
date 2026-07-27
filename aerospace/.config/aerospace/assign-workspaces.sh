#!/usr/bin/env bash
set -euo pipefail

# Dynamically assign workspaces to monitors on startup.
# Workspace 1 → built-in (handled by config's workspace-to-monitor-force-assignment)
# Workspaces 2+ → distributed round-robin across external monitors.

# Get external (non-built-in) monitor IDs
mapfile -t ext_monitors < <(
  aerospace list-monitors | grep -iv 'built-in' | awk -F' \\| ' '{print $1}' | tr -d ' '
)

if [[ ${#ext_monitors[@]} -eq 0 ]]; then
  exit 0 # No externals connected (laptop-only mode), nothing to do
fi

# Workspaces to distribute across externals
workspaces=(2 3 4 5 6 7 8 9)

for i in "${!workspaces[@]}"; do
  ws="${workspaces[$i]}"
  monitor_idx=$((i % ${#ext_monitors[@]}))
  monitor="${ext_monitors[$monitor_idx]}"
  aerospace move-workspace-to-monitor --workspace "$ws" "$monitor"
done
