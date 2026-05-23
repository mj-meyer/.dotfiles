# Documentation Patterns

Templates extracted from real Alchemy documentation. Use these when writing resource docs, provider indexes, getting started guides, and example projects.

## Table of Contents

1. [Resource Documentation Page](#1-resource-documentation-page) - Per-resource .md template
2. [Provider Index Page](#2-provider-index-page) - Provider overview index.md
3. [Getting Started Guide](#3-getting-started-guide-mdx) - Astro/Starlight MDX with Tabs
4. [Example Project Structure](#4-example-project-structure) - package.json, tsconfig, alchemy.run.ts
5. [Writing Style](#5-writing-style) - Concise, example-first conventions
6. [CI Guide Pattern](#6-ci-guide-pattern) - GitHub Actions setup
7. [Framework Guide Pattern](#7-framework-guide-pattern) - Web framework deployment guides
8. [Headless Infrastructure Guide Pattern](#8-headless-infrastructure-guide-pattern) - Database/queue provider guides
9. [Sidebar Ordering](#9-sidebar-ordering) - Guide navigation order conventions
10. [Admonition Types](#10-admonition-types) - Astro/Starlight admonition syntax

## 1. Resource Documentation Page

From `alchemy-web/src/content/docs/providers/neon/project.md`:

```md
---
title: NeonProject
description: Learn how to create, configure, and manage Neon serverless Postgres projects and databases using Alchemy.
---

The NeonProject resource lets you create and manage [Neon serverless PostgreSQL](https://neon.tech) projects.

## Minimal Example

Create a basic Neon project with default settings:

\`\`\`ts
import { NeonProject } from "alchemy/neon";

const project = await NeonProject("my-project", {
  name: "My Project",
});
\`\`\`

## Custom Region and Version

Create a project in a specific region with a specific PostgreSQL version:

\`\`\`ts
import { NeonProject } from "alchemy/neon";

const project = await NeonProject("eu-project", {
  name: "EU Project",
  region_id: "aws-eu-west-1",
  pg_version: 16,
  apiKey: alchemy.secret(process.env.NEON_API_KEY),
});
\`\`\`

## Adopting an Existing Project

Use `NeonProject` to adopt an existing project by name.

\`\`\`ts
import { NeonProject } from "alchemy/neon";

const project = await NeonProject("my-project", {
  adopt: true,
});
\`\`\`

:::caution
Adopting an existing project will cause the resource to be managed by the
current Alchemy app. Set `delete: false` to prevent deletion on destroy,
or use a Ref function for read-only access.
:::
```

Key conventions:
- Frontmatter: `title` is the Resource name, `description` is a full sentence
- Start with one-sentence description linking to official docs
- "Minimal Example" section first with the simplest usage
- One section per variant/use case
- Show adoption with `:::caution` admonition
- No `import alchemy` unless using `alchemy.secret()`

## 2. Provider Index Page

From `alchemy-web/src/content/docs/providers/coinbase/index.md`:

```md
---
title: {Provider} Provider
description: {One-sentence description of what the provider manages}
---

{1-2 paragraph overview of the provider and what it enables in Alchemy.}

## Resources

The {Provider} provider includes the following resources:

- [{Resource1}](/providers/{provider}/{resource1}/) - {Brief description}
- [{Resource2}](/providers/{provider}/{resource2}/) - {Brief description}

## Prerequisites

1. **API Keys**: Obtain credentials from [{Provider} Dashboard](https://...)

2. **Authentication**: Set up environment variables:

\`\`\`bash
export {PROVIDER}_API_KEY=your-api-key
\`\`\`

## Example

Here's a complete example of using the {Provider} provider:

\`\`\`typescript
import { Resource1, Resource2 } from "alchemy/{provider}";
import alchemy from "alchemy";

const resource1 = await Resource1("my-resource", {
  name: "example",
});

const resource2 = await Resource2("dependent", {
  parent: resource1,
});
\`\`\`

## Additional Resources

- [{Provider} Official Documentation](https://docs.example.com/)
- [{Provider} API Reference](https://api.example.com/)
```

## 3. Getting Started Guide (MDX)

Guides use Astro/Starlight MDX format. From `alchemy-web/src/content/docs/guides/cloudflare-vitejs.mdx`:

```mdx
---
title: {Provider Title}
description: {One-sentence description of what the guide covers}
sidebar:
  order: {number}
---

import { Tabs, TabItem } from '@astrojs/starlight/components';

This guide shows how to {brief description of what you'll build}.

## Init

Start by creating a new project:

<Tabs syncKey="pkgManager">
  <TabItem label="bun">
    \`\`\`sh
    bunx alchemy create my-app --template={template}
    cd my-app
    \`\`\`
  </TabItem>
  <TabItem label="npm">
    \`\`\`sh
    npx alchemy create my-app --template={template}
    cd my-app
    \`\`\`
  </TabItem>
  <TabItem label="pnpm">
    \`\`\`sh
    pnpm dlx alchemy create my-app --template={template}
    cd my-app
    \`\`\`
  </TabItem>
  <TabItem label="yarn">
    \`\`\`sh
    yarn dlx alchemy create my-app --template={template}
    cd my-app
    \`\`\`
  </TabItem>
</Tabs>

## Credentials

{How to obtain and store credentials}

## Deploy

Run the deploy script:

<Tabs syncKey="pkgManager">
  <TabItem label="bun">
    \`\`\`sh
    bun run deploy
    \`\`\`
  </TabItem>
  <TabItem label="npm">
    \`\`\`sh
    npm run deploy
    \`\`\`
  </TabItem>
  <TabItem label="pnpm">
    \`\`\`sh
    pnpm run deploy
    \`\`\`
  </TabItem>
  <TabItem label="yarn">
    \`\`\`sh
    yarn run deploy
    \`\`\`
  </TabItem>
</Tabs>

You'll get the live URL:

\`\`\`sh
{
  url: "https://my-app.example.com",
}
\`\`\`

## Local Development

<Tabs syncKey="pkgManager">
  <TabItem label="bun">
    \`\`\`sh
    bun run dev
    \`\`\`
  </TabItem>
  <TabItem label="npm">
    \`\`\`sh
    npm run dev
    \`\`\`
  </TabItem>
  <TabItem label="pnpm">
    \`\`\`sh
    pnpm run dev
    \`\`\`
  </TabItem>
  <TabItem label="yarn">
    \`\`\`sh
    yarn run dev
    \`\`\`
  </TabItem>
</Tabs>

## Destroy

Clean up all resources:

<Tabs syncKey="pkgManager">
  <TabItem label="bun">
    \`\`\`sh
    bun run destroy
    \`\`\`
  </TabItem>
  <TabItem label="npm">
    \`\`\`sh
    npm run destroy
    \`\`\`
  </TabItem>
  <TabItem label="pnpm">
    \`\`\`sh
    pnpm run destroy
    \`\`\`
  </TabItem>
  <TabItem label="yarn">
    \`\`\`sh
    yarn run destroy
    \`\`\`
  </TabItem>
</Tabs>
```

Key conventions:
- File extension is `.mdx` (not `.md`)
- Import `{ Tabs, TabItem }` from `@astrojs/starlight/components`
- `syncKey="pkgManager"` keeps tab selection in sync across sections
- Always show all four package managers: bun, npm, pnpm, yarn
- Sidebar order determines position in navigation tree
- For headless infrastructure, connect via Cloudflare Worker + Vite frontend

## 4. Example Project Structure

### package.json

```json
{
  "name": "{provider}-{qualifier}",
  "version": "0.0.0",
  "description": "Alchemy Typescript Project",
  "type": "module",
  "scripts": {
    "build": "tsc -b",
    "deploy": "alchemy deploy --env-file ../../.env",
    "destroy": "alchemy destroy --env-file ../../.env",
    "dev": "alchemy dev --env-file ../../.env"
  },
  "devDependencies": {
    "@types/node": "^24.0.1",
    "alchemy": "workspace:*",
    "typescript": "catalog:"
  },
  "dependencies": {
  }
}
```

### tsconfig.json

```json
{
  "extends": "../../tsconfig.base.json",
  "include": ["src/**/*.ts", "alchemy.run.ts"],
  "compilerOptions": {
    "composite": true,
    "resolveJsonModule": true
  },
  "references": [{ "path": "../../alchemy/tsconfig.json" }]
}
```

For Cloudflare examples, add workers types:
```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "allowImportingTsExtensions": true,
    "rewriteRelativeImportExtensions": true,
    "noEmit": true,
    "types": ["@cloudflare/workers-types"]
  },
  "include": ["src/**/*", "types/**/*", "alchemy.run.ts"],
  "references": [{ "path": "../../alchemy/tsconfig.json" }]
}
```

### alchemy.run.ts

```ts
import alchemy from "alchemy";
import { Resource1, Resource2 } from "alchemy/{provider}";

const app = await alchemy("{example-name}");

// Create resources
const resource1 = await Resource1("my-resource", {
  name: `${app.name}-${app.stage}-resource`,
});

const resource2 = await Resource2("dependent", {
  parent: resource1,
});

console.log({
  id: resource1.id,
  url: resource2.url,
});

await app.finalize();
```

Key conventions:
- Use `${app.name}-${app.stage}` in resource names for uniqueness
- `await app.finalize()` is always the last line
- Console log outputs useful for the user to interact with
- Use `Promise.all()` for concurrent resource creation when possible
- Use `app.local` for dev-vs-prod conditional logic

### Root tsconfig.json Update

Add a reference to the new example:
```json
{
  "references": [
    // ... existing references
    { "path": "examples/{provider}-{qualifier}" }
  ]
}
```

## 5. Writing Style

- **Concise** - One sentence per concept, no filler
- **Example-first** - Show code before explaining it
- **Progressive** - Start minimal, add complexity
- **No assumptions** - Include all imports in every code block
- **Link to official docs** - Always link to provider's own documentation
- **Admonitions** - Use `:::tip`, `:::caution`, `:::note` sparingly for critical information

## 6. CI Guide Pattern

For providers that benefit from a CI/CD section, follow the pattern from `guides/ci.mdx`:

```mdx
---
title: CI/CD
description: Set up CI/CD pipelines for Alchemy projects
sidebar:
  order: 20
---

import { Tabs, TabItem } from '@astrojs/starlight/components';

## GitHub Actions

\`\`\`yaml
name: Deploy
on:
  push:
    branches: [main]
  pull_request:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install
      - run: bun alchemy deploy --stage ${{ github.event_name == 'push' && 'prod' || format('pr-{0}', github.event.pull_request.number) }}
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
\`\`\`
```

## 7. Framework Guide Pattern

For guides involving web frameworks deployed to Cloudflare, follow this structure:

1. **Init** - Create project using `alchemy create --template {framework}`
2. **Prerequisites** - Login to Cloudflare (`alchemy login`)
3. **Create App** - Show the `alchemy.run.ts` configuration with the framework resource
4. **Configure Framework** - Show the vite/svelte/nuxt config with the Alchemy adapter/plugin
5. **Deploy** - Show `bun run deploy` with output
6. **Local Development** - Show `bun run dev` / `alchemy dev`
7. **Tear Down** - Show `bun run destroy`

Framework resources available:
- `Vite` from `alchemy/cloudflare` with `alchemy/cloudflare/vite`
- `Astro` from `alchemy/cloudflare` with `alchemy/cloudflare/astro`
- `SvelteKit` from `alchemy/cloudflare` with `alchemy/cloudflare/sveltekit`
- `Nuxt` from `alchemy/cloudflare` with `alchemy/cloudflare/nuxt`
- `ReactRouter` from `alchemy/cloudflare` with `alchemy/cloudflare/react-router`
- `TanStackStart` from `alchemy/cloudflare` with `alchemy/cloudflare/tanstack-start`
- `BunSPA` from `alchemy/cloudflare` (no Vite plugin needed)
- `Nextjs` from `alchemy/cloudflare` with `alchemy/cloudflare/nextjs`

## 8. Headless Infrastructure Guide Pattern

For providers without UI (databases, queues, etc.), the guide should:

1. Show the provider resource in `alchemy.run.ts`
2. Connect it to a Cloudflare Worker via bindings
3. Show the Worker code accessing the provider resource
4. Deploy and test the full stack

Example structure for a database provider:

```mdx
## Create App

\`\`\`ts title="alchemy.run.ts"
import alchemy from "alchemy";
import { Worker } from "alchemy/cloudflare";
import { Database } from "alchemy/{provider}";

const app = await alchemy("my-app");

const db = await Database("my-db", {
  name: "my-database",
});

const worker = await Worker("api", {
  entrypoint: "./src/worker.ts",
  bindings: {
    DATABASE_URL: db.connectionString,
  },
});

console.log({ url: worker.url });
await app.finalize();
\`\`\`
```

## 9. Sidebar Ordering

Guide sidebar order follows these conventions:

| Range | Category |
|-------|----------|
| 0-5 | Core framework guides (cloudflare, vitejs, worker) |
| 6-10 | Framework-specific (astro, sveltekit, react-router, etc.) |
| 11-15 | Feature guides (durable-objects, queues, workflows) |
| 16-20 | Database guides (drizzle, prisma, planetscale) |
| 20+ | Advanced topics (CI, debugging, turborepo) |

## 10. Admonition Types

Astro/Starlight supports these admonition types:

```md
:::note
Informational content
:::

:::tip
Helpful advice
:::

:::caution
Important warning about potential issues
:::

:::danger
Critical warning about destructive actions
:::
```
