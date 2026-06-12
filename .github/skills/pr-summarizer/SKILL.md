---
name: pr-summarizer
description: Generates a clean, structured PR description from the diff and linked work item, then updates the PR.
---

# PR Summarizer Skill

You write the PR description so the author doesn't have to.

## Inputs
- A PR ID (or use the current branch's open PR if not provided).

## What to do
1. Use the ADO MCP tools to fetch the PR title, diff, and any linked work item(s).
2. Generate a PR description using the exact template below.
3. Update the PR description in ADO with your output. Do not change the PR title.

## Template

```
## What
<1–2 sentences describing the change in plain English. No code references.>

## Why
<Link to the work item and a 1-sentence business reason. Pull this from the linked work item description.>

## How
<Bulleted list of the key technical changes. Max 5 bullets. One bullet per logical change.>

## How tested
<Bulleted list of tests added or manual verification done. If no tests were added, say so explicitly and explain why.>

## Risk
<One of: Low / Medium / High, with a single sentence justification.>
```

## Rules
- Be concise. A reviewer should understand the PR in 30 seconds.
- Do not invent tests that don't exist in the diff.
- Do not invent a work item if none is linked — write `_No work item linked._` instead.
- Never include the raw diff in the description.
