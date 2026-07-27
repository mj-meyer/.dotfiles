/**
 * Wiki Extension — Generic LLM-maintained wiki system (Global)
 *
 * Lives in ~/.pi/agent/extensions/wiki/ so it's available in ANY pi session.
 * All wiki paths are resolved from the configured vaultRoot, not ctx.cwd.
 *
 * Commands:
 *   /wiki                        → Interactive menu (select wiki + operation)
 *   /wiki <name> <request>       → Run in background (forked context, default model)
 *   /wiki <name> --inline <req>  → Run in current session
 *   /wiki create <name>          → Scaffold a new wiki
 *   /wiki list                   → Show registered wikis
 *   /wiki register <name> <path> → Register an existing wiki (path relative to vault)
 *
 * Config: ~/.pi/agent/extensions/wiki/config.json
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";

interface WikiConfig {
  path: string; // Relative to vault (or vaultRoot if vault not set)
  vault?: string; // Optional per-wiki vault root (absolute). Falls back to top-level vaultRoot.
  model?: string;
}

interface Config {
  vaultRoot: string; // Absolute path to the Obsidian vault
  wikis: Record<string, WikiConfig>;
  defaults: {
    model: string;
    mode: "background" | "inline";
  };
}

const CONFIG_PATH = join(
  process.env.HOME || "~",
  ".pi/agent/extensions/wiki/config.json"
);

async function loadConfig(): Promise<Config> {
  try {
    const raw = await readFile(CONFIG_PATH, "utf-8");
    return JSON.parse(raw);
  } catch {
    return {
      vaultRoot: "",
      wikis: {},
      defaults: { model: "anthropic/claude-sonnet-4-5", mode: "background" },
    };
  }
}

async function saveConfig(config: Config): Promise<void> {
  await writeFile(CONFIG_PATH, JSON.stringify(config, null, 2) + "\n", "utf-8");
}

/** Resolve a wiki's absolute path */
function resolveWikiPath(config: Config, wiki: WikiConfig): string {
  const root = wiki.vault || config.vaultRoot;
  return join(root, wiki.path);
}

export default function (pi: ExtensionAPI) {
  const OPERATIONS = ["ingest", "query", "lint", "daily", "task", "status", "log"];

  pi.registerCommand("wiki", {
    description: "LLM-maintained wiki system — /wiki <name> <request> or /wiki for menu",
    getArgumentCompletions: (prefix) => {
      const builtins = ["create", "list", "register"];
      const all = [...builtins, ...OPERATIONS];
      const filtered = all.filter((o) => o.startsWith(prefix));
      return filtered.length > 0
        ? filtered.map((o) => ({ value: o, label: o }))
        : null;
    },
    handler: async (args, ctx) => {
      const config = await loadConfig();

      if (!config.vaultRoot) {
        ctx.ui.notify(
          "Wiki extension not configured. Set vaultRoot in ~/.pi/agent/extensions/wiki/config.json",
          "error"
        );
        return;
      }

      const trimmed = args.trim();

      // No args → interactive menu
      if (!trimmed) {
        await interactiveMenu(config, ctx, pi);
        return;
      }

      // /wiki list
      if (trimmed === "list") {
        await listWikis(config, ctx);
        return;
      }

      // /wiki create <name>
      if (trimmed.startsWith("create ")) {
        const name = trimmed.slice(7).trim().toLowerCase().replace(/[^a-z0-9-]/g, "-");
        if (!name) {
          ctx.ui.notify("Usage: /wiki create <name>", "warning");
          return;
        }
        await createWiki(name, config, ctx);
        return;
      }

      // /wiki register <name> <path>
      if (trimmed.startsWith("register ")) {
        const parts = trimmed.slice(9).trim().split(/\s+/);
        if (parts.length < 2) {
          ctx.ui.notify("Usage: /wiki register <name> <path>", "warning");
          return;
        }
        const [name, ...pathParts] = parts;
        const wikiPath = pathParts.join(" ");
        config.wikis[name.toLowerCase()] = { path: wikiPath };
        await saveConfig(config);
        ctx.ui.notify(`Registered wiki '${name}' at ${wikiPath}`, "info");
        return;
      }

      // /wiki <name> [--inline] <request>
      await routeWikiRequest(trimmed, config, ctx, pi);
    },
  });

  // -------------------------------------------------------------------
  // Interactive menu
  // -------------------------------------------------------------------
  async function interactiveMenu(config: Config, ctx: any, pi: ExtensionAPI) {
    const wikiNames = Object.keys(config.wikis);

    if (wikiNames.length === 0) {
      const create = await ctx.ui.confirm(
        "No wikis registered",
        "Create one now?"
      );
      if (create) {
        const name = await ctx.ui.input("Wiki name:", "e.g. spark, personal, research");
        if (name) {
          await createWiki(name.toLowerCase().replace(/[^a-z0-9-]/g, "-"), config, ctx);
        }
      }
      return;
    }

    // Step 1: Pick a wiki
    const wikiItems = wikiNames.map((n) => `${n} — ${config.wikis[n].path}`);
    wikiItems.push("--- Management ---");
    wikiItems.push("+ Create new wiki");
    wikiItems.push("⚙ Edit config");

    const selected = await ctx.ui.select("Select wiki", wikiItems);
    if (!selected) return;

    if (selected === "+ Create new wiki") {
      const name = await ctx.ui.input("Wiki name:", "e.g. spark, personal, research");
      if (name) {
        await createWiki(name.toLowerCase().replace(/[^a-z0-9-]/g, "-"), config, ctx);
      }
      return;
    }
    if (selected === "⚙ Edit config") {
      pi.sendUserMessage(
        `Read the file ${CONFIG_PATH} and help me edit it.`,
        { deliverAs: "followUp" }
      );
      return;
    }
    if (selected.startsWith("---")) return;

    const wikiName = selected.split(" — ")[0];

    // Step 2: Pick an operation
    const ops = [
      "daily — Log today's work (priorities, done, blockers)",
      "ingest — Process raw material into wiki pages",
      "task — Create or update a task",
      "query — Ask a question against the wiki",
      "status — Quick orientation (what's active, blocked)",
      "lint — Health-check the wiki",
      "--- Modes ---",
      "💬 Free-form (inline) — Build context in this session",
      "💬 Free-form (background) — Run without polluting context",
    ];

    const op = await ctx.ui.select(`${wikiName} — what do you want to do?`, ops);
    if (!op || op.startsWith("---")) return;

    const opKey = op.split(" — ")[0].replace(/[^\w-]/g, "").trim();

    if (opKey.includes("inline") || opKey.includes("background")) {
      const request = await ctx.ui.input("What would you like to do?", "");
      if (!request) return;
      const inline = opKey.includes("inline");
      await executeWikiRequest(wikiName, request, config, ctx, pi, inline);
      return;
    }

    // For structured operations, may prompt for details
    let request = opKey;
    if (opKey === "ingest" || opKey === "task" || opKey === "query") {
      const detail = await ctx.ui.input(`${opKey} — details:`, "");
      if (detail) request = `${opKey} ${detail}`;
    }

    await executeWikiRequest(wikiName, request, config, ctx, pi, false);
  }

  // -------------------------------------------------------------------
  // Route a wiki request from args
  // -------------------------------------------------------------------
  async function routeWikiRequest(input: string, config: Config, ctx: any, pi: ExtensionAPI) {
    const wikiNames = Object.keys(config.wikis);

    // Check if first word is a wiki name
    const parts = input.split(/\s+/);
    const firstWord = parts[0].toLowerCase();

    if (!wikiNames.includes(firstWord)) {
      // If only one wiki, assume it
      if (wikiNames.length === 1) {
        const wikiName = wikiNames[0];
        const inline = input.includes("--inline");
        const request = input.replace("--inline", "").trim();
        await executeWikiRequest(wikiName, request, config, ctx, pi, inline);
        return;
      }
      ctx.ui.notify(
        `Unknown wiki '${firstWord}'. Available: ${wikiNames.join(", ")}`,
        "warning"
      );
      return;
    }

    const wikiName = firstWord;
    const rest = parts.slice(1).join(" ");
    const inline = rest.includes("--inline");
    const request = rest.replace("--inline", "").trim();

    if (!request) {
      ctx.ui.notify(`Usage: /wiki ${wikiName} <request>`, "warning");
      return;
    }

    await executeWikiRequest(wikiName, request, config, ctx, pi, inline);
  }

  // -------------------------------------------------------------------
  // Execute a wiki request (background or inline)
  // -------------------------------------------------------------------
  async function executeWikiRequest(
    wikiName: string,
    request: string,
    config: Config,
    ctx: any,
    pi: ExtensionAPI,
    inline: boolean
  ) {
    const wiki = config.wikis[wikiName];
    if (!wiki) {
      ctx.ui.notify(`Wiki '${wikiName}' not found.`, "error");
      return;
    }

    const absoluteWikiRoot = resolveWikiPath(config, wiki);
    const schemaPath = join(absoluteWikiRoot, "WIKI.md");
    const model = wiki.model || config.defaults.model;

    let schema: string;
    try {
      schema = await readFile(schemaPath, "utf-8");
    } catch {
      ctx.ui.notify(
        `Cannot read ${absoluteWikiRoot}/WIKI.md — run /wiki create ${wikiName} first.`,
        "error"
      );
      return;
    }

    if (inline) {
      // Run in current session — injects schema + request directly
      const message = [
        `<wiki-schema wiki="${wikiName}" path="${absoluteWikiRoot}/WIKI.md" root="${absoluteWikiRoot}">`,
        schema,
        `</wiki-schema>`,
        "",
        `<wiki-request wiki="${wikiName}" root="${absoluteWikiRoot}">`,
        `All file operations must use absolute paths under: ${absoluteWikiRoot}/`,
        "",
        request,
        `</wiki-request>`,
      ].join("\n");

      pi.sendUserMessage(message, { deliverAs: "followUp" });
    } else {
      // Run in background subagent with forked context
      const task = [
        `You are operating on the "${wikiName}" wiki.`,
        `Wiki absolute root: ${absoluteWikiRoot}/`,
        `All file operations must use absolute paths under: ${absoluteWikiRoot}/`,
        `Only modify files within ${absoluteWikiRoot}/. Never touch files outside.`,
        "",
        "## Wiki Schema (WIKI.md)",
        "",
        schema,
        "",
        "## Request",
        "",
        request,
      ].join("\n");

      const subagentMessage = [
        `Use the subagent tool to run this wiki operation in a forked background context.`,
        `Use agent "worker" with context "fork" and async true.`,
        `Set the model to "${model}".`,
        `Set cwd to "${absoluteWikiRoot}".`,
        "",
        `Task for the subagent:`,
        "",
        "```",
        task,
        "```",
      ].join("\n");

      pi.sendUserMessage(subagentMessage, { deliverAs: "followUp" });
    }
  }

  // -------------------------------------------------------------------
  // List wikis
  // -------------------------------------------------------------------
  async function listWikis(config: Config, ctx: any) {
    const names = Object.keys(config.wikis);
    if (names.length === 0) {
      ctx.ui.notify("No wikis registered. Use /wiki create <name>", "info");
      return;
    }
    const lines = names.map(
      (n) => `• ${n} → ${resolveWikiPath(config, config.wikis[n])} (model: ${config.wikis[n].model || config.defaults.model})`
    );
    ctx.ui.notify(lines.join("\n"), "info");
  }

  // -------------------------------------------------------------------
  // Create a new wiki
  // -------------------------------------------------------------------
  async function createWiki(name: string, config: Config, ctx: any) {
    const wikiRelPath = `Spaces/${name.charAt(0).toUpperCase() + name.slice(1)}`;
    const fullPath = join(config.vaultRoot, wikiRelPath);

    // Scaffold directories
    const dirs = [
      "raw/meetings",
      "raw/docs",
      "raw/assets",
      "wiki/people",
      "wiki/code",
      "wiki/processes",
      "wiki/decisions",
      "wiki/tasks",
      "daily",
    ];

    for (const dir of dirs) {
      await mkdir(join(fullPath, dir), { recursive: true });
    }

    // Write WIKI.md schema
    const schema = generateSchema(name);
    await writeFile(join(fullPath, "WIKI.md"), schema, "utf-8");

    // Write index.md
    const index = [
      `# ${name.charAt(0).toUpperCase() + name.slice(1)} Wiki Index`,
      "",
      `> Auto-maintained by agents. See [[WIKI.md]] for schema.`,
      "",
      "## People",
      "",
      "## Code & Architecture",
      "",
      "## Processes",
      "",
      "## Decisions",
      "",
      "## Tasks",
      "",
    ].join("\n");
    await writeFile(join(fullPath, "index.md"), index, "utf-8");

    // Write log.md
    const log = [
      `# ${name.charAt(0).toUpperCase() + name.slice(1)} Wiki Log`,
      "",
      `> Chronological record of wiki activity. Append-only.`,
      "",
    ].join("\n");
    await writeFile(join(fullPath, "log.md"), log, "utf-8");

    // Register in config
    config.wikis[name] = { path: wikiRelPath };
    await saveConfig(config);

    ctx.ui.notify(
      `✓ Created wiki '${name}' at ${fullPath}/\n` +
        `  Schema: ${wikiRelPath}/WIKI.md\n` +
        `  Use: /wiki ${name} daily`,
      "info"
    );
  }
}

// -------------------------------------------------------------------
// Schema template
// -------------------------------------------------------------------
function generateSchema(name: string): string {
  const title = name.charAt(0).toUpperCase() + name.slice(1);
  return `# ${title} Wiki — Agent Operating Schema

> You are maintaining a persistent, compounding wiki for "${title}".
> You write and maintain all wiki content. The user curates sources, asks questions, and directs focus.
> Only modify files within this wiki's directory. Never touch files outside.

## Architecture

\`\`\`
${title}/
├── WIKI.md          ← This file. Schema and operating instructions (you + user co-evolve)
├── index.md         ← Content catalog of all wiki pages (you maintain)
├── log.md           ← Chronological activity log (append-only)
├── daily/           ← Daily work logs (standup notes, priorities, blockers)
├── raw/             ← Source material (user adds, you read but NEVER modify)
│   ├── meetings/
│   ├── docs/
│   └── assets/
└── wiki/            ← Generated wiki pages (you own entirely)
    ├── people/      ← Person pages (role, team, projects, interaction notes)
    ├── code/        ← Architecture, repos, patterns, runbooks
    ├── processes/   ← How things work (deployments, reviews, ceremonies)
    ├── decisions/   ← ADRs, key decisions and their context
    └── tasks/       ← Work items, goals, priorities
\`\`\`

## Core Rules

1. **Only modify files in this wiki's directory** — the rest of the vault is off-limits
2. **Never modify \`raw/\`** — raw sources are immutable reference material
3. **Always update \`index.md\`** after creating or significantly changing pages
4. **Always append to \`log.md\`** after any operation (ingest, query that generates a page, lint)
5. **Use \`[[wikilinks]]\`** for internal references between wiki pages
6. **Use Obsidian-compatible markdown** — YAML frontmatter, wikilinks, callouts

## Page Format

Every wiki page uses this structure:

\`\`\`markdown
---
created: YYYY-MM-DD
updated: YYYY-MM-DD
type: person | code | process | decision | task | overview
tags: [relevant, tags]
---

# Title

Content here. Link to related pages with [[wiki/category/Page Name]].

## See Also
- [[related pages]]
\`\`\`

## Operations

### Ingest

When user says "ingest" or provides raw material to process:

1. Read the source material (from \`raw/\` or provided inline)
2. Discuss key takeaways with the user if unclear
3. Create or update relevant wiki pages
4. Update \`index.md\` with any new pages
5. Append to \`log.md\`: \`## [YYYY-MM-DD] ingest | Source Title\`

A single source might touch many pages. Update people pages if people are mentioned, code pages if architecture is discussed, process pages if workflows are described.

### Query

When user asks a question:

1. Check \`index.md\` to find relevant pages
2. Read those pages and synthesise an answer
3. If the answer is substantial or reusable, offer to save it as a new wiki page
4. If saved, update \`index.md\` and append to \`log.md\`

### Daily

When user says "daily", "standup", or "log":

1. Create or update \`daily/YYYY-MM-DD.md\` with today's entry
2. Structure: priorities, what was done, blockers, notes
3. Link to relevant wiki pages (people, tasks, code)
4. This is the user's work diary — capture what they tell you

Daily format:

\`\`\`markdown
---
date: YYYY-MM-DD
type: daily
---

# YYYY-MM-DD

## Priorities
- [ ] Task or focus item
- [ ] Another priority

## Done
- What was accomplished (link to [[wiki/tasks/...]] or [[wiki/code/...]])

## Blockers
- Anything stuck

## Notes
- Ad-hoc observations, meeting outcomes, decisions
\`\`\`

### Task

When user says "task" or wants to track work:

1. Create or update pages in \`wiki/tasks/\`
2. Tasks can be: active, blocked, done, parked
3. Link tasks to people, code areas, and decisions
4. Include context — why this matters, who cares, what "done" looks like

### Lint

When user says "lint" or "health check":

1. Scan the wiki for:
   - Orphan pages (no inbound links)
   - Stale information (pages not updated in weeks that reference active work)
   - Missing pages (linked but don't exist)
   - People mentioned in logs but without a person page
   - Tasks marked active with no recent updates
   - Contradictions between pages
2. Report findings and offer to fix them
3. Append to \`log.md\`: \`## [YYYY-MM-DD] lint | Summary of findings\`

### Status

When user says "status" or "where am I":

1. Read recent daily logs
2. Read active tasks
3. Summarise: what's in flight, what's blocked, what needs attention
4. This is a quick orientation — keep it concise

## Index Format

\`index.md\` is a categorised catalog:

\`\`\`markdown
# ${title} Wiki Index

## People
- [[wiki/people/Person Name]] — Role, team. One-line summary.

## Code & Architecture
- [[wiki/code/Page Name]] — What this covers.

## Processes
- [[wiki/processes/Page Name]] — What this covers.

## Decisions
- [[wiki/decisions/Page Name]] — Date. One-line summary.

## Tasks
- [[wiki/tasks/Task Name]] — Status. One-line summary.
\`\`\`

## Log Format

\`log.md\` is append-only, newest at bottom:

\`\`\`markdown
# ${title} Wiki Log

## [YYYY-MM-DD] ingest | Meeting notes from sprint planning
Created: wiki/tasks/Auth Migration. Updated: wiki/people/Jane, wiki/code/Auth Service.

## [YYYY-MM-DD] daily | Standup
Priorities: auth migration, review PR #142. Blockers: waiting on API team.

## [YYYY-MM-DD] lint | Health check
Found: 3 orphan pages, 2 missing person pages. Fixed 2, flagged 1 for review.
\`\`\`

## Conventions

- **Person pages**: Include role, team, what they own, communication preferences, notes from interactions
- **Code pages**: Include repo, tech stack, key patterns, how to run/deploy, gotchas
- **Process pages**: Step-by-step, who's involved, tools used, common failure modes
- **Decision pages**: Context, options considered, what was decided, who decided, date
- **Task pages**: What, why, who, status, definition of done, links to relevant code/people

## Tips for the Agent

- When in doubt, create a page. Pages are cheap. Linking is what makes the wiki valuable.
- Always link between pages. A person page should link to the code they own. A task should link to the people involved.
- Keep pages atomic — one concept per page. Split if a page tries to cover too much.
- Use callouts for important notes: \`> [!warning]\` for risks, \`> [!info]\` for context
- When the user is vague, ask clarifying questions before writing
- Prefer updating existing pages over creating duplicates
- Date everything. Stale info with a date is still useful. Undated info is confusing.
`;
}
