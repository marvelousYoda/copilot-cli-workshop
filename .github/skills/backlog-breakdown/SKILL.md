---
name: backlog-breakdown
description: Creates implementation Tasks under the workshop User Stories in ADO, assigns them to the participant, and sets Effort (Hours) using 1/3/5-hour estimates. Use after plan-to-backlog.
---

# Backlog to Tasks Skill

You turn the workshop User Stories into implementation Tasks so participants do not have to manually prompt for decomposition, assignment, and effort estimates.

## Inputs
- `.workshop/backlog.json`, produced by `spec-to-plan` and updated by `plan-to-backlog`.
- Optional parent Feature URL or ID. If omitted, use `.workshop/backlog.json` → `parent_feature.ado_id`.
- Optional assignee. If omitted, infer the participant from the parent Feature title alias and the current authenticated ADO identity when possible. If you cannot confidently resolve the assignee, stop and ask for the participant's ADO email or display name.

## Prerequisites
- The ADO MCP server must be available. If it isn't, stop and tell the user:
  > `❌ ADO MCP server not available. Check .mcp.json and restart Copilot CLI.`
- `.workshop/backlog.json` must exist and include `parent_feature.ado_id` plus story `ado_id` values. If it doesn't, stop and tell the user:
  > `❌ Run spec-to-plan and plan-to-backlog first so .workshop/backlog.json contains ADO IDs.`
- The parent work item must be a `Feature` whose title is alias-prefixed, for example `youralias - On-Call Handoff Notes`.
- The parent Feature's `System.AreaPath` is the boundary. If `ADO_AREA_PATH` is set, it must match the parent Feature's area path.

## What to do

1. **Read** `.workshop/backlog.json`.

2. **Validate the parent Feature**:
   - Fetch the parent Feature by URL/ID or `parent_feature.ado_id`.
   - Confirm `System.WorkItemType` is `Feature`.
   - Confirm the title starts with the participant alias followed by ` - `.
   - Use the Feature's `System.AreaPath` for every Task.

3. **Fetch the User Stories** listed in `.workshop/backlog.json`.
   - Only process stories with `ado_id`.
   - Confirm each story is under the validated parent Feature and same area path.
   - Do not process stories outside this hierarchy, even if they are tagged `workshop`.

4. **Check for existing child Tasks** under each story.
   - Match by exact Task title.
   - If a Task already exists, update assignment and Effort fields but do not create a duplicate.

5. **Create missing Tasks** using the task plan below.
   - Work item type: `Task`.
   - Parent: the matching User Story.
   - Area path: validated parent Feature area path.
   - Tags: `workshop`, `oncall`, `task`.
   - Assigned To: the resolved participant.
   - Effort (Hours): set both `Microsoft.VSTS.Scheduling.OriginalEstimate` and `Microsoft.VSTS.Scheduling.RemainingWork`.
   - Use only `1`, `3`, or `5` hours.

## Task plan

Use these exact Task titles and effort values unless the spec has been customized. If a matching `feature_id` is missing, skip that group and mention it in the summary.

| Story | Task title | Effort |
|---|---|---:|
| F1 | F1: Implement note creation schema and persistence | 3 |
| F1 | F1: Build create-note form and validation tests | 3 |
| F2 | F2: Implement newest-first notes list query | 1 |
| F2 | F2: Render notes list and coverage | 3 |
| F3 | F3: Add service filter route and query support | 1 |
| F3 | F3: Add service filter UI and tests | 3 |
| F4 | F4: Implement resolve-note endpoint | 1 |
| F4 | F4: Render resolved state and tests | 3 |
| F5 | F5: Add open-only list mode | 1 |
| F5 | F5: Add open/all toggle UI and tests | 3 |
| F6 | F6: Add draft/source schema support for WorkIQ suggestions | 3 |
| F6 | F6: Implement import:workiq script with mock fallback | 5 |
| F6 | F6: Build suggested-notes inbox actions and tests | 5 |
| F7 | F7: Implement severity sort ordering | 1 |
| F7 | F7: Add sort toggle UI and test coverage | 3 |
| F8 | F8: Implement Markdown share endpoints | 3 |
| F8 | F8: Add copy and email share UI | 3 |
| F8 | F8: Add share endpoint tests | 3 |

### Effort sizing rule
- `1` hour: small route, query, or ordering change.
- `3` hours: normal UI plus test coverage.
- `5` hours: larger integration or multi-step workflow, such as WorkIQ import.

## Output

After creating/updating Tasks, print:

```text
✅ Created implementation tasks

Parent Feature: #<id> — <alias> - On-Call Handoff Notes
Area path: <path>
Assignee: <display name> <email>

Tasks created: <n>
Tasks updated/skipped (already existed): <n>
Effort set: all Tasks use 1/3/5 hours for Original Estimate and Remaining

Next step: run the backlog-organizer skill to visualize backlog health.
```

## Rules
- **Idempotent.** Running twice must not create duplicate Tasks.
- **Scope tightly.** Only create/update Tasks under the validated parent Feature and story IDs from `.workshop/backlog.json`.
- **Never change story state, title, or priority.** For existing Tasks, only update tags, assignee, and Effort fields.
- **Never create Tasks without assignment and Effort.** This skill exists to remove those manual follow-up prompts.
