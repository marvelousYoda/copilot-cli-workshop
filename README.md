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

**Configure ADO** (sets env vars + writes `.copilot/mcp.json` in one shot):

```powershell
.\configure.ps1
# It will prompt for: ADO org name, ADO project name, and your area path.
# Or pass them on the command line:
# .\configure.ps1 -Org "myorg" -Project "MyProject" -AreaPath "MyProject\Workshop"
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

## The workshop loop

> **Spec → Backlog → Visualize → Build → PR → Review → Visualize again**

The same skill (`backlog-organizer`) is run twice — once before the build (lots of red flags) and once after (green, with burndown). That's the headline demo moment.

---

## The 6 phases (and the prompts you'll use)

Copy-paste these into Copilot CLI as you go. Brackets like `<ID>` mark where to substitute your own value.

### Phase 1 — Spec → Tasks *(7 min)*

The spec is **ready to use**. Skim it so you know what you're building:

```powershell
code spec/oncall-handoff-notes.md
```

Then generate the task list:

```
Run the spec-to-tasks skill on spec/oncall-handoff-notes.md
```

**Output:** `.workshop/backlog.json` — review it, make sure it looks right.

> *Optional (if you have time): the spec has a few `<OPTIONAL EDIT>` markers where you can replace example content with your own voice. Skip them if you're pressed for time — the spec works as-is.*

### Phase 2 — Generate the backlog in ADO *(7 min)*

```
Run the backlog-to-ado skill
```

**Output:** an Epic + 6–7 User Stories appear in your ADO project, all tagged `workshop`.

### Phase 2.5 — Poke the backlog with freeform MCP *(6 min)*

This is where you *feel* what ADO MCP is. Try a few of these:

```
> List all workshop-tagged work items in my project, grouped by state.
> Show me the top 3 stories by priority with their acceptance criteria.
> Add a comment to story #<ID>: "let's discuss in standup".
> Find any stories whose title mentions "workiq" and tag them "needs-design".
```

The point: **MCP = Copilot CLI can do anything ADO's API can do, in plain English.**

#### Power-user prompt (optional, 1 min)

If you want to see hierarchical decomposition in action — useful when you're about to pick up a story and want it broken into half-hour chunks:

```
> Pick the story for F6 (WorkIQ import). Decompose it into 3–5 implementation tasks
> in ADO, linked as children of the story. Each task should be small enough to do
> in 30 minutes. Don't assign them, and pin them under the same area path as the parent.
```

> **Note:** We intentionally don't decompose every story upfront — it would flood the dashboard. Decompose **on demand**, only when you're about to work on something. This is closer to how real teams operate.

### Phase 3 — Visualize the backlog (Run #1) *(7 min)*

```
Run the backlog-organizer skill
```

**Output:** `docs/dashboard.html` opens in your browser. You'll see:
- A low-ish health score (40–60s is normal here)
- 6+ stories all missing owners (intentional)
- Maybe a few "unclear" or "no priority" flags
- An empty burndown

Click into a flagged story in ADO — you'll see the skill's comment explaining what it found.

### Phase 4 — Build the prototype *(20 min)*

Pick one story (preferably your F7 or the F6 WorkIQ import — those are the most interesting):

```
> Show me ready stories in my ADO project that are not assigned.
> Assign story #<ID> to me, move it to In Progress, and tell me what its AC are.
```

Then build:

```
> Implement ADO story #<ID> in this repo. Use Express and better-sqlite3.
> Add the route(s), a minimal HTML view if needed, and at least one Jest test in tests/.
> Run the tests when done.
```

Iterate with Copilot CLI as it works.

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
  -Body '{"title":"Test handoff","body":"Watch the SQL queue at 9am."}'

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
> Show me work item <ID> and move it to Active.
```

Same result. MCP just removes the need to remember flags.

### Phase 5 — Raise the PR + review with Skills *(10 min)*

Open the PR:

```
> Create a branch for story #<ID>, commit my changes, push it, and open a PR in ADO linked to that work item.
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
| `backlog-to-ado` | Reads the JSON → creates ADO Epic + Stories | Yes (creates ADO items, idempotent) |
| `backlog-organizer` | Analyzes the ADO backlog → tags gaps, adds comments, renders dashboard | Yes (tags + comments only; never changes state/assignee) |
| `pr-review` | Reviews your PR against team standards | Yes (posts review on PR) |
| `pr-summarizer` | Generates a clean PR description from the diff | Yes (updates PR description) |

All skills live in `.copilot/skills/` and are version-controlled with the repo. Share them with your team by sharing the repo.

---

## MCP one-liner cheat sheet

Use these anytime — no skill needed.

```
# Read
> List my work items in priority order
> Show me PRs raised this week in this repo
> Get the description and AC of story #<ID>

# Write
> Add a comment to #<ID>: <text>
> Tag stories matching <query> with <tag>
> Link story #<ID> to PR #<PR-ID>

# Reflect
> Summarize what's blocking story #<ID> based on its comments
> What changed in this repo in the last 24 hours?
```

---

## What's in this repo

```
.
├── spec/
│   └── oncall-handoff-notes.md   # The product spec — edit me in Phase 1
├── src/server.js                 # Hello-world Express app — your starting point
├── tests/server.test.js          # One passing smoke test
├── data/                         # SQLite file will live here
├── docs/                         # backlog-organizer writes dashboard.html here
├── .workshop/                    # spec-to-tasks writes backlog.json here
├── .copilot/
│   ├── mcp.json                  # ADO MCP server config (edit org/project)
│   └── skills/
│       ├── spec-to-tasks.md
│       ├── backlog-to-ado.md
│       ├── backlog-organizer.md
│       ├── pr-review.md
│       └── pr-summarizer.md
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
| `verify.ps1` fails on Copilot CLI | `npm install -g @github/copilot` then `copilot auth login` |
| `verify.ps1` fails on `az` | `az login` and `az extension add --name azure-devops` |
| Port 3000 in use | `$env:PORT=3001; npm start` |
| ADO MCP can't see my project | Edit `.copilot/mcp.json` with your org/project (or just re-run `.\configure.ps1`), restart Copilot CLI |
| I opened a new terminal and my work items go to the wrong area | ADO env vars are session-scoped. Re-run `.\configure.ps1` in the new terminal, **then** restart `copilot`. |
| Tests hang | Make sure you're on Node 20+: `node --version` |
| Dashboard looks empty | You haven't run `backlog-to-ado` yet, or your ADO items aren't tagged `workshop` |
| WorkIQ import returns nothing | The `import:workiq` script will use mock data automatically. That's fine for the workshop. |
| I edited a skill but my changes aren't taking effect | **Restart Copilot CLI.** Skills are loaded once at startup. `exit` then `copilot` to re-launch. |
| Dashboard didn't regenerate after re-running | Delete `docs/dashboard.html` first, then re-run the skill. Browsers also cache — hard-refresh with `Ctrl+F5`. |

---

## After the workshop

- **Fork this repo** for your team
- **Edit the spec** to describe your real product
- **Tweak the skills** in `.copilot/skills/` — they're just markdown, version-controlled with your code
- **Add your own skills** — a skill is a markdown file with a `name` and `description`. Copilot CLI will discover them automatically.
