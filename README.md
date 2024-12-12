# 🚀 MJ's Dotfiles

This repository contains my personal dotfiles and setup scripts for macOS development environment.

Test change

## 🏃 Quick Start

Copy and paste this command into Terminal to get started:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mj-meyer/.dotfiles/main/scripts/setup.sh)" -- --all
```

This will:
1. Install Xcode Command Line Tools (if not installed)
2. Clone this repository to `~/.dotfiles`
3. Install Homebrew
4. Install Ansible
5. Configure your entire environment using Ansible

## 🔍 What Gets Installed?

- **Package Manager**: Homebrew
- **Shell**: Zsh with Oh-My-Zsh
- **Terminal Multiplexer**: Tmux with custom configuration
- **Window Management**: Yabai with skhd for keyboard shortcuts
- **Development Tools**: 
  - Node.js (via fnm)
  - Python
  - AWS CLI and tools
  - Git with delta for better diffs
  - And many more (see Brewfile for complete list)
- **Applications**: Various macOS apps via Homebrew Casks
- **Terminal**: Wezterm/Alacritty
- **Editor**: Neovim (LazyVim configuration)

## 🛠️ Manual Installation

If you prefer to run steps individually:

1. Install Xcode Command Line Tools:
```bash
xcode-select --install
```

2. Clone the repository:
```bash
git clone https://github.com/mj-meyer/.dotfiles.git ~/.dotfiles
```

3. Run individual components:
```bash
cd ~/.dotfiles/scripts
./setup.sh --xcode    # Install Xcode Command Line Tools
./setup.sh --brew     # Install Homebrew
./setup.sh --ansible  # Run Ansible playbook
```

## ⚙️ Configuration

The main configuration files are:
- Ansible config: `scripts/common/ansible/config.yaml`
- Window management: `.skhdrc` and `.yabairc`
- Shell: `.zshrc`
- Git: `.gitconfig`

## 🔄 Post-Installation

After installation:
1. Open Terminal preferences and set Wezterm/Alacritty as your default terminal
2. Log out and log back in for all changes to take effect
3. Open Raycast and set up your preferred keyboard shortcut
4. Configure system preferences that couldn't be automated

## 🐛 Troubleshooting

If you encounter issues:
1. Ensure you have full disk access granted to Terminal
2. Check system logs: `tail -f /var/log/system.log`
3. Run individual components with `--verbose` flag:
```bash
./setup.sh --ansible --verbose
```

## 📝 Notes

- Some settings require a logout/restart to take effect
- System Preferences may need to be closed/reopened to see changes
- Make sure to grant necessary permissions when prompted
- If you're using Apple Silicon (M1/M2), some packages might need Rosetta 2

## 🔒 Security

The setup script requires sudo access for certain operations. Always review scripts before running them with elevated privileges.

## 📜 License

MIT License - feel free to use and modify as you see fit!
