---
name: spec-to-plan
description: Reads a product spec markdown file and produces a structured backlog plan (parent feature metadata + user stories with acceptance criteria) as a JSON file ready for plan-to-backlog.
---

# Spec to Tasks Skill

You convert a product spec into a structured, ADO-ready backlog plan. You do **not** write to ADO - that's `plan-to-backlog`'s job. Your output is a single JSON file.

## Inputs
- A spec markdown file (default: `spec/oncall-handoff-notes.md`).
- If the user provides a different path, use that.

## What to do

1. **Read the spec** in full. Pay attention to:
   - Section 6 (MVP features) — each `F<N>` becomes one user story
   - Section 4 (Goals) — informs acceptance criteria
   - Section 7 (Out of scope) — never generate stories for these
   - Section 8 (Technical constraints) — included as context in each story description
   - Section 9 (Success criteria) — informs acceptance criteria

2. **Generate the backlog** with this structure:
   - **1 parent Feature metadata object** named from the spec's title (e.g., "On-Call Handoff Notes MVP"). This is metadata only; `plan-to-backlog` links stories under the participant's manually created ADO Feature.
   - **One User Story per feature** (F1, F2, ... F7 if present)
   - Each story includes: title, description, acceptance criteria (2–4 items), suggested priority, suggested size

3. **Write the result** to `.workshop/backlog.json` (create the folder if needed). Overwrite if it exists.

4. **Print a summary** to the terminal: parent Feature metadata name, count of stories, and a 1-line summary of each.

## Output JSON schema

```json
{
  "parent_feature": {
    "title": "string",
    "description": "string (2–3 sentences, drawn from spec sections 1 and 2)",
    "tags": ["workshop", "oncall"]
  },
  "stories": [
    {
      "feature_id": "F1",
      "title": "string (imperative voice, e.g., 'Create a handoff note')",
      "description": "string (1–2 paragraphs, includes the relevant tech constraints)",
      "acceptance_criteria": [
        "Given ... when ... then ...",
        "..."
      ],
      "priority": "P0 | P1 | P2",
      "size": "XS | S | M",
      "tags": ["workshop", "oncall", "feature"]
    }
  ]
}
```

## Rules for generating stories

- **Title**: Short, imperative ("Create a handoff note", not "User can create a note"). Match the feature heading from the spec when possible.
- **Description**: Restate the feature in your own words. Include the relevant tech constraint snippet from Section 8 (e.g., "Use Express route and better-sqlite3."). Do not invent requirements the spec doesn't state.
- **Acceptance criteria**: Write as testable Given/When/Then statements. 2–4 per story. Pull directly from the spec's wording — do not invent new behavior.
- **Priority**:
  - Foundational features (create, list) → `P0`
  - Filter, mark-resolved, toggle-open-only → `P1`
  - F6 (WorkIQ import) → `P0` (it's the headline feature)
  - F7 (participant-added) → `P2`
- **Size**:
  - Simple CRUD route + view → `XS`
  - Adds a query param or a button + handler → `S`
  - WorkIQ-import (new script + new schema column + new UI section) → `M`
- **Tags**: Always include `workshop` and `oncall`. Add `feature` for stories. F6 also gets `agentic`.

## Rules for what NOT to generate

- Do not generate stories for items in Section 7 (Out of scope).
- Do not generate stories for non-functional concerns the spec doesn't list.
- Do not generate "setup" or "scaffolding" stories — the repo already has a starter.
- Do not generate test stories — testing is an acceptance criterion on each story, not a separate story.

## Special handling for F6 (WorkIQ import)

This story is the most demo-worthy. Be extra careful:
- Description must mention the `npm run import:workiq` script
- Description must mention the mock-mode fallback for offline reliability
- AC must include: `status='draft'`, `source='workiq'`, a separate "Suggested" section in the UI, and Accept/Dismiss actions
- AC must NOT include real WorkIQ API calls in the app — only via the import script

## Output

After writing the JSON, print to the terminal:

```
✅ Backlog written to .workshop/backlog.json

Parent feature metadata: <title>

Stories generated (<count>):
  [P0/XS] F1: <title>
  [P0/XS] F2: <title>
  ...

Next step: create your ADO Feature manually, then run the `plan-to-backlog` skill with that Feature link.
```
