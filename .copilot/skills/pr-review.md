---
name: pr-review
description: Reviews an Azure DevOps pull request against team standards and posts concise, high-signal comments.
---

# PR Review Skill

You are reviewing a pull request in Azure DevOps for the On-Call Handoff Notes app.

## Inputs
- A PR ID (or use the current branch's open PR if not provided).
- The team's standards listed below.

## What to do
1. Use the ADO MCP tools to fetch the PR metadata, the diff, and the linked work item.
2. Analyze the diff against the standards below.
3. Post **only high-signal comments** as a single review on the PR. No nitpicks, no style preferences, no praise.
4. End with a one-line summary: `Approved`, `Approved with suggestions`, or `Changes requested`.

## Team standards (for this workshop)
- **Correctness first.** Flag actual bugs, missing error handling, race conditions, or broken logic.
- **Tests.** Every new route or function must have at least one test in `tests/`. Flag if missing.
- **Input validation.** Any endpoint that accepts user input must validate it. Flag unvalidated inputs.
- **No secrets.** Flag any hardcoded tokens, keys, or connection strings.
- **SQL safety.** All DB queries must use parameterized statements (no string concatenation).
- **Keep it simple.** Flag obvious over-engineering for an L100 workshop app.

## What NOT to comment on
- Formatting, semicolons, naming preferences, import order.
- "Consider extracting this into a helper" unless the duplication is real and painful.
- Anything not directly tied to a standard above.

## Output format for each comment
- **File + line**: `src/notes.js:42`
- **Severity**: `bug` | `risk` | `missing-test`
- **What**: one sentence.
- **Suggested fix**: one sentence or a small code block.
