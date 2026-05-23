# Completeness Checklist

Run through this checklist after implementing all artifacts for a provider or resource.

## Table of Contents

1. [Per-Resource Checklist](#per-resource-checklist) - Implementation, test, and docs checks for each resource
2. [Per-Provider Checklist](#per-provider-checklist) - Structure, package config, docs, example project
3. [Quick Smoke Test](#quick-smoke-test) - Commands to verify everything works

## Per-Resource Checklist

For each resource `{Resource}` in provider `{provider}`:

### Implementation

- [ ] File exists: `alchemy/src/{provider}/{resource}.ts`
- [ ] `{Resource}Props` interface defined with JSDoc on every property
- [ ] `{Resource}` output type defined (name matches exported const)
- [ ] Output type uses `Omit` pattern (not `extends`)
- [ ] `is{Resource}` type guard exported using `ResourceKind` (required for binding resources; recommended for all)
- [ ] `Resource("{provider}::{Resource}", ...)` implementation complete
- [ ] Physical name: `props.name ?? this.output?.name ?? this.scope.createPhysicalName(id)`
- [ ] All three phases handled: create, update, delete
- [ ] Delete phase returns `this.destroy()`
- [ ] Delete handles 404 gracefully (resource already deleted)
- [ ] Adoption support (if applicable): `adopt?: boolean` prop
- [ ] Conditional deletion (if data resource): `delete?: boolean` prop
- [ ] Secrets: `Secret.unwrap()` for API calls, `Secret.wrap()` for output
- [ ] Cross-resource refs use `string | Resource` pattern (not `resourceId: string`)
- [ ] JSDoc on the resource const with `@example` blocks
- [ ] All I/O is async (no `fs.readFileSync`, etc.)
- [ ] Exported from `alchemy/src/{provider}/index.ts`

### Test

- [ ] File exists: `alchemy/test/{provider}/{resource}.test.ts`
- [ ] Imports `"../../src/test/vitest.ts"`
- [ ] Uses `alchemy.test(import.meta, { prefix: BRANCH_PREFIX })`
- [ ] Test IDs use `${BRANCH_PREFIX}-{descriptive-id}` (deterministic, unique)
- [ ] CRUD test: create, assert, update, assert in try block
- [ ] Cleanup: `destroy(scope)` in finally block
- [ ] API verification: direct API call confirms deletion (404)
- [ ] Adoption test (if resource supports adopt)
- [ ] Delete:false test (if resource is data resource)
- [ ] Replacement test (if resource has immutable properties that trigger `this.replace()`)
- [ ] All imports are static (no dynamic `import()`)
- [ ] Tests pass: `bunx vitest alchemy/test/{provider}/{resource}.test.ts`

### Documentation

- [ ] File exists: `alchemy-web/src/content/docs/providers/{provider}/{resource}.md`
- [ ] Frontmatter: title matches resource name, description is a sentence
- [ ] Minimal example section
- [ ] Variant examples for each major use case
- [ ] Adoption section with `:::caution` (if applicable)
- [ ] All code blocks include imports

## Per-Provider Checklist

### Structure

- [ ] Provider README: `alchemy/src/{provider}/README.md` (lists all resources, describes API client approach)
- [ ] API client: `alchemy/src/{provider}/api.ts`
- [ ] Index file: `alchemy/src/{provider}/index.ts` exports all resources
- [ ] All resources pass their individual checklists (above)

### Package Configuration

- [ ] `package.json` exports: `"./{provider}": "./lib/{provider}/index.js"`
- [ ] Dependencies are peer deps (not regular deps)
- [ ] Installed with `bun` (not npm/yarn/pnpm)

### Documentation

- [ ] Provider index: `alchemy-web/src/content/docs/providers/{provider}/index.md`
  - [ ] Overview paragraph
  - [ ] Official links to provider website
  - [ ] Resource list with links to each resource page
  - [ ] Prerequisites/auth section
  - [ ] End-to-end example
- [ ] Getting started guide: `alchemy-web/src/content/docs/guides/{provider}.mdx`
  - [ ] MDX format with Astro/Starlight imports
  - [ ] `<Tabs>` for all four package managers (bun, npm, pnpm, yarn)
  - [ ] Sections: Init, Credentials, Deploy, Local Development, Destroy
  - [ ] Sidebar order number set

### Example Project

- [ ] Directory: `examples/{provider}-{qualifier?}/`
- [ ] `package.json` with deploy/destroy/dev scripts
- [ ] `tsconfig.json` extending `../../tsconfig.base.json`
- [ ] `alchemy.run.ts` with end-to-end usage
- [ ] Root `tsconfig.json` references updated

### Formatting and Tests

- [ ] `bun format` passes with no changes
- [ ] `bunx vitest alchemy/test/{provider}/` all tests pass
- [ ] No TypeScript errors: `bun tsc -b`

### Dev Mode (if Cloudflare-based)

- [ ] Resources that support local emulation handle `this.scope.local` correctly
- [ ] `dev` prop is documented in Props interface with JSDoc
- [ ] Resource returns mock/cached data when `this.scope.local` is true
- [ ] If resource can be used as a Worker binding, document which modes it supports (local emulation vs remote binding)

### Cross-Cutting Concerns

- [ ] All API calls handle 404 gracefully (don't throw on "not found" during delete)
- [ ] Resource handles the case where `this.output` is undefined (first create)
- [ ] No hardcoded environment variable names without fallback to props
- [ ] API key prop pattern: `Secret.unwrap(options.apiKey) ?? process.env.{PROVIDER}_API_KEY`
- [ ] Profile support if the provider uses Cloudflare: `profile` prop and `Scope.current.profile`

## Quick Smoke Test

After completing all artifacts, run these commands:

```bash
# Format check
bun format

# Type check (uses project references)
bun tsc -b

# Run provider tests
bunx vitest alchemy/test/{provider}/

# Verify exports work
bun -e "import('alchemy/{provider}').then(m => console.log(Object.keys(m)))"

# Verify alchemy.run.ts example (if example project exists)
cd examples/{provider}-{qualifier}
bun install
bun run deploy --stage test
bun run destroy --stage test
```
