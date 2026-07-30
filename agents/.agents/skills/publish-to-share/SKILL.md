---
name: publish-to-share
description: Publish a self-contained HTML document (plan, report, proposal, deliverable) to the user's private sharing service at share.mjmeyer.dev and return a shareable link. Use when the user wants to share, publish, host, or send a document/report/plan as a web page on their own subdomain — especially for contracting clients — as a public page, an unguessable secret link, or a password-protected page. Triggers include "publish this", "share this with my client", "put this on share.mjmeyer.dev", "make a shareable link", "host this report".
---

# Publish to share.mjmeyer.dev

Turn content into a clean standalone HTML page and publish it to the user's private
service, returning a link they can send to a client. The `share` CLI is the only way
to publish; it is authenticated by a token only the user holds.

## Quick start

```sh
share publish ./report.html --title "Q3 Plan" --unlisted
```

Prints the URL (e.g. `https://share.mjmeyer.dev/q3-plan-a1b2…/`). Hand that back to the user.

## Workflow

1. **Build a self-contained HTML page.** One `.html` file, all CSS inline, **no external
   CDNs/fonts/scripts** (it must load instantly from R2 and work offline). Start from
   [assets/report-template.html](assets/report-template.html) for client-facing plans/reports —
   copy it, fill in the content, save it (e.g. `/tmp/<name>.html`).
2. **Pick the access mode** from the table below based on sensitivity. Default to
   `--unlisted` for anything client-facing. Add `--password` for sensitive material.
3. **Publish** with a clear `--title` and, for public pages only, a clean `--slug`.
4. **Report back** the full URL — and the password, if you set one — to the user.

## Access modes

| Goal | Flags | Result |
|---|---|---|
| Public page, clean URL | `--slug q3-plan` | `…/q3-plan/`, guessable, anyone can view |
| Secret link (default for clients) | `--unlisted` | random unguessable slug appended |
| Password protected | `--password "…"` | viewer must enter the password first |
| Secret link **and** password | `--unlisted --password "…"` | both gates |

If unsure which to use, ask the user, or default to `--unlisted`.

## Commands

```sh
share publish <folder-or-file.html> [--slug x] [--unlisted] [--password p] [--title t] [--entry index.html]
share list          # every published site, with URLs (owner-only)
share rm <slug>     # delete a site and its files
```

- A **single `.html` file** is served as the site's index. A **folder** is published
  as-is (its `index.html` is the entrypoint); use a folder when there are assets like
  images or extra pages.
- Re-running `publish` with the same `--slug` updates it in place. Omitting `--password`
  on a re-publish **removes** an existing password.

## Setup (one-time, if commands fail)

On a new machine, run the installer from the dotfiles — it clones the repo, links the
binary into `~/.local/bin`, and pulls the token from 1Password:

```sh
~/.dotfiles/scripts/common/install_share.sh   # or: scripts/setup.sh --share
```

- **`share: command not found`** → run the installer above. (Do *not* use `npm link`;
  it installs into an fnm version-specific path that breaks on Node switch.)
- **`SHARE_TOKEN is not set`** → the installer could not reach 1Password. The token
  lives at `op://Private/share.mjmeyer.dev/credential` and must match the
  `PUBLISH_TOKEN` Worker secret. Do not invent or guess the token; ask the user.
- The CLI needs **Node >=23.6** (it runs TypeScript directly, no `npm install`).
- To target a local dev server instead of production, set `SHARE_URL` (env or config).
