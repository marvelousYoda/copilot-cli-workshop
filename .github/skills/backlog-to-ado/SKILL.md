---
name: backlog-to-ado
description: Reads .workshop/backlog.json (produced by spec-to-tasks) and creates user stories under a participant-created Azure DevOps Feature via the ADO MCP server. Requires a Feature URL or ID whose title starts with the participant's alias.
---

# Backlog to ADO Skill

You take a generated backlog and push it into Azure DevOps as child User Stories under an existing Feature, using the ADO MCP server. You do **not** generate the backlog yourself — `spec-to-tasks` does that. You also do **not** create the parent Feature; the participant creates it manually in ADO so the workshop video shows the boundary before the skill writes anything.

## Inputs
- A backlog JSON file (default: `.workshop/backlog.json`).
- A parent Feature URL or Feature ID. The Feature title must start with the participant's alias, for example `shaygupt - On-Call Handoff Notes`.
- The ADO organization and project come from the MCP server's configured environment. Do not ask the user for these — read them from the MCP context.

## Prerequisites
- The ADO MCP server must be available. If it isn't, stop and tell the user:
  > `❌ ADO MCP server not available. Check .mcp.json and restart Copilot CLI.`
- The backlog JSON file must exist. If it doesn't, stop and tell the user:
  > `❌ No backlog found at .workshop/backlog.json. Run the spec-to-tasks skill first.`
- The user must provide a parent Feature URL or ID. If they don't, stop and ask for it:
  > `❌ Please provide the ADO Feature link or ID for your manually created Feature, named like "<alias> - On-Call Handoff Notes".`
- The parent work item must be a `Feature`. Fetch it before creating anything. If it is not a Feature, stop with:
  > `❌ Work item #<id> is a <type>, not a Feature. Create or provide the parent Feature first.`
- The parent Feature title must start with the participant's alias followed by ` - `, or contain the alias clearly at the beginning. Infer the alias from the Feature title or from the user's prompt if provided. If the title does not match, stop with:
  > `❌ Feature #<id> must be named like "<alias> - On-Call Handoff Notes" so this skill cannot write into another participant's Feature.`
- **Area path safeguard**: read the `ADO_AREA_PATH` environment variable.
  - If `ADO_AREA_PATH` is **set**, it must match the parent Feature's `System.AreaPath`. If it differs, refuse to run and show both values.
  - If `ADO_AREA_PATH` is **not set**, use the parent Feature's `System.AreaPath` as the write boundary. Never create items at the project root.

## What to do

1. **Read** `.workshop/backlog.json`.

2. **Resolve and validate the parent Feature**:
   - Accept either a full ADO URL like `https://.../_workitems/edit/<id>` or a numeric Feature ID.
   - Fetch the work item and confirm `System.WorkItemType` is `Feature`.
   - Confirm its title starts with the participant's alias, such as `shaygupt - On-Call Handoff Notes`.
   - Use the Feature's `System.AreaPath` as the area path if `ADO_AREA_PATH` is not set. If both are set and they differ, stop and explain the mismatch instead of guessing.

3. **Check ADO for existing child items** under that Feature with the same titles to avoid duplicates. If a child User Story with the same title and tag `workshop` already exists under the Feature, skip it and note this in the summary. **Never delete or modify existing items.**

4. **Create each User Story** in ADO via MCP:
   - Work item type: `User Story` (or `Product Backlog Item` if the project uses Scrum process — detect from the project)
   - Title, description, acceptance criteria, priority, tags from the JSON
   - **Set `System.AreaPath` to the validated Feature area path**
   - Set the parent link to the validated Feature
   - Add a tag indicating size: e.g., `size:XS`
   - **Do not assign** any story — leave assignee blank (the `backlog-organizer` will flag these next, which is intentional for the workshop)

5. **Write the ADO IDs back** to `.workshop/backlog.json`:
   - Add a top-level `parent_feature` object with `ado_id`, `title`, and `area_path`.
   - Write each created/skipped story ID under the story's `ado_id` field so later skills can reference them.

6. **Print a summary**:

```
✅ Pushed backlog to ADO

Parent Feature: #<id> — <alias> - On-Call Handoff Notes
Area path: <path>
Stories created: <n>
  #<id> [P0/XS] F1: <title>
  #<id> [P0/XS] F2: <title>
  ...
Stories skipped under this Feature (already exist): <n>

🔗 View in ADO: https://dev.azure.com/<org>/<project>/_workitems/edit/<feature_id>

Next step: run the `backlog-organizer` skill to analyze and visualize.
```

## Rules

- **Idempotent.** Running twice in a row must not create duplicates. Match by exact title + `workshop` tag.
- **Never delete.** If something is wrong, prefer leaving stale items over destroying user data.
- **Preserve all fields from the JSON.** Do not summarize or trim descriptions or acceptance criteria.
- **Tag everything with `workshop`.** This lets the `backlog-organizer` filter to just our items.
- **Never create the parent Feature.** The participant must create it manually and pass the Feature URL or ID.
- **Only write under the validated Feature.** If the Feature is missing, not a Feature, outside the area path, or not alias-prefixed, refuse to run.
- **No assignment.** Leave assignees blank deliberately — the organizer phase will flag this as a gap, which is the teaching moment.
- **Honor `$env:ADO_AREA_PATH`.** If set, every item must be created under it and it must match the parent Feature's area path. If unset, use only the validated parent Feature's area path.
