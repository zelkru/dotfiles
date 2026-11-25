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

# tun: tunnel ports from sao to this PC, so a dev server running on sao opens at http://localhost:<port>.
#   tun 3000            sao:3000 -> localhost:3000
#   tun 3000 5173       several ports at once
#   tun 8080:3000       sao:3000 -> localhost:8080 (local:remote, when the local port is taken)
# Ctrl+C closes the tunnel. `tun --help` explains everything.
function tun {
    param(
        [Alias('h')][switch]$Help,
        [Parameter(ValueFromRemainingArguments)][string[]]$Ports
    )
    if ($Help -or -not $Ports -or $Ports -contains '--help' -or $Ports -contains 'help' -or $Ports -contains '/?') {
        Write-Host @'

tun: open a tunnel from the sao laptop to this PC

USAGE
  tun <port> [<port> ...]
  tun <local>:<remote> [...]
  tun --help            (also: tun -h, tun help, or tun with no arguments)

EXAMPLES
  tun 3000              sao:3000 becomes http://localhost:3000 on this PC
  tun 3000 5173         two tunnels at once (for example an API and a front end)
  tun 8080:3000         sao:3000 becomes http://localhost:8080 (use it when 3000 is busy here)
  tun 5432              any TCP port works, not only web servers (a database, for example)

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
    never does) or loses the network. Run tun again once it is back.
  - Tailscale is off on this PC.

COMMON ERRORS
  "bind [127.0.0.1]:3000: Address already in use"
      Something on this PC already uses that local port (maybe a dev server of your own, or a
      tunnel left open). Pick another local port: tun 8080:3000
  Page does not load and the ssh window shows "connect failed: Connection refused"
      The tunnel is fine but nothing is listening on that port on sao. Start the server there,
      and check it uses the port you gave. A server that listens on another interface only
      (for example the sao LAN address) is not reached through "localhost".
  "Permission denied (publickey)" or "Could not resolve hostname sao"
      Tailscale is off, or sao is asleep or off. Check: ssh sao
  "tun: 'abc' is not a port"
      The argument is not 3000 or 8080:3000.

WHEN YOU DO NOT NEED IT
  - VS Code with Remote-SSH forwards ports by itself (Ports tab), including the ones a dev server
    announces in its terminal.
  - Claude Desktop in an SSH session has no browser pane for your app, so start the server on sao
    and use tun to open it in your own browser.

'@
        return
    }
    $forwards = foreach ($p in $Ports) {
        if ($p -notmatch '^(\d{1,5}:)?\d{1,5}$') { Write-Error "tun: '$p' is not a port (use 3000 or 8080:3000). Try: tun --help"; return }
        $local, $remote = if ($p -match ':') { $p -split ':' } else { $p, $p }
        if (@($local, $remote) | Where-Object { [int]$_ -lt 1 -or [int]$_ -gt 65535 }) { Write-Error "tun: '$p' has a port outside 1-65535"; return }
        Write-Host "sao:$remote -> http://localhost:$local"
        '-L'; "${local}:localhost:${remote}"
    }
    if (-not $forwards) { return }
    Write-Host 'Ctrl+C to close the tunnel'
    ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 @forwards sao
}

# echo -n and base64, the way they behave in bash:
#   echo "text" | base64        encodes "text" plus a newline (what bash does)
#   echo -n "text" | base64     encodes "text" with no newline
#   "dGV4dA==" | base64 -d      decodes (also --decode); the result prints like any text
#   base64 file.txt             encodes a file; -w 0 turns off the 76 column wrapping
# PowerShell's built-in `echo` alias is replaced so that `echo -n` can mark its output as "no
# newline". Without -n, echo behaves exactly as before. Decoding assumes the data is UTF-8 text.
Remove-Item Alias:echo -Force -ErrorAction SilentlyContinue
function echo {
    param([switch]$n, [Parameter(ValueFromRemainingArguments)][object[]]$Rest)
    if (-not $n) { if ($Rest) { $Rest }; return }
    $text = ($Rest | ForEach-Object { "$_" }) -join ' '
    Add-Member -InputObject $text -NotePropertyName NoNewline -NotePropertyValue $true -PassThru
}

function base64 {
    $decode = $false; $wrap = 76; $files = @()
    for ($i = 0; $i -lt $args.Count; $i++) {
        $a = "$($args[$i])"
        if ($a -ceq '-d' -or $a -ceq '-D' -or $a -eq '--decode') { $decode = $true }
        elseif ($a -eq '-w' -or $a -eq '--wrap') { $i++; $wrap = [int]"$($args[$i])" }
        elseif ($a -match '^(-w|--wrap=)(\d+)$') { $wrap = [int]$Matches[2] }
        else { $files += $a }
    }
    $utf8 = [Text.UTF8Encoding]::new($false)
    if ($files) {
        $raw = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $files[0]).ProviderPath)
        $text = [Text.Encoding]::ASCII.GetString($raw)
    } else {
        $sb = [Text.StringBuilder]::new()
        foreach ($x in @($input)) {
            [void]$sb.Append("$x")
            # a piped string is a line (like piping to a native command), unless echo -n marked it
            $bare = $null -ne $x -and $x.PSObject.Properties['NoNewline']
            if (-not $decode -and -not $bare) { [void]$sb.Append("`n") }
        }
        $text = $sb.ToString()
        $raw = $utf8.GetBytes($text)
    }
    if ($decode) {
        try { $out = $utf8.GetString([Convert]::FromBase64String(($text -replace '\s', ''))) }
        catch { Write-Error 'base64: invalid input'; return }
        # the host adds one newline when printing, so drop the one the data ends with
        if ($out.EndsWith("`r`n")) { $out = $out.Substring(0, $out.Length - 2) }
        elseif ($out.EndsWith("`n")) { $out = $out.Substring(0, $out.Length - 1) }
        $out
    } else {
        $b64 = [Convert]::ToBase64String($raw)
        if ($wrap -le 0) { $b64 }
        else { for ($p = 0; $p -lt $b64.Length; $p += $wrap) { $b64.Substring($p, [Math]::Min($wrap, $b64.Length - $p)) } }
    }
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
