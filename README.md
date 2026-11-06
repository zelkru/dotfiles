# dotfiles

My setup on two systems, with the same look on both: the Ash theme (`#181818`, based on
Alacritty's default palette) and `IosevkaTerm Nerd Font Mono`.

| | Folder | Guide |
|---|---|---|
| Windows 10 / 11 | [`windows/`](windows) | Windows Terminal, PowerShell 7, Starship, fastfetch, Git, VS Code. See [`windows/README.md`](windows/README.md), and [`windows/SETUP.md`](windows/SETUP.md) for a full reinstall |
| Linux Mint (Cinnamon) | [`linux/`](linux) | Alacritty, zellij, fish, Starship, rofi, riced Cinnamon. See [`linux/README.md`](linux/README.md) |
| Both | [`shared/`](shared) | Starship prompt, global gitignore, mise tools, VS Code settings |

`hooks/` (`pre-push`, `commit-msg`) is shared too and works on both.

## Layout

```
shared/     used by both systems (starship.toml, git/ignore, mise/, vscode/)
windows/    install.ps1, packages/ (winget), config/ (powershell, git, fastfetch),
            powershell/, windows-terminal/, README.md, SETUP.md
linux/      install.sh, config/, bin/, cinnamon/, autostart/, README.md
hooks/      pre-push, commit-msg
```

## Use

Windows:

```powershell
pwsh ./windows/install.ps1            # repo -> system
pwsh ./windows/install.ps1 -Collect   # system -> repo (after editing configs live)
```

New PC: `pwsh ./windows/packages/install-packages.ps1` first (programs, font, VS Code context menu).

Linux:

```bash
./linux/install.sh            # repo -> system
./linux/install.sh --collect  # system -> repo (after editing configs live)
```

Both installers enable the git hooks (secret check, commit message check). `linux/install.sh` sets
`core.hooksPath` for this repo; `windows/install.ps1` installs them in `~\.config\git\hooks`, and the
git config points there, so they run in every repo.

## What is shared and what is not

| Shared (`shared/`) | Per system |
|---|---|
| `starship.toml` (one prompt everywhere) | terminal and multiplexer config |
| `git/ignore` (global gitignore) | `git/config` (`autocrlf`, credential helper differ) |
| `mise/config.toml` (node, java, python, pnpm, fzf) | shell config, package installs, desktop |
| `vscode/` (settings) | |

## Safety

`hooks/pre-push` blocks a push that adds private keys, tokens, `.env` files, `.ssh/` content,
`CLAUDE.md` / `AGENTS.md`, or a commit message with Claude/Anthropic attribution.
`hooks/commit-msg` rejects a commit whose subject is not `type(scope): description`, whose
message has an em dash, or that credits Claude/Anthropic (co-authored-by lines for people are
fine). `shared/git/ignore` is a global gitignore that also skips agent files.

## Not included

- `~/.ssh` (keys, `allowed_signers`): secrets. Each machine has its own key, see `linux/README.md`.
- The Ash theme lives in its own public repo, [`ash-theme`](https://github.com/zelkru/ash-theme) (VS Code, Brave, Firefox, Discord). Both install scripts clone it next to this repo and install the VS Code theme.
- Programs themselves: installed by `windows/packages` (winget) or `linux/install.sh` (apt, mise).
