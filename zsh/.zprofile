# .zprofile -- login shells only.
#
# Deliberately (almost) empty: all environment setup lives in .zshrc so there is
# exactly ONE place to look, and so login vs non-login shells end up with an
# identical environment. Previously this file and .zshrc both ran `brew
# shellenv`, `fnm env` and `rbenv init`, which meant:
#   - PATH/FPATH picked up duplicate entries that grew with shell nesting
#   - oh-my-zsh saw a different $fpath every startup and rebuilt the whole
#     completion cache each time (~700ms per shell)
#   - fnm allocated a second throwaway multishell dir per shell
#
# .zshrc is guarded + uses `typeset -U`, so running it in nested shells is cheap
# and idempotent.
#
# Trade-off: non-interactive login shells (e.g. `ssh host 'some command'`) don't
# source .zshrc, so they won't get Homebrew on PATH. If that ever matters, add a
# minimal `brew shellenv` here rather than moving everything back.

[[ -o interactive ]] || return
