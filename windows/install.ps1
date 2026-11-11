<#
.SYNOPSIS
  Copies the dotfiles in this repo to where Windows programs read them.
  Use -Collect to go the other way: copy the live files back into the repo.
#>
param([switch]$Collect)

# $PSScriptRoot is windows/; shared/ lives next to it
$root = Split-Path $PSScriptRoot -Parent

# Dev folder layout: one folder per kind of project. config\ holds this repo and ash-theme.
if (-not $Collect) {
    foreach ($d in 'config', 'code', 'euxora') {
        New-Item -ItemType Directory -Force "C:\dev\$d" | Out-Null
    }
}

$wtDir = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter "Microsoft.WindowsTerminal_*" |
    Select-Object -First 1 -ExpandProperty FullName

# repo path (relative to the repo root) -> live path
$map = [ordered]@{
    'windows\config\fastfetch'                   = "$HOME\.config\fastfetch"
    'windows\config\git\config'                 = "$HOME\.config\git\config"
    'windows\config\git\euxora'                 = "$HOME\.config\git\euxora"
    'windows\config\git\allowed_signers'        = "$HOME\.config\git\allowed_signers"
    'shared\git\ignore'                          = "$HOME\.config\git\ignore"
    'hooks'                                      = "$HOME\.config\git\hooks"
    'shared\mise'                                 = "$HOME\.config\mise"
    'windows\config\powershell'                  = "$HOME\.config\powershell"
    'shared\starship.toml'                        = "$HOME\.config\starship.toml"
    'windows\powershell\profile-stub.ps1'        = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    'shared\vscode\settings.json'                = "$env:APPDATA\Code\User\settings.json"
}
if ($wtDir) { $map['windows\windows-terminal\settings.json'] = "$wtDir\LocalState\settings.json" }

foreach ($rel in $map.Keys) {
    $repo = Join-Path $root $rel
    $live = $map[$rel]
    if ($Collect) { $from, $to = $live, $repo } else { $from, $to = $repo, $live }

    if (-not (Test-Path $from)) { Write-Warning "missing: $from"; continue }
    New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
    if ((Get-Item $from).PSIsContainer) {
        Copy-Item $from (Split-Path $to) -Recurse -Force
    } else {
        Copy-Item $from $to -Force   # file: exact target name (the profile stub gets renamed)
    }
    Write-Host "$from -> $to"
}

# mise: put its shims folder on the user PATH, so every program (not only this shell) finds the
# node, python, java... it installs, then install the tools in shared/mise. The folder comes from
# LOCALAPPDATA (or MISE_DATA_DIR), so it works for any username.
if (-not $Collect) {
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        $data  = if ($env:MISE_DATA_DIR) { $env:MISE_DATA_DIR } else { Join-Path $env:LOCALAPPDATA 'mise' }
        $shims = Join-Path $data 'shims'
        $userPath = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ })
        if ($userPath -notcontains $shims) {
            # first, so mise's python wins over the Microsoft Store python stub in WindowsApps
            [Environment]::SetEnvironmentVariable('Path', (@($shims) + $userPath) -join ';', 'User')
            Write-Host "Added to the user PATH: $shims"
        }
        if (($env:Path -split ';') -notcontains $shims) { $env:Path = "$shims;$env:Path" }
        mise install
    } else {
        Write-Warning 'mise not found: open a new terminal after install-packages.ps1 and run this again.'
    }
}

# Ash theme for VS Code: its own public repo, cloned next to this one and kept up to date
if (-not $Collect) {
    $ash = Join-Path (Split-Path $root -Parent) 'ash-theme'
    # same owner as this repo's origin, so a renamed GitHub account needs no edit here
    $ashUrl = (git -C $root remote get-url origin) -replace '[^/:]+$', 'ash-theme.git'
    if (Test-Path "$ash\.git") { git -C $ash pull --ff-only -q } else { git clone -q $ashUrl $ash }
    if (Test-Path "$ash\vscode\install.ps1") { & "$ash\vscode\install.ps1" } else { Write-Warning "Ash theme not available: $ash" }
}

# Docker Desktop: never start with Windows. Its installer adds a Run entry, and the app re-adds it
# on launch unless its own AutoStart setting is off, so turn both off. Safe to re-run.
if (-not $Collect -and (Test-Path "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe")) {
    $dockerSettings = "$env:APPDATA\Docker\settings-store.json"
    $s = if (Test-Path $dockerSettings) { Get-Content $dockerSettings -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    $s | Add-Member -NotePropertyName AutoStart -NotePropertyValue $false -Force
    New-Item -ItemType Directory -Force (Split-Path $dockerSettings) | Out-Null
    $s | ConvertTo-Json -Depth 10 | Set-Content $dockerSettings -Encoding utf8NoBOM
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Docker Desktop' -ErrorAction SilentlyContinue
    Write-Host 'Docker Desktop: autostart off'
}

# Vencord: patch Discord with the official installer CLI. Safe to re-run (it re-patches with the
# latest build), and needed after Discord updates itself, which undoes the patch. The `vc` function
# in the PowerShell profile does the same on demand.
if (-not $Collect) {
    if (Test-Path "$env:LOCALAPPDATA\Discord") {
        $cli = Join-Path $env:TEMP 'VencordInstallerCli.exe'
        Invoke-WebRequest 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe' -OutFile $cli
        $root = "$env:LOCALAPPDATA\Discord"
        Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force
        # The installer only patches the newest app-* folder, but Discord can keep launching an older
        # one. Patch every app-* folder by hiding the others while each one is patched.
        $apps = @(Get-ChildItem $root -Directory -Filter 'app-*')
        foreach ($app in $apps) {
            $held = @($apps | Where-Object FullName -ne $app.FullName | ForEach-Object { Rename-Item $_.FullName "_hold-$($_.Name)" -PassThru })
            try { & $cli -install -location $root }
            finally { $held | ForEach-Object { Rename-Item $_.FullName ($_.Name -replace '^_hold-', '') } }
        }
        Remove-Item $cli -ErrorAction SilentlyContinue
    } else {
        Write-Warning 'Discord is not installed, skipping Vencord.'
    }
}
