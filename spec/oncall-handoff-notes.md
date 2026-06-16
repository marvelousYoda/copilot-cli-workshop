# Product Spec — On-Call Handoff Notes

> **Workshop instructions:** This spec is **ready to use** - read it end-to-end so you understand what you're building, then run the `spec-to-plan` skill in the next step. No editing required.
>
> *(Optional — if you finish early or want to personalize: the sections marked `<OPTIONAL EDIT>` are good places to add your own voice. Skip them if you're pressed for time.)*

---

## 1. One-liner

A lightweight tool where the outgoing on-call engineer leaves structured handoff notes for the incoming on-call, so context isn't lost between shifts.

## 2. Problem

On-call rotations hand off every week (or every day). Today, handoffs happen in ad-hoc Teams chats, scattered emails, IcM comments, or — most often — not at all. The incoming on-call walks into their shift blind to:

- What incidents are still open or simmering
- Which services have been flaky and might page again
- Workarounds applied that haven't been turned into permanent fixes
- Customer escalations that need follow-up
- **Context that already exists, but is fragmented across Teams chats, emails, meetings, and IcMs** — nobody has time to chase it down

This causes repeated investigation, slower MTTR, and on-call fatigue.

**Additional pain point:** Hand-offs that happen at midnight or during a SEV-2 are the worst — Slack messages get lost in scroll, IcM tickets only capture the *current* issue (not the broader context), and the new on-call has to piece together "what was already tried" from 5+ tools.

> *`<OPTIONAL EDIT>` — Replace this with a pain point you've personally seen if you want to make it your own.*

## 3. Users

| User | What they do |
|---|---|
| **Outgoing on-call engineer** | Writes notes at end of shift |
| **Incoming on-call engineer** | Reads notes at start of shift, marks items resolved as they handle them |
| **On-call lead / EM** | Skims notes across shifts to spot patterns |

## 4. Goals

- Capture handoff context in **under 2 minutes** per shift
- Make notes **searchable** and **filterable** by service
- Surface **unresolved notes** to the incoming on-call automatically
- **Auto-discover** handoff-worthy context that already exists in Teams chats, emails, meetings, and IcMs — so the on-call doesn't have to remember everything

## 5. Non-goals

- Not an incident management tool (does not replace IcM)
- Not a chat or messaging tool
- No SLAs, no alerting, no paging integration
- No multi-tenant / no permissions model — single-team use only for v1

## 6. MVP features

Each item below should become **one user story** in the backlog.

### F1. Create a handoff note
A simple form with these fields:
- **Title** (short, required)
- **Service / area** (free text, required — e.g., "AuthService", "Billing API")
- **Severity** (dropdown: `info`, `watch`, `urgent`)
- **Details** (multi-line text, required)
- **Suggested action** (multi-line text, optional)

Submitting saves the note with the current timestamp and the author's name (from a simple text input for v1 — no auth).

### F2. List all handoff notes
A page showing every note, newest first. Each row shows: timestamp, author, service, severity (color-coded), title, and a "resolved" badge if applicable.

### F3. Filter notes by service
A dropdown or text filter at the top of the list. Shows only notes matching the selected service.

### F4. Mark a note as resolved
Each note has a "Mark resolved" button. Clicking it sets a resolved flag + timestamp. Resolved notes still appear in the list but are visually de-emphasized.

### F5. View only unresolved notes
A toggle at the top of the list: "Show all" / "Open only". Defaults to "Open only" so the incoming on-call sees what matters first.

### F6. Import suggested notes from scattered sources (WorkIQ)
On-call context is everywhere except where it should be. This feature uses **WorkIQ** (via a Copilot CLI workflow) to scan Teams chats, emails, meetings, and IcMs for the past 7 days and surface anything that looks like a handoff-worthy item.

**How it works:**
- A separate script (`npm run import:workiq`) invokes Copilot CLI with a WorkIQ-flavored prompt
- The script writes each suggested item into the SQLite DB with `status='draft'` and `source='workiq'`
- The app's UI shows a **"Suggested notes" inbox** at the top of the list
- For each suggestion, the on-call can **Accept** (promotes to a real note), **Edit then accept**, or **Dismiss**
- Each suggestion shows where it came from (e.g., "From Teams chat with @alice, 2 days ago")

**Acceptance criteria:**
- Running `npm run import:workiq` populates at least 1 draft note (using mock data if WorkIQ is unavailable, so the demo always works)
- The list page shows a separate "Suggested (N)" section above the regular notes
- Accept / Dismiss buttons work and update the DB
- Source attribution is visible on every suggestion

> **Note for workshop:** The script ships with a **mock-mode fallback** so this feature works offline. When WorkIQ is available, real data flows; when it isn't, canned suggestions appear. Same UX either way.

### F7. Sort notes by severity
On the list view, allow sorting so `urgent` notes appear before `watch`, which appear before `info`. Default ordering on first load: severity descending, then created_at descending.

**Acceptance:**
- `GET /notes?sort=severity` returns notes ordered urgent → watch → info, then by newest within each bucket
- The HTML view has a "Sort by: [Severity ▾] [Newest]" toggle that swaps the order
- Existing tests still pass; one new test covers the sort order

> *`<OPTIONAL EDIT>` — Want to build something different? Replace F7 with any small feature: "snooze until" date, export to markdown, open-notes count per service, tags on a note, etc. Keep it small enough to build in ~5 minutes.*

### F8. Share notes (copy or email)
Once a handoff is written, the on-call needs to get it into Teams, an email, or an IcM comment. We don't want to *send* messages from the app (no SMTP, no Teams API, no auth) — we just need to make the content **one-click shareable**.

**Acceptance:**
- `GET /notes/:id/share?format=md` returns a clean, copy-pasteable Markdown summary of that note (title, severity, service, details, suggested action, author, timestamp).
- `GET /notes/share/today?format=md` returns a summary of **all open notes**, grouped by severity (urgent first), suitable for pasting into a daily handoff Teams chat.
- The HTML list view shows a **"📋 Copy"** button per note (copies the markdown to clipboard) and a **"✉️ Email"** button (opens a `mailto:` link with subject `On-call handoff: <title>` and the markdown as the body — properly URL-encoded).
- The list view also has a **"📋 Share today's handoff"** button at the top that copies the all-open-notes summary.
- Both work offline. No external API calls. No auth.
- One Jest test per endpoint covers the markdown shape (e.g. starts with `# `, contains severity emoji, etc.).

> *Why this is in scope when "Email or Teams notifications sent by the app" is out of scope:* We're not **sending** anything — we generate copy-pasteable content and use the user's own mail client via `mailto:`. The user stays in control of who sees what, and we never need their credentials.

## 7. Out of scope (explicitly)

- Authentication / login
- Email or Teams notifications **sent by the app via SMTP or Graph API** (we *read* from sources via WorkIQ, we don't *write back* programmatically — but see F8 for `mailto:` and copy-to-clipboard, which stay client-side)
- Mobile-optimized UI
- Multi-team / multi-rotation support
- Editing a note after it's submitted (v2)
- Attachments / images
- Real-time / streaming ingestion from WorkIQ — import is on-demand only
- Auto-acceptance of suggested notes — a human always reviews

## 8. Technical constraints

- **Stack:** Node.js + Express + better-sqlite3
- **Storage:** Single SQLite file in `data/`
- **UI:** Plain HTML rendered server-side. No SPA, no build step.
- **Tests:** Each route must have at least one Jest test in `tests/`
- **Runs locally:** `npm start` → `http://localhost:3000`. No cloud dependencies for the app itself.
- **WorkIQ integration:** Implemented as an `npm run import:workiq` script that shells out to Copilot CLI. The app itself never calls WorkIQ directly — it only reads from the SQLite DB.
- **Schema:** Notes table includes a `status` column (`draft` | `open` | `resolved`) and a `source` column (`manual` | `workiq` | future sources).

## 9. Success criteria

- A new on-call engineer can read the open notes and feel oriented in **< 5 minutes**
- Writing a note takes **< 2 minutes**
- All MVP features (F1–F5, F6 WorkIQ import, F7 sort, F8 share) are demoable end-to-end in the workshop
- Test suite passes (`npm test`)

## 10. Open questions

**Open questions:**
1. Do we want resolved notes to auto-archive after 30 days, or remain searchable forever?
2. Should the on-call lead get a weekly digest summarizing the week's notes (top services hit, most-cited root causes)?

> *`<OPTIONAL EDIT>` — Add your own questions to the list if you want to make it personal.*

---

## How this spec becomes a backlog

The `spec-to-plan` skill will read this file and produce:
- **1 parent Feature metadata object** — "On-Call Handoff Notes MVP"
- **8 User Stories** — one per feature (F1–F8)
- Each story will have a title, description, and 2–4 acceptance criteria

You'll review them, manually create your alias-prefixed ADO Feature, then `plan-to-backlog` pushes the stories under that Feature.
