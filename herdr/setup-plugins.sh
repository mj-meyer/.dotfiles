#!/usr/bin/env bash
# Install Herdr plugins from source.
# Run after `stow herdr` on a fresh machine.
set -euo pipefail

if ! command -v herdr &>/dev/null; then
  echo "herdr not found — install it first: brew install herdr"
  exit 1
fi

plugins=(
  "cloudmanic/herdr-plus"
  "paulbkim-dev/vim-herdr-navigation"
  "devashish2203/herdr-worktrunk"
)

for plugin in "${plugins[@]}"; do
  echo "Installing $plugin..."
  # --yes: the plugin list above is the review step; herdr otherwise refuses
  # to run a plugin's build step without one. Note: --yes must come *after*
  # the repo argument (herdr 0.7.1 parses positionally).
  herdr plugin install "$plugin" --yes || echo "  ⚠ failed (may already be installed)"
done

echo "Done. Restart herdr to pick up changes."
