# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

# I think p10k is causing some issues. Disabling for now. Gonna try starship.
# ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# include Z, yo
# . ~/z.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# key bindings
bindkey "^[^[[C" forward-word
bindkey "^[^[[D" backward-word

# export NVM_DIR=~/.nvm
#  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

eval "$(fnm env --use-on-cd)"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform
alias tf=terraform

eval "$(zoxide init zsh)"

# Can use \nvim if you don't want to use lvim
# alias nvim=lvim 
# export EDITOR='lvim'

export PATH="$HOME/.local/bin":$PATH

# ~/.tmux/plugins
# export PATH=$HOME/.tmux/plugins/t-smart-tmux-session-manager/bin:$PATH
# ~/.config/tmux/plugins
# export PATH=$HOME/.config/tmux/plugins/t-smart-tmux-session-manager/bin:$PATH


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(starship init zsh)"

# pnpm
# export PATH="/opt/homebrew/opt/pnpm@9/bin:$PATH"
export PATH="/opt/homebrew/Cellar/pnpm/10.5.2/bin:$PATH"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Herd injected PHP 8.3 configuration.
export HERD_PHP_83_INI_SCAN_DIR="/Users/mj.meyer/Library/Application Support/Herd/config/php/83/"

alias ls='eza --icons=always'
# alias hc='~/Downloads/hc-v0.14.0-mac/hc'
alias hc='~/Work/HyperCinema/toolkit-cli/dist/hc'
alias docker=podman
alias kc=kubectl

# nvim config launcher
# TODO: investigate other distros
alias nvim-lazy="NVIM_APPNAME=LazyVim nvim"
function nvims() {
  #items=("default" "kickstart" "LazyVim" "NvChad" "AstroNvim")
  items=("LazyVim")
  config=$(printf "%s\n" "${items[@]}" | fzf --prompt=" Neovim Config 󰄾 " --height=~50% --layout=reverse --border --exit-0)
  if [[ -z $config ]]; then
    echo "Nothing selected"
    return 0
  elif [[ $config == "default" ]]; then
    config=""
  fi
  NVIM_APPNAME=$config nvim $@
}

bindkey -s ^a "nvims\n"

# Herd injected PHP binary.
export PATH="/Users/mj.meyer/Library/Application Support/Herd/bin/":$PATH

eval "$(rbenv init - --no-rehash zsh)"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
export PATH="/usr/local/opt/postgresql@15/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"
export PATH="/Users/mjmeyer/.config/herd-lite/bin:$PATH"
export PHP_INI_SCAN_DIR="/Users/mjmeyer/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"
export LEDGER_FILE=~/Personal/coinops/2025.journal

# opencode
export PATH=/Users/mjmeyer/.opencode/bin:$PATH


alias claude="/Users/mjmeyer/.claude/local/claude"

# bun completions
[ -s "/Users/mjmeyer/.bun/_bun" ] && source "/Users/mjmeyer/.bun/_bun"

# sesh session manager (triggered by cmd+k via F13 when not in tmux)
function sesh-sessions() {
  {
    exec </dev/tty
    exec <&1
    local session
    session=$(sesh list --icons | fzf --height 70% --reverse \
      --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
      --header '  ^a all ^t tmux ^g configs ^x zoxide ^w worktrees ^d kill ^f find' \
      --bind 'tab:down,btab:up' \
      --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
      --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
      --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
      --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
      --bind 'ctrl-w:change-prompt(🌳  )+reload(sesh list --icons -z | grep -F "$(sesh root)")' \
      --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
      --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
      --preview-window 'right:55%' \
      --preview 'sesh preview {}')
    zle reset-prompt > /dev/null 2>&1 || true
    [[ -z "$session" ]] && return
    sesh connect "$session"
  }
}

zle -N sesh-sessions
bindkey '^]' sesh-sessions

# Clone a repo as a bare repo with worktree structure
# Usage: git-clone-bare <repo-url> [directory-name]
# Creates: directory/.bare, directory/.git, directory/main (worktree)
function git-clone-bare() {
  local repo_url="$1"
  local dir_name="$2"

  if [[ -z "$repo_url" ]]; then
    echo "Usage: git-clone-bare <repo-url> [directory-name]"
    return 1
  fi

  # Extract repo name from URL if dir_name not provided
  if [[ -z "$dir_name" ]]; then
    dir_name=$(basename "$repo_url" .git)
  fi

  # Create directory and clone bare
  mkdir -p "$dir_name"
  git clone --bare "$repo_url" "$dir_name/.bare"

  # Create .git file pointing to .bare
  echo "gitdir: ./.bare" > "$dir_name/.git"

  # Set fetch to get all branches
  git -C "$dir_name/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  # Fetch all branches
  git -C "$dir_name/.bare" fetch origin

  # Get default branch name
  local default_branch=$(git -C "$dir_name/.bare" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [[ -z "$default_branch" ]]; then
    default_branch="main"
  fi

  # Create main worktree
  git -C "$dir_name" worktree add "$default_branch" "$default_branch"

  # Add to zoxide
  zoxide add "$PWD/$dir_name"
  zoxide add "$PWD/$dir_name/$default_branch"

  echo "✓ Cloned bare repo to $dir_name"
  echo "✓ Created worktree: $default_branch"
  echo "✓ Added to zoxide"

  # Ask to connect
  echo ""
  read "connect?Open in tmux with LazyVim? [y/N] "
  if [[ "$connect" =~ ^[Yy]$ ]]; then
    local session_name="$dir_name/$default_branch"
    local worktree_path="$PWD/$dir_name/$default_branch"
    tmux new-session -d -s "$session_name" -c "$worktree_path"
    tmux send-keys -t "$session_name" "NVIM_APPNAME=LazyVim nvim" Enter
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach-session -t "$session_name"
    fi
  fi
}

# Initialize a new bare repo with worktree structure + optional GitHub repo
# Usage: git-init-bare <project-name> [--github / --private]
# Creates: project/.bare, project/.git, project/main (worktree)
function git-init-bare() {
  local project_name="$1"
  local github_flag="$2"

  if [[ -z "$project_name" ]]; then
    echo "Usage: git-init-bare <project-name> [--github | --private]"
    echo "  --github  Create public GitHub repo"
    echo "  --private Create private GitHub repo"
    return 1
  fi

  # Check if directory exists
  if [[ -d "$project_name" ]]; then
    echo "Error: Directory '$project_name' already exists"
    return 1
  fi

  local full_path="$PWD/$project_name"

  # Create directory structure
  mkdir -p "$project_name/.bare"
  mkdir -p "$project_name/main"

  # Initialize bare repo
  git init --bare "$project_name/.bare"

  # Set default branch to main
  git -C "$project_name/.bare" symbolic-ref HEAD refs/heads/main

  # Create .git file in project root pointing to .bare
  echo "gitdir: ./.bare" > "$project_name/.git"

  # Create .git file in main worktree pointing to bare repo's worktree tracking
  echo "gitdir: $full_path/.bare/worktrees/main" > "$project_name/main/.git"

  # Register the worktree with the bare repo
  mkdir -p "$project_name/.bare/worktrees/main"
  echo "$full_path/main" > "$project_name/.bare/worktrees/main/gitdir"
  echo "$full_path/.bare" > "$project_name/.bare/worktrees/main/commondir"
  cp "$project_name/.bare/HEAD" "$project_name/.bare/worktrees/main/HEAD"

  # Create initial commit in the main worktree
  (
    cd "$project_name/main"
    echo "# $project_name" > README.md
    git add README.md
    git commit -m "Initial commit"
  )

  # Create GitHub repo if requested
  if [[ "$github_flag" == "--github" || "$github_flag" == "--private" ]]; then
    local visibility="public"
    [[ "$github_flag" == "--private" ]] && visibility="private"

    echo ""
    echo "Creating $visibility GitHub repo..."

    (
      cd "$project_name/main"
      gh repo create "$project_name" --"$visibility" --source=. --remote=origin --push
    )

    # Configure fetch for bare repo
    git -C "$project_name/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

    echo "✓ GitHub repo created"
  fi

  # Add to zoxide
  zoxide add "$full_path"
  zoxide add "$full_path/main"

  echo ""
  echo "✓ Created bare repo: $project_name"
  echo "✓ Created worktree: main"
  echo "✓ Added to zoxide"

  # Ask to connect
  echo ""
  read "connect?Open in tmux with LazyVim? [y/N] "
  if [[ "$connect" =~ ^[Yy]$ ]]; then
    local session_name="$project_name/main"
    tmux new-session -d -s "$session_name" -c "$full_path/main"
    tmux send-keys -t "$session_name" "NVIM_APPNAME=LazyVim nvim" Enter
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach-session -t "$session_name"
    fi
  fi
}
