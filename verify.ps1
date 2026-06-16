# verify.ps1
# Pre-flight environment check for the "From Backlog to Product" workshop.
# Run this BEFORE the workshop starts. Green = ready. Red = grab a helper.

$ErrorActionPreference = "Continue"
$checks = @()

function Check {
    param([string]$Name, [scriptblock]$Test, [string]$FixHint)
    try {
        $result = & $Test
        if ($result) {
            $script:checks += [pscustomobject]@{ Name = $Name; Status = "PASS"; Detail = "$result"; Fix = "" }
            Write-Host "[ PASS ] $Name  ->  $result" -ForegroundColor Green
        } else {
            $script:checks += [pscustomobject]@{ Name = $Name; Status = "FAIL"; Detail = "no output"; Fix = $FixHint }
            Write-Host "[ FAIL ] $Name" -ForegroundColor Red
            Write-Host "         Fix: $FixHint" -ForegroundColor Yellow
        }
    } catch {
        $script:checks += [pscustomobject]@{ Name = $Name; Status = "FAIL"; Detail = $_.Exception.Message; Fix = $FixHint }
        Write-Host "[ FAIL ] $Name  ->  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "         Fix: $FixHint" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Workshop Pre-Flight: From Backlog to Product ===`n" -ForegroundColor Cyan

Check "Node.js >= 20" {
    $v = (node --version) -replace "v",""
    if ([version]$v -ge [version]"20.0.0") { "v$v" } else { $null }
} "Install Node 20+ from https://nodejs.org"

Check "npm available" {
    npm --version
} "Reinstall Node — npm ships with it."

Check "Git installed" {
    (git --version) -replace "git version ",""
} "Install Git from https://git-scm.com"

Check "Copilot CLI installed" {
    copilot --version 2>&1 | Select-Object -First 1
} "Install: npm install -g @github/copilot or follow internal install doc."

Check "Copilot CLI authenticated" {
    # Wrap in a job with a 10s timeout: `copilot auth status` can hang when run
    # from a non-interactive script context (no TTY).
    $job = Start-Job -ScriptBlock { copilot auth status 2>&1 | Out-String }
    if (Wait-Job $job -Timeout 10) {
        $out = Receive-Job $job
        Remove-Job $job
        if ($out -match "logged in|authenticated") { "authenticated" } else { $null }
    } else {
        Stop-Job $job; Remove-Job $job -Force
        # Treat hang as "unknown" rather than failing — common in script contexts
        "skipped (timed out — run 'copilot auth status' manually to confirm)"
    }
} "Run: copilot login"

Check "Port 3000 free" {
    $inUse = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
    if (-not $inUse) { "free" } else { $null }
} "Stop whatever is using port 3000, or set PORT=3001 before npm start."

Check "ADO project reachable" {
    $org = $env:ADO_ORG
    $project = $env:ADO_PROJECT
    if (-not $org -or -not $project) { return $null }
    # Try both URL formats: new (dev.azure.com) and legacy (visualstudio.com)
    $urls = @(
        "https://dev.azure.com/$org/$project",
        "https://$org.visualstudio.com/$project"
    )
    foreach ($url in $urls) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 203) { return "$($r.StatusCode) OK ($url)" }
        } catch { continue }
    }
    return $null
} "Set `$env:ADO_ORG and `$env:ADO_PROJECT, then sign in to ADO in your browser."

Check ".mcp.json present" {
    if (Test-Path ".\.mcp.json") { "found" } else { $null }
} "You may be in the wrong folder. cd into the cloned workshop repo."

Check "npm install completed" {
    if (Test-Path ".\node_modules") { "node_modules present" } else { $null }
} "Run: npm install"

Check "Azure CLI installed" {
    (az --version 2>&1 | Select-Object -First 1)
} "Install Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli-windows"

Check "azure-devops extension installed" {
    $exts = az extension list --query "[?name=='azure-devops'].name" -o tsv 2>$null
    if ($exts -eq "azure-devops") { "installed" } else { $null }
} "Run: az extension add --name azure-devops"

Check "az signed in" {
    $acc = az account show --query "user.name" -o tsv 2>$null
    if ($acc) { $acc } else { $null }
} "Run: az login"

Check "spec file present" {
    if (Test-Path ".\spec\oncall-handoff-notes.md") { "found" } else { $null }
} "Make sure you cloned the full repo. Spec lives at spec/oncall-handoff-notes.md."

Check "all 6 skills present" {
    $expected = @("spec-to-plan","plan-to-backlog","backlog-breakdown","backlog-organizer","pr-review","pr-summarizer")
    $missing = $expected | Where-Object { -not (Test-Path ".\.github\skills\$_\SKILL.md") }
    if ($missing.Count -eq 0) { "6/6" } else { $null }
} "Re-clone the repo. Skills should be in .github/skills/<skill-name>/SKILL.md."

Write-Host "`n=== Summary ===`n" -ForegroundColor Cyan
$pass = ($checks | Where-Object Status -eq "PASS").Count
$fail = ($checks | Where-Object Status -eq "FAIL").Count
Write-Host "Passed: $pass" -ForegroundColor Green
Write-Host "Failed: $fail" -ForegroundColor ($(if ($fail -gt 0) { "Red" } else { "Green" }))

if ($fail -gt 0) {
    Write-Host "`nYou have failing checks. Grab a workshop helper before we start.`n" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`nYou're ready. See you at the workshop!`n" -ForegroundColor Green
    exit 0
}
