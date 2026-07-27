export const meta = {
  name: 'milestone_bead',
  description: 'Implement one milestone bead end-to-end: brief from the bead text, multi-angle recon, implement (with injected skills), lens-based verify with skeptics on judgment lenses only, bounded fix-loop, finalize with a strict bar on follow-up beads. Invoke with args: { beadId: "weaver-xxx" }',
  phases: [
    { title: 'Brief' },
    { title: 'Recon' },
    { title: 'Implement' },
    { title: 'Verify' },
    { title: 'Fix' },
    { title: 'Finalize' },
  ],
}

// ─── Inputs ──────────────────────────────────────────────────────────────
const parsedArgs = typeof args === 'string' ? JSON.parse(args) : args
const beadId = parsedArgs?.beadId
if (!beadId) throw new Error('args.beadId required — e.g. { beadId: "weaver-xxx" }')

// User must explicitly opt in to letting agents run `alchemy dev/plan` against
// the live Cloudflare account (bd memory: alchemy-cli-uses-profile-creds-and-mutates).
const truthy = (value) => value === true || value === 'true' || value === '1' || value === 'yes' || value === 'on'
const intArg = (value, fallback) => {
  const n = Number(value)
  return Number.isFinite(n) && n > 0 ? n : fallback
}
const nonNegativeIntArg = (value, fallback) => {
  const n = Number(value)
  return Number.isInteger(n) && n >= 0 ? n : fallback
}
const allowAlchemyDev = truthy(parsedArgs?.allowAlchemyDev)
const MAX_ROUNDS = intArg(parsedArgs?.maxRounds, 3)
const MAX_FOLLOWUPS = nonNegativeIntArg(parsedArgs?.maxFollowups, 2)

// New workflow tool routing: model/tier selection is controlled by the parent
// Pi session/tool invocation. Keep these helpers so the port stays close to the
// old script, but do not pass old dynamic-workflow-only tier/model/phase options
// into agent().
const roleOpt = (_role) => ({})
const verifierRoleOpt = (_lensName) => ({})

// ─── Lens library ────────────────────────────────────────────────────────
// kind: 'mechanical' lenses produce command-output evidence (greps, test runs)
//       and get NO skeptic pass — re-running the command is the refutation.
//       'judgment' lenses involve interpretation and DO get a skeptic.
// A bead may also define custom lenses inline (name + kind + instruction in its
// "## Verification lenses" section); those override / extend this library.
const LENS_LIBRARY = {
  'ac-coverage': {
    kind: 'judgment',
    instruction: () => `Read 'bd show ${beadId}' and enumerate every "- [ ]" checkbox in the Acceptance Criteria. For each, find concrete evidence in the working tree (file:line, test output, screenshot) that satisfies it. A checkbox without evidence = fail. Be specific — "the auth gate works" is NOT evidence; "apps/web/src/routes/_authed.tsx:12 wraps /chat/* in a beforeLoad that redirects to /signin when context.session is null, and the test at apps/web/src/tests/auth-gate.test.ts:34 passes" IS evidence.
${allowAlchemyDev ? `Special case: if an AC mentions "alchemy plan clean" or "deploy parity", run 'alchemy plan' (authorised for this run). Capture exit code + final ~20 lines as evidence. Exit 0 with no errors = pass; any error = fail with the excerpt.` : `If an AC requires 'alchemy plan' / live deploy verification, mark that AC as deferred-to-human in your evidence (do NOT run alchemy) and judge the lens on the remaining ACs; note the deferral (kind=out_of_scope, suggested_bead_title naming the human verification).`}`,
  },
  'effect-idiom': {
    kind: 'judgment',
    instruction: () => `Audit the diff for Effect v4 correctness. Pass conditions: no Effect.catchAll (use Effect.match/matchEffect), Effect.gen inside DO methods uses the { self: this } form, Data.TaggedError subclasses for typed errors, error serialisation via Object.getOwnPropertyNames where logged (message is non-enumerable). Fail on any v3 idiom. When unsure of the v4 form, grep repos/effect-smol. Cite file:line for each pass/fail item.`,
  },
  'pattern-fidelity': {
    kind: 'judgment',
    instruction: () => `Each non-trivial pattern in the diff should map to a vendored source under repos/ (effect-smol, agents, pi-mono, alchemy) or an ADR. For each major implementation choice, find the corresponding file:line in repos/ that the implementer drew from, or the ADR justifying divergence. Fail if a major pattern has neither.`,
  },
  'ui-behavior': {
    kind: 'judgment',
    instruction: (uiFlow) => `Use the agent-browser CLI ('agent-browser --help' for syntax). You need a running website serving the SSR routes. Options in order of preference:
${allowAlchemyDev ? `(A) AUTHORISED for this run: 'alchemy dev' in a detached tmux session (tmux new-session -d). Wait for the deploy URL, then drive agent-browser against it. If the flow needs GitHub OAuth, start emulate too ('npx emulate start --port 4001 --service github --seed emulate.config.yaml', detached tmux session) and ensure BETTER_AUTH_GITHUB_BASE_URL points at it. Stop both tmux sessions when done (tmux kill-session).` : `(A) unavailable — 'alchemy dev' is NOT authorised for this run.`}
(B) 'pnpm --filter @weaver/web dev' (bare vite). May fail on 'cloudflare:workers' imports — if so report that as the blocker and try (C).
(C) vitest-pool-workers serves SSR routes inside real workerd without deploying (see apps/runtime/wrangler.test.jsonc for the pattern). HTTP-level assertions only — sufficient for redirects/status codes, not for visual rendering.

The user-visible flow to drive: ${uiFlow || `whatever flow the bead description specifies — re-read 'bd show ${beadId}'.`}
Save screenshots and reference them as evidence. Fail if any step diverges from the bead's described behaviour.`,
  },
  'security': {
    kind: 'judgment',
    instruction: () => `Audit the diff's new/changed surfaces for authorization and isolation. Checks: every new route/endpoint/WS path verifies the session cookie before doing work; everything Organization-scoped filters by the cookie-derived organizationId (never a client-supplied one); DO names and R2 key prefixes preserve the {organizationId}:{sessionId} / {organizationId}/... discipline; no secrets in logs or client-visible payloads; failure paths are fail-closed. Fail with file:line for any gap.`,
  },
  'regression': {
    kind: 'mechanical',
    instruction: () => `Run 'pnpm typecheck' and 'pnpm -r test'. Every previously-passing test must still pass. Paste the summary lines (test counts per package, exit codes) as evidence. Even one regression = fail, naming the broken test.`,
  },
  'anti-pattern': {
    kind: 'mechanical',
    instruction: () => `Grep the diff (and any files it touches) for the project's forbidden patterns: imports from repos/** (read-only vendored source), process.env in worker code (use effect/Config), direct R2 calls from the Harness (must go through the Sandbox seam), new tables that collide with the cf_agents_* / cf_workspace_* / cf_weaver_* disjoint-prefix discipline, top-level static 'cloudflare:email' imports (local workerd boot bug). Paste each grep command + output as evidence. Any hit = fail with file:line.`,
  },
  'grep-gate': {
    kind: 'mechanical',
    instruction: (custom) => custom || `The bead did not supply grep-gate commands. Re-read 'bd show ${beadId}' for a "## Verification lenses" entry defining them; if none exists, fail this lens and say so — a grep-gate without commands is a bead-authoring bug.`,
  },
}

// ─── Skill catalog ───────────────────────────────────────────────────────
// Skills installed on this machine that map to this stack. The Brief phase
// picks ≤3 per bead (or honours the bead's "## Relevant skills" section);
// recon/implement/ui-verify agents load them before working.
const SKILL_CATALOG = `
- cloudflare           : anything Workers/KV/D1/R2/platform-wide on Cloudflare
- workers-best-practices: authoring/reviewing Worker code (streaming, floating promises, bindings)
- durable-objects      : DO design, RPC methods, SQLite storage, alarms, WebSockets
- agents-sdk           : Cloudflare agents-SDK (Agent class, routeAgentRequest, useAgent, state)
- sandbox-sdk          : @cloudflare/sandbox / code-execution surfaces
- alchemy              : Alchemy IaC (alchemy.run.ts, bindings, dev/deploy model)
- wrangler             : wrangler CLI syntax and config
- tdd                  : red-green-refactor when the bead is test-first
- frontend-design      : building distinctive, production-grade UI
- design-taste-frontend: UI/UX engineering rules, component architecture
- shadcn               : shadcn/ui components and registries
- vercel-react-best-practices: React/Next perf + correctness patterns
- vercel-composition-patterns: React composition/component-API design
- agent-browser        : driving a browser to verify user-visible flows
- diagnose             : disciplined debugging when a bead is a bug-fix
- ai-sdk               : Vercel AI SDK specifics (only if a bead touches it)
`

const SKILL_LOADING = (skills) => skills?.length ? `
SKILLS — load these BEFORE starting work; they carry stack-specific knowledge that
overrides your pretrained assumptions:
${skills.map((s) => `- ${s}`).join('\n')}
To load a skill in Pi: read the relevant SKILL.md directly before work. Project/user skills usually live at ~/.pi/agent/skills/<name>/SKILL.md or ~/.agents/skills/<name>/SKILL.md. Follow the skill's guidance for any retrieval it recommends (e.g. fetching current Cloudflare docs).` : ''

// ─── Schemas ─────────────────────────────────────────────────────────────
const NOTE_SCHEMA = {
  type: 'object',
  required: ['kind', 'summary'],
  properties: {
    kind: { type: 'string', enum: ['surprise', 'improvement_idea', 'out_of_scope', 'anti_pattern_deferred', 'retrospective'] },
    summary: { type: 'string', description: 'One-sentence description of what was noted.' },
    detail: { type: 'string', description: 'Optional longer context — file refs, what was tried, why it matters.' },
    suggested_bead_title: { type: 'string', description: 'If this should become a follow-up bd issue, the title to use. Most notes should NOT become beads — see the Finalize bar.' },
    suggested_bead_priority: { type: 'integer', minimum: 0, maximum: 4 },
  },
}

const BRIEF_SCHEMA = {
  type: 'object',
  required: ['title', 'summary', 'lenses', 'skills', 'recon_angles'],
  properties: {
    title: { type: 'string' },
    summary: { type: 'string', description: 'Two-to-four sentence digest of what the bead delivers and its tracer-bullet behaviour.' },
    acceptance_criteria: { type: 'array', items: { type: 'string' } },
    lenses: {
      type: 'array',
      minItems: 1,
      items: {
        type: 'object',
        required: ['name', 'kind'],
        properties: {
          name: { type: 'string' },
          kind: { type: 'string', enum: ['mechanical', 'judgment'] },
          instruction: { type: 'string', description: 'Custom instruction text. Required for lenses not in the library and for grep-gate; omit to use the library instruction.' },
        },
      },
    },
    skills: { type: 'array', items: { type: 'string' }, description: 'Skill names from the catalog, ≤3 unless the bead pins more.' },
    recon_angles: { type: 'array', items: { type: 'string', enum: ['repos', 'external', 'surface'] }, minItems: 1 },
    ui_flow: { type: 'string', description: 'If a ui-behavior lens is present: the concrete user-visible flow to drive, extracted from the bead.' },
  },
}

const RECON_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['topic', 'source', 'pattern_or_rule'],
        properties: {
          topic: { type: 'string', description: 'What aspect of the bead this finding informs.' },
          source: { type: 'string', description: 'Where found — file:line for repos/, URL for external docs, ADR number, skill name.' },
          pattern_or_rule: { type: 'string', description: 'The concrete code pattern, idiom, or rule to follow.' },
          caveats: { type: 'string', description: 'Known gotchas, version skew, or anti-patterns to avoid.' },
        },
      },
    },
    notes: { type: 'array', items: NOTE_SCHEMA, default: [] },
  },
}

const IMPLEMENT_SCHEMA = {
  type: 'object',
  required: ['summary', 'files_changed', 'commit_sha'],
  properties: {
    summary: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    commit_sha: { type: 'string', description: 'The git commit sha created (or "<dirty>" if committing failed and the diff is staged).' },
    ac_coverage: {
      type: 'array',
      description: 'Self-report of how each AC checkbox is intended to be covered. Verify will cross-check.',
      items: {
        type: 'object',
        required: ['ac_text', 'covered_by'],
        properties: { ac_text: { type: 'string' }, covered_by: { type: 'string' } },
      },
    },
    notes: { type: 'array', items: NOTE_SCHEMA, default: [] },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['lens', 'pass', 'evidence'],
  properties: {
    lens: { type: 'string' },
    pass: { type: 'boolean', description: 'True only if the implementation cleanly satisfies this lens. Default to false if uncertain.' },
    evidence: { type: 'array', items: { type: 'string' }, minItems: 1, description: 'Concrete evidence lines (file:line, command + output excerpt, screenshot path, or explicit "could not find X"). Required regardless of pass/fail.' },
    failure_reason: { type: 'string' },
    fix_hint: { type: 'string' },
    notes: { type: 'array', items: NOTE_SCHEMA, default: [] },
  },
}

const SKEPTIC_SCHEMA = {
  type: 'object',
  required: ['refuted', 'reasoning'],
  properties: {
    refuted: { type: 'boolean', description: 'True if you found a hole in the pass claim. Default to true if uncertain.' },
    reasoning: { type: 'string', description: 'Cite concrete evidence (file:line, command output).' },
    notes: { type: 'array', items: NOTE_SCHEMA, default: [] },
  },
}

const FINALIZE_SCHEMA = {
  type: 'object',
  required: ['closed', 'followup_beads_created', 'comment_text'],
  properties: {
    closed: { type: 'boolean', description: 'True if `bd close` was run on the bead.' },
    followup_beads_created: {
      type: 'array',
      items: {
        type: 'object',
        required: ['bead_id', 'title'],
        properties: { bead_id: { type: 'string' }, title: { type: 'string' } },
      },
    },
    considered_not_filed: { type: 'array', items: { type: 'string' }, description: 'Candidate follow-ups that did not clear the bar (also listed in the retro comment).' },
    comment_text: { type: 'string', description: 'The retrospective comment added to the bead.' },
    residuals: { type: 'string', description: 'If closed=false, the specific lens failures that remain.' },
  },
}

// ─── Shared context ──────────────────────────────────────────────────────
const ALCHEMY_DEV_POLICY = allowAlchemyDev
  ? `- AUTHORISED FOR THIS RUN: 'alchemy plan' and 'alchemy dev' are permitted for verification ONLY.
    They mutate the user's live Cloudflare account (state-store always; full stack on 'dev').
    Run 'alchemy dev' in a detached tmux session with a unique name, wait for the deploy URL via
    'tmux capture-pane', then stop it with 'tmux kill-session -t <session>'. 'alchemy deploy'
    and 'alchemy destroy' are STILL forbidden.`
  : `- Do not run 'alchemy plan' / 'alchemy dev' / 'alchemy deploy' — they mutate the user's
    Cloudflare account. Stick to typecheck/test/grep/agent-browser/vitest-pool-workers.`

const REPO_CONTEXT = `
Project: weaver (Cloudflare Workers + agents-SDK + Pi harness; Effect v4; Alchemy v2).
Working tree root: /Users/mjmeyer/Personal/FabricLabz/weaver
CLAUDE.md, AGENTS.md, CONTEXT.md and docs/agents/milestone-protocol.md at repo root are required reading.
Hard constraints:
- Effect v4 ONLY. No v3 idioms (no catchAll — use Effect.match/matchEffect; Effect.gen({ self: this }, function*(){...}) form inside DOs).
- The repos/ directory is read-only vendored source for grep inspiration. NEVER import from repos/**, never build it, never edit it.
- The model is Workers AI kimi-k2 via the existing AI Gateway seam — a deliberate decision. Do NOT propose or implement switching models/providers.
- The bd CLI is the canonical task tracker ('bd show', 'bd create', 'bd comments add', 'bd close', 'bd search'). Do not use TodoWrite or markdown todo lists.
- Do not push to remote. Commits OK; pushing is reserved for the human.
${ALCHEMY_DEV_POLICY}
`

// ─── Prompts ─────────────────────────────────────────────────────────────
const briefPrompt = `${REPO_CONTEXT}

You are the brief agent for bead ${beadId}. Run 'bd show ${beadId}' (and 'bd comments list ${beadId}' if comments exist) and produce the structured brief that configures the rest of this workflow.

Rules:
1. LENSES — if the bead has a "## Verification lenses" section, honour it exactly: each entry names a lens, optionally its kind and a custom instruction. Library lenses (use these names verbatim): ac-coverage, effect-idiom, pattern-fidelity, ui-behavior, security, regression, anti-pattern, grep-gate. Entries marked mechanical/judgment keep that kind; unknown lens names require an inline instruction from the bead (carry it through) and default to kind=judgment.
   If the section is ABSENT, compose defaults: always [ac-coverage, regression, anti-pattern]; add effect-idiom if the bead touches Effect-typed code (apps/runtime, packages/core); add ui-behavior (and extract ui_flow) if the bead describes user-visible behaviour; add security if the bead adds/changes a route, WS path, or anything Organization-scoped; add pattern-fidelity only if the bead introduces a new dependency or technology not yet in the codebase.
   Keep the lens set MINIMAL — every lens costs a verifier agent. Do not add a lens without a reason.
2. SKILLS — if the bead has a "## Relevant skills" section, use it. Otherwise pick AT MOST 3 from this catalog (fewer is better; zero is fine for pure-refactor beads):
${SKILL_CATALOG}
3. RECON ANGLES — 'surface' always. Add 'repos' if vendored patterns (Effect/agents-SDK/Pi/Alchemy idioms) matter for this bead. Add 'external' ONLY if the bead references external tech/docs not covered by repos/ or a skill.
4. Extract acceptance_criteria verbatim (the "- [ ]" lines).

Return the structured brief.`

function reconPrompt(angle, brief) {
  const angles = {
    repos: `Grep repos/ — repos/effect-smol, repos/agents (cloudflare agents-SDK), repos/pi-mono, repos/alchemy — for patterns directly relevant to this bead. Focus on the seams the bead touches; bring back concrete file:line citations the implementer can imitate.`,
    external: `Read the bead via 'bd show ${beadId}', then fetch the external docs it references. Also read any ADRs it names (docs/adr/) and CONTEXT.md. Check 'bd memories <keyword>' for stored gotchas about the technologies involved.`,
    surface: `Read the bead via 'bd show ${beadId}'. From its scope/deliverables, enumerate the exact files this bead needs to create or modify. For each: does it exist, what does it look like now, what should it look like after. Also run 'bd memories' searches for keywords matching the bead's topics — stored gotchas regularly save hours here.`,
  }
  return `${REPO_CONTEXT}
${SKILL_LOADING(brief.skills)}

You are a recon agent for bead ${beadId} ("${brief.title}"). Angle: ${angle}.

Bead summary: ${brief.summary}

${angles[angle]}

Return structured findings. Each finding cites a source (file:line, URL, ADR, or skill) and a concrete pattern/rule the implementer should follow. Flag anything surprising as a note (kind=surprise or improvement_idea). Do not write any code.`
}

function implementPrompt(brief, reconOutputs, prior) {
  const priorBlock = prior ? `
PRIOR ROUND FAILED LENSES (you must fix these):
${JSON.stringify(prior, null, 2)}

The prior commit already exists. Build on it. Do NOT revert it; add a follow-up commit (amend ONLY if the prior commit is yours from this same workflow run and you genuinely improved a single file — prefer follow-up commits).` : ''

  return `${REPO_CONTEXT}
${SKILL_LOADING(brief.skills)}

You are the implementer for bead ${beadId}. Read the bead via 'bd show ${beadId}' for the full AC.

Recon findings (ground your implementation in the codebase's actual patterns):
${JSON.stringify(reconOutputs, null, 2)}
${priorBlock}

FIRST: check for prior implementation work before writing any code.
- Run 'git log --oneline -30' and look for commits referencing ${beadId}.
- If recent commits exist and the diff against the bead's scope is substantially complete, DO NOT re-implement: run 'pnpm typecheck' + 'pnpm -r test' to confirm prior work is green, report files_changed from those commits, commit_sha = the latest relevant commit, map each AC to its covering file/test, and note that prior work was reused.
- Otherwise implement (or finish implementing) per the rules below.

Implementation rules:
- Write the code. Run 'pnpm typecheck' and 'pnpm -r test' as you go. Fix what you break.
- Match the codebase's existing Effect v4 patterns. When in doubt, grep repos/effect-smol for the right idiom.
- Keep the diff scoped to the bead. Out-of-scope discoveries: note them (kind=out_of_scope) — do NOT expand the diff. Anti-patterns you couldn't fix in scope: note (kind=anti_pattern_deferred).
- When the diff compiles and the AC look satisfied:
    git add <files>
    git commit -m "<imperative summary referencing ${beadId}>"
  (HEREDOC for multi-line messages.) Return the commit sha. Do NOT push.
- If you cannot commit (pre-commit hook failing repeatedly), leave the diff staged and return commit_sha="<dirty>" with a note explaining why.

Return your implementation report.`
}

function lensInstructionFor(lens, brief) {
  if (lens.instruction) return lens.instruction
  const lib = LENS_LIBRARY[lens.name]
  if (!lib) return `No instruction available for unknown lens "${lens.name}" — fail and report this as a bead-authoring bug.`
  return lib.instruction(lens.name === 'ui-behavior' ? brief.ui_flow : undefined)
}

function verifyPrompt(lens, brief, implementResult) {
  const needsBrowser = lens.name === 'ui-behavior'
  return `${REPO_CONTEXT}
${needsBrowser ? SKILL_LOADING(['agent-browser']) : ''}

You are an adversarial verifier for bead ${beadId}, lens "${lens.name}" (${lens.kind}). Default to pass=false if you cannot find clean, concrete evidence of pass.

Implementation summary:
${JSON.stringify(implementResult, null, 2)}

Your check: ${lensInstructionFor(lens, brief)}

Return a verdict. evidence[] is REQUIRED whether pass=true or pass=false. If pass=false, supply failure_reason and fix_hint so the implementer can act.`
}

function skepticPrompt(lens, verdict) {
  return `${REPO_CONTEXT}

A verifier claims lens "${lens.name}" passes for bead ${beadId}. Your job: try to refute the claim. Default to refuted=true if you cannot positively verify the evidence is sound.

Claimed evidence:
${JSON.stringify(verdict.evidence, null, 2)}

Approaches:
- Re-read each cited file:line and confirm it says what the verifier claimed.
- Look for adjacent code paths the verifier didn't check.
- Look for happy-path bias: success case checked, failure mode not.
- For browser evidence, screenshots can mislead — was the actual behaviour what the bead asks for, or just a similar-looking page?

Reasoning must cite concrete evidence (file:line, command output). If refuted=true, explain exactly what the implementer must fix.`
}

function finalizePrompt(brief, allGreen, rounds, verdicts, allNotes) {
  return `${REPO_CONTEXT}

Workflow for bead ${beadId} ("${brief.title}") is wrapping up.

Status: ${allGreen ? 'ALL GREEN' : 'NOT ALL GREEN — residuals remain'}
Verify rounds taken: ${rounds}

Final verdicts:
${JSON.stringify(verdicts, null, 2)}

Collected notes from all phases (deduplicate as you process):
${JSON.stringify(allNotes, null, 2)}

Your job — execute in this order:

1. Split notes into (a) workflow retrospective material and (b) candidate follow-up work.

2. Apply THE BAR to every candidate. File a bd issue ONLY if at least one holds:
   - DEFECT: a genuine bug or security gap in code that is now committed (not hypothetical, not style).
   - DEFERRED AC: an acceptance criterion of THIS bead that was explicitly deferred during this run (e.g. human-only verification like 'alchemy plan').
   - MILESTONE BLOCKER: it concretely blocks or de-risks a named milestone in docs/roadmap.md — name the milestone in the description.
   Everything else — doc nits, comment wording, speculative refactors, nice-to-have hygiene, process suggestions — goes in the retro comment under "Considered, not filed" and NOWHERE else. When in doubt, do not file.

3. DEDUPE before every create: run 'bd search "<2-3 keywords>"'. If an open bead already covers it, add a comment there ('bd comments add <id> ...') instead of creating a duplicate.

4. HARD CAP: at most ${MAX_FOLLOWUPS} new beads from this run. If more clear the bar, file the highest-priority ones and list the rest under "Considered, not filed" so a human can promote them.
   Priority discipline: P1 only for security/data-loss, P2 for defects, P3 for milestone blockers. Each created bead: bd create --title "<concrete title>" --description "<why this exists, the bar criterion it met, link back to ${beadId}>" --type=task --priority=<N> --json

5. Compose a retrospective comment for ${beadId} (markdown): workflow stats (rounds, lenses, agents), what went well, what was hard, follow-up beads filed (ids + titles), "Considered, not filed" list${allGreen ? '' : ', and Residuals: the lenses still failing with their fix_hints'}.
   Add it (bd comments does NOT read stdin — write a temp file first):
     Write the markdown to /tmp/${beadId}-retro.md, then: bd comments add ${beadId} -f /tmp/${beadId}-retro.md

6. ${allGreen
    ? `Close the bead: bd close ${beadId} — then verify with 'bd show ${beadId}' that status=closed.`
    : `Do NOT close the bead. Leave it open; the human decides whether to re-invoke the workflow or take over.`}

Return a structured report including the follow-up bead ids you created and the considered-not-filed list.`
}

// ─── Run ─────────────────────────────────────────────────────────────────
phase('Brief')
const brief = await agent(briefPrompt, { schema: BRIEF_SCHEMA, label: `brief ${beadId}`, ...roleOpt('brief') })
if (!brief) throw new Error('brief agent failed — cannot configure workflow')
log(`Brief: "${brief.title}" — lenses: ${brief.lenses.map((l) => `${l.name}(${l.kind})`).join(', ')}; skills: ${brief.skills.join(', ') || 'none'}; recon: ${brief.recon_angles.join(', ')}`)

phase('Recon')
const reconResults = await parallel(
  brief.recon_angles.map((a) => () => agent(reconPrompt(a, brief), { schema: RECON_SCHEMA, label: `recon ${a}`, ...roleOpt('recon') }))
)
const reconForImpl = Object.fromEntries(brief.recon_angles.map((a, i) => [a, reconResults[i]?.findings ?? []]))
const allNotes = reconResults.filter(Boolean).flatMap((r) => r.notes ?? [])

phase('Implement')
let implementResult = await agent(implementPrompt(brief, reconForImpl, null), { schema: IMPLEMENT_SCHEMA, label: 'implement', ...roleOpt('implement') })
if (implementResult?.notes) allNotes.push(...implementResult.notes)
log(`Implement committed: ${implementResult?.commit_sha ?? '<none>'} — ${implementResult?.files_changed?.length ?? 0} files`)

const lensByName = Object.fromEntries(brief.lenses.map((l) => [l.name, l]))
const verdicts = {}
let pendingLenses = brief.lenses.map((l) => l.name)
let round = 0

while (round < MAX_ROUNDS && pendingLenses.length > 0) {
  round++
  phase('Verify')

  log(`Round ${round}: verifying ${pendingLenses.length} lens(es) — ${pendingLenses.join(', ')}`)

  const newVerdicts = await parallel(
    pendingLenses.map((name) => () =>
      agent(verifyPrompt(lensByName[name], brief, implementResult), {
        schema: VERDICT_SCHEMA,
        label: `verify r${round} ${name}`,
        ...verifierRoleOpt(name),
      })
    )
  )

  pendingLenses.forEach((name, i) => {
    const v = newVerdicts[i]
    verdicts[name] = v ?? { lens: name, pass: false, evidence: ['verifier agent returned null'], failure_reason: 'agent failure' }
    if (v?.notes) allNotes.push(...v.notes)
  })

  // Skeptics refute pass claims — JUDGMENT lenses only. Mechanical lens evidence
  // is command output; re-running the command is the refutation, a skeptic is waste.
  const passJudgment = pendingLenses.filter((n) => verdicts[n]?.pass === true && lensByName[n].kind === 'judgment')
  if (passJudgment.length > 0) {
    log(`Round ${round}: skeptics refuting ${passJudgment.length} judgment pass claim(s)`)
    const skeptics = await parallel(
      passJudgment.map((name) => () =>
        agent(skepticPrompt(lensByName[name], verdicts[name]), {
          schema: SKEPTIC_SCHEMA,
          label: `skeptic r${round} ${name}`,
          ...roleOpt('skeptic'),
        })
      )
    )
    passJudgment.forEach((name, i) => {
      const s = skeptics[i]
      if (s?.refuted) {
        verdicts[name] = {
          ...verdicts[name],
          pass: false,
          failure_reason: `skeptic refuted: ${s.reasoning}`,
          fix_hint: verdicts[name].fix_hint || s.reasoning,
        }
      }
      if (s?.notes) allNotes.push(...s.notes)
    })
  }

  pendingLenses = brief.lenses.map((l) => l.name).filter((n) => verdicts[n]?.pass !== true)
  log(`Round ${round} complete. Still failing: ${pendingLenses.length === 0 ? 'none' : pendingLenses.join(', ')}`)

  if (pendingLenses.length === 0) break

  if (round < MAX_ROUNDS) {
    phase('Fix')
    const failedDetails = pendingLenses.map((n) => ({
      lens: n,
      failure_reason: verdicts[n]?.failure_reason,
      fix_hint: verdicts[n]?.fix_hint,
      evidence: verdicts[n]?.evidence,
    }))
    const fixResult = await agent(implementPrompt(brief, reconForImpl, failedDetails), {
      schema: IMPLEMENT_SCHEMA,
      label: `fix round ${round}`,
      ...roleOpt('implement'),
    })
    if (fixResult?.notes) allNotes.push(...fixResult.notes)
    if (fixResult) implementResult = fixResult
    log(`Fix round ${round} committed: ${fixResult?.commit_sha ?? '<none>'}`)
  }
}

const allGreen = pendingLenses.length === 0

phase('Finalize')
const finalize = await agent(finalizePrompt(brief, allGreen, round, verdicts, allNotes), {
  schema: FINALIZE_SCHEMA,
  label: 'finalize',
  ...roleOpt('finalize'),
})

return {
  beadId,
  title: brief.title,
  allGreen,
  rounds: round,
  verdicts,
  finalize,
  notesCount: allNotes.length,
}
