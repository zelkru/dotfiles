# SSH logins: sshd starts pwsh without -NoLogo and can't pass it arguments, so erase the banner.
# The session starts on a cleared screen, so going home and clearing down only removes the banner.
# Skipped for `ssh host command` (pwsh -c ...), where it would end up in the command's output.
if ($env:SSH_CONNECTION -and -not ([Environment]::GetCommandLineArgs() -match '^-(c|command|f|file)$')) {
    Write-Host "`e[H`e[J" -NoNewline
}

if (Get-Module -ListAvailable Terminal-Icons) { Import-Module Terminal-Icons }

# Opt out of telemetry (docker agent / cagent)
$env:TELEMETRY_ENABLED = 'false'

# Real pwsh profile. $PROFILE just dot-sources this file.
# Prompt
$env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# Smarter cd
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# Handy aliases
Set-Alias ff fastfetch

# ep: edit this profile ($env:EDITOR, else VS Code, else Notepad)
function ep {
    $file = "$HOME\.config\powershell\Microsoft.PowerShell_profile.ps1"
    $editor = if ($env:EDITOR) { $env:EDITOR }
              elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code' }
              else { 'notepad' }
    & $editor $file
}


# dev: jump to the projects folder (C:\dev)
function dev { Set-Location "C:\dev" }

# code: with no arguments jump to the personal projects folder (C:\dev\code); with arguments it is
# still VS Code's `code` command (`code .`, `code --wait`, ...)
function code {
    if ($args.Count -eq 0) { Set-Location "C:\dev\code"; return }
    & (Get-Command code -CommandType Application | Select-Object -First 1).Source @args
}

# fp: open a folder in File Pilot, from any folder. `fp` opens the current folder; `fp euxora` opens
# the path relative to the current folder (any path works, relative or absolute)
function fp {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Path)
    $target = if ($Path) { $Path -join ' ' } else { '.' }
    $full = Resolve-Path -LiteralPath $target -ErrorAction SilentlyContinue
    if (-not $full) { Write-Error "fp: path not found: $target"; return }
    Start-Process "$env:LOCALAPPDATA\Voidstar\FilePilot\FPilot.exe" -ArgumentList "`"$($full.ProviderPath)`""
}

# vc: patch Discord with Vencord's official installer CLI. Run it again after Discord updates itself,
# which undoes the patch
function vc {
    if (-not (Test-Path "$env:LOCALAPPDATA\Discord")) { Write-Warning 'vc: Discord is not installed.'; return }
    $root = "$env:LOCALAPPDATA\Discord"
    $cli = Join-Path $env:TEMP 'VencordInstallerCli.exe'
    Invoke-WebRequest 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe' -OutFile $cli
    Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force
    # The installer only patches the newest app-* folder, but Discord can keep launching an older one.
    # Patch every app-* folder by hiding the others while each one is patched.
    $apps = @(Get-ChildItem $root -Directory -Filter 'app-*')
    foreach ($app in $apps) {
        $held = @($apps | Where-Object FullName -ne $app.FullName | ForEach-Object { Rename-Item $_.FullName "_hold-$($_.Name)" -PassThru })
        try { & $cli -install -location $root }
        finally { $held | ForEach-Object { Rename-Item $_.FullName ($_.Name -replace '^_hold-', '') } }
    }
    Remove-Item $cli -ErrorAction SilentlyContinue
}

# 7z: alias for 7-Zip
Set-Alias 7z "C:\Program Files\7-Zip\7z.exe"
# Syntax colors as you type (same palette as the VS Code theme) and history suggestions
if (Get-Module -ListAvailable PSReadLine) {
    $c = { param($hex) $r,$g,$b = [Convert]::ToInt32($hex.Substring(0,2),16),[Convert]::ToInt32($hex.Substring(2,2),16),[Convert]::ToInt32($hex.Substring(4,2),16); "`e[38;2;$r;$g;${b}m" }
    Set-PSReadLineOption -Colors @{
        Command            = & $c '6a9fb5'   # blue
        Parameter          = & $c 'f4bf75'   # yellow
        String             = & $c '90a959'   # green
        Number             = & $c 'f4bf75'
        Variable           = & $c 'd8d8d8'
        Operator           = & $c 'aa759f'   # magenta
        Keyword            = & $c 'aa759f'
        Type               = & $c 'f4bf75'
        Member             = & $c 'd06060'   # red
        Comment            = & $c '7f7f7f'
        Error              = & $c 'd06060'
        InlinePrediction   = & $c '6b6b6b'
        Default            = & $c 'd8d8d8'
    }
    # Predictions need a real terminal; skip quietly when output is redirected
    try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView } catch {}
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
