# Dotfiles

Personal dotfiles for macOS (primary) and Linux. Configs are stowed/symlinked into `$HOME`
(e.g. `~/.tmux.conf` → `tmux/.tmux.conf`). Provisioning lives under `scripts/`.

## Provisioning flow

`scripts/setup.sh` is the orchestrator. `./setup.sh --all`:

1. macOS: Xcode CLT, Rosetta 2
2. downloads the repo (if needed)
3. Linux: `scripts/linux/install_dependencies.sh`
4. `scripts/common/install_brew.sh`
5. `ensure_pip`, then `brew install ansible`
6. `scripts/common/ansible.sh --all` → runs `scripts/common/ansible/main.yaml`

Brew formulae/casks (incl. `bash`, Nerd Font casks) are declared in
`scripts/common/ansible/config.yaml`; the `common` role installs them.

## Bootstrap order & dependency chain (fresh machine)

There is a hard ordering with an unavoidable **manual** step in the middle. Nothing that
needs git-over-SSH can run before the human has set up 1Password. The required order:

1. **Xcode Command Line Tools** — provides `git`, compilers.
2. **Homebrew** — the package manager; everything else depends on it.
3. **Required core toolset** — `brew install` the non-negotiable tools the wizard itself
   needs, always installed regardless of profile: at least `git`, `bash` (4+), `coreutils`,
   and **`fzf`**. This is the answer to the chicken-and-egg around the picker: fzf is
   installed here, right after Homebrew, so it is guaranteed present before any selection
   step runs. Core tools are never part of the optional picker.
4. **Install 1Password** — `brew install --cask 1password` (+ `1password-cli` / `op` if used).
   Can't be installed before Homebrew; SSH keys can't be reached before this.
5. **🛑 MANUAL GATE** (cannot be automated — GUI + master password/biometric):
   - Sign in to 1Password and unlock it.
   - Enable the SSH agent: **Settings → Developer → "Use the SSH agent"** (this is the
     "allow dev access" step). Authorize the integration.
   - (The GitHub account must already have the matching public key — one-time, out of band.)
6. **Fetch the dotfiles over HTTPS** (public, so it works *before* SSH is available):
   `git clone https://github.com/mj-meyer/.dotfiles ~/.dotfiles`
   — this resolves the chicken-and-egg, because the SSH config that points at the
   1Password agent lives *inside* the dotfiles.
7. **Symlink the SSH config** so `IdentityAgent` → the 1Password agent socket
   (`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`).
8. **Verify SSH access**: `ssh -T git@github.com` should succeed.
9. **Flip the dotfiles remote to SSH** (so future pulls/pushes use keys):
   `git -C ~/.dotfiles remote set-url origin git@github.com:mj-meyer/.dotfiles.git`
10. **Continue provisioning**: run the **package picker** (profiles + fzf — see below) to
    choose optional formulae/casks, install them, symlink remaining configs, and clone any
    *other* (private) repos that need git-over-SSH.

### How the bootstrap script should behave

Make it a **guided, interactive wizard**, not a fire-and-forget script:

- Run the automated steps automatically (Xcode, Homebrew, install 1Password, the HTTPS
  clone, the remote flip, the rest of provisioning).
- For each **manual** step, print clear "now do this" instructions and **wait for the
  user to confirm** (e.g. `read -rp "Press Enter once 1Password SSH agent is enabled…"`).
- **Verify** where possible before moving on (e.g. loop on `ssh -T git@github.com` after
  the 1Password gate; check `command -v brew`).
- Be **idempotent / re-runnable** — safe to run again if interrupted at any step.

### Package selection (profiles + fzf)

Optional apps/utilities are chosen interactively rather than installing one fixed list.

- **Tool: `fzf --multi`.** fzf is installed in the *required core toolset* step (right after
  Homebrew), so it's always present by the time selection runs — no chicken-and-egg.
- **Model: profiles, then refine.** Define named profiles (e.g. `minimal`, `full`, `work`,
  `personal`). Picking one installs its base set automatically; fzf is then used to add
  optional extras on top.
- **Single source of truth.** Keep the package list as data — a manifest file or bash arrays
  tagged by category (`cli` / `cask` / `font` / `optional`) and by profile membership — so
  both the profiles and the picker read from one place. Migrate the lists currently in
  `scripts/common/ansible/config.yaml` into this manifest.
- **fzf caveat:** fzf can't easily pre-check items. Practical pattern — install the profile's
  base set unconditionally, then use `fzf --multi` to pick *additional* optional packages
  from the remainder. Use `--preview` to show each package's description.
- **Never in the picker:** the always-installed core (git, bash, coreutils, fzf, 1password,
  …) — it's required for the machine/wizard to function.

## DIRECTION: migrating off Ansible → plain shell (`.sh`) scripts

**We are progressively replacing the Ansible provisioning with plain `.sh` scripts.**
This is deliberate and incremental — **do NOT rip out Ansible all at once.** Keep the
existing playbook working until each piece has a shell replacement.

Guidance when touching provisioning:

- **New provisioning logic → write it as a `.sh` script** under `scripts/common/`,
  `scripts/macos/`, or `scripts/linux/`. Do **not** add new Ansible roles/tasks.
- **When asked to change an existing role**, prefer migrating that whole role to a shell
  script (and removing it from `main.yaml`) over editing the role in place.
- Keep `scripts/setup.sh` as the single entry point; wire new shell scripts into it
  (and/or into `install_brew.sh`) instead of into `ansible.sh`.
- Match the existing script conventions: `#!/usr/bin/env bash`, `set -euoE pipefail`,
  platform helpers like `macos()`/`linux()` (see `setup.sh`).
- Once a role is fully migrated, delete it from `roles/` and comment/remove it in
  `main.yaml` (lunarvim is already commented out as a model).
- End state: `ansible.sh` and `scripts/common/ansible/` are gone, and `bash`/font/etc.
  packages install via a shell script (e.g. extend `install_brew.sh` with a package list).

### Migration status (Ansible roles → shell)

- [ ] **bootstrap wizard** — the guided ordered flow above (Homebrew → 1Password → manual gate → HTTPS clone → SSH-remote flip → provisioning)
- [ ] **package manifest + fzf picker** — turn `config.yaml` lists into a data manifest with profiles; build the `fzf --multi` selector
- [ ] `common` (brew formulae + casks from `config.yaml`) — biggest; likely fold into `install_brew.sh`
- [ ] `oh-my-zsh`
- [ ] `dotfiles` (symlinking)
- [ ] `tmux` (installs tpm + plugins; see `roles/tmux/tasks/main.yaml`)
- [ ] `system_defaults` (macOS defaults / dock) — includes autocorrect/autocomplete disabling (`NSAutomaticSpellingCorrectionEnabled`, `NSAutomaticCapitalizationEnabled`, `NSAutomaticDashSubstitutionEnabled`, `NSAutomaticPeriodSubstitutionEnabled`, `NSAutomaticQuoteSubstitutionEnabled`); straightforward `defaults write` commands, good candidate for early migration
- [ ] `node`
- [ ] `aws`
- [x] `lunarvim` — already removed from the playbook (installed manually)

## Notes

- macOS ships bash 3.2; many tools need bash 4+. Homebrew `bash` is required (e.g. the
  tokyo-night-tmux theme uses `declare -A`). Any new shell scripts using associative
  arrays must run under `/opt/homebrew/bin/bash`, not `/bin/bash`.
- Provisioning has historically run incompletely on some machines — verify a declared
  package/cask is actually installed before assuming a tool is broken.
