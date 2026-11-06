# Windows 10 / 11

Windows Terminal + PowerShell 7 + Starship, with the Ash palette (`#181818`) and
`IosevkaTerm Nerd Font Mono`. Same look as the Linux setup, different tools (see
[what differs from Linux](#what-differs-from-linux)).

For a full rebuild of a machine after a fresh install (drivers, DNS, SSH keys, restoring files),
follow [`SETUP.md`](SETUP.md). This file explains what is in the folder and how to use it day to day.

## Install

```powershell
git clone git@github.com:zelkru/dotfiles.git C:\dev\config\dotfiles
cd C:\dev\config\dotfiles
pwsh ./windows/packages/install-packages.ps1   # new PC only: programs, font, VS Code context menu
pwsh ./windows/install.ps1                     # repo -> system
pwsh ./windows/install.ps1 -Collect            # system -> repo, after editing configs live
```

Both scripts are safe to run again. After `install-packages.ps1`, open a new terminal so `code`,
`mise` and the rest are on PATH before running `install.ps1`.

What `install-packages.ps1` does:

1. `winget import` of `packages/winget.json` (Git, GitHub CLI, PowerShell, Windows Terminal,
   Starship, fastfetch, zoxide, mise, VS Code, 7-Zip, Tailscale, Brave, Discord, Docker Desktop,
   lazydocker).
2. `install-font.ps1`: IosevkaTerm Nerd Font Mono.
3. `install-vscode-context-menu.ps1`: the "Open with Code" Explorer menu.
4. Installs the `Terminal-Icons` PowerShell module.

What `install.ps1` does:

1. Creates the [`C:\dev` folders](#dev-folder).
2. Copies the configs listed below into place.
3. Adds mise's shims folder (`%LOCALAPPDATA%\mise\shims`) to the user PATH and runs `mise install`
   (node, java, python, pnpm, fzf).
4. Clones [`ash-theme`](https://github.com/zelkru/ash-theme) next to this repo, in
   `C:\dev\config\ash-theme` (same owner as `origin`), and installs the VS Code theme.
5. Turns off Docker Desktop's start with Windows.
6. Patches Discord with Vencord (run `vc` after a Discord update, which undoes the patch).

VS Code extensions are not installed by the scripts: they come back with VS Code's own settings sync.

With `-Collect` only step 2 runs, in the other direction.

## Dev folder

Projects live in `C:\dev`, one folder per kind of project (the `dev` command jumps there):

| Folder | For |
|---|---|
| `config` | this repo (`config\dotfiles`) and `config\ash-theme` |
| `code` | personal projects |
| `euxora` | business projects (client projects go in `euxora\clients`) |

## Layout

| Repo path | Installed to |
|---|---|
| `config/fastfetch` | `~\.config\fastfetch` |
| `config/git/config` | `~\.config\git\config` (the global ignore comes from `shared/git/ignore`) |
| `hooks/` (repo root) | `~\.config\git\hooks`, used by every repo: the git config sets `core.hooksPath` to it |
| `config/powershell` | `~\.config\powershell` (the real profile) |
| `powershell/profile-stub.ps1` | `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` (only dot-sources the real profile) |
| `windows-terminal/settings.json` | Windows Terminal's `LocalState\settings.json` |
| `packages/` | not copied, it runs winget and the font / context menu scripts |

`shared/` is used as well: `starship.toml`, the global gitignore, the mise tool list and the
VS Code settings.

## Keybindings

### Windows Terminal

| Keys | Action |
|---|---|
| `Ctrl + C` | Copy (the selection) |
| `Ctrl + V` | Paste |
| `Alt + Shift + D` | Split the pane |

### PowerShell (PSReadLine)

| Keys | Action |
|---|---|
| `Up` / `Down` | Search the history for what you already typed |
| inline gray text | History prediction, accept with `Right` |

## How it works

**Terminal.** Windows Terminal starts PowerShell 7 (`pwsh -NoLogo`) in `%USERPROFILE%`. The Ash
color scheme and tab theme are in `settings.json`, with a bar cursor, no acrylic and the window
dimmed a little (opacity 88) when it loses focus.

**Profile.** `$PROFILE` only dot-sources `~\.config\powershell\Microsoft.PowerShell_profile.ps1`,
so the real file lives with the other configs and is easy to collect. It sets up:

- Starship (config from `~\.config\starship.toml`), zoxide and Terminal-Icons, each only if installed.
- Aliases and functions: `ff` (fastfetch), `7z` (7-Zip), `dev` (go to `C:\dev`), `fp` (open the current folder, or `fp <folder>`, in File Pilot), `code` (with no
  arguments go to `C:\dev\code`; with arguments it is still VS Code's `code`) `ep` (edit the
  profile with `$env:EDITOR`, else VS Code, else Notepad) and `vc` (patch Discord with Vencord,
  run it again after each Discord update).
- Syntax colors as you type, from the same palette as the VS Code theme, and history suggestions.
- `TELEMETRY_ENABLED=false`, so `docker agent` does not send telemetry.
- A fix for SSH logins: sshd starts pwsh without `-NoLogo`, so the banner is erased (skipped for
  `ssh host command`).

**Tools.** mise manages node, java, python, pnpm and fzf; its shims are on the user PATH so any
program finds them, not only the shell that installed them.

## Git, GitHub and SSH

`config/git/config` has `autocrlf = true`, `longpaths`, `pull.rebase`, `push.autoSetupRemote`,
`fetch.prune` and `rebase.autoStash`. The credential helper is `gh.exe`. Commits are signed with
`~/.ssh/id_ed25519_github.pub` (`gpg.format = ssh`).

Each machine has its own key. The same key must also be added to GitHub as a **signing** key (a
separate entry from the authentication key) for commits to show as verified. Private keys are never
in the repo (`hooks/pre-push` blocks them); they are restored from the backup drive, see
[`SETUP.md`](SETUP.md).

## What differs from Linux

| | Windows | Linux |
|---|---|---|
| Terminal | Windows Terminal | Alacritty + zellij |
| Shell | PowerShell 7 | fish |
| Prompt | Starship (shared config) | Starship (shared config) |
| Launcher | Start menu | rofi |
| Packages | winget | apt + mise |
| Git `autocrlf` | `true` | `input` |
| Credential helper | `gh.exe` | `/usr/bin/gh` |

## Not included

- `~\.ssh` keys: restored by copy from the backup drive.
- GitHub CLI and Tailscale tokens: you sign in again.
- Brave and Discord sync: sign in to each.
- The programs themselves: installed by `packages/` (winget).

## Troubleshooting

- **`code` or `mise` not found right after installing**: open a new terminal so PATH refreshes,
  then run `install.ps1` again (it skips the mise tools when they are missing).
- **Discord lost its Vencord patch**: Discord updated itself, run `vc`.
- **Icons look like empty boxes**: the terminal is not using `IosevkaTerm Nerd Font Mono`, run
  `packages/install-font.ps1` and open a new window.
- **A tool installed by mise is not found**: `mise doctor` should end with `No problems found`
  and show `shims_on_path: yes`; if not, run `install.ps1` again.
