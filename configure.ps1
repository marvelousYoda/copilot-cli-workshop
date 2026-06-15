# configure.ps1
# One-shot config for the workshop. Sets ADO env vars for THIS shell session and
# writes them into .mcp.json so the ADO MCP server can reach your project.
#
# Usage:
#   .\configure.ps1                                         # interactive (prompts for values)
#   .\configure.ps1 -Org "myorg" -Project "MyProject"       # non-interactive
#   .\configure.ps1 -Org "myorg" -Project "MyProject" -AreaPath "MyProject\Workshop" -Alias "youralias"
#   .\configure.ps1 -Org "myorg" -Project "MyProject" -AreaPath "MyProject\Workshop" -ParentId 12345 -Alias "youralias"
#
# -ParentId is optional. If provided, it should be the ADO work item ID of YOUR
# manually created Feature, named "<your alias> - On-Call Handoff Notes".
# You can also paste the Feature URL directly into the backlog-to-ado skill prompt.
#
# This must be re-run each time you open a new PowerShell window (env vars are
# scoped to the shell session). The .mcp.json edit is persistent.

param(
    [string]$Org,
    [string]$Project,
    [string]$AreaPath,
    [string]$ParentId,
    [string]$Alias
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Workshop ADO Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Interactive prompts if not provided
if (-not $Org) {
    $Org = Read-Host "ADO organization name (for example, 'contoso')"
}
if (-not $Project) {
    $Project = Read-Host "ADO project name (e.g. 'MyTeam-Workshop')"
}
if (-not $AreaPath) {
    $default = "$Project\Workshop"
    $input = Read-Host "Area path under which to create your backlog [$default]"
    $AreaPath = if ([string]::IsNullOrWhiteSpace($input)) { $default } else { $input }
}
if (-not $Alias) {
    $default = $env:USERNAME
    $input = Read-Host "Your alias (used for '<alias> - On-Call Handoff Notes' and participant tags) [$default]"
    $Alias = if ([string]::IsNullOrWhiteSpace($input)) { $default } else { $input }
}
if ($Alias -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Host "X Alias may only contain letters, digits, '.', '_', '-' (got '$Alias')." -ForegroundColor Red
    exit 1
}
if ($ParentId -and $ParentId -notmatch '^\d+$') {
    Write-Host "X ParentId must be a numeric work item ID (got '$ParentId')." -ForegroundColor Red
    exit 1
}

# Safeguard: refuse to point at the project root without a specific area path.
if (-not $AreaPath -or $AreaPath -eq $Project) {
    Write-Host ""
    Write-Host "X Refusing to configure without a specific area path." -ForegroundColor Red
    Write-Host "  Use the area path provided by your facilitator to avoid writing to the wrong backlog." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Re-run with the provided area path, for example:" -ForegroundColor Yellow
    Write-Host "    .\configure.ps1 -Org '$Org' -Project '$Project' -AreaPath '$Project\Workshop'" -ForegroundColor Yellow
    exit 1
}
if (-not $ParentId) {
    Write-Host ""
    Write-Host "! No -ParentId was given." -ForegroundColor Yellow
    Write-Host "  That's OK if you'll paste your Feature URL when running backlog-to-ado." -ForegroundColor Yellow
    Write-Host "  Create a Feature in ADO named '$Alias - On-Call Handoff Notes'," -ForegroundColor Yellow
    Write-Host "  then either paste its URL into the skill prompt or re-run with -ParentId <id>." -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: env vars for this shell
$env:ADO_ORG = $Org
$env:ADO_PROJECT = $Project
$env:ADO_AREA_PATH = $AreaPath
if ($ParentId) { $env:ADO_PARENT_ID = $ParentId } else { Remove-Item Env:\ADO_PARENT_ID -ErrorAction SilentlyContinue }
$env:ADO_PARTICIPANT = $Alias
Write-Host "[ OK ] Set `$env:ADO_ORG, `$env:ADO_PROJECT, `$env:ADO_AREA_PATH, `$env:ADO_PARENT_ID, `$env:ADO_PARTICIPANT for this shell" -ForegroundColor Green

# Step 2: rewrite .mcp.json with the chosen org
# Copilot CLI loads workspace MCP config from .mcp.json (or .github/mcp.json).
# The org is passed as a positional arg to the server.
$mcpPath = ".\.mcp.json"
if (-not (Test-Path $mcpPath)) {
    Write-Host "[FAIL] .mcp.json not found. Are you in the workshop repo root?" -ForegroundColor Red
    exit 1
}
$mcp = Get-Content $mcpPath -Raw
$mcp = $mcp -replace "REPLACE_WITH_ORG", $Org
$mcp = $mcp -replace "REPLACE_WITH_PROJECT", $Project
Set-Content -Path $mcpPath -Value $mcp -NoNewline
Write-Host "[ OK ] Wrote $mcpPath with org='$Org' project='$Project'" -ForegroundColor Green

# Step 3: configure az defaults if az is installed (silent if not)
if (Get-Command az -ErrorAction SilentlyContinue) {
    $orgUrl = "https://dev.azure.com/$Org/"
    az devops configure --defaults organization=$orgUrl project="$Project" 2>$null | Out-Null
    Write-Host "[ OK ] Configured 'az devops' defaults" -ForegroundColor Green
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  ADO_ORG       = $Org"
Write-Host "  ADO_PROJECT   = $Project"
Write-Host "  ADO_AREA_PATH = $AreaPath"
Write-Host "  ADO_PARENT_ID = $(if ($ParentId) { $ParentId } else { '(none — paste Feature URL into backlog-to-ado)' })"
Write-Host "  ADO_PARTICIPANT = $Alias"
Write-Host ""
Write-Host "Next: run .\verify.ps1 to confirm everything is wired up." -ForegroundColor Cyan
Write-Host ""
Write-Host "TIP: env vars only last for THIS terminal window. If you close it and" -ForegroundColor Yellow
Write-Host "     open a new one, re-run .\configure.ps1 (or the skills will lose" -ForegroundColor Yellow
Write-Host "     their area-path filter)." -ForegroundColor Yellow
