#!/bin/bash
# Linux Mint (Cinnamon) setup: programs, font, configs, scripts and desktop.
#   ./install.sh             repo -> system  (everything below)
#   ./install.sh --collect   system -> repo  (after editing configs live)
#   ./install.sh --no-apt    skip the apt step (no sudo)
# Safe to run again. Paths with @HOME@ in the repo are expanded to $HOME on install.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
collect=0; apt=1
for a in "$@"; do
    case "$a" in
        --collect) collect=1 ;;
        --no-apt) apt=0 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done

# repo path (relative to the repo root) -> live path
declare -a MAP=(
    "linux/config/alacritty/alacritty.toml|$HOME/.config/alacritty/alacritty.toml"
    "linux/config/kitty/kitty.conf|$HOME/.config/kitty/kitty.conf"
    "linux/config/fish/config.fish|$HOME/.config/fish/config.fish"
    "linux/config/fish/conf.d/windows-selection.fish|$HOME/.config/fish/conf.d/windows-selection.fish"
    "linux/config/fish/functions/fastfetch.fish|$HOME/.config/fish/functions/fastfetch.fish"
    "linux/config/fish/functions/neofetch.fish|$HOME/.config/fish/functions/neofetch.fish"
    "linux/config/zellij/config.kdl|$HOME/.config/zellij/config.kdl"
    "linux/config/zellij/layouts/clean.kdl|$HOME/.config/zellij/layouts/clean.kdl"
    "linux/config/rofi/config.rasi|$HOME/.config/rofi/config.rasi"
    "linux/config/git/config|$HOME/.config/git/config"
    "shared/git/ignore|$HOME/.config/git/ignore"
    "shared/git/euxora|$HOME/.config/git/euxora"
    "shared/git/allowed_signers|$HOME/.config/git/allowed_signers"
    "shared/starship.toml|$HOME/.config/starship.toml"
    "linux/config/fastfetch/config.jsonc|$HOME/.config/fastfetch/config.jsonc"
    "linux/config/fastfetch/logo.txt|$HOME/.config/fastfetch/logo.txt"
    "linux/config/mise/conf.d/linux.toml|$HOME/.config/mise/conf.d/linux.toml"
    "linux/config/fontconfig/fonts.conf|$HOME/.config/fontconfig/fonts.conf"
    "linux/bin/pinned-app|$HOME/.local/bin/pinned-app"
    "linux/bin/focus-new-windows|$HOME/.local/bin/focus-new-windows"
    "linux/bin/zj-hints|$HOME/.local/bin/zj-hints"
    "linux/bin/power-menu|$HOME/.local/bin/power-menu"
    "linux/applications/power-menu.desktop|$HOME/.local/share/applications/power-menu.desktop"
    "linux/autostart/focus-new-windows.desktop|$HOME/.config/autostart/focus-new-windows.desktop"
)

copy_in()  { mkdir -p "$(dirname "$2")"; rm -f "$2"; sed "s|@HOME@|$HOME|g" "$1" > "$2"; [ -x "$1" ] && chmod +x "$2"; echo "$1 -> $2"; }
copy_out() { sed "s|$HOME|@HOME@|g" "$1" > "$2"; echo "$1 -> $2"; }

if [ "$collect" = 1 ]; then
    for entry in "${MAP[@]}"; do
        rel="${entry%%|*}"; live="${entry#*|}"
        [ -f "$live" ] || { echo "missing: $live"; continue; }
        copy_out "$live" "$root/$rel"
    done
    echo "Collected. Review with: git -C $root diff"
    exit 0
fi

# --- 1. Programs (needs sudo) -------------------------------------------------------------------
if [ "$apt" = 1 ]; then
    sudo apt install -y alacritty kitty fish rofi gh git zoxide xsel wmctrl curl unzip

    # Laptops whose firmware allows it: stop charging at 80% (see linux/system/battery-charge-limit.service)
    if [ -e /sys/class/power_supply/BAT0/charge_control_end_threshold ]; then
        sudo install -m 644 "$here/system/battery-charge-limit.service" /etc/systemd/system/battery-charge-limit.service
        sudo systemctl daemon-reload
        sudo systemctl enable --now battery-charge-limit.service
    fi
fi

# --- 2. mise tools (starship, fastfetch, zellij, plus shared/mise: node, java, python...) --------
if command -v mise >/dev/null 2>&1 || [ -x "$HOME/.local/bin/mise" ]; then
    m="$(command -v mise || echo "$HOME/.local/bin/mise")"
    [ -f "$HOME/.config/mise/config.toml" ] || { mkdir -p "$HOME/.config/mise"; cp "$root/shared/mise/config.toml" "$HOME/.config/mise/config.toml"; }
else
    echo "mise is not installed. Install it (https://mise.jdx.dev) and run this script again."
    m=""
fi

# --- 3. Font: IosevkaTerm Nerd Font Mono (only the 4 styles used) -------------------------------
if ! fc-list | grep -qi "IosevkaTerm Nerd Font Mono"; then
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/IosevkaTerm.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip
    mkdir -p "$HOME/.local/share/fonts/IosevkaTermNF"
    unzip -oq "$tmp/IosevkaTerm.zip" \
        'IosevkaTermNerdFontMono-Regular.ttf' 'IosevkaTermNerdFontMono-Bold.ttf' \
        'IosevkaTermNerdFontMono-Italic.ttf' 'IosevkaTermNerdFontMono-BoldItalic.ttf' \
        -d "$HOME/.local/share/fonts/IosevkaTermNF"
    rm -rf "$tmp"
else
    echo "font already installed"
fi

# --- 4. Configs and scripts ---------------------------------------------------------------------
for entry in "${MAP[@]}"; do
    copy_in "$root/${entry%%|*}" "${entry#*|}"
done
fc-cache -f

# ssh config is only created when missing; the git hooks are global (core.hooksPath in git/config)
[ -f "$HOME/.ssh/config" ] || { mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; copy_in "$here/config/ssh_config" "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"; }
mkdir -p "$HOME/.config/git/hooks"
cp "$root"/hooks/* "$HOME/.config/git/hooks/"
chmod +x "$HOME/.config/git/hooks/"*
git -C "$root" config --unset core.hooksPath 2>/dev/null || true   # the global hooks path (git/config) covers every repo

# mise tools after the config is in place
[ -n "$m" ] && "$m" install

# Ash theme for VS Code: its own public repo, cloned next to this one and kept up to date
ash="$(dirname "$root")/ash-theme"
if [ -d "$ash/.git" ]; then git -C "$ash" pull --ff-only -q || echo "could not update $ash"
else
    # same owner as this repo's origin, so a renamed GitHub account needs no edit here
    git clone -q "$(git -C "$root" remote get-url origin | sed -E 's#[^/:]+$#ash-theme.git#')" "$ash" || true
fi
[ -x "$ash/vscode/install.sh" ] && "$ash/vscode/install.sh" || echo "Ash theme not available: $ash"

# Vencord: patch Discord with the official installer CLI. Safe to re-run (it re-patches with the
# latest build), and needed after a Discord update, which undoes the patch. Discord lives in
# /usr/share/discord (root-owned), so it runs with sudo; sudo sets SUDO_USER, which the installer
# uses to keep Vencord's own files in your home.
if [ "$apt" = 0 ]; then
    echo "--no-apt: skipping Vencord (needs sudo)"
elif command -v discord >/dev/null 2>&1; then
    cli="$(mktemp -d)/VencordInstallerCli"
    if curl -fsSL -o "$cli" https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux; then
        chmod +x "$cli"
        sudo "$cli" -install -branch auto || echo "Vencord install failed"
    else
        echo "could not download the Vencord installer"
    fi
    rm -rf "$(dirname "$cli")"
else
    echo "Discord is not installed, skipping Vencord."
fi

# --- 5. zjstatus (the zellij tab-only bar) ------------------------------------------------------
plugin="$HOME/.config/zellij/plugins/zjstatus.wasm"
if [ ! -f "$plugin" ]; then
    mkdir -p "$(dirname "$plugin")"
    curl -fsSL -o "$plugin" https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm
fi
# Pre-grant its permissions so zellij does not ask
mkdir -p "$HOME/.cache/zellij"
grep -qs "$plugin" "$HOME/.cache/zellij/permissions.kdl" || cat >> "$HOME/.cache/zellij/permissions.kdl" <<EOF
"$plugin" {
    ReadApplicationState
    ChangeApplicationState
    RunCommands
    ReadCliPipes
    MessageAndLaunchOtherPlugins
}
EOF

# --- 6. Start fish from bash in interactive terminals (bash stays the login shell) --------------
if ! grep -qs "exec fish" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'

# Open fish in interactive terminals (bash stays the login shell)
if [[ $- == *i* ]] && [[ -z "$BASH_EXECUTION_STRING" ]] && command -v fish >/dev/null 2>&1 && [[ "$(ps -o comm= -p $PPID)" != "fish" ]]; then
  exec fish
fi
EOF
fi

# --- 7. Desktop ---------------------------------------------------------------------------------
if command -v gsettings >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    bash "$here/cinnamon/apply.sh"
else
    echo "No graphical session: run linux/cinnamon/apply.sh from the desktop later."
fi

cat <<'EOF'

Done. Still manual (see linux/README.md):
  1. ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github   (one key per machine)
  2. gh auth login, then gh auth refresh -h github.com -s admin:ssh_signing_key
  3. gh ssh-key add ~/.ssh/id_ed25519_github.pub --type authentication
     gh ssh-key add ~/.ssh/id_ed25519_github.pub --type signing
  4. Log out and in once, then run linux/cinnamon/apply.sh again (applet settings).
EOF
