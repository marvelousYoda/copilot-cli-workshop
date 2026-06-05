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
  > `❌ ADO MCP server not available. Check .copilot/mcp.json and restart Copilot CLI.`
- The backlog JSON file must exist. If it doesn't, stop and tell the user:
  > `❌ No backlog found at .workshop/backlog.json. Run the spec-to-tasks skill first.`
- **Area path safeguard**: read the `ADO_AREA_PATH` environment variable.
  - If `ADO_AREA_PATH` is **set**, every work item you create MUST have its `System.AreaPath` field set to this value. No exceptions.
  - If `ADO_AREA_PATH` is **not set** AND the project name is one of the known shared/large projects (`Enterprise Cloud`, `OS`, `AzureDevOps`, `DevDiv`, `Office`), refuse to run with:
    > `❌ Project "<name>" looks like a shared project. Refusing to create work items without an area path. Set $env:ADO_AREA_PATH (e.g., "Enterprise Cloud\MTIP\YourTeam") and try again, or use the reset-dryrun.ps1 script with -AreaPath.`
  - If `ADO_AREA_PATH` is **not set** AND the project is not in the shared list, proceed but print a warning:
    > `⚠️ No ADO_AREA_PATH set. Work items will be created at the project root. This is OK for a dedicated workshop project, but NOT OK for shared projects.`

## What to do

1. **Read** `.workshop/backlog.json`.

2. **Check ADO for existing items** with the same titles to avoid duplicates. If a work item with the same title and tag `workshop` already exists, skip it and note this in the summary. **Never delete or modify existing items.**

3. **Create the Epic** in ADO via MCP:
   - Work item type: `Epic`
   - Title, description, tags from the JSON
   - **Set `System.AreaPath` to `$env:ADO_AREA_PATH`** if set
   - Capture the new Epic ID

4. **Create each User Story** in ADO via MCP:
   - Work item type: `User Story` (or `Product Backlog Item` if the project uses Scrum process — detect from the project)
   - Title, description, acceptance criteria, priority, tags from the JSON
   - **Set `System.AreaPath` to `$env:ADO_AREA_PATH`** if set
   - Set the parent link to the Epic created in step 3
   - Add a tag indicating size: e.g., `size:XS`
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
