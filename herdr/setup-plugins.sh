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
  herdr plugin install "github:$plugin" || echo "  ⚠ failed (may already be installed)"
done

echo "Done. Restart herdr to pick up changes."
