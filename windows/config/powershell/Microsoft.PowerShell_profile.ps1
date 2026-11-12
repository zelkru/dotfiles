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

# sv: tunnel ports from sao to this PC, so a dev server running on sao opens at http://localhost:<port>.
#   sv 3000            sao:3000 -> localhost:3000
#   sv 3000 5173       several ports at once
#   sv 8080:3000       sao:3000 -> localhost:8080 (local:remote, when the local port is taken)
# Ctrl+C closes the tunnel. `sv --help` explains everything. This replaces PowerShell's built-in
# `sv` alias for Set-Variable.
Remove-Item Alias:sv -Force -ErrorAction SilentlyContinue
function sv {
    param(
        [Alias('h')][switch]$Help,
        [Parameter(ValueFromRemainingArguments)][string[]]$Ports
    )
    if ($Help -or -not $Ports -or $Ports -contains '--help' -or $Ports -contains 'help' -or $Ports -contains '/?') {
        Write-Host @'

sv: open a tunnel from the sao laptop to this PC

USAGE
  sv <port> [<port> ...]
  sv <local>:<remote> [...]
  sv --help            (also: sv -h, sv help, or sv with no arguments)

EXAMPLES
  sv 3000              sao:3000 becomes http://localhost:3000 on this PC
  sv 3000 5173         two tunnels at once (for example an API and a front end)
  sv 8080:3000         sao:3000 becomes http://localhost:8080 (use it when 3000 is busy here)
  sv 5432              any TCP port works, not only web servers (a database, for example)

PORT SYNTAX
  3000        same number on both sides
  8080:3000   <local port on this PC>:<port on sao>, in that order
  Valid ports are 1 to 65535. Anything else is rejected before ssh starts.

WHAT IT RUNS
  ssh -N -L <local>:localhost:<remote> [-L ...] -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 sao
  -N    no shell, the connection only carries the tunnel
  -L    forward a local port to a port on sao. "localhost" is resolved ON SAO, so it reaches
        servers that listen on 127.0.0.1 there (what almost every dev server does by default)
  ExitOnForwardFailure   if a port cannot be opened, ssh quits with an error instead of staying
                         connected with a tunnel that does not exist
  ServerAliveInterval    pings every 30 s, so a dead connection is noticed in about 90 s
  Several ports share ONE ssh process, so a single Ctrl+C closes all of them.
  "sao" is the Host alias in ~\.ssh\config (Tailscale name, key ~\.ssh\sao). No password is asked.

THE TUNNEL IS PRIVATE
  The local side listens on this PC only (127.0.0.1), so nobody else on your network can reach
  it. Nothing is exposed on sao either: it only connects to its own localhost.

THE TERMINAL STAYS BUSY
  While the tunnel is open the prompt does not come back. Leave it open in its own tab and work
  in another one. Ctrl+C (or closing the tab) closes the tunnel.

THE TUNNEL DIES WHEN
  - You press Ctrl+C or close the terminal.
  - sao suspends (it does on battery after 15 minutes or when the lid closes; on the charger it
    never does) or loses the network. Run sv again once it is back.
  - Tailscale is off on this PC.

COMMON ERRORS
  "bind [127.0.0.1]:3000: Address already in use"
      Something on this PC already uses that local port (maybe a dev server of your own, or a
      tunnel left open). Pick another local port: sv 8080:3000
  Page does not load and the ssh window shows "connect failed: Connection refused"
      The tunnel is fine but nothing is listening on that port on sao. Start the server there,
      and check it uses the port you gave. A server that listens on another interface only
      (for example the sao LAN address) is not reached through "localhost".
  "Permission denied (publickey)" or "Could not resolve hostname sao"
      Tailscale is off, or sao is asleep or off. Check: ssh sao
  "sv: 'abc' is not a port"
      The argument is not 3000 or 8080:3000.

WHEN YOU DO NOT NEED IT
  - VS Code with Remote-SSH forwards ports by itself (Ports tab), including the ones a dev server
    announces in its terminal.
  - Claude Desktop in an SSH session has no browser pane for your app, so start the server on sao
    and use sv to open it in your own browser.

ABOUT THE NAME
  PowerShell already has a built-in alias called sv for Set-Variable. Aliases win over functions,
  so this profile removes that alias on startup (Remove-Item Alias:sv) to make room for this one.
  Nothing else changes: Set-Variable and its other alias, set, still work. To get the old sv back
  in one window:  Remove-Item Function:sv; Set-Alias sv Set-Variable

'@
        return
    }
    $forwards = foreach ($p in $Ports) {
        if ($p -notmatch '^(\d{1,5}:)?\d{1,5}$') { Write-Error "sv: '$p' is not a port (use 3000 or 8080:3000). Try: sv --help"; return }
        $local, $remote = if ($p -match ':') { $p -split ':' } else { $p, $p }
        if (@($local, $remote) | Where-Object { [int]$_ -lt 1 -or [int]$_ -gt 65535 }) { Write-Error "sv: '$p' has a port outside 1-65535"; return }
        Write-Host "sao:$remote -> http://localhost:$local"
        '-L'; "${local}:localhost:${remote}"
    }
    if (-not $forwards) { return }
    Write-Host 'Ctrl+C to close the tunnel'
    ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 @forwards sao
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
