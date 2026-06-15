# From Backlog to Product: On-Call Handoff Notes

> A 90-minute hands-on lab for PMs and Engineers. Build a real product end-to-end using **Copilot CLI**, **ADO MCP**, **WorkIQ**, and reusable **Skills** — going from a spec, to a backlog, to working code, to a reviewed PR, to a burndown dashboard.

**Speakers:** Many Ndoro · Shayon Gupta · Tyler Gunter · Youssef Ouenniche

---

## Quick start

```powershell
git clone <this repo>
cd copilot-cli-workshop
npm install
npm test                # should pass (2 smoke tests)
```

Before starting the lab, make sure you are in the cloned repo directory and can find the two key workshop inputs:

```powershell
pwd
dir spec
dir .github\skills
```

You should see `spec/oncall-handoff-notes.md` and six skills under `.github/skills`.

**Configure ADO** (sets env vars + writes `.mcp.json` in one shot):

Your facilitator will provide the workshop ADO values during the meeting.

```powershell
.\configure.ps1
# It will prompt for the required ADO values.
```

**Pre-flight checks:**

```powershell
.\verify.ps1
```

All green? You're ready. Then start Copilot CLI in the same terminal:

```powershell
copilot
```

> **Heads-up:** the ADO env vars live for one terminal session. If you close this window and open a new one, **re-run `.\configure.ps1`** before starting `copilot` — otherwise the skills will lose their area-path filter and create work items in the wrong place.

---

## Phase 0 — Seed WorkIQ context *(2 min — do this first)*

Later, in **Phase 4**, you'll build **F6 (Import suggested notes from WorkIQ)**, which scans your emails, Teams chats, meetings, and IcMs for handoff-worthy context. To make that real instead of canned, seed WorkIQ with a dummy IcM **now**, so it's ingested by the time you get there.

```powershell
!code workiq/demo-icm-email.md
```

1. **Pair up** with the person next to you and swap email addresses.
2. Open `workiq/demo-icm-email.md`, paste the **Subject** and **Body** into a new Outlook email **to your buddy**, and send it. (You'll get theirs too — now you both have inbound context.)
3. **Carry on with the rest of setup.** WorkIQ takes ~2 minutes to pick up the email, so let it bake while you configure ADO and run Phases 1–3.

> **Why a real email?** WorkIQ draws on your actual work context. Sending the IcM gives F6 something genuine to surface — and gets you used to how WorkIQ ingests context. (If it hasn't ingested by the time you reach F6, that's fine: the import script still has a mock-mode fallback.)

---

## The workshop loop

> **Spec → Backlog → Visualize → Build → PR → Review → Visualize again**

The same skill (`backlog-organizer`) is run twice — once before the build (lots of red flags) and once after (green, with burndown). That's the headline demo moment.

---

## The 6 phases (and the prompts you'll use)

Copy-paste these into Copilot CLI as you go. Brackets like `<ID>` mark where to substitute your own value.

### Phase 1 — Spec → Tasks *(7 min)*

Open the repo folder first:

```powershell
!code .
```

Keep the Explorer pane open so you can see generated files appear later, like `.workshop/backlog.json`, `docs/dashboard.html`, and code or test files created during the build phase. The product spec lives at `spec/oncall-handoff-notes.md`:

```powershell
!code spec/oncall-handoff-notes.md
```

Skim the spec so you know what you're building.

> **What's the  "!" for?** Inside Copilot CLI, anything you type is normally sent to the agent as a prompt. Prefixing a line with `!` tells Copilot CLI to **run it directly in your shell** instead. So `!code spec/oncall-handoff-notes.md` launches VS Code, while typing the same line *without* the `!` would just hand the text to the agent to interpret.
>
> **Try it both ways** to see the difference in action: first type `code spec/oncall-handoff-notes.md` (no `!`) and watch the agent respond, then run `!code spec/oncall-handoff-notes.md` and watch VS Code open.
>
> Sometimes, this is useful when you don't want to exit out of your session or open another shell window.

Then generate the task list:

```
Run the spec-to-tasks skill on spec/oncall-handoff-notes.md
```

**Output:** `.workshop/backlog.json` — review it, make sure it looks right.

> *Optional (if you have time): the spec has a few `<OPTIONAL EDIT>` markers where you can replace example content with your own voice. Skip them if you're pressed for time — the spec works as-is.*

### Phase 2 — Create your ADO Feature, then generate stories *(7 min)*

In the video/demo, create the parent Feature manually in ADO first. This makes the shared project safer and easier to explain because everyone can see their own clearly named container before Copilot writes anything.

Your facilitator will provide the parent Epic to use during the meeting. Create your Feature under that Epic.

Create a **Feature** named:

```text
<alias> - On-Call Handoff Notes
```

Example:

```text
youralias - On-Call Handoff Notes
```

After saving the Feature, copy its **Feature ID** from the work item header. The Feature URL should look like your organization's ADO work item URL with the new Feature ID at the end.

```text
https://dev.azure.com/<org>/<project>/_workitems/edit/<FEATURE_ID>
```

> **Important:** if you create the Feature from inside the Epic page, copying the browser address bar may copy the **Epic** URL instead of the new Feature URL. The safer shortcut is to copy the numeric **Feature ID** from the saved Feature and use that ID in the prompt.

Then ask the skill to create the backlog under that Feature:

```
Run the backlog-to-ado skill using this parent feature: <FEATURE_ID>
```

**Output:** User Stories appear as children of your manually created Feature, all tagged `workshop`.

### Phase 2.5 — Decompose stories into assigned Tasks *(3 min)*

Run one more skill to create the implementation Tasks, assign them to you, and set Effort (Hours) using the workshop's 1/3/5-hour sizing convention:

```
Run the backlog-to-tasks skill
```

**Output:** Tasks appear under the User Stories, assigned to you, with **Original Estimate** and **Remaining** set to 1, 3, or 5 hours.

### Phase 2.6 — Poke the backlog with freeform MCP *(6 min)*

This is where you *feel* what ADO MCP is. Try a few of these, one at a time:

```
List all workshop-tagged work items in my project, grouped by state.
```

```
Show me the top 3 stories by priority with their acceptance criteria.
```

```
Add a comment to story #<ID>: "let's discuss in standup".
```

```
Find any stories whose title mentions "workiq" and tag them "needs-design".
```

The point: **MCP = Copilot CLI can do anything ADO's API can do, in plain English.**

> **Area-path scoping is automatic.** `.github/copilot-instructions.md` tells Copilot CLI to
> scope ADO read/write work to your `$env:ADO_AREA_PATH` or to the validated alias-prefixed
> Feature link you provided in Phase 2, so even freeform prompts like the ones above won't
> touch other teams' items on a shared project. (Loaded at startup — if you edit it,
> `/restart`.) You can still name the area path explicitly in a prompt if you want.

#### Power-user prompt (optional, 1 min)

If you want to see hierarchical decomposition in action for a custom or newly imagined story:

```
Pick story #<ID>. Decompose it into 3–5 implementation tasks
in ADO, linked as children of the story. Each task should be small enough to do.
Assign them to me, and pin them under the same area path as the parent.
For each Task, set Effort (Hours): Original Estimate and Remaining to one of 1, 3, or 5.
```

> **Effort sizing rule of thumb:** use **1 hour** for a small route/query change, **3 hours** for normal UI + test work, and **5 hours** for larger integration work like WorkIQ import. The `backlog-to-tasks` skill applies this automatically for the standard workshop backlog.

### Phase 3 — Visualize the backlog (Run #1) *(7 min)*

```
Run the backlog-organizer skill
```

**Output:** `docs/dashboard.html` opens in your browser. You'll see:
- A Feature-scoped **Backlog Item health** score
- A burn-down chart for remaining stories / effort
- New / Active / Closed state for User Stories and Tasks under your Feature
- Any gaps the organizer found, without mixing in other participants' backlog items

The dashboard is deterministic for the same ADO state: it reads only descendants of your alias-prefixed Feature, sorts items by ID, uses fixed health formulas, and avoids tag-only or area-wide fallbacks.

Click into a flagged story in ADO — you'll see the skill's comment explaining what it found.

### Phase 4 — Build the prototype *(20 min)*

**Suggested build order.** The stories build on each other, so tackle them in this sequence:

1. **Create a handoff note (F1)** — the foundation: the form, the `notes` table, and the create route.
2. **List all handoff notes (F2)** — a server-side page that renders the notes you just created, newest first.
3. **WorkIQ import (F6)** *(stretch / homework)* — the agentic story. If you run out of time in the workshop, this is a fun one to try afterward on your own.

Start by finding and claiming a story:

```
Show me ready stories in my ADO project that are not assigned.
```

```
Assign story #<ID> to me, move it to Active, and tell me what its Acceptance Criteria is.
```

Then build it:

```
Implement ADO story #<ID> in this repo. Use Express and better-sqlite3.
Add the route(s), a minimal HTML view if needed, and at least one Jest test in the tests/ directory.
Run the tests when done.
```

Once F1 is green, repeat the claim → build loop for **F2 (List all handoff notes)** so you can actually see the notes you create. Then, if time allows, take on **F6 (WorkIQ import)** — or save it as homework.

> **F6 tip:** the dummy IcM you emailed your buddy back in [Phase 0](#phase-0--seed-workiq-context-2-min--do-this-first) should be in WorkIQ's context by now — that's the live data F6 can surface. If it isn't, the import script's mock-mode fallback still works.

Iterate with Copilot CLI as it works.

> 💡 **Go for the full app — and beyond.** Implementing *all* the stories gets you a genuinely useful, full-featured handoff tool, so don't stop at one. And don't feel boxed in by the backlog: if you imagine a feature that isn't on the list — dark mode, search, Slack/Teams export, an LLM-written shift summary, whatever — build it! This is the whole point of working with AI: it collapses the cost of trying ideas, so lean into your creativity and go above and beyond. The best demos at the end are usually the ones where someone followed a "what if…" and let Copilot CLI run with it.

**Review before committing:**

```powershell
git status              # what files changed
git diff                # the actual changes
git diff --stat         # a quick summary
npm test                # re-run the tests yourself
```

Only commit once you've eyeballed the diff. If the agent went off the rails:

```powershell
git checkout -- .       # discard all unstaged changes and try again
```

When you're happy:

```powershell
git checkout -b feature/story-<ID>
git add -A
git commit -m "feat: implement story #<ID>"
```

**Quick smoke-test your built endpoint** (in a second PowerShell window, while `npm start` is running):

```powershell
# Happy path
Invoke-RestMethod -Method POST -Uri http://localhost:3000/notes `
  -ContentType "application/json" `
  -Body '{"title":"Test handoff","service":"payments","severity":"urgent","details":"Watch the SQL queue at 9am.","author":"You"}'

# See it in the list (newest first)
Invoke-RestMethod -Uri http://localhost:3000/notes -Headers @{ Accept = "application/json" }

# Sad path (should return a 400 + error)
Invoke-RestMethod -Method POST -Uri http://localhost:3000/notes `
  -ContentType "application/json" -Body '{}'
```

> **Tip:** Use `Invoke-RestMethod` (built into PowerShell), not `curl.exe`. Backslash-escaping JSON for `curl.exe` on Windows is painful.

### Phase 4.5 — ADO CLI vs Copilot CLI *(3 min)*

A quick contrast to feel why MCP matters. Run **one** raw ADO CLI command:

```powershell
az boards work-item show --id <ID>
az boards work-item update --id <ID> --state "Active"
```

Then ask Copilot CLI the same thing:

```
Show me work item <ID> and move it to Active.
```

Same result. MCP just removes the need to remember flags.

### Phase 5 — Raise the PR + review with Skills *(10 min)*

Open the PR:

```
Create a branch for story #<ID>, commit my changes, push it, and open a PR in ADO linked to that work item.
```

Then run both review skills:

```
Run the pr-summarizer skill on my open PR
Run the pr-review skill on my open PR
```

**Output:** A polished PR description + a focused review with only high-signal comments.

### Phase 6 — Visualize again (Run #2) *(7 min)*

```
Run the backlog-organizer skill
```

**Output:** Same `docs/dashboard.html`, but now:
- Health score climbed (ownership 40% → 100%, etc.)
- Burndown line shows real movement
- Done count is non-zero
- Recently completed list shows your story

Same skill, run twice. That's the lesson.

---

## The 5 Skills

| Skill | What it does | Mutates state? |
|---|---|---|
| `spec-to-tasks` | Reads the spec → writes `.workshop/backlog.json` | No (file write only) |
| `backlog-to-ado` | Reads the JSON → creates ADO User Stories under your manual Feature | Yes (creates ADO items, idempotent) |
| `backlog-to-tasks` | Creates child Tasks, assigns them, and sets 1/3/5-hour Effort | Yes (creates/updates Task items, idempotent) |
| `backlog-organizer` | Analyzes the ADO backlog → tags gaps, adds comments, renders dashboard | Yes (tags + comments only; never changes state/assignee) |
| `pr-review` | Reviews your PR against team standards | Yes (posts review on PR) |
| `pr-summarizer` | Generates a clean PR description from the diff | Yes (updates PR description) |

All skills live in `.github/skills/<skill-name>/SKILL.md` and are version-controlled with the repo. Share them with your team by sharing the repo.

**What is a skill?** A skill is a small Markdown instruction pack that teaches Copilot CLI how to do one repeatable workflow. For example, `.github/skills/backlog-to-tasks/SKILL.md` tells Copilot how to create child Tasks, assign them, and set Effort without a pile of follow-up prompts.

---

## MCP one-liner cheat sheet

Use these anytime — no skill needed.

### Read

```
List my work items in priority order
```

```
Show me PRs raised this week in this repo
```

```
Get the description and AC of story #<ID>
```

### Write

```
Add a comment to #<ID>: <text>
```

```
Tag stories matching <query> with <tag>
```

```
Link story #<ID> to PR #<PR-ID>
```

### Reflect

```
Summarize what's blocking story #<ID> based on its comments
```

```
What changed in this repo in the last 24 hours?
```

---

## What's in this repo

```
.
├── spec/
│   └── oncall-handoff-notes.md   # The product spec — edit me in Phase 1
├── workiq/
│   └── demo-icm-email.md         # Dummy IcM email to seed WorkIQ context — send during Phase 0
├── src/server.js                 # Hello-world Express app — your starting point
├── tests/server.test.js          # One passing smoke test
├── data/                         # SQLite file will live here
├── docs/                         # backlog-organizer writes dashboard.html here
├── .workshop/                    # spec-to-tasks writes backlog.json here
├── .mcp.json                     # ADO MCP server config (edit org)
├── .github/
│   ├── copilot-instructions.md   # Auto-loaded rules (scopes ADO work to your area path)
│   └── skills/
│       ├── spec-to-tasks/SKILL.md
│       ├── backlog-to-ado/SKILL.md
│       ├── backlog-to-tasks/SKILL.md
│       ├── backlog-organizer/SKILL.md
│       ├── pr-review/SKILL.md
│       └── pr-summarizer/SKILL.md
├── verify.ps1                    # Pre-flight env check
├── package.json
└── README.md                     # You are here
```

---

## Fallback branches

If you fall behind, you can catch up at any phase boundary:

- `phase-3-fallback` — backlog generated, dashboard rendered (start of Phase 4)
- `phase-5-fallback` — full app implemented, ready for review (start of Phase 5)
- `phase-6-fallback` — PR merged, ready for the final dashboard run

```powershell
git fetch origin
git checkout phase-3-fallback
npm install
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `verify.ps1` fails on Copilot CLI | `npm install -g @github/copilot` then `copilot login` |
| `verify.ps1` fails on `az` | `az login` and `az extension add --name azure-devops` |
| Port 3000 in use | `$env:PORT=3001; npm start` |
| ADO MCP can't see my project | Edit `.mcp.json` with your org (or just re-run `.\configure.ps1`), restart Copilot CLI |
| I opened a new terminal and my work items go to the wrong area | ADO env vars are session-scoped. Re-run `.\configure.ps1` in the new terminal, **then** restart `copilot`. |
| Tests hang | Make sure you're on Node 20+: `node --version` |
| `npm install` fails building `better-sqlite3` (`gyp ERR! find Python`) | `better-sqlite3` is a native module that uses a **prebuilt binary** for your Node version — no Python/compiler needed. The error means npm couldn't find a prebuilt binary and fell back to compiling from source. Fix: use a Node version with prebuilds. This repo pins `better-sqlite3@^12`, which has prebuilds through **Node 24**. If you're on an even newer Node, install **Node 20 or 22 LTS** (`node --version` to check), delete `node_modules`, and re-run `npm install`. |
| Dashboard looks empty | You haven't run `backlog-to-ado` yet, or your ADO items aren't tagged `workshop` |
| WorkIQ shows no real context | Make sure you actually sent `workiq/demo-icm-email.md` to your buddy in Phase 0 and waited ~2 min for ingestion. The F6 mock-mode fallback works regardless. |
| I edited a skill but my changes aren't taking effect | **Reload skills.** Run `/skills reload`, or run `/restart` to reload the whole CLI while keeping your current session. **Tip:** when you `exit`, the CLI prints a session ID with a `copilot --resume <id>` command so you can pick the conversation back up where you left off. |
| Dashboard didn't regenerate after re-running | Delete `docs/dashboard.html` first, then re-run the skill. Browsers also cache — hard-refresh with `Ctrl+F5`. |

---

## After the workshop

- **Fork this repo** for your team
- **Edit the spec** to describe your real product
- **Tweak the skills** in `.github/skills/` — they're just markdown, version-controlled with your code
- **Add your own skills** — a skill is a markdown file with a `name` and `description`. Copilot CLI will discover them automatically.
