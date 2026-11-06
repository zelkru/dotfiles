# Linux (Mint / Cinnamon)

Alacritty + zellij + fish + Starship, rofi as the launcher, and a Cinnamon desktop riced with the
Ash palette (`#181818`) and `IosevkaTerm Nerd Font Mono`. Same look as the Windows setup,
different tools (see [what differs from Windows](#what-differs-from-windows)).

## Install

```bash
git clone git@github.com:zelkru/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles/linux
./install.sh             # repo -> system (asks for sudo once, for apt)
./install.sh --no-apt    # same, without the apt step
./install.sh --collect   # system -> repo, after editing configs live
```

It is safe to run again. `mise` has to be installed first (https://mise.jdx.dev). Paths written as
`@HOME@` in the repo are expanded to `$HOME` on install and collapsed back on `--collect`.

What `install.sh` does, in order:

1. `apt install`: alacritty, kitty, fish, rofi, gh, git, zoxide, xsel, wmctrl.
2. `mise install`: starship, fastfetch, zellij (from `config/mise/conf.d/linux.toml`) plus the
   shared tools (node, java, python, pnpm, fzf).
3. Downloads IosevkaTerm Nerd Font Mono (Regular, Bold, Italic, Bold Italic) into `~/.local/share/fonts`.
4. Copies the configs and scripts listed below, installs the Ash VS Code theme from
   [`ash-theme`](https://github.com/zelkru/ash-theme), and patches Discord with Vencord (needs
   sudo, skipped with `--no-apt`; run it again after a Discord update, which undoes the patch).
5. Downloads the zjstatus plugin for zellij and pre-grants its permissions.
6. Adds a snippet to `~/.bashrc` that starts fish (bash stays the login shell).
7. Runs `cinnamon/apply.sh` (theme, top bar, keybindings, fonts, workspaces).

After the first install, log out and in once and run `cinnamon/apply.sh` again: Cinnamon only
creates the applet settings files after an applet has loaded once.

## Layout

| Repo path | Installed to |
|---|---|
| `config/alacritty`, `kitty`, `fish`, `zellij`, `rofi`, `fastfetch`, `fontconfig` | `~/.config/<name>` |
| `config/git/config` | `~/.config/git/config` (the global ignore comes from `shared/git/ignore`) |
| `config/mise/conf.d/linux.toml` | `~/.config/mise/conf.d/` |
| `config/ssh_config` | `~/.ssh/config`, only if missing (keys are never in the repo) |
| `bin/` | `~/.local/bin/` |
| `applications/power-menu.desktop` | `~/.local/share/applications/` (launcher behind the top bar's power button) |
| `autostart/focus-new-windows.desktop` | `~/.config/autostart/` |
| `cinnamon/ash.css` | appended to a copy of the Mint-Y-Dark-Red Cinnamon theme, installed as `~/.themes/Ash` |
| `cinnamon/apply.sh` | not copied, it runs `gsettings` / `dbus` |

`shared/` is used as well: `starship.toml`, the global gitignore and the mise tool list.

## Keybindings

### Desktop (Cinnamon)

| Keys | Action |
|---|---|
| `Super + T` or `Ctrl + Alt + T` | New terminal (Alacritty) |
| `Super + S` | rofi launcher (apps; `Tab` switches to commands / windows) |
| `Super + Q` | Close window (`Alt + F4` still works) |
| `Super + 1..4` | Go to workspace 1..4 |
| `Super + Shift + 1..4` | Move the focused window to workspace 1..4 |
| `Super + arrows` or drag a window to a screen edge/corner | Snap it to a half or quarter of the screen (edge tiling is on) |
| `Alt + 1..4` | Focus or launch the Nth app pinned in the taskbar |
| `Super + Shift + L` | Power menu: lock, log out, suspend, reboot, shut down (also the power button at the right end of the top bar) |

### Terminal (Alacritty, zellij, fish)

| Keys | Action |
|---|---|
| `Ctrl + Shift + T` (or `Alt + T`) | New tab |
| `Ctrl + Shift + W` (or `Alt + W`) | Close pane |
| `Ctrl + Tab` / `Ctrl + Shift + Tab` | Next / previous tab (also `Ctrl + PageUp/Down`, `Alt + H/L`) |
| `Alt + Shift + D` | Split pane |
| `Alt + Shift + -` / `Alt + Shift + =` | Split down / right |
| `Alt + arrows` | Move between panes |
| `Alt + Shift + arrows` | Resize pane |
| `Ctrl + Shift + Z` (or `Alt + Z`) | Zoom pane |
| `Alt + /` | Show / hide the key hints in the tab bar |
| `Ctrl + A` | Select the whole command line |
| `Shift + arrows / Home / End` | Select text on the command line (`Ctrl + Shift + arrows` by word) |
| typing, `Backspace`, `Delete` | Replace / delete the selection |
| `Ctrl + Shift + C` | Copy the command-line selection to the clipboard |
| `Ctrl + Shift + V` | Paste |
| mouse selection (in zellij) | Copies on release, through `xsel` |

## How it works

**Terminal.** Alacritty starts zellij (`[shell]` in `alacritty.toml`) with the `clean` layout: a
one-line [zjstatus](https://github.com/dj95/zjstatus) bar that only shows tab numbers, no session
name and no hint bar. `Alt + /` runs `bin/zj-hints`, which sends text to the right side of that
bar and clears it on the next press. zellij is set to quit (not detach) when the window closes, so
sessions do not pile up. Alacritty's colors are written out in full from `ash-theme/palette.md`.

**Key translation.** Terminals cannot tell `Ctrl+Tab` or `Ctrl+Shift+T` apart from plain keys.
`alacritty.toml` rewrites them to `Alt` sequences that zellij and fish bind (for example
`Ctrl+Shift+T` is sent as `Alt+T`, `Ctrl+Tab` as `Alt+.`).

**Shell.** fish with Starship (the same `starship.toml` as Windows), zoxide and mise. The palette is
set through `fish_color_*`. `conf.d/windows-selection.fish` adds PSReadLine-style selection:
`Ctrl+A`, `Shift+arrows`, typing over a selection, copy. Do not bind the catch-all key (`bind ''`)
to a shell function: it swallows every keypress.

**Desktop.**
- `apply.sh` builds the Cinnamon theme (a copy of Mint-Y-Dark-Red plus `ash.css`), sets
  fonts, keybindings and workspaces, and lays out the panels: a 36 px top bar (workspaces, clock,
  tray, bluetooth, network, sound, battery, power button) and the taskbar at the bottom, auto-hidden.
- `bin/focus-new-windows` runs at login and activates every new normal window. Muffin denies focus to
  apps that do not send a startup timestamp (Alacritty, for one), so new windows opened without a click.
- `bin/power-menu` is a rofi menu (same theme) for lock, log out, suspend, reboot and shut down; the last three
  ask for confirmation. The power button in the top bar is a `panel-launchers` applet that opens it.
- `bin/pinned-app N` reads the taskbar's pinned apps each time, so `Alt + N` follows the pinned order.
  The taskbar applet's own `Super + N` shortcut is switched off because `Super + N` is for workspaces.
- The terminal shortcut uses `gtk-launch Alacritty` instead of calling `alacritty`, for the same
  focus reason.

## Git, GitHub and SSH

`config/git/config` is the Windows config adapted: `autocrlf = input`, the credential helper points to
`/usr/bin/gh`, and `gpg.ssh.allowedSignersFile` is set. Commits are signed with
`~/.ssh/id_ed25519_github.pub`.

Each machine has **its own** key: do not copy the Windows key, add a second one to GitHub.

```bash
ssh-keygen -t ed25519 -C "783613+zeldxh@users.noreply.github.com" -f ~/.ssh/id_ed25519_github
gh auth login                                              # SSH, upload the key when asked
gh auth refresh -h github.com -s admin:ssh_signing_key     # permission to add signing keys
gh ssh-key add ~/.ssh/id_ed25519_github.pub --type signing --title "Mint (signing)"
echo "783613+zeldxh@users.noreply.github.com $(cut -d' ' -f1,2 ~/.ssh/id_ed25519_github.pub)" > ~/.ssh/allowed_signers
ssh -T git@github.com                                      # "Hi zelkru!"
```

`gh auth login` already uploads the key as an authentication key; the signing key is a separate
entry and has to be added by hand. Private keys and `allowed_signers` are never in the repo
(`hooks/pre-push` blocks them).

## What differs from Windows

| | Windows | Linux |
|---|---|---|
| Terminal | Windows Terminal | Alacritty + zellij (Alacritty has no tabs) |
| Shell | PowerShell 7 | fish |
| Prompt | Starship | Starship (shared config) |
| Launcher | Start menu | rofi (`Super + S`) |
| Packages | winget | apt + mise |
| Git `autocrlf` | `true` | `input` |
| Credential helper | `gh.exe` | `/usr/bin/gh` |
| Font size | 22 (high-DPI) | 18 in the terminal |

## Not included

- `~/.ssh` keys and `allowed_signers`.
- Browser themes: load `ash-theme/brave` and `ash-theme/firefox` by hand from the browser.
- Discord's Custom CSS comes from `ash-theme/discord`. The VS Code theme is installed by `install.sh`.
- The base Cinnamon theme (`Mint-Y-Dark-Red`), it ships with Mint; only the overrides are here.

## Troubleshooting

- **A keybinding does nothing right after install**: log out and in once.
- **The clock or battery label look unchanged**: run `cinnamon/apply.sh` again after logging in.
- **zellij asks to allow the plugin**: `~/.cache/zellij/permissions.kdl` lost the zjstatus entry, run `install.sh` again.
- **Typing does nothing in a new fish**: a binding in `conf.d/windows-selection.fish` broke input; move it away and open a new terminal.
- **`Alt + N` conflicts in Brave or VS Code**: those apps lose `Alt + 1..4`, the desktop takes them. Change the bindings in `cinnamon/apply.sh`.
