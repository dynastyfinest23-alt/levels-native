# Purpose: daily read-only ping so the free-tier Supabase project is not paused for inactivity (paused 2026-11-08, restored same day).
# Reads URL + publishable key from env.json (never printed). Logs to %LOCALAPPDATA%\levels-keep-alive.log. Run by the "Levels Supabase keep-alive" scheduled task.
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:LOCALAPPDATA 'levels-keep-alive.log'
$envPath = Join-Path $PSScriptRoot '..\env.json'
try {
    $cfg = Get-Content $envPath -Raw | ConvertFrom-Json
    if (-not $cfg.SUPABASE_URL -or -not $cfg.SUPABASE_PUBLISHABLE_KEY) { throw 'env.json missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY' }
    $resp = Invoke-WebRequest -UseBasicParsing -Method Get `
        -Uri "$($cfg.SUPABASE_URL)/rest/v1/ascension_loops?select=id&limit=1" `
        -Headers @{ apikey = $cfg.SUPABASE_PUBLISHABLE_KEY }
    "$(Get-Date -Format s) OK $($resp.StatusCode)" | Add-Content $log
} catch {
    "$(Get-Date -Format s) FAIL $($_.Exception.Message)" | Add-Content $log
    exit 1
}
