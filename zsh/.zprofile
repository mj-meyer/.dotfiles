# Homebrew PATH setup
if [[ $(uname -s) == "Darwin" ]]; then
  if [[ $(uname -m) == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ~/.tmux/plugins
export PATH=$HOME/.tmux/plugins/t-smart-tmux-session-manager/bin:$PATH
# ~/.config/tmux/plugins
# export PATH=$HOME/.config/tmux/plugins/t-smart-tmux-session-manager/bin:$PATH

eval "$(fnm env --use-on-cd)"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Added by `rbenv init` on Tue Feb 18 17:38:54 NZDT 2025
eval "$(rbenv init - --no-rehash zsh)"
