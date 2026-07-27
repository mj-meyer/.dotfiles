# Wiki Extension Implementation Plan

Date: 2026-06-19

## Goal

Turn the wiki extension from a prompt launcher into a safer wiki manager that can:

1. manage multiple Obsidian-backed wikis,
2. create domain-appropriate wiki scaffolds,
3. run wiki operations in isolated, resumable pi sidecar sessions,
4. preserve optional access to current-session context without polluting the current session,
5. maintain enough operation metadata to debug, resume, and audit wiki changes.

This plan intentionally avoids a big rewrite. Build a thin vertical slice first, then harden.

---

## Current problem summary

The extension already has useful pieces:

- `/wiki` command
- wiki registry in `config.json`
- `WIKI.md`, `index.md`, `log.md` scaffolding
- inline/background conceptual split
- operation-oriented prompts: ingest, query, lint, daily, task, status

But the important gaps are:

- background mode currently uses `pi.sendUserMessage`, so it still enters the active chat session;
- create scaffolding is hardcoded for work/project wikis;
- config loading can silently discard malformed config;
- existing wiki files can be overwritten;
- provenance, source summaries, and query filing are under-specified;
- no operation records, queue, locks, or resumable sidecar metadata.

---

## Target command contract

### Keep existing basics

```txt
/wiki
/wiki list
/wiki register <name> <path>
/wiki create <name>
/wiki <name> --inline <request>
/wiki <name> <request>
```

### MVP behavior change

```txt
/wiki <name> <request>
```

should run as a **sidecar pi session**, not as a synthetic message in the current chat.

The current chat should receive only a short command result, such as:

```txt
Started wiki operation.
Wiki: spark
Operation: 2026-06-19T153012Z-ingest
Session dir: /Users/.../Spark/.wiki/operations/2026-06-19T153012Z-ingest/sessions
Log: /Users/.../Spark/.wiki/operations/2026-06-19T153012Z-ingest/run.log
```

### Later commands

```txt
/wiki <name> operations
/wiki <name> operation <id>
/wiki <name> resume <id>
/wiki create
/wiki create <name> --profile research
/wiki <name> capture --attach-last 5 <request>
/wiki <name> capture --attach-session-summary <request>
```

---

## Phase 1 — safety and config foundation

Complexity: low-medium.

### Changes

1. Fix `loadConfig` behavior.
   - If config is missing, create defaults.
   - If config has malformed JSON, show a clear error and do not overwrite it.

2. Prevent accidental overwrites in `createWiki`.
   - If `WIKI.md`, `index.md`, or `log.md` exists, require confirmation or abort.
   - Later: support `--force` explicitly.

3. Use `defaults.mode`.
   - If default mode is `background`, run sidecar.
   - If default mode is `inline`, use current-session inline injection.
   - `--inline` should override config.
   - Later: maybe add `--background` to override config the other way.

4. Resolve and validate paths.
   - Expand `~`.
   - Resolve absolute real path.
   - Ensure wiki path exists for registered wikis.
   - Ensure create target is inside configured `vaultRoot` unless user explicitly chooses an absolute external path.

5. Improve command completions.
   - First argument should prefer command names plus registered wiki names.
   - After a wiki name, suggest operation names.
   - Avoid suggesting `ingest` as first arg if it will be interpreted as a wiki name.

6. Small cleanup.
   - Remove unused imports.
   - Introduce narrower context types if practical.

### Acceptance criteria

- Malformed `config.json` cannot be silently replaced.
- Existing wiki files are not overwritten without explicit confirmation/force.
- Config `defaults.mode` affects operation routing.
- Registered wiki paths are absolute and validated before use.

---

## Phase 2 — basic sidecar execution

Complexity: low-medium.

### Design

Replace background `pi.sendUserMessage(...)` with a child pi process.

Use Node `child_process.spawn` from the extension.

Sidecar process should:

- run with `cwd` set to the wiki root;
- use the wiki's configured model;
- use `pi -p` non-interactive mode;
- save a normal pi session into an operation-specific session directory;
- write stdout/stderr to operation logs;
- not inject any messages into the current chat session.

### Suggested operation directory

For each run:

```txt
<wiki>/.wiki/operations/<operation-id>/
  operation.json
  prompt.md
  stdout.log
  stderr.log
  exit.json
  sessions/
```

Example operation id:

```txt
2026-06-19T153012Z-ingest
2026-06-19T153012Z-query
2026-06-19T153012Z-freeform
```

### Suggested sidecar invocation

Prefer avoiding huge command-line arguments by writing `prompt.md` first.

Possible command shape:

```sh
cd <wiki-path>
pi -p \
  --model <model> \
  --name "wiki:<name> <operation>" \
  --session-dir .wiki/operations/<operation-id>/sessions \
  @.wiki/operations/<operation-id>/prompt.md
```

The generated `prompt.md` should include:

```md
# Wiki Operation

Wiki name: spark
Wiki root: /Users/t836307/Notes/Spaces/Spark
Operation: ingest
Mode: sidecar

## Required instructions

1. Read `WIKI.md` first.
2. Only modify files under this wiki root.
3. Treat `raw/` as immutable.
4. Update `index.md` and `log.md` when relevant.
5. Summarize changed files at the end.

## User request

...
```

If `@prompt.md` handling is not sufficient in `pi -p`, fallback to passing prompt contents as the final arg. Verify before implementation.

### Blocking vs detached

Implement blocking sidecar first unless the extension API/TUI makes that unpleasant.

Blocking sidecar:

- easier to test;
- returns exit code immediately;
- operation record is complete after command returns.

Detached sidecar can come next:

- spawn with `detached: true`;
- redirect logs;
- record pid;
- add `/wiki <name> operations` to inspect status.

### Acceptance criteria

- `/wiki spark status` creates a separate pi session under the wiki operation directory.
- The active chat receives only the extension's short status output, not the operation prompt.
- Operation stdout/stderr are saved.
- User can resume or inspect the generated sidecar session using its session dir/path.

---

## Phase 3 — operation metadata and history

Complexity: medium.

### `operation.json` schema

```json
{
  "id": "2026-06-19T153012Z-ingest",
  "wiki": "spark",
  "wikiPath": "/Users/t836307/Notes/Spaces/Spark",
  "operation": "ingest",
  "request": "ingest these meeting notes...",
  "mode": "sidecar",
  "model": "anthropic/claude-sonnet-4-5",
  "cwd": "/Users/t836307/Notes/Spaces/Spark",
  "startedAt": "2026-06-19T15:30:12.000Z",
  "finishedAt": null,
  "status": "running",
  "pid": 12345,
  "exitCode": null,
  "promptPath": ".wiki/operations/2026-06-19T153012Z-ingest/prompt.md",
  "stdoutPath": ".wiki/operations/2026-06-19T153012Z-ingest/stdout.log",
  "stderrPath": ".wiki/operations/2026-06-19T153012Z-ingest/stderr.log",
  "sessionDir": ".wiki/operations/2026-06-19T153012Z-ingest/sessions",
  "sessionFiles": [],
  "attachedContext": {
    "type": "none"
  }
}
```

On process completion, update:

```json
{
  "finishedAt": "...",
  "status": "succeeded|failed",
  "exitCode": 0,
  "sessionFiles": ["..."]
}
```

### Commands

```txt
/wiki <name> operations
```

Show recent operations with status, operation type, request summary, exit code, and session path if known.

```txt
/wiki <name> operation <id>
```

Show full metadata and tail of stdout/stderr.

```txt
/wiki <name> resume <id>
```

Either:

- prints the exact command to resume the session, or
- if extension API supports it cleanly, opens/forks/resumes that sidecar session.

Example printed command:

```sh
pi --session-dir /Users/.../Spark/.wiki/operations/<id>/sessions --resume
```

or, if a specific session file is known:

```sh
pi --session /Users/.../Spark/.wiki/operations/<id>/sessions/...jsonl
```

### Acceptance criteria

- Every sidecar run has an operation directory and machine-readable metadata.
- Recent operations can be listed from `/wiki`.
- Failed operations preserve enough logs to debug.
- Successful operations expose the pi session file/path if discoverable.

---

## Phase 4 — profile-based scaffolding

Complexity: medium.

### Base scaffold

Every wiki should get a neutral base:

```txt
WIKI.md
index.md
log.md
raw/
raw/assets/
wiki/
wiki/sources/
wiki/entities/
wiki/concepts/
wiki/questions/
wiki/syntheses/
wiki/maintenance/
.wiki/
.wiki/operations/
```

### Profile overlays

Add static profile data, probably in TypeScript first. Later it can move to JSON/YAML.

#### `generic`

Use only the base scaffold.

#### `work` / `client`

```txt
daily/
raw/meetings/
raw/docs/
wiki/people/
wiki/tasks/
wiki/decisions/
wiki/processes/
wiki/systems/
```

#### `research`

```txt
raw/papers/
raw/articles/
raw/notes/
wiki/papers/
wiki/claims/
wiki/experiments/
wiki/bibliography/
```

#### `self-improvement`

```txt
journal/
wiki/goals/
wiki/patterns/
wiki/practices/
wiki/reflections/
wiki/metrics/
```

#### `project-idea`

```txt
wiki/hypotheses/
wiki/users/
wiki/competitors/
wiki/experiments/
wiki/decisions/
wiki/risks/
```

#### `book` / `course`

```txt
wiki/chapters/
wiki/themes/
wiki/outline/
wiki/references/
wiki/exercises/
```

### Generated `WIKI.md`

`WIKI.md` should be built from:

1. invariant wiki operating principles;
2. source/provenance rules;
3. operation definitions;
4. profile-specific page types and folder conventions;
5. index/log format;
6. user customization notes.

### Provenance rules to add

All profiles should include:

- create `wiki/sources/...` summaries for substantial raw sources;
- cite source pages from synthesized pages;
- use frontmatter with `created`, `updated`, `type`, `status`, `sources`, and optional `confidence`;
- log every ingest/query/lint that changes files;
- explicitly track contradictions or unresolved questions.

### Acceptance criteria

- `/wiki create <name> --profile generic` creates neutral scaffold.
- `/wiki create <name> --profile work` creates work/client overlay.
- Generated `index.md` matches the selected profile.
- Generated `WIKI.md` no longer assumes every wiki is about code, people, and tasks.

---

## Phase 5 — interactive setup wizard

Complexity: medium.

### Command

```txt
/wiki create
```

with no name should launch a UI wizard.

`/wiki create <name>` can either:

- use defaults and still ask for profile/path confirmation, or
- remain a non-interactive shortcut.

### Wizard questions

1. Wiki name.
2. Wiki location.
   - default: `<vaultRoot>/Spaces/<Title>` if `vaultRoot` is configured;
   - allow custom path.
3. Profile.
   - generic
   - work/client
   - research
   - self-improvement
   - project idea
   - book/course
4. Source types.
   - files/docs
   - meeting notes
   - current pi sessions
   - web articles
   - PDFs/images
   - journals
5. Default operation mode.
   - sidecar/background
   - inline
6. Model.
   - default from config
   - override per wiki
7. Review generated `WIKI.md` in editor before writing.
8. Confirm file creation.

### Design constraint

The wizard must be handled by extension UI. It should not send setup questions into the active LLM session.

### Acceptance criteria

- User can create a tailored wiki without polluting current chat context.
- User can edit generated `WIKI.md` before it is written.
- Existing files are never overwritten without confirmation.

---

## Phase 6 — explicit session attachment

Complexity: medium.

This should come after sidecar execution works.

### Commands

```txt
/wiki <name> capture --attach-last 5 <request>
/wiki <name> capture --attach-session <request>
/wiki <name> capture --attach-summary <request>
```

Potential aliases:

```txt
/wiki <name> <request> --attach-last 5
/wiki <name> <request> --attach-summary
```

### Attachment types

#### `none`

Default. No current session context is attached.

#### `last-n`

Read the active session and attach last N user/assistant messages from the current branch.

#### `summary`

Generate or request a compact summary first, then attach only that summary.

#### `selected`

Later: show a UI picker over recent messages and allow user selection.

### Implementation notes

Pi sessions are JSONL under `~/.pi/agent/sessions/`, and `/session` exposes session file/id. Extension may also use `ctx.sessionManager` to access current state.

The hard part is not reading the JSONL. The important part is pruning:

- avoid tool spam;
- avoid huge content;
- avoid secrets;
- respect current branch;
- make attachment explicit and auditable.

### Operation metadata

Record attachment details in `operation.json`:

```json
"attachedContext": {
  "type": "last-n",
  "messageCount": 5,
  "sourceSession": "/Users/.../session.jsonl",
  "sourceBranchLeaf": "..."
}
```

### Acceptance criteria

- Default sidecar operations attach no current-session context.
- User can explicitly attach recent session context.
- Attached context is visible in the saved operation prompt.
- The active chat still receives no synthetic operation prompt.

---

## Phase 7 — queueing, locks, and polish

Complexity: medium to medium-hard.

### Locking

Add per-wiki lock file:

```txt
<wiki>/.wiki/wiki.lock
```

Basic behavior:

- if another sidecar operation is running, either refuse or queue;
- stale locks can be cleared after checking pid/process existence;
- inline operations should warn if a sidecar operation is active.

### Queueing

Optional later:

```txt
<wiki>/.wiki/queue/
```

Start with refusal instead of queueing unless queueing is clearly needed.

### Better operation UI

Enhance `/wiki` menu to include:

- run operation
- list operations
- inspect failed operation
- create/register wiki
- open docs/help

### Git support

Later optional feature:

- detect if wiki root is in a git repo;
- show changed files after operation;
- optionally auto-commit with operation id.

### Acceptance criteria

- Concurrent sidecar writes to the same wiki are prevented or clearly queued.
- Stale operations can be diagnosed.
- Operation history is useful from both CLI and Obsidian/filesystem.

---

## External references and optional search integration

Complexity:

- Incorporating `Astro-Han/karpathy-llm-wiki` ideas: low.
- Adding basic `qmd` CLI detection/init/update/search: medium.
- Deep `qmd` SDK/MCP integration: medium-hard.

### `Astro-Han/karpathy-llm-wiki`

Recommendation: use as **prompt/schema inspiration**, not as the extension architecture.

Useful ideas to adapt into generated `WIKI.md` profiles:

- clear `raw/` → `wiki/` workflow;
- “always fetch raw + compile wiki” rule for ingest;
- initialize only missing files; never overwrite existing files;
- concrete templates for raw source files, wiki articles, archived query answers, and indexes;
- query behavior: read the index first, cite wiki pages, and do not write files unless asked;
- lint split:
  - deterministic checks can auto-fix;
  - heuristic checks should report only;
- cascade update rule after ingest;
- explicit conflict/contradiction annotation.

Do not copy it wholesale because it assumes:

- one wiki per project root;
- only `raw/` and `wiki/`;
- one-level topic directories;
- no Obsidian vault/profile model;
- no multi-wiki registry;
- no pi sidecar sessions;
- no interactive setup wizard;
- no explicit session attachment.

Implementation note: mine its `SKILL.md` and `references/*` templates when improving our generated `WIKI.md`, especially during Phase 4.

### `tobi/qmd`

Recommendation: integrate later as an **optional search backend**, not as an MVP dependency.

Good use cases:

- searching large wikis;
- searching across `wiki/`, `raw/`, and possibly the broader Obsidian vault;
- prefetching relevant files/snippets before a sidecar query;
- better file selection during ingest and lint;
- eventually exposing search through MCP if useful.

Do not make `qmd` mandatory. It downloads local models and adds setup/runtime complexity that is unnecessary for the first sidecar MVP.

Possible config shape:

```json
{
  "qmd": {
    "enabled": true,
    "collections": {
      "wiki": "wiki-spark",
      "raw": "raw-spark"
    }
  }
}
```

Possible setup commands:

```sh
qmd collection add <wiki>/wiki --name wiki-spark
qmd collection add <wiki>/raw --name raw-spark
qmd context add qmd://wiki-spark "Compiled Spark wiki pages"
qmd context add qmd://raw-spark "Immutable raw Spark source material"
qmd update
```

Potential future commands:

```txt
/wiki <name> search <query>
/wiki <name> qmd init
/wiki <name> qmd update
/wiki <name> query <question> --search qmd
```

Potential query flow:

```txt
/wiki spark query "What do I know about X?" --search qmd
→ qmd query --json --collection wiki-spark "What do I know about X?"
→ include top file paths/snippets in the sidecar prompt
→ sidecar reads full relevant files and answers with citations
```

### Recommendation summary

- Near term: adapt `karpathy-llm-wiki` templates/rules into our own generated schemas.
- Later: add `qmd` as an optional search/indexing layer.
- Avoid: replacing the pi extension with the external skill, or making `qmd` required for normal wiki use.

---

## Suggested implementation order

1. Phase 1: safety/config fixes.
2. Phase 2: blocking sidecar execution.
3. Phase 3: operation metadata/history.
4. Phase 4: profile-based scaffolding, using `karpathy-llm-wiki` as schema/template inspiration.
5. Phase 5: interactive setup wizard.
6. Phase 6: explicit session attachment.
7. Phase 7: locks, detached mode, queueing, and polish.
8. Optional later: `qmd` search integration.

Reasoning:

- Sidecar execution is the highest leverage behavior change.
- Blocking sidecar is enough to prove the design.
- Operation records make later detached mode and debugging much easier.
- Profiles and wizard are mostly additive after the execution model is fixed.
- `qmd` should wait until the wiki manager works without it.

---

## Open decisions / questions

These are not blockers for Phase 1, but should be decided before or during Phase 2–5.

1. Should sidecar mode be blocking first, or should the first implementation go directly to detached/background?
   - Recommendation: blocking first, then detached.

2. Where should wiki sidecar sessions live?
   - Option A: operation-local: `<wiki>/.wiki/operations/<id>/sessions/`
   - Option B: shared wiki-local: `<wiki>/.wiki/sessions/`
   - Recommendation: operation-local for easy discovery/auditing.

3. Should `.wiki/` be hidden implementation state, or should operation history be visible in Obsidian?
   - Recommendation: keep machine logs in `.wiki/`; append human summaries to `log.md`.

4. Should `/wiki <name> <request>` be detached by default eventually?
   - Recommendation: yes, after operation status/listing works.

5. Should the generic profile or the current work/client profile be the default?
   - Recommendation: generic for new wikis; preserve current Spark wiki as work/client.

6. Should the extension include profile templates inline in `index.ts`, or split into files?
   - Recommendation: start inline for speed; split once stable.

7. Should session attachment support raw `--attach-session`, or only safer `--attach-last` / `--attach-summary`?
   - Recommendation: support `--attach-last` first. Add full-session only with explicit warning/preview.

---

## Definition of done for MVP upgrade

MVP upgrade means:

- config handling is safe;
- wiki creation does not overwrite existing files accidentally;
- default background mode runs a real sidecar pi process;
- sidecar runs save normal resumable pi sessions;
- each operation writes an operation record and logs;
- current chat is not polluted by background operation prompts;
- generated schema includes stronger provenance rules.

This would move the extension from “wiki prompt launcher” to “basic isolated wiki manager.”
