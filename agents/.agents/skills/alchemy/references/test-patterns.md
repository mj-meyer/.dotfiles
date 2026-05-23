# Test Patterns

Test conventions extracted from real Alchemy test suites. Use these as templates when writing resource tests.

## Table of Contents

1. [Test File Scaffold](#1-test-file-scaffold) - Required imports and setup
2. [Resource ID Convention](#2-resource-id-convention) - Deterministic, unique IDs
3. [Full CRUD Test](#3-full-crud-test-canonical-pattern) - Create, update, delete with verification
4. [Adoption Test](#4-adoption-test) - Adopting pre-existing resources
5. [Delete:false Test](#5-deletefalse-test) - Data resource persistence
6. [API Verification Helpers](#6-api-verification-helpers) - Direct API assertion functions
7. [Running Tests](#7-running-tests) - CLI commands
8. [Import Style Difference](#8-import-style-difference) - Test vs alchemy.run.ts imports
9. [Error Logging](#9-error-logging) - Preventing swallowed errors
10. [Multiple Resources](#10-multiple-resources-in-one-test) - Dependent resource testing
11. [Concurrent Creation](#11-concurrent-resource-creation) - Promise.all pattern
12. [Vitest Global Setup](#12-vitest-global-setup-for-integration-tests) - Integration tests with deployed infra
13. [Test Runner Selection](#13-test-runner-selection) - Vitest vs Bun test runner augmentation
14. [Timeout Considerations](#14-test-timeout-considerations) - Slow provider APIs
15. [Replace Test](#15-replace-test) - Testing immutable property replacement

## 1. Test File Scaffold

Every test file must follow this exact structure:

```ts
import { describe, expect } from "vitest";
import { alchemy } from "../../src/alchemy.ts";
import { destroy } from "../../src/destroy.ts";
import { MyResource } from "../../src/my-provider/my-resource.ts";
import { createMyProviderApi } from "../../src/my-provider/api.ts";
import { BRANCH_PREFIX } from "../util.ts";
// MUST import this or else alchemy.test won't exist
import "../../src/test/vitest.ts";

// Create API client for direct verification
const api = createMyProviderApi();

const test = alchemy.test(import.meta, {
  prefix: BRANCH_PREFIX,
});
```

Critical rules:
- **Static imports only** - no dynamic `import()` in test files
- **`import "../../src/test/vitest.ts"`** is required - without it `alchemy.test` doesn't exist
- **`BRANCH_PREFIX`** comes from `../util.ts` and provides branch-based unique prefixes

## 2. Resource ID Convention

Test resource IDs must be:
1. **Deterministic** - no `Math.random()` or `crypto.randomUUID()`
2. **Unique across all tests and all test suites** - use `BRANCH_PREFIX` plus a descriptive suffix

```ts
const testId = `${BRANCH_PREFIX}-test-neon-project`;
```

## 3. Full CRUD Test (Canonical Pattern)

From `alchemy/test/neon/project.test.ts`:

```ts
describe("NeonProject Resource", () => {
  const testId = `${BRANCH_PREFIX}-test-neon-project`;

  test("create, update, and delete neon project", async (scope) => {
    let project: NeonProject | undefined;
    try {
      // === CREATE ===
      project = await NeonProject(testId, {
        name: `Test Project ${testId}`,
        region_id: "aws-us-east-1",
        pg_version: 16,
      });

      // Assert creation
      expect(project.id).toBeTruthy();
      expect(project.name).toEqual(`Test Project ${testId}`);
      expect(project.region_id).toEqual("aws-us-east-1");

      // Verify via direct API call
      const { data } = await api.getProject({
        path: { project_id: project.id },
      });
      expect(data.project.name).toEqual(`Test Project ${testId}`);

      // === UPDATE ===
      project = await NeonProject(testId, {
        name: `Test Project ${testId}-updated`,
        region_id: "aws-us-east-1",
        pg_version: 16,
      });

      expect(project.name).toEqual(`Test Project ${testId}-updated`);

      // Verify update via direct API call
      const { data: updatedData } = await api.getProject({
        path: { project_id: project.id },
      });
      expect(updatedData.project.name).toEqual(`Test Project ${testId}-updated`);

    } catch (err) {
      // Log errors before they get swallowed by destroy errors in finally
      console.log(err);
      throw err;
    } finally {
      // === DELETE ===
      await destroy(scope);

      // Verify deletion via direct API call
      if (project?.id) {
        const { response } = await api.getProject({
          path: { project_id: project.id },
          throwOnError: false,
        });
        expect(response.status).toEqual(404);
      }
    }
  });
});
```

Key points:
- `try/catch/finally` ensures cleanup even if assertions fail
- Create and update in the `try` block
- `catch` block logs errors before rethrowing (prevents swallowed errors)
- `destroy(scope)` in the `finally` block
- Direct API verification after both create and update
- 404 verification after delete

## 4. Adoption Test

Test that existing resources can be adopted:

```ts
test("adopt existing resource", async (scope) => {
  let project: NeonProject | undefined;
  let adoptedProject: NeonProject | undefined;
  try {
    // Create a resource via API directly (simulating pre-existing resource)
    const { data: { project: existingProject } } = await api.createProject({
      body: {
        project: {
          name: `${testId}-existing`,
          region_id: "aws-us-east-1",
        },
      },
    });

    // Adopt the resource through Alchemy
    adoptedProject = await NeonProject(`${testId}-adopted`, {
      adopt: true,
      name: existingProject.name,
    });

    // Verify it adopted the same resource (same ID)
    expect(adoptedProject.id).toEqual(existingProject.id);
    expect(adoptedProject.name).toEqual(existingProject.name);

  } finally {
    await destroy(scope);

    // Verify adopted resource was deleted by Alchemy
    if (adoptedProject?.id) {
      const { response } = await api.getProject({
        path: { project_id: adoptedProject.id },
        throwOnError: false,
      });
      expect(response.status).toEqual(404);
    }
  }
});
```

## 5. Delete:false Test

Test that data resources can survive destruction:

```ts
test("does not delete resource when delete is false", async (scope) => {
  let project: NeonProject | undefined;
  try {
    project = await NeonProject(`${testId}-delete-false`, {
      delete: false,
    });
    expect(project.id).toBeTruthy();
  } finally {
    await destroy(scope);

    if (project?.id) {
      // Verify resource STILL EXISTS after destroy
      const { response } = await api.getProject({
        path: { project_id: project.id },
        throwOnError: false,
      });
      expect(response.status).toEqual(200);

      // Manual cleanup since Alchemy didn't delete it
      await api.deleteProject({
        path: { project_id: project.id },
        throwOnError: false,
      });

      // Verify manual cleanup worked
      const { response: deletedResponse } = await api.getProject({
        path: { project_id: project.id },
        throwOnError: false,
      });
      expect(deletedResponse.status).toEqual(404);
    }
  }
});
```

## 6. API Verification Helpers

Create helper functions to verify resource state via direct API calls:

```ts
async function assertProjectDoesNotExist(projectId: string) {
  const { response } = await api.getProject({
    path: { project_id: projectId },
    throwOnError: false,
  });
  expect(response.status).toEqual(404);
}

async function assertProjectExists(projectId: string) {
  const { response } = await api.getProject({
    path: { project_id: projectId },
    throwOnError: false,
  });
  expect(response.status).toEqual(200);
}
```

## 7. Running Tests

```bash
# Run a specific test file
bunx vitest alchemy/test/neon/project.test.ts

# Run a specific test by name
bunx vitest --test-name-pattern="create, update, and delete" alchemy/test/neon/project.test.ts

# Run all tests for a provider
bunx vitest alchemy/test/neon/

# Run all changed tests (requires being on a branch)
bun run test
```

## 8. Import Style Difference

Test files and `alchemy.run.ts` files use different import styles:

```ts
// In test files: named import from source path
import { alchemy } from "../../src/alchemy.ts";

// In alchemy.run.ts files: default import from package
import alchemy from "alchemy";
```

Both are correct for their context. Do not mix them up.

## 9. Error Logging

Always log errors in the try block before rethrowing, otherwise they get swallowed by `destroy` errors in the finally block:

```ts
try {
  // ... test logic
} catch(err) {
  console.log(err);
  throw err;
} finally {
  await destroy(scope);
}
```

This is a common pain point. Consider adding the `catch` block to every test, especially during development.

## 10. Multiple Resources in One Test

When testing resources that depend on each other:

```ts
test("branch depends on database", async (scope) => {
  let database: Database | undefined;
  let branch: Branch | undefined;
  try {
    database = await Database(`${testId}-db`, {
      name: `test-db-${testId}`,
    });

    branch = await Branch(`${testId}-branch`, {
      name: `test-branch-${testId}`,
      database, // Pass the Resource object directly
    });

    expect(branch.databaseId).toEqual(database.id);
  } finally {
    // destroy handles deletion order automatically
    await destroy(scope);
  }
});
```

## 11. Concurrent Resource Creation

Test resources that can be created in parallel:

```ts
test("concurrent creation", async (scope) => {
  try {
    const [ns1, ns2, ns3] = await Promise.all([
      KVNamespace(`${testId}-kv-1`, { title: `${testId}-kv-1` }),
      KVNamespace(`${testId}-kv-2`, { title: `${testId}-kv-2` }),
      KVNamespace(`${testId}-kv-3`, { title: `${testId}-kv-3` }),
    ]);

    expect(ns1.namespaceId).toBeTruthy();
    expect(ns2.namespaceId).toBeTruthy();
    expect(ns3.namespaceId).toBeTruthy();
  } finally {
    await destroy(scope);
  }
});
```

## 12. Vitest Global Setup for Integration Tests

For tests that need deployed infrastructure (e.g. testing a live Worker endpoint):

```ts
// vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    globalSetup: "./vitest.setup.ts",
  },
});
```

```ts
// vitest.setup.ts
import type { TestProject } from "vitest/node";

export async function setup({ provide }: TestProject) {
  const { app, worker } = await import("./alchemy.run.ts");

  if (!worker.url) throw new Error("worker.url is not defined");

  provide("workerUrl", worker.url);

  return async () => {
    await app.cleanup();
  };
}

declare module "vitest" {
  export interface ProvidedContext {
    workerUrl: string;
  }
}
```

```ts
// test/worker.test.ts
import { describe, expect, inject, it } from "vitest";

describe("worker", () => {
  it("should respond", async () => {
    const workerUrl = inject("workerUrl");
    const response = await fetch(workerUrl);
    expect(response.status).toBe(200);
  });
});
```

## 13. Test Runner Selection

Alchemy supports both Vitest and Bun test runners. Import the appropriate augmentation:

```ts
// For vitest (recommended for provider tests)
import "../../src/test/vitest.ts";

// For bun:test
import "../../src/test/bun.ts";
```

This augmentation adds `alchemy.test()` to the alchemy object. Without it, `alchemy.test` won't exist and tests will fail at runtime.

## 14. Test Timeout Considerations

Some provider APIs are slow (e.g. database provisioning). Increase test timeout for slow resources:

```ts
test("create slow resource", async (scope) => {
  // test body
}, { timeout: 120_000 }); // 2 minutes
```

## 15. Replace Test

Test resource replacement for immutable property changes:

```ts
test("replace resource when name changes", async (scope) => {
  let resource: MyResource | undefined;
  try {
    resource = await MyResource(`${testId}-replace`, {
      name: `${testId}-original`,
    });
    const originalId = resource.id;

    // Update with different name triggers replacement
    resource = await MyResource(`${testId}-replace`, {
      name: `${testId}-renamed`,
    });

    // New resource should have different ID
    expect(resource.id).not.toEqual(originalId);
    expect(resource.name).toEqual(`${testId}-renamed`);
  } finally {
    await destroy(scope);
  }
});
```
