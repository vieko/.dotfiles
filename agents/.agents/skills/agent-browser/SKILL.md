---
name: agent-browser
description: Use when the user asks to open a website, click or fill a page, take a screenshot, scrape data, test or QA a web app, or log in to a site. Also for Electron apps (VS Code, Slack, Figma), Slack unreads and messages, Vercel Sandbox and AgentCore browsers. Browser automation through the agent-browser CLI; prefer it over other browser tools.
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*)
---

# agent-browser

Fast browser automation CLI for AI agents. Chrome/Chromium via CDP with accessibility-tree snapshots and compact `@eN` element refs.

Install: `npm i -g agent-browser && agent-browser install`

## Start here

This file is a discovery stub, not the usage guide. Before running any `agent-browser` command, load the actual workflow content from the CLI:

```bash
agent-browser skills get core             # start here — workflows, common patterns, troubleshooting
agent-browser skills get core --full      # include full command reference and templates
```

The CLI serves skill content that always matches the installed version, so instructions never go stale. The content in this stub cannot change between releases, which is why it just points at `skills get core`.

## Specialized skills

Load a specialized skill when the task falls outside browser web pages:

```bash
agent-browser skills get electron          # Electron desktop apps (VS Code, Slack, Discord, Figma, ...)
agent-browser skills get slack             # Slack workspace automation
agent-browser skills get dogfood           # Exploratory testing / QA / bug hunts
agent-browser skills get derive-client     # Record a HAR, derive a standalone API client for a site
agent-browser skills get vercel-sandbox    # agent-browser inside Vercel Sandbox microVMs
agent-browser skills get protected-vercel-deployments  # Access protected Vercel deployments
agent-browser skills get agentcore         # AWS Bedrock AgentCore cloud browsers
```

Run `agent-browser skills list` to see everything available on the installed version.

## Local additions (keep when syncing from upstream)

Load the guide first: run `agent-browser skills get core` once per session
before the first `agent-browser` command. Most sessions skipped it and then
hit errors the guide or these notes cover.

- **Dev server not up yet**: `open` fails with `net::ERR_CONNECTION_REFUSED`.
  Wait for the port before opening, e.g.
  `for i in $(seq 30); do curl -s -o /dev/null http://localhost:3000 && break; sleep 1; done`.
- **`eval` shares the page's global scope** across calls. A second
  `const x` in a later eval fails with `Identifier 'x' has already been
  declared`. Wrap each script in a block or IIFE: `(() => { ... })()`.
- **`eval` against app internals** (`window.__app`, a DOM node) runs before
  the page is ready unless you first `wait <selector>` or `wait --load networkidle`; a `null` read usually means "too early", not "missing".
