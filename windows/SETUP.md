# Reinstall guide

Steps to rebuild this machine by hand after a fresh Windows 10 or 11 install. Updated 2026-11-06.

Projects live in `C:\dev`, one folder per kind of project. The `dev` shell shortcut points to
`C:\dev`. `install.ps1` creates the folders (step 4):

```
C:\dev\
  config\       this repo (config\dotfiles) and ash-theme (config\ash-theme)
  code\         personal projects
  euxora\       business projects; client projects go in euxora\clients
```

Personal files live in `~\personal`, not `Documents`, which programs fill with their own folders.

Every block below is plain PowerShell, copy and paste it straight into a terminal. Most steps
check first and skip anything already in place, so it is fine to run a step again.

## 0. Before touching the installer

Use a custom install and format only the OS drive. The other physical drives, including the
backup drive (labeled `Backup`) and the Ventoy USB stick, must not be selected in the Windows
installer's partition screen.

Then install drivers and run Windows Update, rebooting until nothing is pending, so no installer
in step 4 runs into a pending reboot.

### DNS: IPv4 only

This connection has no working IPv6 (the router announces an IPv6 route, but the PC only gets a
`fe80::` address). With IPv6 DNS servers configured, Windows tries them first for every new name
and waits for them to time out: every new site takes 7 to 15 s to start loading.

- If you debloat with WinUtil, set its DNS option to **Default**, never a provider: picking one
  (Cloudflare, Google...) also sets its IPv6 servers. Its "IPv6: Set IPv4 as Preferred" tweak
  is fine to keep, it does not touch DNS.
- Set Cloudflare by hand, **IPv4 only**:
  - **Windows 11**, in the Settings app: Settings > Network & internet > Ethernet > DNS server
    assignment > Edit > Manual. Turn on **IPv4**: preferred `1.1.1.1`, alternate `1.0.0.1`, DNS
    over HTTPS **On (automatic template)** for both. Leave **IPv6 off**. Save.
  - **Windows 10**, whose Settings app cannot change only the DNS and has no DNS over HTTPS:
    Win + R, `ncpa.cpl`, right click Ethernet > Properties. "Internet Protocol Version 4
    (TCP/IPv4)" > "Use the following DNS server addresses": `1.1.1.1` and `1.0.0.1`. "Internet
    Protocol Version 6 (TCP/IPv6)" > "Obtain DNS server address automatically". OK on both.

Step 7 checks that it worked.

## 1. Base tools

`winget` comes with the App Installer package. On a fresh Windows 10 it can be missing or too
old: if `winget --version` fails, update **App Installer** from the Microsoft Store first.

```powershell
winget --version
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { winget install --id Git.Git -e } else { "Git already installed" }
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) { winget install --id Microsoft.PowerShell -e } else { "PowerShell 7 already installed" }
```

Close that window and open **PowerShell 7** (`pwsh`). Every step below runs in it.

## 2. Find the backup drive

Its letter is not fixed (it changes with what else is plugged in), so look it up by label:

```powershell
$backup = (Get-Volume -FileSystemLabel Backup).DriveLetter + ":"
$backup
```

Steps 3 and 6 use `$backup`. In a new window, run this block again first.

## 3. Restore SSH keys and Git identity

```powershell
if (Test-Path "$HOME\.ssh\id_ed25519_github") {
    "SSH keys already present, skipping"
} else {
    New-Item -ItemType Directory -Force "$HOME\.ssh" | Out-Null
    Copy-Item "$backup\credentials\.ssh\*" "$HOME\.ssh\" -Force
    icacls "$HOME\.ssh" /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" | Out-Null
    Get-ChildItem "$HOME\.ssh" -File | ForEach-Object {
        icacls $_.FullName /inheritance:r /grant:r "${env:USERNAME}:F" /grant:r "SYSTEM:F" | Out-Null
    }
}

if (Test-Path "$HOME\.config\git\config") {
    "Git config already present, skipping"
} else {
    New-Item -ItemType Directory -Force "$HOME\.config\git" | Out-Null
    Copy-Item "$backup\credentials\.config\git\*" "$HOME\.config\git\" -Force
}

ssh -T git@github.com
```

The last line should answer `Hi <your GitHub username>!` (its exit code is 1 even then, GitHub gives no shell).
The `icacls` lines matter: OpenSSH refuses a private key that other accounts can read.

## 4. Clone the dotfiles and install everything

```powershell
$login = [regex]::Match((ssh -T git@github.com 2>&1 | Out-String), 'Hi ([^!]+)!').Groups[1].Value
New-Item -ItemType Directory -Force "C:\dev\config" | Out-Null
if (Test-Path "C:\dev\config\dotfiles") { "dotfiles already cloned" } else { git clone "git@github.com:$login/dotfiles.git" "C:\dev\config\dotfiles" }
Set-Location "C:\dev\config\dotfiles"
pwsh ./windows/packages/install-packages.ps1
```

`install-packages.ps1` installs, with `winget`: Git, GitHub CLI, PowerShell, Windows Terminal,
Starship, fastfetch, zoxide, mise, VS Code, 7-Zip, Tailscale, Brave, Discord, Docker Desktop and
lazydocker. Then the
IosevkaTerm Nerd Font, the "Open with Code" Explorer menu and the Terminal-Icons module. Some
installers ask for admin rights (UAC), accept them.

**Close the window and open a new one** so `code`, `mise` and the rest are on PATH. Without this,
`install.ps1` skips the Ash theme and the mise tools.

```powershell
Set-Location "C:\dev\config\dotfiles"
pwsh ./windows/install.ps1
```

`install.ps1` creates the `C:\dev` folders listed at the top, copies the configs into place (PowerShell profile, Starship, fastfetch, git, mise,
Windows Terminal, VS Code settings), adds mise's shims folder (`%LOCALAPPDATA%\mise\shims`) to the
user PATH and runs `mise install` (node, java, python, pnpm, fzf), clones
`ash-theme` (from the same GitHub owner as the dotfiles' `origin`) next to `dotfiles` and installs it into VS
Code, turns off Docker Desktop's start with Windows, and patches Discord with Vencord. It also installs the git hooks in `~\.config\git\hooks`, which the git config uses for every repo: pre-push checks for
secrets and Claude attribution before a push, commit-msg checks each commit message (format,
no em dash, no Claude attribution).

Both scripts are safe to run again. Run `vc` (a function in the PowerShell profile) after a Discord
update, which undoes the Vencord patch. VS Code extensions are not installed here: they come back
with VS Code's own settings sync.

## 5. Sign in to the rest

```powershell
if ((gh auth status 2>&1) -match "Logged in") { "Already signed in to GitHub CLI" } else { gh auth login }
tailscale login
```

In `gh auth login` pick GitHub.com, SSH, **Skip** the key upload (`id_ed25519_github` is already
on the account), and log in with the browser. Sign in to Brave and Discord too if you use their sync, there is nothing to script for
either.

## 6. Optional: SSH into this PC from the other machines

Windows has no SSH server by default. From an **admin** PowerShell:

```powershell
pwsh -ExecutionPolicy Bypass -File "$backup\credentials\scripts\enable-sshd.ps1"
```

It installs OpenSSH Server (several silent minutes on the first step), allows port 22 only from
Tailscale addresses (`100.64.0.0/10`), makes PowerShell 7 the login shell and authorizes sao's
key, so `ssh atlas` from sao gets in without a password.

## 7. Verify

DNS first: no IPv6 DNS servers, and a lookup of a name nobody asked for before (so the cache
cannot hide anything) well under 1000 ms:

```powershell
Get-DnsClientServerAddress -InterfaceAlias Ethernet -AddressFamily IPv6 | Select-Object -ExpandProperty ServerAddresses
(Measure-Command { Resolve-DnsName "check$(Get-Random).cloudflare.com" }).TotalMilliseconds
```

The first line must print nothing. If it prints addresses and the lookup takes seconds, remove
them from an admin terminal: `netsh interface ipv6 delete dnsservers "Ethernet" all`.

Then mise, in a new window: `mise doctor` must end with `No problems found` (and show
`shims_on_path: yes`). If a tool is missing, `mise install`; if the shims are not on PATH, run
`install.ps1` again.

Open a new Windows Terminal window and check for the Ash color scheme, the IosevkaTerm font, and
the Starship prompt showing `user@hostname`. Running `dev` should jump to `C:\dev`. VS Code
should open with the Ash theme. A commit should show as verified once the same SSH key is also
added as a signing key in your GitHub account settings, which is a setting on GitHub's side and
not something restored by any file here.

## What is intentionally not backed up

Your own files (`~\personal`) are restored by hand, these scripts never copy
them. Projects come back by cloning them from GitHub into the matching folder of `C:\dev` (`code`
or `euxora`).

SSH private keys never go into any git repository, only into `credentials\.ssh` on the backup
drive, restored by copy in step 3. GitHub CLI and Tailscale tokens are not stored anywhere, they
come back by signing in again.
