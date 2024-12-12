#!/usr/bin/env bash

set -euoE pipefail

# shellcheck disable=SC2086
cwd="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"

source="https://github.com/mj-meyer/.dotfiles"
branch="${branch:-main}"
tarball="$source/tarball/$branch"
target="$HOME/.dotfiles"
tar_cmd="tar -xzv -C $target --strip-components=1 --exclude='{.gitignore}'"


display_help() {
  echo "Usage: ./setup.sh [arguments]..."
  echo
  echo "  --deps              install deps for linux"
  echo "  --brew              install brew for linux/macos"
  echo "  --ansible           execute ansible for linux/macos"
  echo "  --all               setup everything"
  echo "  --xcode             install Xcode Command Line Tools (macos only)"
  echo "  -h, --help          display this help message"
  echo
}

exit_help() {
  display_help
  echo "Error: $1"
  exit 1
}

macos() { test "$(uname -s)" == "Darwin"  && return 0; }
linux() { test "$(uname -s)" == "Linux"  && return 0; }
is_executable() { type "$1" > /dev/null 2>&1; }

install_xcode_tools() {
  if macos; then
    if ! xcode-select -p &>/dev/null; then
      echo "Xcode Command Line Tools not found. Installing..."
      xcode-select --install
      until xcode-select -p &>/dev/null; do
        sleep 5
      done
    else
      echo "Xcode Command Line Tools already installed."
    fi
  else
    echo "This function is only valid for MacOS."
  fi
}

download_repository() {
  if is_executable "git"; then
    cmd="git clone -b $branch $source $target"
  elif is_executable "curl"; then
    cmd="curl -#L $tarball | $tar_cmd"
  elif is_executable "wget"; then
    cmd="wget --no-check-certificate -O - $tarball | $tar_cmd"
  fi

  if test -z "$cmd"; then
    exit_help "No git, curl or wget available. Aborting."
  else
    mkdir -p "$target"
    eval "$cmd"
  fi
}

ensure_pip() {
  if ! command -v pip3 &> /dev/null; then
    echo "⚪ Setting up pip..."
    # Use Homebrew's Python specifically
    if brew list python@3.11 &>/dev/null; then
      /opt/homebrew/bin/python3 -m ensurepip --upgrade --user
      /opt/homebrew/bin/python3 -m pip install --upgrade pip --user
    else
      echo "⚪ Installing Python via Homebrew..."
      brew install python@3.11
      /opt/homebrew/bin/python3 -m ensurepip --upgrade --user
      /opt/homebrew/bin/python3 -m pip install --upgrade pip --user
    fi
  fi
}

setup_all() {
  if macos; then
    install_xcode_tools
    
    # Install Rosetta 2 on Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
      echo "⚪ Checking Rosetta 2 installation..."
      if ! pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto > /dev/null 2>&1; then
        echo "⚪ Installing Rosetta 2..."
        softwareupdate --install-rosetta --agree-to-license
      else
        echo "✅ Rosetta 2 already installed."
      fi
    fi
  fi

  test -d "$target" || download_repository
  if linux; then
    "${target}/scripts/linux/install_dependencies.sh"
  fi
  
  sudo -v  # prompt for sudo password
  "${target}/scripts/common/install_brew.sh"
  
  # Ensure brew is in PATH immediately after installation
  if macos; then
    if [[ $(uname -m) == 'arm64' ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  
  # Verify brew is available
  if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew installation succeeded but 'brew' command not found."
    echo "This is likely a PATH issue. Please restart your terminal and try again."
    exit 1
  fi
  
  # Ensure pip is available before ansible
  ensure_pip
  
  # Install ansible if not present
  if ! command -v ansible &> /dev/null; then
    echo "⚪ Installing Ansible..."
    brew install ansible
  fi
  
  "${target}/scripts/common/ansible.sh" --all
}

# process arguments
while [[ $# -gt 0 ]]; do
  arg=$1
  case $arg in
    -h | --help)
      display_help
      exit 0
      ;;
    --deps)
      "${cwd}/linux/install_dependencies.sh"
      ;;
    --brew)
      "${cwd}/common/install_brew.sh"
      ;;
    --ansible)
      "${cwd}/common/ansible.sh"
      ;;
    --xcode)
      install_xcode_tools
      ;;
    --all)
      setup_all
      ;;
    *)
      exit_help "Unknown argument: $arg"
      ;;
  esac
  shift
done
