---
name: backlog-organizer
description: Analyzes all workshop-tagged backlog items in ADO to categorize work, suggest priority, flag gaps (missing owners, unclear tasks, ambiguous lineage, stale items), and generate an HTML dashboard showing backlog structure, gaps, burndown, and overall health. Designed to be run twice — once after backlog creation, once after work is in flight.
---

# Backlog Organizer Skill

You are a backlog quality analyst. You read the ADO backlog, **make it better** (add comments and tags), then render a self-contained HTML dashboard that shows the team's backlog state at a glance.

This skill is run **twice** during the workshop:
- **First run** (after `backlog-to-ado`): fresh backlog, many gaps. Dashboard shows a low health score and many flags.
- **Second run** (after PRs are merged): work is in flight. Dashboard shows burndown, completion %, and an improved health score.

Both runs use **exactly the same skill** with no parameters. The dashboard adapts to whatever state ADO is in.

## Inputs
- No inputs required. The skill reads all ADO work items tagged `workshop` from the configured project.
- If `$env:ADO_PARTICIPANT` is set, the skill further scopes to items tagged `participant:<alias>` so each participant sees only their own backlog when the workshop area path is shared.

## Prerequisites
- The ADO MCP server must be available. If it isn't, stop and tell the user:
  > `❌ ADO MCP server not available. Check .mcp.json and restart Copilot CLI.`

## What to do

### Step 1 — Fetch the backlog
- Use ADO MCP to list all work items with tag `workshop` in the project.
- **If `$env:ADO_AREA_PATH` is set**, further filter to items where `System.AreaPath` starts with that value. This ensures we only analyze items the workshop participant created.
- **If `$env:ADO_PARTICIPANT` is set**, further filter to items whose `System.Tags` contains `participant:<alias>`. This isolates each participant's backlog when area path is shared.
- Fetch each item's full fields: title, description, AC, state, assignee, priority, tags, parent link, created date, changed date, linked PRs.

### Step 2 — Analyze each item against these checks

For each work item, evaluate:

| Check | Rule | Flag |
|---|---|---|
| **Missing owner** | `assignedTo` is empty AND state is not `New` | 🔴 `gap:missing-owner` |
| **Unclear task** | description is shorter than 40 chars, OR acceptance criteria is empty, OR title matches vague patterns (`/fix stuff/i`, `/misc/i`, `/tbd/i`) | 🟡 `gap:unclear` |
| **Ambiguous lineage** | story has no parent epic, OR epic has zero child stories | 🟡 `gap:lineage` |
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

For all `workshop`-tagged items:

| Metric | Formula |
|---|---|
| **Ownership %** | `(items with assignee) / (total items)` × 100 |
| **Clarity %** | `(items WITHOUT gap:unclear) / (total)` × 100 |
| **Lineage %** | `(items WITHOUT gap:lineage) / (total)` × 100 |
| **Freshness %** | `(items WITHOUT gap:stale) / (total)` × 100 |
| **Prioritized %** | `(items WITHOUT gap:no-priority) / (total)` × 100 |
| **Health score** | average of the 5 percentages above, rounded to nearest integer |

Also compute:
- **Total stories**, **stories Done**, **stories In Progress**, **stories New**
- **Completion %** = `Done / Total × 100`
- **Linked PRs**: count of work items with a linked PR
- **Burndown points**: an array of `{date, remaining}` pairs computed from work item state-change history over the last 7 days (only meaningful on the second run)

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

### Dashboard sections (in this order)

1. **Header**
   - Title: "On-Call Handoff Notes — Backlog Health"
   - Subtitle: "Run #N · Generated <timestamp>"
   - Big health score (0–100) with color: red <50, amber 50–80, green >80

2. **At a glance** (4 KPI cards in a row)
   - Total stories · Done · In Progress · Open gaps

3. **Health breakdown** (horizontal bar chart, 5 bars)
   - Ownership %, Clarity %, Lineage %, Freshness %, Prioritized %
   - Each bar colored red/amber/green by threshold

4. **Status distribution** (donut or stacked bar)
   - **Data source: `System.State` field of each work item.** Not the category tag.
   - Buckets: `New`, `Active`, `Resolved`, `Closed`, `Removed`, `Other` (any state not in the first 5).
   - Each bucket shows a count and a percentage.
   - Section title in the HTML must be exactly: **"State distribution"** (renamed from "Status" to avoid confusion with category).

4b. **Work item type breakdown** (small horizontal bar chart, immediately under State distribution)
   - Buckets: count of each `System.WorkItemType` value seen (e.g., `User Story`, `Task`, `Bug`, `Feature`, `Product Backlog Item`).
   - This makes it obvious when child tasks are inflating totals.

5. **Gaps to fix** (table)
   - Columns: Work item ID (linked to ADO), Title, Gap, Suggested action
   - Sort by severity: missing-owner first, then unclear, then lineage, then stale, then no-priority
   - If no gaps: show "🎉 No gaps detected. Backlog is healthy."

6. **By category** (small horizontal bar chart)
   - Count of items per `category:*` tag.
   - **Data source: the `category:*` tag** written in Step 3. Not the work item state. Not the work item type.
   - If all items end up in one category, that's a signal the classifier rules need to be tuned — surface this with a small note: "All items classified as <X>. Consider whether other categories apply."

7. **Burndown** (line chart, full width)
   - X-axis: last 7 days
   - Y-axis: remaining stories (Total − Done)
   - Show "Awaiting more data" message if all points are equal (first run)

8. **Recently completed** (list of last 5 items moved to Done, with date)
   - If empty: "No items completed yet."

9. **Footer**
   - "Generated by backlog-organizer skill · <repo URL>"
   - Link: "Run again: `copilot> Run the backlog-organizer skill`"

### Step 6 — Open the dashboard

After writing the file:
- Open it in the default browser (on Windows: `Start-Process docs/dashboard.html`; on macOS: `open docs/dashboard.html`).
- Print a summary to the terminal:

```
✅ Backlog organizer complete (Run #N)

Health score: 58/100  🟡
  Ownership:    40%  🔴
  Clarity:      83%  🟢
  Lineage:      100% 🟢
  Freshness:    100% 🟢
  Prioritized:  17%  🔴

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
- **Never destructive.** Tags and comments only.
- **Deterministic rendering.** Given the same ADO state, produce the same dashboard. No model creativity in the HTML — use the data, render the chart.
- **Self-contained HTML.** Must work offline, in file:// mode, screenshots cleanly.
- **Robust to empty state.** If the project has zero workshop items, render a friendly empty-state dashboard, do not crash.
