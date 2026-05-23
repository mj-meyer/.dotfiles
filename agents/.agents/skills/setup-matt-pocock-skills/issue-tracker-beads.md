# Issue tracker: Beads (bd)

Issues and PRDs for this repo live in **beads**, a Dolt-backed issue tracker with
first-class dependencies. Use the `bd` CLI for all operations. (The beads MCP tools
and `beads:*` slash commands are equivalent — use whichever the agent has; the
commands below are the canonical reference.)

Issue IDs look like `bd-xyz`. `bd create --json` returns the new ID — capture it so
you can wire dependencies and cross-reference issues.

## Conventions

- **Create an issue**: `bd create "<title>" -d "<description>" --json`. For a
  multi-line body, pipe it in:

  ```sh
  bd create "<title>" --body-file - --json <<'EOF'
  ...multi-line description...
  EOF
  ```

  Useful flags: `--acceptance "<criteria>"`, `-l <label1>,<label2>` (labels),
  `--parent <id>` (make it a hierarchical child of a parent issue), `-p <0-4>`
  (priority, 0 = highest). `bd q "<title>"` is a quick-capture that prints only the
  new ID.
- **Read an issue**: `bd show <id> --json` (add `--long` for all fields). Comment
  thread: `bd comments <id>`.
- **List / query issues**: `bd list --json` (defaults to open issues). Filter by
  label: `bd list --label <label> --json` (AND — must have all) or
  `--label-any a,b` (OR). Richer filtering: `bd query "..."`. Count: `bd count`.
- **Comment on an issue**: `bd comment <id> "<text>"` (or `--stdin` / `--file`).
- **Apply / remove labels**: `bd update <id> --add-label "<label>"` /
  `--remove-label "<label>"` (or `bd label add/remove <label> <id>`).
- **Close**: `bd close <id> -r "<reason>"`. Add `--suggest-next` to surface
  newly-unblocked issues, or `--claim-next` to immediately pick up the next one.
- **Reopen**: `bd reopen <id>`.

## Dependencies — first-class, use them

Beads tracks blocking relationships as real edges, not prose. Whenever a skill
describes one issue as "blocked by" another, wire it:

- `bd dep add <blocked-id> <blocker-id>` — `<blocked-id>` depends on `<blocker-id>`.
- Equivalent: `bd dep <blocker-id> --blocks <blocked-id>`.
- Inline at creation: `bd create "<title>" --deps "blocks:<id>,<id>" --json`.
- Whole plan at once: `bd create --graph <plan.json>` creates an issue graph with
  dependencies in a single command.
- Inspect / verify: `bd dep tree <id>`, `bd dep list <id>`, `bd dep cycles` (run
  after bulk wiring to confirm there are no cycles).

Because edges are real, the **"## Blocked by" section in an issue body is
redundant** — record the dependency as an edge and omit the body section (keep at
most a one-line human pointer).

## Ready work / AFK semantics

`bd ready` is the source of truth for "what can an agent pick up right now" — open
issues with no active blockers (it excludes in_progress, blocked, and deferred):

- `bd ready --json` — list claimable work.
- `bd ready --label <ready-for-agent-label> --json` — claimable work that has also
  been triaged as AFK-ready.
- `bd ready --label <ready-for-agent-label> --claim --json` — **atomically claim**
  the next such issue (sets assignee + status `in_progress`).
- `bd ready --explain` — show why each issue is ready or blocked.

This is the payoff of beads-first: an issue is actionable when it (a) carries the
AFK-ready triage label *and* (b) appears in `bd ready`. The label is the human
"specified well enough" judgment; `bd ready` is the dependency-state judgment.

## Triage roles → beads

The five canonical triage roles (see `triage-labels.md`) map to beads as labels,
with two conventions:

- `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human` → beads
  **labels** (`bd update <id> --add-label <label>`). Put the actual label strings
  in `triage-labels.md`.
- `wontfix` → **close** the issue with a reason: `bd close <id> -r "wontfix: <why>"`
  (it is terminal, so a status fits better than a label). Optionally also
  `--add-label wontfix` before closing if you want it queryable later.

## When a skill says "publish to the issue tracker"

Run `bd create ... --json` and capture the returned ID. If the skill describes
blocking relationships, wire them with `bd dep add` (or `--deps` / `--graph`).
Apply the triage label the skill specifies.

## When a skill says "fetch the relevant ticket"

Run `bd show <id> --json` (and `bd comments <id>` for the thread). The user normally
passes the `bd-...` ID directly.

## Persistence

Beads is Dolt-backed. Depending on this repo's `dolt.auto-commit` policy, writes may
stay in the working set until committed. After a batch of issue changes, flush with
the project's beads sync workflow (`bd dolt commit` / push, or the `beads` skill) so
the changes are persisted and shareable.
