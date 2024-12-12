#!/usr/bin/env bash

set -euoE pipefail

install_brew() {
  echo "⚪ [homebrew] installing..."

  if command -v brew &> /dev/null; then
    echo "⚪ [homebrew] already installed."
    return 0
  fi

  # Prompt for sudo password
  echo "This script requires sudo access to install homebrew"
  sudo -v
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH temporarily for this session
  if test "$(uname -s)" == "Darwin"; then
    if [[ $(uname -m) == 'arm64' ]]; then
      # M1/M2 Mac
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      # Intel Mac
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    # Linux
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  # Verify Homebrew is now available
  if ! command -v brew &> /dev/null; then
    echo "❌ [homebrew] installation succeeded but 'brew' command not found. Please restart your terminal and try again."
    exit 1
  fi

  brew analytics off
  echo "✅ [homebrew] installed!"
}

install_brew
