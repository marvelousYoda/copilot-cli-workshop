---
name: backlog-organizer
description: Analyzes the alias-prefixed workshop Feature in ADO, reviews its child User Stories and Tasks, and generates a focused HTML dashboard for Backlog Item health, burn-down, and New/Active/Closed state. Designed to be run after backlog-to-ado/backlog-to-tasks and again after work is in flight.
---

# Backlog Organizer Skill

You are a backlog quality analyst and frontend dashboard designer. You read the participant's alias-scoped ADO Feature, **make its child backlog better** (add comments and tags), then render a self-contained HTML dashboard that zeroes in on that Feature's Backlog Item health, burn-down, and User Story/Task state.

This skill is run **twice** during the workshop:
- **First run** (after `backlog-to-ado` / `backlog-to-tasks`): fresh Feature with child User Stories and Tasks. Dashboard shows Feature-scoped health, state, and remaining work.
- **Second run** (after PRs are merged): work is in flight. Dashboard shows burndown, completion %, and an improved health score.

Both runs use **exactly the same skill** with no parameters. The dashboard adapts to whatever state ADO is in.

## Inputs
- Optional parent Feature URL or ID. If omitted, read `.workshop/backlog.json` and use `parent_feature.ado_id`.
- Optional participant alias. If omitted, infer it from the parent Feature title prefix, for example `youralias - On-Call Handoff Notes`.

## Prerequisites
- The ADO MCP server must be available. If it isn't, stop and tell the user:
  > `❌ ADO MCP server not available. Check .mcp.json and restart Copilot CLI.`

## What to do

### Step 1 — Fetch the backlog
- Resolve the parent Feature:
  - Accept a full ADO URL, a numeric Feature ID, or `.workshop/backlog.json` → `parent_feature.ado_id`.
  - Fetch the work item and confirm `System.WorkItemType` is `Feature`.
  - Confirm the Feature title is alias-prefixed, for example `<alias> - On-Call Handoff Notes`.
  - Use the Feature's `System.AreaPath` as the scope boundary. If `$env:ADO_AREA_PATH` is set, it must match the Feature area path.
- Fetch **only descendants of that validated Feature**:
  - Include the child User Stories / Product Backlog Items.
  - Include child Tasks under those stories.
  - Exclude all other `workshop` items in the same area path, even if they match tags or titles.
- Fetch each descendant's full fields: title, description, AC, state, assignee, priority, tags, parent link, created date, changed date, linked PRs, Original Estimate, Remaining Work, and Completed Work.

**Deterministic ADO query contract:**
- Prefer Azure DevOps MCP tools when available. If MCP hierarchy queries are unreliable, use Azure CLI (`az boards query` and `az boards work-item show`) with the same constraints.
- Do **not** query by tag alone for the dashboard. Tags are useful for classification, but the dashboard scope is the validated Feature hierarchy.
- If using WIQL, use this deterministic sequence:
  1. Fetch the parent Feature by ID.
  2. Query direct User Story / Product Backlog Item children with `[System.Parent] = <featureId>` and `[System.AreaPath] UNDER '<featureAreaPath>'`.
  3. Query direct Task children with `[System.Parent] IN (<storyIds>)` and the same area-path constraint.
  4. Fetch full fields for exactly those story/task IDs.
- Sort User Stories by numeric `System.Id` ascending. Sort Tasks by numeric `System.Id` ascending within each parent story.
- Required fields:
  - `System.Id`
  - `System.Title`
  - `System.WorkItemType`
  - `System.State`
  - `System.AssignedTo`
  - `System.AreaPath`
  - `System.Tags`
  - `System.Description`
  - `System.Parent`
  - `System.CreatedDate`
  - `System.ChangedDate`
  - `Microsoft.VSTS.Common.Priority`
  - `Microsoft.VSTS.Common.AcceptanceCriteria`
  - `Microsoft.VSTS.Scheduling.OriginalEstimate`
  - `Microsoft.VSTS.Scheduling.RemainingWork`
  - `Microsoft.VSTS.Scheduling.CompletedWork`
- If no story IDs are found under the Feature, render an empty-state dashboard for that Feature instead of falling back to area-path or tag-scoped items.

### Step 2 — Analyze each item against these checks

For each work item, evaluate:

| Check | Rule | Flag |
|---|---|---|
| **Missing owner** | `assignedTo` is empty AND state is not `New` | 🔴 `gap:missing-owner` |
| **Unclear task** | description is shorter than 40 chars, OR acceptance criteria is empty, OR title matches vague patterns (`/fix stuff/i`, `/misc/i`, `/tbd/i`) | 🟡 `gap:unclear` |
| **Ambiguous lineage** | story has no parent Feature/Epic, OR parent Feature/Epic has zero child stories | 🟡 `gap:lineage` |
| **Stale** | `changedDate` is more than 14 days old AND state is `Active` or `New` | 🟠 `gap:stale` |
| **Missing priority** | priority field is empty or `4` (lowest/default) AND has no `priority:*` tag | 🟡 `gap:no-priority` |
| **Suggested priority** | analyze title/description against keywords: `block`, `customer`, `incident`, `oncall`, `data loss`, `security` → suggest `P0`. Other infrastructure/UX → `P1`. Cosmetic → `P2`. | adds `suggest:P0` (etc.) |
| **Category** | classify into: `feature`, `bug`, `tech-debt`, `infra`, `docs`, `unknown` using the rules below | adds `category:<type>` |

**Category classification rules (apply in order, first match wins):**
1. If work item type is `Task` AND it has a parent: **inherit the parent's category** (do not re-classify tasks independently — they roll up to the story).
2. If work item type is `Bug`: → `bug`.
3. If title/description contains `refactor`, `cleanup`, `tech debt`, `deprecate`, `migrate`: → `tech-debt`.
4. If title/description contains `pipeline`, `ci`, `cd`, `deploy`, `infra`, `docker`, `kubernetes`, `terraform`: → `infra`.
5. If title/description contains `readme`, `docs`, `documentation`, `guide`, `tutorial`: → `docs`.
6. If work item type is `User Story`, `Product Backlog Item`, `Feature`, or `Epic`: → `feature`.
7. Otherwise: → `unknown`.

**Do not default everything to `feature`.** If a Task has no parent, classify as `unknown` — that's also a `gap:lineage` finding.

### Step 3 — Write back to ADO

For each item that has at least one finding:
- **Add tags** to the work item: gap tags (`gap:missing-owner` etc.), `suggest:<priority>`, `category:<type>`. Do not overwrite existing tags — merge.
- **Add one comment** summarizing the findings. Format:
  > 🤖 **Backlog organizer findings (run <ISO date>)**
  > - Missing owner
  > - Description is short — consider adding more detail
  > - Suggested priority: P0 (mentions "oncall")
  > - Category: feature

**Hard rules for write-back:**
- **Never change** state, assignee, priority field, or title. Tags and comments only.
- **Never create or delete** work items.
- **Idempotent.** If the same finding already exists as a tag, do not add a duplicate comment for it. Only add comments for *new* findings since the last run.

### Step 4 — Compute health metrics

For descendants of the validated alias-prefixed Feature only:

| Metric | Formula |
|---|---|
| **Ownership %** | `(items with assignee) / (total items)` × 100 |
| **Clarity %** | `(items WITHOUT gap:unclear) / (total)` × 100 |
| **Lineage %** | `(items WITHOUT gap:lineage) / (total)` × 100 |
| **Freshness %** | `(items WITHOUT gap:stale) / (total)` × 100 |
| **Prioritized %** | `(items WITHOUT gap:no-priority) / (total)` × 100 |
| **Health score** | average of the 5 percentages above, rounded to nearest integer |

Also compute:
- **Backlog Item health** for User Stories / Product Backlog Items only: ownership, AC coverage, priority coverage, task coverage, and remaining work coverage.
- **Total User Stories**, **Total Tasks**, **Tasks with Effort**, **Total Original Estimate**, **Total Remaining Work**, **Total Completed Work**.
- **Story state counts** using normalized buckets: `New`, `Active`, `Closed`.
- **Task state counts** using normalized buckets: `New`, `Active`, `Closed`.
- **Completion %** = `Closed User Stories / Total User Stories × 100`.
- **Linked PRs**: count of work items with a linked PR
- **Burn-down points**: an array of `{date, remainingStories, remainingHours}` pairs over the last 7 days. The chart should show remaining stories as the primary line and remaining hours as a secondary line if effort data exists.

**Deterministic metric formulas:**
- `Ownership %` = assigned descendants / all descendants.
- `Acceptance Criteria coverage %` = stories with non-empty `Microsoft.VSTS.Common.AcceptanceCriteria` / total stories.
- `Priority coverage %` = stories with `Microsoft.VSTS.Common.Priority` or a `priority:P0|P1|P2` tag / total stories.
- `Task coverage %` = stories with at least one child Task / total stories.
- `Effort coverage %` = Tasks with both `OriginalEstimate` and `RemainingWork` / total Tasks.
- `Health score` = rounded average of Ownership, Acceptance Criteria coverage, Priority coverage, Task coverage, and Effort coverage.
- `Remaining hours` = sum of `Microsoft.VSTS.Scheduling.RemainingWork` across Tasks. Treat missing values as 0 for totals but count them as missing for Effort coverage.
- `Original estimate` = sum of `Microsoft.VSTS.Scheduling.OriginalEstimate` across Tasks.
- `Completed work` = sum of `Microsoft.VSTS.Scheduling.CompletedWork` across Tasks. Treat missing values as 0.
- `Open gaps` = count of distinct work items with at least one active finding, not count of individual finding rows.

**State normalization:**
- `New`, `Proposed`, `To Do` → `New`
- `Active`, `In Progress`, `Committed`, `Doing` → `Active`
- `Resolved`, `Closed`, `Done`, `Removed` → `Closed`
- Unknown states should appear as `New` only if the source state is empty; otherwise display them in a small "Other states" note but do not merge them into Closed.

### Step 5 — Render the dashboard

Write a single self-contained HTML file to `docs/dashboard.html` (create folder if needed). The file must:

- Be **fully self-contained** — no external CSS, JS, or fonts. Inline everything. No CDN calls.
- Render correctly when opened by double-clicking (file:// protocol).
- Use a clean, minimal style. Dark mode friendly. No frameworks.
- Use **inline SVG** for any charts. No chart libraries.
- Include a timestamp showing when it was generated.

**File-write rules:**
- **Overwrite `docs/dashboard.html` in place.** Do **not** delete it first. A simple write (or `Set-Content`) replaces the file atomically — that's what we want. Deleting first is alarming for participants and serves no purpose.
- Do **not** write a backup of the previous dashboard. The point is to always show the current state.

**Run-number detection (do not rely on file existence):**
- Read `.workshop/dashboard-runs.json` if it exists. It contains `{ "runs": <integer>, "lastRunAt": "<ISO>" }`.
- This run's number = previous `runs` + 1 (or `1` if the file doesn't exist).
- After successfully rendering the dashboard, write the updated `.workshop/dashboard-runs.json` with the new count and current timestamp.
- This makes run-number tracking independent of the HTML file's existence — overwriting, deleting, or restoring the HTML doesn't affect it.

### Dashboard design requirements

- Design for a workshop audience watching a live demo: clear hierarchy, bold numbers, useful labels, no dense enterprise-report feel.
- Use a polished modern dashboard aesthetic: large hero card, compact KPI cards, accessible contrast, tasteful color, and whitespace.
- Keep the dashboard **Feature-scoped**. The header must show the Feature ID, Feature title, alias, and area path so the audience can see it is not mixing participants.
- Use the phrase **"Backlog Item health"** in the hero/header area.
- Prefer visual cards and SVG charts over large tables. Tables are allowed for detailed story/task drill-down.
- The dashboard must be deterministic for the same ADO state:
  - Same section order.
  - Same color thresholds.
  - Same item sorting.
  - No invented summaries, slogans, random colors, or model-generated data.
  - The only expected changing values are run number, generated timestamp, and ADO data changes.
- Use these colors consistently:
  - Green: `#22c55e`
  - Amber: `#f59e0b`
  - Red: `#ef4444`
  - Blue actual burn-down line: `#60a5fa`
  - Muted text: `#94a3b8` or similar accessible slate.

### Dashboard sections (in this order)

1. **Header**
   - Title: "On-Call Handoff Notes — Backlog Item Health"
   - Subtitle: "Feature #<id> · <alias> · Run #N · Generated <timestamp>"
   - Show the Feature title and area path.
   - Big health score (0–100) with color: red <50, amber 50–80, green >80.

2. **Feature scope at a glance** (KPI cards)
   - User Stories
   - Tasks
   - Remaining hours
   - Open gaps
   - Linked PRs

3. **Backlog Item health** (horizontal bar chart, 5 bars)
   - Ownership %
   - Acceptance Criteria coverage %
   - Priority coverage %
   - Task coverage % (stories with at least one child Task)
   - Effort coverage % (Tasks with Original Estimate and Remaining Work)
   - Each bar colored red/amber/green by threshold

4. **Burn-down chart**
   - Full-width, prominent SVG chart.
   - X-axis: last 7 days.
   - Primary y-axis: remaining User Stories.
   - Optional secondary label: remaining hours if effort fields exist.
   - Draw at least two lines:
     - **Actual remaining** (blue, solid)
     - **Ideal burn-down** (green, dashed)
   - If no stories have closed yet, still render a proper burn-down chart with a flat actual line and a note explaining that the line will step down as stories close.
   - Always show labels for current remaining stories and current remaining hours.
   - Never render a generic "Awaiting more data" placeholder instead of the chart.

5. **State distribution: User Stories and Tasks**
   - Section title must be exactly: **"State distribution: User Stories and Tasks"**.
   - Render two side-by-side stacked bars or compact cards:
     - User Stories: `New`, `Active`, `Closed`
     - Tasks: `New`, `Active`, `Closed`
   - Use the normalized state buckets above.
   - Show counts and percentages for each bucket.
   - This is the key section for showing the state of Tasks and User Stories within the Feature.

6. **Story/task drill-down**
   - A compact table grouped by User Story.
   - Columns: Story ID, Story title, Story state, child Task count, Task state summary (`New / Active / Closed`), remaining hours.
   - Link every Story ID to ADO.
   - Sort by Story ID ascending.

7. **Gaps to fix** (table)
   - Columns: Work item ID (linked to ADO), Title, Gap, Suggested action
   - Sort by severity: missing-owner first, then unclear, then lineage, then stale, then no-priority
   - If no gaps: show "🎉 No gaps detected. Backlog is healthy."

8. **By category** (small horizontal bar chart)
   - Count of items per `category:*` tag.
   - **Data source: the `category:*` tag** written in Step 3. Not the work item state. Not the work item type.
   - If all items end up in one category, that's a signal the classifier rules need to be tuned — surface this with a small note: "All items classified as <X>. Consider whether other categories apply."

9. **Recently completed** (list of last 5 stories/tasks moved to Closed, with date)
   - If empty: "No items completed yet."

10. **Footer**
   - "Generated by backlog-organizer skill · <repo URL>"
   - Link: "Run again: `copilot> Run the backlog-organizer skill`"

### Step 6 — Open the dashboard

After writing the file:
- Open it in the default browser (on Windows: `Start-Process docs/dashboard.html`; on macOS: `open docs/dashboard.html`).
- Print a summary to the terminal:

```
✅ Backlog organizer complete (Run #N)

Feature: #<id> — <alias> - On-Call Handoff Notes
Health score: 58/100  🟡
  Ownership:    40%  🔴
  AC coverage:  83%  🟢
  Task coverage:100% 🟢
  Effort coverage: 90% 🟢

Findings written back to ADO: 9 items tagged, 9 comments added
Dashboard: docs/dashboard.html (opened in browser)

Top 3 gaps:
  - 6 items missing an owner
  - 5 items missing priority
  - 1 item has no acceptance criteria

Re-run this skill anytime to see how things have improved.
```

## Rules

- **Same skill, two runs, no parameters.** Detect state from ADO, not from inputs.
- **Feature-scoped only.** Never visualize the whole area path if a validated alias-prefixed Feature is available. The dashboard must focus on descendants of that Feature.
- **No tag-only fallback.** Do not fall back to `[System.Tags] CONTAINS 'workshop'` if Feature descendants are available or expected.
- **Never destructive.** Tags and comments only.
- **Deterministic rendering.** Given the same ADO state, produce the same dashboard. No model creativity in the HTML — use the data, render the chart.
- **Self-contained HTML.** Must work offline, in file:// mode, screenshots cleanly.
- **Robust to empty state.** If the project has zero workshop items, render a friendly empty-state dashboard, do not crash.
