# herdr

Stow package for [herdr](https://herdr.dev/): `stow --no-folding herdr`.

`--no-folding` matters. It makes `~/.config/herdr/` and the plugin config dirs
real directories holding per-file symlinks, instead of one directory symlink.
That is what lets a machine drop in its own **unstowed** files next to the
shared ones (see below), and it keeps herdr free to write its own runtime state
(`session.json`, sockets, logs) into `~/.config/herdr/`.

After stowing, install the plugins the config binds keys to:

```sh
./setup-plugins.sh
```

## Sharing this config across machines

The same config is used on the work and personal machines. Three mechanisms
handle the differences:

**1. `$VARS` in paths.** herdr-plus expands `~` and `$VAR` / `${VAR}` in a
project's `working_dir` (Go's `os.ExpandEnv` — note there is *no*
`${VAR:-default}` support). So shared projects reference variables that
`zsh/.zshrc` defines per machine:

```toml
working_dir = "$NOTES_DIR"   # ~/Notes here, ~/Documents/Notes there
```

`NOTES_DIR` and `CODE_DIR` are exported near the end of `zsh/.zshrc`. Add more
there rather than hard-coding a path in a project file. Anything truly local
goes in `~/.zshrc.local`, which `.zshrc` sources if it exists.

**2. Machine-local project files.** A project is one TOML file, and herdr-plus
reads every file in `projects/`. Files that come from this repo are symlinks;
anything else in that directory is local to the machine and invisible to git:

```sh
# work-only project, never committed
$EDITOR ~/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/spark-bff.toml
```

Use this for repos that only exist on one machine. A project whose
`working_dir` is missing still shows in the picker but fails on open with
"working directory does not exist", so don't commit projects for paths the
other machine doesn't have.

**3. Wildcard worktree layouts.** `worktrees/*.toml` matches on `repo`, and
`repo = "*"` is a catch-all for every repo without a specific layout — one file
instead of one per repo.
