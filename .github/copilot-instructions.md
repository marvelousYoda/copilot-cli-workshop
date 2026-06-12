# Copilot CLI instructions for this workshop

These rules apply to every prompt in this repo, including ad-hoc / freeform requests
(e.g., Phase 2.5, Phase 4) — not just the named skills.

## Always scope Azure DevOps work to the configured area path

The workshop sets the `ADO_AREA_PATH` environment variable (via `configure.ps1`). It marks
the slice of the ADO project that belongs to **this** participant. Other items in the same
project belong to other teams or other participants and must be left alone.

When reading from, querying, or modifying Azure DevOps work items via the ADO MCP server:

- **Always scope to `$env:ADO_AREA_PATH`.** Add `AND [System.AreaPath] UNDER '<value>'`
  to every WIQL query, substituting the current value of `ADO_AREA_PATH`.
- **Never return, summarize, tag, comment on, or modify work items outside that area path**,
  even if they match the `workshop` tag or other filters. The `workshop` tag alone is **not**
  sufficient isolation on a shared project — area path is the real boundary. Combine both:
  `[System.Tags] CONTAINS 'workshop' AND [System.AreaPath] UNDER '$env:ADO_AREA_PATH'`.
- **When creating work items, set `System.AreaPath` to `$env:ADO_AREA_PATH`.**
- **If `ADO_AREA_PATH` is not set**, do not silently fall back to the whole project. Stop and
  ask the user to run `.\configure.ps1` first. The one exception is a dedicated, non-shared
  workshop project where creating at the project root is acceptable — confirm with the user
  before proceeding. Never write to a known shared project
  (`Enterprise Cloud`, `OS`, `AzureDevOps`, `DevDiv`, `Office`) without an area path.
- **If the user provides an explicit workshop Feature URL or ID**, you may fetch that single
  Feature to read its `System.AreaPath`, but only proceed with writes if the Feature title is
  clearly alias-prefixed (for example, `shaygupt - On-Call Handoff Notes`). Use that Feature's
  area path as the boundary, and write only child items under that Feature. If the Feature is
  not alias-prefixed, is outside the expected workshop area, or is not a Feature, stop.
- If a request would touch items outside `$env:ADO_AREA_PATH`, ask the user to confirm before
  proceeding, and explain that it falls outside their workshop area path.
