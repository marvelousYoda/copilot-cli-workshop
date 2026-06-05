# configure.ps1
# One-shot config for the workshop. Sets ADO env vars for THIS shell session and
# writes them into .copilot/mcp.json so the ADO MCP server can reach your project.
#
# Usage:
#   .\configure.ps1                                         # interactive (prompts for values)
#   .\configure.ps1 -Org "myorg" -Project "MyProject"       # non-interactive
#   .\configure.ps1 -Org "myorg" -Project "MyProject" -AreaPath "MyProject\Workshop"
#
# This must be re-run each time you open a new PowerShell window (env vars are
# scoped to the shell session). The .copilot/mcp.json edit is persistent.

param(
    [string]$Org,
    [string]$Project,
    [string]$AreaPath
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Workshop ADO Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Interactive prompts if not provided
if (-not $Org) {
    $Org = Read-Host "ADO organization name (e.g. 'contoso' or 'o365exchange')"
}
if (-not $Project) {
    $Project = Read-Host "ADO project name (e.g. 'MyTeam-Workshop')"
}
if (-not $AreaPath) {
    $default = "$Project\Workshop"
    $input = Read-Host "Area path under which to create your backlog [$default]"
    $AreaPath = if ([string]::IsNullOrWhiteSpace($input)) { $default } else { $input }
}

# Safeguard: refuse to point at known shared projects without an area path
$sharedProjects = @("Enterprise Cloud", "OS", "AzureDevOps", "DevDiv", "Office")
if ($sharedProjects -contains $Project -and (-not $AreaPath -or $AreaPath -eq $Project)) {
    Write-Host ""
    Write-Host "X '$Project' is a known shared project." -ForegroundColor Red
    Write-Host "  Refusing to configure without a more specific area path," -ForegroundColor Red
    Write-Host "  to prevent polluting the shared backlog." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Re-run with your team's area path, e.g.:" -ForegroundColor Yellow
    Write-Host "    .\configure.ps1 -Org '$Org' -Project '$Project' -AreaPath '$Project\YourTeam'" -ForegroundColor Yellow
    exit 1
}

# Step 1: env vars for this shell
$env:ADO_ORG = $Org
$env:ADO_PROJECT = $Project
$env:ADO_AREA_PATH = $AreaPath
Write-Host "[ OK ] Set `$env:ADO_ORG, `$env:ADO_PROJECT, `$env:ADO_AREA_PATH for this shell" -ForegroundColor Green

# Step 2: rewrite .copilot/mcp.json with the chosen org/project
$mcpPath = ".\.copilot\mcp.json"
if (-not (Test-Path $mcpPath)) {
    Write-Host "[FAIL] .copilot\mcp.json not found. Are you in the workshop repo root?" -ForegroundColor Red
    exit 1
}
$mcp = Get-Content $mcpPath -Raw
$mcp = $mcp -replace "REPLACE_WITH_ORG", $Org
$mcp = $mcp -replace "REPLACE_WITH_PROJECT", $Project
Set-Content -Path $mcpPath -Value $mcp -NoNewline
Write-Host "[ OK ] Wrote $mcpPath with org='$Org' project='$Project'" -ForegroundColor Green

# Step 3: configure az defaults if az is installed (silent if not)
if (Get-Command az -ErrorAction SilentlyContinue) {
    $orgUrl = if ($Org -eq "o365exchange") {
        "https://o365exchange.visualstudio.com/"
    } else {
        "https://dev.azure.com/$Org/"
    }
    az devops configure --defaults organization=$orgUrl project="$Project" 2>$null | Out-Null
    Write-Host "[ OK ] Configured 'az devops' defaults" -ForegroundColor Green
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  ADO_ORG       = $Org"
Write-Host "  ADO_PROJECT   = $Project"
Write-Host "  ADO_AREA_PATH = $AreaPath"
Write-Host ""
Write-Host "Next: run .\verify.ps1 to confirm everything is wired up." -ForegroundColor Cyan
Write-Host ""
Write-Host "TIP: env vars only last for THIS terminal window. If you close it and" -ForegroundColor Yellow
Write-Host "     open a new one, re-run .\configure.ps1 (or the skills will lose" -ForegroundColor Yellow
Write-Host "     their area-path filter)." -ForegroundColor Yellow
