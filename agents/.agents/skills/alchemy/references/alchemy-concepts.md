# Alchemy Core Concepts

Comprehensive reference for Alchemy's core primitives and patterns. Load this when you need to understand Alchemy fundamentals before implementing a provider.

## Table of Contents

1. [Apps and Stages](#1-apps-and-stages) - Application lifecycle, stages, finalization
2. [Resources](#2-resources) - Core building blocks, FQN, lifecycle function
3. [Scopes](#3-scopes) - Hierarchical resource organization
4. [Phases](#4-phases) - create/update/delete at resource level; up/destroy/read at app level
5. [Secrets](#5-secrets) - Encryption, alchemy.secret(), Secret.wrap/unwrap
6. [State](#6-state) - State files, storage backends, state file structure
7. [Bindings](#7-bindings) - Type-safe Cloudflare Worker bindings
8. [CLI](#8-cli) - Commands, flags, entrypoint conventions
9. [Local Development](#9-local-development) - Dev mode, miniflare, hot reload, remote bindings
10. [Profiles](#10-profiles) - Multi-account credential management
11. [Framework Adapters](#11-framework-adapters) - Vite, Astro, SvelteKit, Nuxt, React Router, TanStack Start, BunSPA
12. [Serialization](#12-serialization) - serde system for state files
13. [Providers Overview](#13-providers-overview) - All 20 providers and their resources

## 1. Apps and Stages

An Alchemy **App** is a collection of **Stages** where each deployed Stage is an isolated copy of your Resources.

```ts
// alchemy.run.ts
import alchemy from "alchemy";

const app = await alchemy("my-app");

// create resources here...
await Worker("api", { entrypoint: "./src/worker.ts" });

// clean up any unused resources from the application
await app.finalize();
```

### Stage

By default, the stage is the current username (`$USER`). Override with `--stage`:

```sh
alchemy deploy              # deploys $USER stage
alchemy deploy --stage prod # deploys prod stage
```

Or set programmatically:

```ts
const app = await alchemy("my-app", { stage: "prod" });
```

### Recommended Setup

1. **Personal Stage** - each developer uses default `$USER` stage
2. **Pull Request Stage** - `pr-${pull-request-number}` stage per PR
3. **Production Stage** - `main` branch deploys to `prod` stage

### Finalization

`await app.finalize()` must be the last line. It deletes orphaned resources (resources in state but no longer in code).

## 2. Resources

Resources are memoized async functions implementing a lifecycle handler for three phases: create, update, delete.

### Resource ID

```ts
await MyResource("unique-id", props);
```

The ID is unique within the Resource's Scope and tracks state.

### Fully Qualified Name (FQN)

Each Resource has a globally unique FQN like `"neon::Database"`:

```ts
export const Database = Resource("neon::Database", ...);
```

Alchemy uses the FQN to look up providers when deleting orphaned resources.

### Lifecycle Function

Must use `function` declaration (not arrow function) because context is passed via `this`:

```ts
async function(
  this: Context<Database>,  // resource state/context
  id: string,               // unique ID within scope
  props: DatabaseProps       // input properties
): Promise<Database>
```

### Physical Name

Resources may have a "physical name" for the infrastructure provider:

```ts
// Explicit name
const worker = await Worker("worker1", { name: "worker1" });

// Auto-generated: ${appName}-${id}-${stage}
const worker = await Worker("worker1"); // "my-app-worker1-prod"
```

In implementation: `props.name ?? this.output?.name ?? this.scope.createPhysicalName(id)`

### Data Resources vs Compute Resources

- **Data resources** (databases, KV stores, buckets, queues) hold user data. They should have a `delete?: boolean` prop so users can opt out of deletion on destroy. Default behavior: delete on destroy, but allow `delete: false` to preserve data.
- **Compute resources** (workers, functions, containers, tunnels) are stateless execution environments. They should always be deleted on destroy — no `delete` prop needed.

### Destroy Strategy

```ts
const Database = Resource(
  "neon::Database",
  { destroyStrategy: "parallel" }, // sub-resources deleted in parallel
  async function(this: Context<Database>, id, props) { ... }
);
```

Or set globally:

```ts
const app = await alchemy("my-app", { destroyStrategy: "parallel" });
```

### Resource Adoption

Opt in per-resource:

```ts
const bucket = await R2Bucket("my-bucket", { name: "existing", adopt: true });
```

Or globally with CLI:

```sh
alchemy deploy --adopt
```

Scope-level adoption: `Scope.current.adopt`

### Resource Replacement

When an immutable property changes, trigger replacement:

```ts
if (this.phase === "update" && this.output.name !== props.name) {
  this.replace();     // deferred: delete old after finalize
  // or
  this.replace(true); // immediate: delete old before creating new (may cause downtime)
}
```

## 3. Scopes

Hierarchical containers organizing resources:

```
app (Application Scope)
├── dev (Stage Scope)
│   ├── api (Nested Scope)
│   └── database (Resource)
└── prod (Stage Scope)
```

### Application Scope

```ts
const app = await alchemy("my-app");
// Resources created here are in the app's stage scope
```

State: `.alchemy/my-app/$USER/`

### Nested Scopes

```ts
await alchemy.run("backend", async () => {
  await ApiGateway("api", {});
  await Function("handler", {});
});
```

State: `.alchemy/my-app/$USER/backend/`

### Resource Scope

Each resource gets its own scope for child resources:

```ts
export const WebApp = Resource("my::WebApp", async function(this, id, props) {
  const db = await Database("db", {}); // child resource in WebApp's scope
  return { url: db.connectionString };
});
```

### Scope Finalization

- Application scopes need manual finalization: `await app.finalize()`
- Nested scopes finalize automatically when execution completes
- Finalization deletes orphaned resources (in state but not in code)

### Test Scope

```ts
const test = alchemy.test(import.meta, { prefix: BRANCH_PREFIX });

test("create resource", async (scope) => {
  // each test gets isolated scope; cleanup with destroy(scope) in finally
});
```

## 4. Phases

### App-Level Phases

```ts
const app = await alchemy("my-app", { phase: "up" });      // create/update/delete (default)
const app = await alchemy("my-app", { phase: "destroy" });  // delete all resources
const app = await alchemy("my-app", { phase: "read" });     // read-only, no changes
```

### Resource-Level Phases

Inside a resource lifecycle handler, `this.phase` is `"create"`, `"update"`, or `"delete"`:

```ts
switch (this.phase) {
  case "delete":
    // delete logic
    return this.destroy(); // signals deletion complete; returns `never`
  case "update":
    // update logic - this.output has current state
    return { ...this.output, ...updatedProps };
  case "create":
    // create logic
    return { ...newResourceProperties };
}
```

### Phase Determination

- **No state file** → `"create"`
- **State exists, props changed** → `"update"`
- **Resource removed from code** → `"delete"` (during finalization)
- **State exists, props unchanged** → skipped entirely (memoized)

## 5. Secrets

### Creating Secrets

```ts
// From value (standard pattern)
const apiKey = alchemy.secret(process.env.API_KEY);

// From env var via proxy (also available - auto-throws if env var is missing)
const apiKey = alchemy.secret.env.API_KEY;
```

### Encryption Password

```ts
const app = await alchemy("my-app", {
  password: process.env.SECRET_PASSPHRASE,
});
```

### In Resource Implementations

```ts
import { Secret } from "../secret.ts";

// Props accept string | Secret
export interface MyResourceProps {
  apiKey?: string | Secret;
}

// When calling API - unwrap to get plain string
const headers = { Authorization: `Bearer ${Secret.unwrap(props.apiKey)}` };

// When returning output - wrap to keep encrypted
return { apiKey: Secret.wrap(props.apiKey) };
```

### In State Files

Secrets are automatically encrypted:

```json
{ "props": { "key": { "@secret": "Tgz3e/WAscu4U1oanm5S4YXH..." } } }
```

## 6. State

### State File Location

```
.alchemy/
  my-app/          # Application scope
    dev/           # Stage scope
      resource.json
```

### State File Structure

```json
{
  "provider": "service::ResourceName",
  "data": {},
  "status": "updated",
  "output": { "id": "resource-123", "name": "My Resource" },
  "props": { "name": "My Resource" }
}
```

### State Stores

| Store | Import | Use Case |
|-------|--------|----------|
| FileSystem (default) | built-in | Local development, simple projects |
| Cloudflare | `alchemy/state` or `alchemy/cloudflare` | Production with Cloudflare |
| S3 | `alchemy/aws` | Production with AWS |
| SQLite | `alchemy/sqlite` | Local persistence |

```ts
import { CloudflareStateStore } from "alchemy/state";

const app = await alchemy("my-app", {
  stateStore: (scope) => new CloudflareStateStore(scope),
});
```

## 7. Bindings

Bindings connect resources to Cloudflare Workers at runtime.

### Binding Types

```ts
const worker = await Worker("my-worker", {
  entrypoint: "./src/worker.ts",
  bindings: {
    // String - non-sensitive config
    STAGE: app.stage,
    // Secret - sensitive values
    API_KEY: alchemy.secret("secret-key"),
    // Resource - infrastructure connections
    MY_KV: await KVNamespace("kv", { title: "my-kv" }),
  },
});
```

### Type-Safe Access

```ts
// In worker code - import type from alchemy.run.ts
import type { worker } from "../alchemy.run.ts";

export default {
  async fetch(request: Request, env: typeof worker.Env) {
    const value = await env.MY_KV.get("key"); // type-safe!
  },
};
```

### Type Guard Requirement

Resources used as bindings **must** export a type guard:

```ts
import { ResourceKind } from "../resource.ts";

export function isKVNamespace(resource: any): resource is KVNamespace {
  return resource?.[ResourceKind] === "cloudflare::KVNamespace";
}
```

## 8. CLI

### Commands

| Command | Description |
|---------|-------------|
| `alchemy deploy` | Deploy resources (phase: up) |
| `alchemy destroy` | Delete all resources (phase: destroy) |
| `alchemy dev` | Local development with hot reload |
| `alchemy run` | Read-only access to infrastructure |
| `alchemy create` | Scaffold a new project from template |
| `alchemy init` | Add Alchemy to existing project |
| `alchemy configure` | Set up cloud provider credentials |
| `alchemy login` | Authenticate with configured provider |
| `alchemy logout` | Clear provider credentials |

### Key Flags

- `--stage <name>` - Target stage (default: `$USER`)
- `--profile <name>` - Alchemy profile for auth (default: `default`)
- `--env-file <path>` - Load environment file
- `--adopt` - Adopt existing unmanaged resources
- `--force` - Update resources even without changes
- `--watch` - Watch for changes and redeploy
- `--quiet` - Suppress create/update/delete messages

### Entrypoint Convention

Default entrypoint: `./alchemy.run.ts` or `./alchemy.run.js`

### Templates

`alchemy create --template`: typescript, vite, bun-spa, astro, react-router, sveltekit, tanstack-start, rwsdk, nuxt

## 9. Local Development

`alchemy dev` runs Workers in Miniflare with hot reloading.

### Worker Dev Mode

```ts
const worker = await Worker("my-worker", {
  entrypoint: "worker.ts",
  dev: { port: 3000 },         // custom port (default starts at 1337)
});
```

### Tunnel Support

```ts
const worker = await Worker("my-worker", {
  entrypoint: "worker.ts",
  dev: { tunnel: true },       // expose via Cloudflare Tunnel
});
```

### Local vs Remote Bindings

Most bindings are emulated locally by default. Set `dev.remote: true` to use the real deployed resource:

```ts
const kv = await KVNamespace("my-kv", {
  dev: { remote: true },       // use deployed KV instead of local emulation
});
```

### `this.scope.local` and `app.local`

In resource implementations, check for dev mode:

```ts
if (this.scope.local) {
  return { /* mock data for local development */ };
}
```

In `alchemy.run.ts` files, use `app.local` for dev-vs-prod conditional logic:

```ts
const app = await alchemy("my-app");

if (app.local) {
  console.log("Running in dev mode");
}
```

## 10. Profiles

Manage credentials for multiple cloud accounts.

```bash
alchemy configure               # configure default profile
alchemy configure --profile prod # configure named profile
alchemy login                    # login to default profile
alchemy login --profile prod     # login to named profile
alchemy deploy --profile prod    # deploy using prod profile
```

Profile data stored in `~/.alchemy/config.json` (config) and `~/.alchemy/credentials/` (sensitive).

Resources can also specify profile:

```ts
const worker = await Worker("my-worker", { profile: "prod" });
```

Or globally:

```ts
const app = await alchemy("my-app", { profile: "prod" });
```

## 11. Framework Adapters

Alchemy provides framework-specific resources and Vite plugins for Cloudflare deployment.

| Framework | Resource | Vite Plugin / Adapter |
|-----------|----------|----------------------|
| Vite (vanilla) | `Vite` | `alchemy/cloudflare/vite` |
| Astro | `Astro` | `alchemy/cloudflare/astro` |
| SvelteKit | `SvelteKit` | `alchemy/cloudflare/sveltekit` |
| Nuxt | `Nuxt` | `alchemy/cloudflare/nuxt` |
| React Router | `ReactRouter` | `alchemy/cloudflare/react-router` |
| TanStack Start | `TanStackStart` | `alchemy/cloudflare/tanstack-start` |
| BunSPA | `BunSPA` | N/A (no Vite needed) |
| Next.js | `Nextjs` | `alchemy/cloudflare/nextjs` |
| Redwood (RWSDK) | `Redwood` | `alchemy/cloudflare/redwood` |

### Pattern

```ts
// alchemy.run.ts
import { Vite } from "alchemy/cloudflare";
const site = await Vite("my-site", {
  entrypoint: "./src/worker.ts",
  bindings: { KV: kv },
});

// vite.config.ts
import alchemy from "alchemy/cloudflare/vite";
export default defineConfig({ plugins: [alchemy()] });
```

All framework resources extend the Worker resource pattern with framework-specific build and dev support.

## 12. Serialization

Alchemy's serde system handles special types in state files:

| Type | Serialized Form | Notes |
|------|----------------|-------|
| Secret | `{ "@secret": "encrypted..." }` | Auto-encrypted with app password |
| Date | `{ "@date": "2023-06-15T..." }` | ISO timestamp |
| Schema | `{ "@schema": {...} }` | ArkType definitions |
| Scope | skipped (`undefined`) | Not serialized |
| Function | skipped (`undefined`) | Not serialized |

```ts
import { serialize, deserialize } from "alchemy";
const serialized = await serialize(scope, complexObject);
const restored = await deserialize(scope, serialized);
```

## 13. Providers Overview

Alchemy includes 20+ providers. Resource names below are the actual exported symbols from each provider's `index.ts`.

| Provider | Import | Resources |
|----------|--------|-----------|
| **cloudflare** | `alchemy/cloudflare` | Worker, KVNamespace, D1Database, R2Bucket, DurableObjectNamespace, Queue, Hyperdrive, Ruleset, CertificatePack, LogPushJob, EmailRouting, Zone, Workflow, Secret, Assets, Vite, Tunnel, AiGateway, DispatchNamespace, CustomDomain, Container, Pipeline, RateLimit, VersionMetadata, Ai, BrowserRendering, Images, AnalyticsEngine, VectorizeIndex, DnsRecords, and 80+ more. Framework resources: Astro, SvelteKit, Nuxt, ReactRouter, TanStackStart, BunSPA, Nextjs, Redwood |
| **neon** | `alchemy/neon` | NeonProject, NeonBranch, createNeonApi |
| **stripe** | `alchemy/stripe` | Card, Client, Coupon, Customer, EntitlementsFeature, File, Meter, PortalConfiguration, Price, Product, ProductFeature, PromotionCode, ShippingRate, TaxRate, Webhook |
| **aws** | `alchemy/aws` | AccountId, Bucket, Function, Policy, PolicyAttachment, Queue, Role, S3StateStore, SES, SSMParameter, Table, EC2 resources |
| **aws-control** | `alchemy/aws-control` | 1000+ auto-generated CloudFormation resources |
| **github** | `alchemy/github` | Comment, RepositoryEnvironment, RepositoryWebhook, Secret |
| **planetscale** | `alchemy/planetscale` | Database, Branch, Organization, Password, Role |
| **prisma-postgres** | `alchemy/prisma-postgres` | Connection, Database, Project, Workspace |
| **clickhouse** | `alchemy/clickhouse` | Service, ApiKey, Organization |
| **upstash** | `alchemy/upstash` | UpstashRedis |
| **vercel** | `alchemy/vercel` | Project, ProjectDomain |
| **sentry** | `alchemy/sentry` | Project, ClientKey, Team |
| **coinbase** | `alchemy/coinbase` | EvmAccount, EvmSmartAccount |
| **dns** | `alchemy/dns` | ImportDns, Record |
| **docker** | `alchemy/docker` | Image, RemoteImage, Container, Network, Volume |
| **esbuild** | `alchemy/esbuild` | Bundle |
| **fs** | `alchemy/fs` | File, CopyFile, FileCollection, FileRef, Folder |
| **os** | `alchemy/os` | exec |
| **random** | `alchemy/random` | RandomString |
| **state** | `alchemy/state` | CloudflareStateStore, D1StateStore, FileSystemStateStore, SQLiteStateStore, R2RestStateStore |

Note: The Cloudflare provider is the largest with 80+ resources. Use `alchemy/src/cloudflare/index.ts` as the source of truth for the full list. SQLite state store is part of the `alchemy/state` module, not a separate provider.

## See Also

For implementation-specific patterns and templates, load these reference files on demand:

- **`resource-patterns.md`** - How to implement resources (Props, Output, lifecycle, adoption, secrets, API client)
- **`test-patterns.md`** - How to write tests (scaffold, CRUD, adoption, deletion, concurrent creation)
- **`doc-patterns.md`** - How to write documentation (resource pages, provider index, guides, examples)
- **`checklist.md`** - Completeness verification for resources and providers
