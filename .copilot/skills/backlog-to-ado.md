---
name: backlog-to-ado
description: Reads .workshop/backlog.json (produced by spec-to-tasks) and creates the epic and user stories as work items in Azure DevOps via the ADO MCP server.
---

# Backlog to ADO Skill

You take a generated backlog and push it into Azure DevOps as real work items, using the ADO MCP server. You do **not** generate the backlog yourself — `spec-to-tasks` does that.

## Inputs
- A backlog JSON file (default: `.workshop/backlog.json`).
- The ADO organization and project come from the MCP server's configured environment. Do not ask the user for these — read them from the MCP context.

## Prerequisites
- The ADO MCP server must be available. If it isn't, stop and tell the user:
  > `❌ ADO MCP server not available. Check .mcp.json and restart Copilot CLI.`
- The backlog JSON file must exist. If it doesn't, stop and tell the user:
  > `❌ No backlog found at .workshop/backlog.json. Run the spec-to-tasks skill first.`
- **Parent work item (required for shared projects)**: read the `ADO_PARENT_ID` environment variable.
  - If set to a numeric work item ID, **skip creating a new Epic** and instead parent every User Story under that existing work item. The parent may be a `Feature` or an `Epic`.
  - Before using it, fetch the work item and verify (a) it exists, (b) its type is `Feature` or `Epic`, and (c) its `System.AreaPath` is under `$env:ADO_AREA_PATH`. If any check fails, stop with a clear error.
  - If `ADO_PARENT_ID` is **not set** AND the project is in the known shared list, refuse to run with:
    > `❌ No ADO_PARENT_ID set. On a shared project, create a Feature under your team's Epic in ADO (e.g., "<your alias> - Backlog Organizer"), then set $env:ADO_PARENT_ID to that Feature's ID and re-run.`
- **Area path safeguard**: read the `ADO_AREA_PATH` environment variable.
  - If `ADO_AREA_PATH` is **set**, every work item you create MUST have its `System.AreaPath` field set to this value. No exceptions.
  - If `ADO_AREA_PATH` is **not set** AND the project name is one of the known shared/large projects (`Enterprise Cloud`, `OS`, `AzureDevOps`, `DevDiv`, `Office`), refuse to run with:
    > `❌ Project "<name>" looks like a shared project. Refusing to create work items without an area path. Set $env:ADO_AREA_PATH (e.g., "Enterprise Cloud\MTIP\YourTeam") and try again, or use the reset-dryrun.ps1 script with -AreaPath.`
  - If `ADO_AREA_PATH` is **not set** AND the project is not in the shared list, proceed but print a warning:
    > `⚠️ No ADO_AREA_PATH set. Work items will be created at the project root. This is OK for a dedicated workshop project, but NOT OK for shared projects.`

## What to do

1. **Read** `.workshop/backlog.json`.

2. **Check ADO for existing items** with the same titles to avoid duplicates. If a work item with the same title and tag `workshop` already exists, skip it and note this in the summary. **Never delete or modify existing items.**

3. **Resolve the parent:**
   - If `$env:ADO_PARENT_ID` is set, use that existing work item (Feature or Epic) as the parent (after validating per Prerequisites). Do NOT create a new Epic. Note this in the summary as "Parent reused: #<id> (<type>)".
   - Otherwise (only allowed on non-shared projects), **create the Epic** in ADO via MCP:
     - Work item type: `Epic`
     - Title, description, tags from the JSON
     - **Set `System.AreaPath` to `$env:ADO_AREA_PATH`** if set
     - Capture the new Epic ID

4. **Create each User Story** in ADO via MCP:
   - Work item type: `User Story` (or `Product Backlog Item` if the project uses Scrum process — detect from the project)
   - Title, description, acceptance criteria, priority, tags from the JSON
   - **Set `System.AreaPath` to `$env:ADO_AREA_PATH`** if set
   - Set the parent link to the Epic resolved in step 3
   - Add a tag indicating size: e.g., `size:XS`
   - **If `$env:ADO_PARTICIPANT` is set, also add tag `participant:<value>`** so each participant's items are filterable on a shared backlog
   - **Do not assign** any story — leave assignee blank (the `backlog-organizer` will flag these next, which is intentional for the workshop)

5. **Write the ADO IDs back** to `.workshop/backlog.json` under each story (`ado_id` field) so later skills can reference them.

6. **Print a summary**:

```
✅ Pushed backlog to ADO

Epic created: #<id> — <title>
Area path: <path or "(project root)">
Stories created: <n>
  #<id> [P0/XS] F1: <title>
  #<id> [P0/XS] F2: <title>
  ...
Stories skipped (already exist): <n>

🔗 View in ADO: https://dev.azure.com/<org>/<project>/_workitems/edit/<epic_id>

Next step: run the `backlog-organizer` skill to analyze and visualize.
```

## Rules

- **Idempotent.** Running twice in a row must not create duplicates. Match by exact title + `workshop` tag.
- **Never delete.** If something is wrong, prefer leaving stale items over destroying user data.
- **Preserve all fields from the JSON.** Do not summarize or trim descriptions or acceptance criteria.
- **Tag everything with `workshop`.** This lets the `backlog-organizer` filter to just our items.
- **One epic per run.** If the JSON has multiple epics (it shouldn't), fail with a clear error.
- **No assignment.** Leave assignees blank deliberately — the organizer phase will flag this as a gap, which is the teaching moment.
- **Honor `$env:ADO_AREA_PATH`.** If set, every item must be created under it. If unset on a shared project, refuse to run.
