<#
  Soulframe Inventory Guard
  -------------------------
  Watches Soulframe's log file while you play and warns you the moment the
  "items don't save" bug starts, so you can relog before wasting more time.

  WHY THIS MATTERS
  Soulframe saves your inventory by uploading a "checkpoint" to its servers
  every so often. When that upload starts failing (server error 409), nothing
  you pick up after that point is really saved -- on your next logout/login the
  game rolls you back. This tool spots the exact moment that begins and alerts
  you, so the rational move (relog now) is obvious instead of invisible.

  This script only READS the log file. It changes nothing on your PC or account.

  Normal use is via the "Watch Soulframe.bat" launcher -- just double-click that.
  Advanced flags:
    -LogPath  "C:\path\to\EE.log"   (override the log location)
    -Scan                            (analyze the current log once and exit)
    -NoPopup                         (console + sound only, no popup window)
    -PollMs   500                    (how often to re-check the file, ms)
#>

param(
  [string]$LogPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Soulframe\EE.log'),
  [switch]$Scan,
  [switch]$NoPopup,
  [int]$PollMs = 1000
)

# PS 5.1 (Windows) leaves $IsWindows undefined; PS7 sets it. Treat "not explicitly false" as Windows.
$script:OnWindows = ($IsWindows -ne $false)

# ---- Signals (kept identical to the analysis that was validated against a real log) ----
$RE_Success = [regex]'Removing checkpoint upload with type \d+ from queue'
$RE_Fail    = [regex]'Failed to commit inventory checkpoint'
$RE_GaveUp  = [regex]'Giving up on checkpoint commit after \d+ failed attempts'
$RE_Loss    = [regex]'total amount of an item in inventory is less than was picked up.*\(Item:\s*([^,]+),\s*Picked up amount:\s*(\d+),\s*Total amount:\s*(\d+)\)'
$RE_Header  = [regex]'Current time:\s*(.+?)\s*\[UTC:'
$RE_Ts      = [regex]'^(\d+(?:\.\d+)?)\s'

# ---- Detector state ----
$script:SessionStart = $null   # [datetime] from the log header
$script:LastGoodTs   = $null   # seconds-since-start of last successful save
$script:InBug        = $false
$script:OnsetTs      = $null
$script:FailCount    = 0
$script:GiveUpCount  = 0

function Reset-State {
  $script:SessionStart = $null
  $script:LastGoodTs   = $null
  $script:InBug        = $false
  $script:OnsetTs      = $null
  $script:FailCount    = 0
  $script:GiveUpCount  = 0
}

function Parse-HeaderTime([string]$s) {
  $ic = [Globalization.CultureInfo]::InvariantCulture
  $style = [Globalization.DateTimeStyles]::AllowWhiteSpaces
  foreach ($f in @('ddd MMM d HH:mm:ss yyyy','ddd MMM dd HH:mm:ss yyyy')) {
    try { return [datetime]::ParseExact($s, $f, $ic, $style) } catch {}
  }
  try { return [datetime]::Parse($s, $ic) } catch { return $null }
}

function Get-Wall([double]$ts) {
  if ($script:SessionStart -and $ts -ge 0) { return $script:SessionStart.AddSeconds($ts) }
  return $null
}

function Wall-Str([double]$ts) {
  $w = Get-Wall $ts
  if ($w) { return $w.ToString('h:mm:ss tt') } else { return '(time unknown)' }
}

function Notify-Bug([double]$ts) {
  $safe = if ($script:LastGoodTs -ne $null) { Wall-Str $script:LastGoodTs } else { 'unknown' }

  try { [console]::Beep(880,350); [console]::Beep(660,350); [console]::Beep(880,350) } catch {}

  $W = 56
  $border = '  ' + ('#' * ($W + 2))
  function BoxLine([string]$t) {
    if ($t.Length -gt $W) { $t = $t.Substring(0, $W) }
    return '  #' + $t.PadRight($W) + '#'
  }

  Write-Host ''
  Write-Host $border -ForegroundColor Red
  Write-Host (BoxLine '') -ForegroundColor Red
  Write-Host (BoxLine '   SOULFRAME INVENTORY BUG DETECTED') -ForegroundColor Red
  Write-Host (BoxLine '') -ForegroundColor Red
  Write-Host (BoxLine "   Stopped saving at about:  $(Wall-Str $ts)") -ForegroundColor Red
  Write-Host (BoxLine "   Last save that sticks:    $safe") -ForegroundColor Yellow
  Write-Host (BoxLine '') -ForegroundColor Red
  Write-Host (BoxLine '   Items you collect now VANISH when you log out.') -ForegroundColor Red
  Write-Host (BoxLine '   >>> Log out and back in NOW to save again. <<<') -ForegroundColor Red
  Write-Host (BoxLine '') -ForegroundColor Red
  Write-Host $border -ForegroundColor Red
  Write-Host ''

  if (-not $NoPopup -and $script:OnWindows) {
    $msg = "Soulframe stopped saving your inventory.`n`n" +
           "Last save that will stick: $safe`n`n" +
           "Anything you collect now disappears when you log out.`n" +
           "Log out and back in NOW to start saving again."
    $ps = "Add-Type -AssemblyName PresentationFramework;" +
          "[System.Windows.MessageBox]::Show('$($msg.Replace("'","''"))','Soulframe: progress is not saving!','OK','Warning')"
    try {
      Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden `
        -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$ps | Out-Null
    } catch {}
  }
}

function Process-Line([string]$line, [bool]$announce) {
  if ([string]::IsNullOrEmpty($line)) { return }

  $h = $RE_Header.Match($line)
  if ($h.Success) {
    $dt = Parse-HeaderTime $h.Groups[1].Value
    if ($dt) { $script:SessionStart = $dt }
    return
  }

  $tsMatch = $RE_Ts.Match($line)
  $ts = if ($tsMatch.Success) { [double]$tsMatch.Groups[1].Value } else { -1 }

  if ($RE_Success.IsMatch($line)) {
    if (-not $script:InBug) { $script:LastGoodTs = $ts }
    return
  }

  if ($RE_Fail.IsMatch($line)) {
    $script:FailCount++
    if (-not $script:InBug) {
      $script:InBug   = $true
      $script:OnsetTs = $ts
      if ($announce) { Notify-Bug $ts }
    }
    return
  }

  if ($RE_GaveUp.IsMatch($line)) {
    $script:GiveUpCount++
    if ($announce) {
      Write-Host ("  [{0}] lost save #{1} (server still rejecting). Relog to recover." -f (Wall-Str $ts), $script:GiveUpCount) -ForegroundColor Red
    }
    return
  }

  $m = $RE_Loss.Match($line)
  if ($m.Success -and $script:InBug -and $announce) {
    Write-Host ("  [{0}] confirmed loss: {1} (got {2}, kept {3})" -f (Wall-Str $ts), $m.Groups[1].Value.Trim(), $m.Groups[2].Value, $m.Groups[3].Value) -ForegroundColor Red
  }
}

function Write-Summary {
  Write-Host ''
  Write-Host '  ============ RESULT ============' -ForegroundColor Cyan
  if ($script:SessionStart) {
    Write-Host ("  Play session started : {0}" -f $script:SessionStart.ToString('g'))
  }
  if ($script:LastGoodTs -ne $null) {
    Write-Host ("  Last save that stuck : {0}" -f (Wall-Str $script:LastGoodTs)) -ForegroundColor Green
  } else {
    Write-Host '  Last save that stuck : (none seen yet)'
  }
  if ($script:OnsetTs -ne $null) {
    Write-Host ("  Saving broke at      : {0}" -f (Wall-Str $script:OnsetTs)) -ForegroundColor Yellow
    Write-Host ("  Saves lost           : {0}" -f $script:GiveUpCount) -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  >>> The bug happened this session. Anything collected after the' -ForegroundColor Red
    Write-Host '  >>> "last save that stuck" time above was rolled back on relog.' -ForegroundColor Red
  } else {
    Write-Host ''
    Write-Host '  >>> No saving problems found. This session looks healthy.' -ForegroundColor Green
  }
  Write-Host '  ===============================' -ForegroundColor Cyan
  Write-Host ''
}

# --------------------------- SCAN MODE (one-shot) ---------------------------
if ($Scan) {
  if (-not (Test-Path -LiteralPath $LogPath)) {
    Write-Host "Could not find the log file at:`n  $LogPath" -ForegroundColor Yellow
    Write-Host "Pass the right path with:  -LogPath `"C:\path\to\EE.log`"" -ForegroundColor Yellow
    exit 1
  }
  Write-Host "Reading $LogPath ..." -ForegroundColor Cyan
  foreach ($line in [IO.File]::ReadLines($LogPath)) { Process-Line $line $false }
  Write-Summary
  exit 0
}

# --------------------------- WATCH MODE (live) ------------------------------
try { $Host.UI.RawUI.WindowTitle = 'Soulframe Inventory Guard' } catch {}

Write-Host ''
Write-Host '  Soulframe Inventory Guard' -ForegroundColor Cyan
Write-Host '  Leave this window open while you play. It will pop up a warning the' -ForegroundColor Gray
Write-Host '  moment Soulframe stops saving your items. Press Ctrl+C to stop.' -ForegroundColor Gray
Write-Host ''

# Wait for the log to exist (so you can start this before launching the game).
if (-not (Test-Path -LiteralPath $LogPath)) {
  Write-Host "  Waiting for Soulframe to start..." -ForegroundColor Yellow
  Write-Host "  (looking for $LogPath)" -ForegroundColor DarkGray
  while (-not (Test-Path -LiteralPath $LogPath)) { Start-Sleep -Milliseconds 1000 }
}

$lastHeartbeat = Get-Date

while ($true) {
  $fs = $null; $sr = $null
  try {
    $fs = New-Object IO.FileStream($LogPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $sr = New-Object IO.StreamReader($fs)

    Reset-State
    # Prime from existing content WITHOUT alerting, so a relaunch of this tool
    # mid-bug still reports state but doesn't re-trumpet an old alert on startup.
    while (($line = $sr.ReadLine()) -ne $null) { Process-Line $line $false }

    if ($script:InBug) {
      Write-Host ("  Note: this session is ALREADY failing to save (since {0}). Relog when you can." -f (Wall-Str $script:OnsetTs)) -ForegroundColor Red
    } else {
      $lg = if ($script:LastGoodTs -ne $null) { Wall-Str $script:LastGoodTs } else { 'n/a' }
      Write-Host ("  Watching. Saving normally. Last save: {0}" -f $lg) -ForegroundColor Green
    }

    # Live follow.
    while ($true) {
      $line = $sr.ReadLine()
      if ($line -ne $null) {
        Process-Line $line $true
      } else {
        Start-Sleep -Milliseconds $PollMs

        # New game session? The engine recreates EE.log on launch, so the file
        # gets shorter than where we are. Reopen and start fresh.
        $len = (Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue).Length
        if ($len -eq $null -or $len -lt $fs.Position) {
          Write-Host '  --- Soulframe restarted; watching the new session ---' -ForegroundColor Cyan
          break
        }

        # Quiet heartbeat every 2 minutes so you know it is still alive.
        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 120) {
          $lastHeartbeat = Get-Date
          if (-not $script:InBug) {
            $lg = if ($script:LastGoodTs -ne $null) { Wall-Str $script:LastGoodTs } else { 'n/a' }
            Write-Host ("  [{0}] still watching - saving normally (last save {1})" -f (Get-Date).ToString('h:mm tt'), $lg) -ForegroundColor DarkGreen
          }
        }
      }
    }
  } catch {
    Write-Host ("  Lost the log file ({0}); waiting for it to come back..." -f $_.Exception.Message) -ForegroundColor Yellow
    Start-Sleep -Milliseconds 1500
    while (-not (Test-Path -LiteralPath $LogPath)) { Start-Sleep -Milliseconds 1000 }
  } finally {
    if ($sr) { $sr.Dispose() }
    if ($fs) { $fs.Dispose() }
  }
}
