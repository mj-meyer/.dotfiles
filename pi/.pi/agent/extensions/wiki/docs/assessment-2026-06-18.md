# Wiki Extension Assessment — 2026-06-18

I reviewed:

- `pi/.pi/agent/extensions/wiki/index.ts`
- `pi/.pi/agent/extensions/wiki/config.json`
- the current generated wiki at `/Users/t836307/Notes/Spaces/Spark/`
- Karpathy’s “LLM Wiki” gist
- relevant pi extension docs/examples for commands, UI, session handling, and `sendUserMessage`

I did **not** make changes during the assessment.

## Short verdict

This is a solid **first scaffold/launcher**, but it is not yet a strong implementation of the Karpathy wiki pattern.

Right now the extension mostly does three things:

1. Registers a global `/wiki` command.
2. Manages a small registry of wiki names → paths.
3. Creates a fixed, work-flavored wiki scaffold and routes future work by injecting a prompt into the current pi session.

The main mismatch: the gist is about a persistent, compounding knowledge artifact with careful source integration, provenance, query filing, linting, and schema co-evolution. Your extension currently creates the folders and tells an agent to behave that way, but it does not yet provide enough workflow, guardrails, setup tailoring, provenance model, or true background isolation.

---

## Biggest findings

### 1. Background mode is not actually isolated from the current session

In `executeWikiRequest`, background mode builds a prompt that says:

```ts
Use the subagent tool to run this wiki operation in a forked background context.
```

Then it sends that prompt into the current session:

```ts
pi.sendUserMessage(subagentMessage, { deliverAs: "followUp" });
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:320-333`

This means the current session still gets polluted with:

- the synthetic user message
- whatever tool calls/results the current agent produces
- any failures/confusion around subagent use

So it violates your desired behavior: “update any wiki without affecting any current sessions.”

Better design: the command handler should run the background job itself, not ask the current agent to do it. Options:

- spawn a separate `pi --mode json --no-session` process with `pi.exec`
- create a real extension tool/runner that directly calls a child agent process
- use `ctx.sessionManager.getBranch()` only when explicitly attaching current-session context
- write operation status to a wiki-local operation log or status file instead of the active chat

The current version is closer to “queue a follow-up request in my current agent” than “sidecar wiki operation.”

---

### 2. The default scaffold is very work/project oriented

The generated schema creates:

```txt
daily/
wiki/people/
wiki/code/
wiki/processes/
wiki/decisions/
wiki/tasks/
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:359-369`, schema at `424+`

That is useful for a workplace/client/project wiki, but it does not fit equally well for:

- a book
- a project idea
- self-improvement
- health tracking
- a research topic
- a personal philosophy area
- a contracting client relationship
- a hobby deep dive

The gist explicitly says the exact structure should depend on domain and preference. Your extension currently hardcodes one domain model.

I would not keep this as the universal default. I’d split it into:

#### Neutral base

Every wiki gets:

```txt
WIKI.md
index.md
log.md
raw/
raw/assets/
wiki/
wiki/sources/
wiki/concepts/
wiki/entities/
wiki/questions/
wiki/syntheses/
```

#### Optional profile overlays

Then interactive setup can add a profile:

- `work/client`: people, tasks, decisions, processes, meetings
- `research`: papers, claims, questions, experiments, bibliography
- `book`: chapters, characters, places, themes, timeline
- `self-improvement`: journal, patterns, goals, practices, reflections
- `business idea`: hypotheses, customers, competitors, experiments, decisions
- `contracting client`: stakeholders, systems, agreements, open loops, risks

---

### 3. Wiki creation needs to be interactive

Currently `/wiki create <name>` asks only for a name and writes the fixed scaffold.

Path: `pi/.pi/agent/extensions/wiki/index.ts:103-110`, `355-417`

For this use case, creation should be a setup wizard. The extension docs support this well via `ctx.ui.select`, `ctx.ui.input`, `ctx.ui.editor`, and `ctx.ui.custom`.

A good setup flow:

1. Wiki name
2. What kind of wiki is this?
   - work/client
   - project idea
   - self-improvement
   - research
   - book/course
   - generic
3. What should count as raw sources?
   - clipped articles
   - conversations
   - meeting notes
   - journals
   - PDFs
   - tweets
   - current pi sessions
4. What page types should exist?
5. Should the agent ask before changing existing pages?
6. Should substantial answers be auto-filed or offered?
7. Should operations auto-commit to git?
8. Should session context ever be attached by default?
9. Open generated `WIKI.md` in an editor for approval.

This can be done **without taking over the current agent context** because extension UI commands are “handled” by the extension. They don’t need to send a message to the model unless you explicitly choose to.

If you want an “agent asks the setup questions” experience, use a sidecar setup agent or direct model call inside the command, then show the draft `WIKI.md` in `ctx.ui.editor`. Do not use `pi.sendUserMessage` unless you want it in the current session.

---

### 4. Karpathy’s source/provenance layer is under-specified

The gist’s strongest idea is not just “make markdown pages.” It is:

> raw sources are immutable, and the wiki integrates them into evolving pages with synthesis, contradictions, citations, and bookkeeping.

Your schema says:

- never modify `raw/`
- ingest raw material
- create/update pages
- update index/log

Good start.

But it does not strongly specify:

- source pages/summaries
- citation format
- claim provenance
- confidence/staleness
- contradiction tracking
- source-to-page backlinks
- “this page was updated because of source X”
- how to handle conflicting evidence
- whether generated pages must cite raw sources

This is a major gap against the gist.

I’d add a generated `wiki/sources/` layer:

```txt
raw/                 immutable source files
wiki/sources/        generated source summaries / bibliographic metadata
wiki/concepts/       synthesized concepts
wiki/entities/       people/orgs/places/things
wiki/syntheses/      larger answers, comparisons, essays
```

And page frontmatter like:

```yaml
created: 2026-06-17
updated: 2026-06-17
type: concept
status: active
sources:
  - "[[wiki/sources/Some Article]]"
confidence: medium
```

For claims:

```md
Spark currently uses X for Y. Source: [[wiki/sources/Meeting 2026-06-10]]
```

Without that, the wiki will become polished but hard to audit.

---

### 5. Query filing is only partially represented

The gist emphasizes that good answers should be filed back into the wiki:

> a comparison you asked for, an analysis, a connection you discovered — these are valuable and shouldn’t disappear into chat history.

Your schema says:

```md
If the answer is substantial or reusable, offer to save it as a new wiki page
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:497-502`

Good. But it would be stronger if the schema defined where filed answers go:

```txt
wiki/syntheses/
wiki/comparisons/
wiki/questions/
```

And how to log them:

```md
## [YYYY-MM-DD] query | Question title
Question: ...
Saved: [[wiki/syntheses/...]]
Sources used: ...
```

Right now, query filing is a suggestion, not a robust workflow.

---

### 6. Lint is conceptually right but operationally weak

The gist recommends periodic health checks for:

- contradictions
- stale claims
- orphan pages
- missing cross-references
- concepts without pages
- data gaps
- source suggestions

Your schema covers some:

```md
- Orphan pages
- Stale information
- Missing pages
- People mentioned in logs but without a person page
- Tasks marked active with no recent updates
- Contradictions between pages
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:546-558`

Missing/weak:

- uncited claims
- sources not integrated into any page
- pages with no source provenance
- duplicate pages
- overgrown pages that should be split
- broken Obsidian wikilinks
- contradictions log
- data gaps / “questions to investigate next”
- suggested new sources/searches

I’d add a `wiki/maintenance/` or `.wiki/reports/` area for lint reports.

---

### 7. `index.md` and `log.md` exist, but they are too shallow

The gist makes `index.md` and `log.md` central:

- `index.md` is the navigation/catalog layer.
- `log.md` is a parseable chronological activity stream.

You create both. Good.

But `index.md` is hardcoded to work categories:

```md
## People
## Code & Architecture
## Processes
## Decisions
## Tasks
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:386-394`

For non-work wikis, this will fight the user.

`log.md` is append-only in concept, but the extension does not enforce append-only behavior. It just tells the agent to do it.

I’d make logs more structured:

```md
## [2026-06-17] ingest | Article title
operation_id: 2026-06-17T10-32-18Z-ingest-article-title
source: [[wiki/sources/...]]
created:
  - [[wiki/concepts/...]]
updated:
  - [[wiki/entities/...]]
open_questions:
  - ...
```

This makes the log grep-able and useful for future agents.

---

## Implementation concerns

### Critical / high priority

#### `loadConfig` swallows malformed JSON

```ts
async function loadConfig(): Promise<Config> {
  try {
    const raw = await readFile(CONFIG_PATH, "utf-8");
    return JSON.parse(raw);
  } catch {
    return {
      vaultRoot: "",
      wikis: {},
      defaults: ...
    };
  }
}
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:42-53`

If `config.json` exists but has invalid JSON, the extension silently treats it as empty. A later save could wipe intent. It should distinguish file-not-found from parse error.

#### `/wiki create` can overwrite existing wiki files

`createWiki` writes:

- `WIKI.md`
- `index.md`
- `log.md`

with no existence check or confirmation.

Path: `pi/.pi/agent/extensions/wiki/index.ts:376-406`

This is dangerous, especially because `WIKI.md` is supposed to co-evolve over time.

#### Path boundaries are only prompt-enforced

The task says:

```md
Only modify files within ...
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:306-310`

But there is no code-level path enforcement. A child agent can still edit elsewhere if it misunderstands. For a wiki extension, that is probably acceptable for MVP, but not robust.

At minimum:

- validate registered paths
- prevent `..` escapes
- resolve realpaths
- add a “wiki operation mode” tool-call guard if possible
- run child process with `cwd` set to wiki root
- instruct absolute path usage, as you already do

#### Background operations can race

Two wiki operations could update `index.md` or `log.md` at the same time. Since the extension wants background operation from anywhere, concurrent writes are likely.

Needs per-wiki locking or a queue.

---

### Medium priority

#### `defaults.mode` is unused

Config has:

```json
"defaults": {
  "model": "...",
  "mode": "background"
}
```

Path: `pi/.pi/agent/extensions/wiki/config.json:9-12`

But routing only checks for `--inline`.

Path: `pi/.pi/agent/extensions/wiki/index.ts:231-246`

So the config default mode currently has no effect.

#### Autocomplete is misleading

`getArgumentCompletions` suggests:

```ts
["create", "list", "register", "ingest", "query", ...]
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:70-76`

But command syntax is actually:

```txt
/wiki <name> <request>
```

If more than one wiki exists, `/wiki ingest ...` will be treated as an unknown wiki named `ingest`.

Autocomplete should probably suggest wiki names first, then operations after a selected wiki.

#### `log` operation exists in `OPERATIONS` but not in schema/menu

```ts
const OPERATIONS = ["ingest", "query", "lint", "daily", "task", "status", "log"];
```

Path: `pi/.pi/agent/extensions/wiki/index.ts:66`

But the menu does not include `log`, and the generated schema does not define a `log` operation except daily/log-ish behavior.

#### `dirname` is imported but unused

Path: `pi/.pi/agent/extensions/wiki/index.ts:20`

Small cleanup.

#### `ctx: any` loses extension type safety

Several helpers accept `ctx: any`. This hides mistakes around command context vs extension context.

---

## Answer to your “interactive without taking over context?” question

Yes, this is very doable in pi.

Use a slash command handler plus `ctx.ui`:

```txt
/wiki setup
```

The command can ask questions with:

- `ctx.ui.select`
- `ctx.ui.input`
- `ctx.ui.editor`
- `ctx.ui.confirm`
- `ctx.ui.custom`

Those UI interactions do **not** need to become LLM messages. The command handles the interaction, writes files, and exits. The current chat context stays clean.

For an agent-assisted setup wizard, there are two safer patterns:

### Pattern A: deterministic UI wizard, then generated schema

The extension asks structured questions, then generates `WIKI.md` from templates. No LLM needed.

Best for reliability.

### Pattern B: sidecar setup agent

The extension gathers answers, then runs a separate child pi/model process to draft a custom schema. The result is shown in an editor for approval. The current session is not touched.

Best for “agent interviews me” feeling.

### Pattern C: explicit current-session attachment

Only when requested:

```txt
/wiki spark capture --attach-last
/wiki spark capture --attach-session-summary
/wiki spark capture --attach-current-response
```

Then the extension reads `ctx.sessionManager.getBranch()`, extracts recent messages, and passes a bounded snapshot to the sidecar agent.

Default should be **no session context attached**.

---

## How I’d reshape the extension

### Keep

- global `/wiki` command
- central registry config
- per-wiki `WIKI.md`
- `index.md`
- `log.md`
- raw/wiki separation
- Obsidian-compatible markdown
- background/inline distinction

### Change

#### 1. Make `/wiki create` a wizard

Instead of only:

```txt
/wiki create spark
```

Support:

```txt
/wiki setup
/wiki create
/wiki create spark --profile research
```

The wizard should produce a tailored schema.

#### 2. Add neutral wiki profiles

Possible profile list:

```txt
generic
work
client
research
book
self
project-idea
business
course
hobby
```

#### 3. Replace hardcoded work folders with profile-generated folders

Generic default could be:

```txt
raw/
raw/assets/
wiki/
wiki/sources/
wiki/entities/
wiki/concepts/
wiki/questions/
wiki/syntheses/
wiki/maintenance/
index.md
log.md
WIKI.md
```

Work/client profile can add:

```txt
wiki/people/
wiki/tasks/
wiki/decisions/
wiki/processes/
wiki/systems/
daily/
```

Self-improvement can add:

```txt
wiki/patterns/
wiki/practices/
wiki/goals/
wiki/reflections/
journal/
```

Book profile can add:

```txt
wiki/chapters/
wiki/characters/
wiki/places/
wiki/themes/
wiki/timeline/
```

#### 4. Make background execution actually sidecar

Do not use `pi.sendUserMessage` for background operations.

Use a child process or direct extension-runner logic.

#### 5. Add explicit session attachment modes

Useful commands:

```txt
/wiki spark capture <thought>
/wiki spark capture --attach-last <thought>
/wiki spark capture --attach-session <thought>
/wiki spark ingest @path
/wiki spark query <question>
/wiki spark lint
/wiki spark doctor
```

#### 6. Add operation metadata

Each operation should have:

- operation id
- wiki name
- mode
- request
- attached context yes/no
- files changed
- log entry
- error/success status

This could live in:

```txt
.wiki/operations/
.wiki/locks/
.wiki/reports/
```

or visible Obsidian pages if you want.

---

## Alignment with the Karpathy gist

| Gist concept | Current extension | Assessment |
|---|---|---|
| Raw sources immutable | Has `raw/`, says never modify | Good start, but no source metadata/citation model |
| Generated wiki layer | Has `wiki/` | Good |
| Schema file | Uses `WIKI.md` | Good |
| Schema co-evolves | Mentions this | Not operationalized |
| Ingest workflow | Described in schema | Partial; no provenance requirements |
| Query workflow | Described | Partial; save-back is optional but under-specified |
| Lint workflow | Described | Partial; missing citation/source health checks |
| `index.md` | Created | Good but hardcoded and work-biased |
| `log.md` | Created | Good but should be more structured |
| Citations | Not emphasized | Gap |
| Contradiction handling | Mentioned in lint | Needs stronger workflow/artifact |
| Obsidian compatibility | Yes | Good |
| Dataview/frontmatter | Basic YAML only | Could be stronger |
| Images/assets | Creates `raw/assets` | Missing image-reading workflow |
| Search/qmd | Not covered | Fine for MVP |
| Git/versioning | Not covered | Gap for safety/collaboration |

---

## Recommended next priority

If you want this to become genuinely useful, I’d prioritize in this order:

1. **Fix execution isolation**: background wiki operations should not enter the current chat.
2. **Make create/setup interactive**: generate domain-specific `WIKI.md`.
3. **Replace work-only scaffold with profile-based schema generation.**
4. **Add provenance/citation rules to the schema.**
5. **Protect existing wikis from overwrite.**
6. **Add config validation and path safety.**
7. **Improve index/log formats for long-term maintainability.**

The core idea is good. The current implementation is a useful MVP, but it is more of a “wiki prompt launcher” than a full “wiki manager” right now.
