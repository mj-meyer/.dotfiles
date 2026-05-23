# Resource Implementation Patterns

Detailed patterns extracted from real Alchemy resources. Use these as templates when implementing new resources.

## Table of Contents

1. [Basic Resource Structure](#1-basic-resource-structure) - Props, output type, Resource const, phase handling
2. [Type Guard](#2-type-guard-required) - `is{Resource}` using ResourceKind
3. [Output Type with Omit](#3-output-type-with-omit) - Separating input from output
4. [Wrapper Function](#4-wrapper-function-for-input-normalization) - Union type normalization
5. [Adoption Patterns](#5-adoption-patterns) - Adopt-on-create vs adopt-on-error
6. [Conditional Deletion](#6-conditional-deletion-data-resources-only) - `delete?: boolean` for data resources
7. [Secret Handling](#7-secret-handling) - unwrap/wrap pattern
8. [Local Development](#8-local-development-support) - `this.scope.local` mock data
9. [Retry with Backoff](#9-retry-with-exponential-backoff) - withExponentialBackoff
10. [API Client Pattern](#10-api-client-pattern) - Minimal fetch wrapper
11. [Resource Replacement](#11-resource-replacement-for-immutable-properties) - `this.replace()` and `this.replace(true)`
12. [Cross-Resource References](#12-cross-resource-references) - `string | Resource` pattern
13. [Provider Index File](#13-provider-index-file) - Exporting from index.ts
14. [Destroy Strategy](#14-destroy-strategy) - Sequential vs parallel sub-resource deletion
15. [Dev Mode Support](#15-dev-mode-support) - `this.scope.local` and `dev` prop patterns
16. [Cloudflare API Patterns](#16-cloudflare-api-patterns) - extractCloudflareResult, CloudflareApiError
17. [Package.json Exports](#17-packagejson-exports) - Adding provider export path

## 1. Basic Resource Structure

Simplified canonical structure based on `NeonProject` (`alchemy/src/neon/project.ts`). See the actual file for the full implementation.

```ts
import { alchemy } from "../alchemy.ts";
import type { Context } from "../context.ts";
import { Resource } from "../resource.ts";

// 1. Props interface - all input properties with JSDoc
export interface NeonProjectProps {
  /**
   * When `true`, will adopt an existing project by `name`
   */
  adopt?: true;

  /**
   * Whether to delete the database when the resource is destroyed.
   * @default true, unless the resource was adopted
   */
  delete?: boolean;

  /**
   * Name of the project
   * @default ${app}-${stage}-${id}
   */
  name?: string;

  /**
   * Region where the project will be provisioned
   * @default "aws-us-east-1"
   */
  region_id?: NeonRegion;
}

// 2. Output interface - name MUST match the exported const
export interface NeonProject {
  id: string;
  name: string;
  created_at: string;
  region_id: NeonRegion;
  // ... all output properties
}

// 3. Resource const with JSDoc @example blocks
/**
 * Creates a Neon serverless PostgreSQL project.
 *
 * @example
 * // Create a basic Neon project with default settings:
 * const project = await NeonProject("my-project", {
 *   name: "My Project"
 * });
 *
 * @example
 * // Adopt an existing Neon project by name:
 * const project = await NeonProject("my-project", {
 *   adopt: true,
 *   name: "adjective-noun-123",
 * });
 */
export const NeonProject = Resource(
  "neon::Project",
  async function (
    this: Context<NeonProject>,
    id: string,
    props: NeonProjectProps,
  ) {
    const api = createNeonApi(props);
    const name =
      props.name ?? this.output?.name ?? this.scope.createPhysicalName(id);

    switch (this.phase) {
      case "create": {
        // Create logic
        const { data } = await api.createProject({ body: { project: { name } } });
        return { id: data.project.id, name: data.project.name, /* ... */ };
      }
      case "update": {
        // Update logic - use this.output for current state
        const { data } = await api.updateProject({
          path: { project_id: this.output.id },
          body: { project: { name } },
        });
        return { ...this.output, name: data.project.name, /* ... */ };
      }
      case "delete": {
        // Delete logic
        if (props.delete !== false && this.output?.id) {
          await api.deleteProject({ path: { project_id: this.output.id } });
        }
        return this.destroy();
      }
    }
  },
);
```

Key points:
- Physical name: `props.name ?? this.output?.name ?? this.scope.createPhysicalName(id)`
- `switch (this.phase)` with `"create"`, `"update"`, `"delete"` cases
- Delete always returns `this.destroy()`
- Update spreads `this.output` to preserve unchanged fields

## 2. Type Guard (Required)

Resources that can be used as bindings (e.g. Cloudflare workers) **must** export a type guard. For other providers, type guards are recommended but not required.

Pattern using `ResourceKind`:

```ts
import { ResourceKind } from "../resource.ts";

export function isKVNamespace(resource: any): resource is KVNamespace {
  return resource?.[ResourceKind] === "cloudflare::KVNamespace";
}
```

The string must match the first argument to `Resource()`.

## 3. Output Type with Omit

Use `Omit` to cleanly separate input-only properties from output. From `KVNamespace`:

```ts
export type KVNamespace = Omit<KVNamespaceProps, "delete" | "dev"> & {
  type: "kv_namespace";

  /**
   * The ID of the namespace
   */
  namespaceId: string;

  /**
   * Time at which the namespace was created
   */
  createdAt: number;

  /**
   * Time at which the namespace was last modified
   */
  modifiedAt: number;

  /**
   * Development mode properties
   * @internal
   */
  dev: {
    id: string;
    remote: boolean;
  };
};
```

Why `Omit` over `extends`:
- Removes input-only props (`delete`, `adopt`) from output
- Allows redefining property types (e.g. `dev` has different shape in output)
- Clear separation of input vs computed properties

Note: Some older resources like `NeonProject` use a plain `export interface NeonProject { ... }` without `Omit`, and the official Alchemy docs (`resource.mdx`) show an `extends` pattern. This is acceptable for simple cases where there is no prop overlap, but the codebase convention has evolved: **new resources should prefer the `Omit` pattern** for cleaner separation of input vs output types.

## 4. Wrapper Function for Input Normalization

When props have union types that need normalization, use a public wrapper function. From `KVNamespace`:

```ts
// Public function - accepts flexible types
export async function KVNamespace(
  id: string,
  props: KVNamespaceProps = {},
): Promise<KVNamespace> {
  return await _KVNamespace(id, {
    ...props,
    dev: {
      ...(props.dev ?? {}),
      force: Scope.current.local,
    },
  });
}

// Internal Resource - guaranteed normalized types
const _KVNamespace = Resource(
  "cloudflare::KVNamespace",
  async function (
    this: Context<KVNamespace>,
    id: string,
    props: KVNamespaceProps,
  ): Promise<KVNamespace> {
    // Implementation
  },
);
```

Only use this pattern when you need to normalize union types or inject computed values. If all props are simple, use the `Resource()` directly as the export.

## 5. Adoption Patterns

### Adopt-on-Create (NeonProject style)

Check `props.adopt` at the start of create phase. Try to fetch first, fall back to create:

```ts
case "create": {
  if (props.adopt) {
    try {
      return await fetchProject(api, { ...props, name });
    } catch (error) {
      if (!(error instanceof NeonProjectNotFound)) {
        throw error;
      }
      // project not found, continue with creation
    }
  }
  // Normal create path
  const { data } = await api.createProject({ body: { project: { name } } });
  return { /* ... */ };
}
```

### Adopt-on-Error (KVNamespace style)

Try to create, catch "already exists" error, find and adopt:

```ts
try {
  const { id } = await extractCloudflareResult(
    `create kv namespace "${props.title}"`,
    api.post(`/accounts/${api.accountId}/storage/kv/namespaces`, { title: props.title }),
  );
  return { namespaceId: id, createdAt: Date.now() };
} catch (error) {
  if (
    error instanceof CloudflareApiError &&
    (error.errorData as CloudflareApiErrorPayload[]).some((e) => e.code === 10014) &&
    (props.adopt ?? Scope.current.adopt)
  ) {
    const existing = await findKVNamespaceByTitle(api, props.title);
    if (!existing) {
      throw new Error(`Failed to find existing namespace '${props.title}' for adoption`);
    }
    return { namespaceId: existing.id, createdAt: existing.createdAt ?? Date.now() };
  }
  throw error;
}
```

## 6. Conditional Deletion (Data Resources Only)

Data resources (databases, storage, KV) should support opt-out deletion:

```ts
export interface MyDatabaseProps {
  /**
   * Whether to delete the database when the resource is destroyed.
   * @default true
   */
  delete?: boolean;
}

// In delete phase:
case "delete": {
  if (props.delete !== false && this.output?.id) {
    const response = await api.deleteProject({
      path: { project_id: this.output.id },
      throwOnError: false,
    });
    if (response.error && response.response.status !== 404) {
      throw new Error(`Failed to delete: ${response.error.message}`);
    }
  }
  return this.destroy();
}
```

Compute resources (workers, functions, containers) should always delete - no `delete` prop.

## 7. Secret Handling

```ts
import { Secret } from "../secret.ts";

// In Props - accept string | Secret
export interface MyResourceProps {
  apiKey?: string | Secret;
}

// When calling API - unwrap
const requestBody = {
  api_key: Secret.unwrap(props.apiKey),
};

// When returning output - wrap
return {
  apiKey: Secret.wrap(props.apiKey),
};
```

For creating secrets from env vars:
```ts
// Preferred (better error messages)
const secret = alchemy.secret.env.API_KEY;

// Also acceptable
const secret = alchemy.secret(process.env.API_KEY);
```

## 8. Local Development Support

Check `this.scope.local` to return mock data for local development:

```ts
if (this.scope.local) {
  return {
    type: "kv_namespace",
    namespaceId: this.output?.namespaceId ?? "",
    title,
    values: props.values,
    dev,
    createdAt: this.output?.createdAt ?? Date.now(),
    modifiedAt: Date.now(),
  };
}
```

## 9. Retry with Exponential Backoff

Use `withExponentialBackoff` from `alchemy/src/util/retry.ts`:

```ts
import { withExponentialBackoff } from "../util/retry.ts";

const result = await withExponentialBackoff(
  async () => {
    const response = await api.put(`/path`, payload);
    if (!response.ok) {
      throw new Error(`Error: ${response.statusText}`);
    }
    return response;
  },
  (error) => {
    // Return true to retry, false to throw
    return error.message?.includes("not found");
  },
  5,     // max attempts
  1000,  // initial delay ms
);
```

## 10. API Client Pattern

Minimal fetch wrapper - check `.ok` at call sites:

```ts
export interface MyProviderApiOptions {
  apiKey?: string | Secret;
}

export function createMyProviderApi(options: MyProviderApiOptions = {}) {
  const apiKey = Secret.unwrap(options.apiKey) ?? process.env.MY_PROVIDER_API_KEY;
  if (!apiKey) {
    throw new Error("MY_PROVIDER_API_KEY environment variable is required");
  }

  const baseUrl = "https://api.myprovider.com/v1";

  return {
    async get(path: string): Promise<Response> {
      return fetch(`${baseUrl}${path}`, {
        headers: { Authorization: `Bearer ${apiKey}` },
      });
    },
    async post(path: string, body: unknown): Promise<Response> {
      return fetch(`${baseUrl}${path}`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
    },
    // put, patch, delete follow the same pattern
  };
}
```

## 11. Resource Replacement for Immutable Properties

When an immutable property changes, signal replacement:

```ts
if (this.phase === "update" && this.output?.name !== name) {
  return this.replace(); // Deferred: deletes old after app.finalize()
}
```

For immediate replacement (when the provider requires unique names):

```ts
if (this.phase === "update" && this.output.name !== name) {
  return this.replace(true); // Immediate: deletes old before creating new (may cause downtime)
}
```

To avoid downtime with immediate replacement, append a random slug:

```ts
const name = `${props.name}-${this.output?.slug ?? generateSlug()}`;

if (this.phase === "update" && this.output?.name !== name) {
  this.replace(); // safe because name is unique
}
```

## 12. Cross-Resource References

Props should accept both string IDs and Resource objects:

```ts
export interface BranchProps {
  /**
   * The database this branch belongs to
   */
  database: string | Database;
}

// In implementation, resolve the ID:
const databaseId = typeof props.database === "string"
  ? props.database
  : props.database.id;
```

## 13. Provider Index File

Export all resources from `alchemy/src/{provider}/index.ts`:

```ts
export { MyResource, type MyResourceProps, isMyResource } from "./my-resource.ts";
export { AnotherResource, type AnotherResourceProps } from "./another-resource.ts";
export { createMyProviderApi, type MyProviderApiOptions } from "./api.ts";
```

## 14. Destroy Strategy

Resources with sub-resources can control deletion order:

```ts
const Database = Resource(
  "neon::Database",
  { destroyStrategy: "parallel" }, // sub-resources deleted in parallel (default: "sequential")
  async function(this: Context<Database>, id, props) {
    // sub-resources created here are deleted in parallel during Database deletion
    await SubResource("sub-1", {});
    await SubResource("sub-2", {});
  }
);
```

## 15. Dev Mode Support

Resources that support local development should check `this.scope.local` and include a `dev` prop:

```ts
export interface MyResourceProps {
  /**
   * Dev mode configuration
   */
  dev?: {
    /**
     * Use the remote deployed resource instead of local emulation
     * @default false
     */
    remote?: boolean;
  };
}

// In implementation:
if (this.scope.local) {
  return {
    id: this.output?.id ?? "",
    name: title,
    createdAt: this.output?.createdAt ?? Date.now(),
    modifiedAt: Date.now(),
    dev: {
      id: this.output?.dev?.id ?? crypto.randomUUID(),
      remote: props.dev?.remote ?? false,
    },
  };
}
```

## 16. Cloudflare API Patterns

When implementing Cloudflare resources, use the shared Cloudflare API client pattern:

```ts
import { createCloudflareApi, type CloudflareApi } from "./api.ts";
import { CloudflareApiError, type CloudflareApiErrorPayload } from "./api-error.ts";

// Extract successful result from Cloudflare response:
import { extractCloudflareResult } from "./api.ts";

const result = await extractCloudflareResult(
  `create resource "${name}"`,
  api.post(`/accounts/${api.accountId}/path`, body),
);
```

The Cloudflare API client provides `api.accountId` and handles auth via profiles/env vars.

## 17. Package.json Exports

After creating a provider, add its export path to `alchemy/package.json`:

```json
{
  "exports": {
    "./{provider}": {
      "types": "./lib/{provider}/index.d.ts",
      "default": "./lib/{provider}/index.js"
    }
  }
}
```

This enables `import { Resource } from "alchemy/{provider}"` in user code.
