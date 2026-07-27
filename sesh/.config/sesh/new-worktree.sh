#!/bin/bash
set -e

RAW_NAME="$1"

# All UI output goes to stderr so stdout is clean for sesh connect
exec 3>&2  # save stderr

# ── Tokyo Night palette ─────────────────────────────────────
ACCENT="#7aa2f7"
ACCENT2="#bb9af7"
MUTED="#565f89"
TEXT="#c0caf5"
RED="#f7768e"
GREEN="#9ece6a"
BORDER="#3b4261"

# ── Helpers ──────────────────────────────────────────────────
die() {
  gum style --foreground="$RED" --bold --padding "1 3" --margin "2 4" \
    --border="rounded" --border-foreground="$RED" \
    "✗ $1" >&3
  sleep 2
  exit 1
}

center_pad() {
  # Print vertical padding (roughly center content in the popup)
  local lines=${1:-4}
  for ((i=0; i<lines; i++)); do echo "" >&3; done
}

# ── Resolve project path ────────────────────────────────────
resolve_path() {
  local name="$1"
  local tmux_path
  tmux_path=$(tmux list-sessions -F '#{session_name} #{session_path}' 2>/dev/null \
    | awk -v n="$name" '$1 == n { print $2; exit }')
  if [ -n "$tmux_path" ]; then
    echo "$tmux_path"
    return
  fi
  zoxide query "$name" 2>/dev/null
}

PROJECT_PATH=$(resolve_path "$RAW_NAME")
[ -z "$PROJECT_PATH" ] && die "Can't resolve path for: $RAW_NAME"

git -C "$PROJECT_PATH" rev-parse --show-toplevel >/dev/null 2>&1 \
  || die "Not a git repo: $PROJECT_PATH"

# Resolve to main worktree root
GIT_COMMON=$(git -C "$PROJECT_PATH" rev-parse --git-common-dir 2>/dev/null)
if [ "$GIT_COMMON" != ".git" ] && [ "$(basename "$GIT_COMMON")" != ".git" ]; then
  GIT_ROOT=$(dirname "$GIT_COMMON")
else
  GIT_ROOT=$(git -C "$PROJECT_PATH" rev-parse --show-toplevel 2>/dev/null)
fi

cd "$GIT_ROOT"

WORK_PREFIX=""
if [[ "$GIT_ROOT" == "$HOME/Code/"* ]] && [[ "$GIT_ROOT" != "$HOME/Code-OSS"* ]]; then
  WORK_PREFIX="t836307/"
fi

REPO_NAME=$(basename "$GIT_ROOT")
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
WORKTREE_COUNT=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')

# ── UI ───────────────────────────────────────────────────────
clear >&3
center_pad 3

# Header box
gum style \
  --border="rounded" --border-foreground="$BORDER" \
  --padding "1 3" --margin "0 6" --align="center" --width 50 \
  "$(gum style --foreground="$ACCENT" --bold "  New Worktree")" \
  "" \
  "$(gum style --foreground="$TEXT" "📦 $REPO_NAME")" \
  "$(gum style --foreground="$MUTED" "   $DEFAULT_BRANCH  ·  $WORKTREE_COUNT worktrees")" >&3

echo "" >&3

MODE=$(gum choose "  New branch" "  Review PR" "  Cancel" \
  --cursor.foreground="$ACCENT" \
  --item.foreground="$MUTED" \
  --selected.foreground="$ACCENT" --selected.bold \
  --cursor="  " \
  --cursor-prefix="" \
  --unselected-prefix="  ")

case "$MODE" in
  *"Cancel"*|"")
    exit 0
    ;;
  *"New branch"*)
    echo "" >&3
    if [ -n "$WORK_PREFIX" ]; then
      gum style --foreground="$MUTED" --margin "0 6" --italic \
        "auto-prefix: ${WORK_PREFIX}" >&3
    fi
    echo "" >&3

    BRANCH_INPUT=$(gum input \
      --placeholder "feature-name" \
      --prompt "  Branch ❯ " \
      --prompt.foreground="$ACCENT" \
      --cursor.foreground="$ACCENT" \
      --header.foreground="$MUTED" \
      --width 40)
    [ -z "$BRANCH_INPUT" ] && exit 0

    BRANCH="${WORK_PREFIX}${BRANCH_INPUT}"

    echo "" >&3
    gum style --foreground="$GREEN" --margin "0 6" \
      "  Creating: $BRANCH" >&3
    echo "" >&3

    if ! wt switch --create --no-cd "$BRANCH" >/dev/tty 2>/dev/tty; then
      die "Failed to create worktree"
    fi

    NEW_PATH=$(wt list --format=json 2>/dev/null \
      | jq -r --arg b "$BRANCH" '.[] | select(.branch == $b) | .path' 2>/dev/null)
    [ -n "$NEW_PATH" ] && echo "$NEW_PATH"
    ;;
  *"Review PR"*)
    echo "" >&3
    gum style --foreground="$ACCENT2" --margin "0 6" \
      "  Loading open PRs..." >&3
    echo "" >&3

    # Snapshot branches before
    BEFORE=$(wt list --format=json 2>/dev/null | jq -r '.[].branch' | sort)

    # Run wt picker — needs full TTY access
    wt switch --prs --no-cd >/dev/tty 2>/dev/tty </dev/tty
    WT_EXIT=$?

    if [ $WT_EXIT -ne 0 ]; then
      exit 0  # User cancelled
    fi

    # Compare branches to find what was added
    AFTER_JSON=$(wt list --format=json 2>/dev/null)
    AFTER=$(echo "$AFTER_JSON" | jq -r '.[].branch' | sort)
    NEW_BRANCH=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | head -1)

    if [ -n "$NEW_BRANCH" ]; then
      # New worktree was created for the PR
      NEW_PATH=$(echo "$AFTER_JSON" | jq -r --arg b "$NEW_BRANCH" \
        '.[] | select(.branch == $b) | .path')
      [ -n "$NEW_PATH" ] && echo "$NEW_PATH"
    fi
    ;;
esac
