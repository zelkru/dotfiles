#!/bin/bash
# Applies the Cinnamon desktop setup: Ash theme, top bar, fonts, keybindings, workspaces.
# Idempotent: safe to run again. Needs a running Cinnamon session (uses gsettings / dbus).
# Applet settings (clock format, battery label...) live in JSON files Cinnamon only creates once an
# applet has been loaded, so on a brand new account run this script, log out and in, and run it again.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
font='IosevkaTerm Nerd Font Mono'
bin="$HOME/.local/bin"
base_theme='Mint-Y-Dark-Red'
theme='Ash'

gs() { gsettings set "$@" 2>/dev/null || echo "skipped: gsettings set $1 $2"; }

# --- Theme: copy of the base Cinnamon theme plus the palette overrides --------------------------
src="/usr/share/themes/$base_theme/cinnamon"
if [ -d "$src" ]; then
    rm -rf "$HOME/.themes/Alacritty-Rice"   # the theme's name before it became Ash
    rm -rf "$HOME/.themes/$theme/cinnamon"
    mkdir -p "$HOME/.themes/$theme"
    cp -r "$src" "$HOME/.themes/$theme/cinnamon"
    cat "$here/ash.css" >> "$HOME/.themes/$theme/cinnamon/cinnamon.css"
    # force a reload when the theme is already active
    [ "$(gsettings get org.cinnamon.theme name)" = "'$theme'" ] && gs org.cinnamon.theme name "$base_theme"
    gs org.cinnamon.theme name "$theme"
else
    echo "base theme $base_theme not found, skipping the panel theme"
fi

# --- Fonts: IosevkaTerm Nerd Font everywhere ----------------------------------------------------
gs org.cinnamon.desktop.interface font-name "$font 12"
gs org.gnome.desktop.interface font-name "$font 12"
gs org.gnome.desktop.interface document-font-name "$font 12"
gs org.gnome.desktop.interface monospace-font-name "$font 13"
gs org.nemo.desktop font "$font 12"
gs org.cinnamon.desktop.wm.preferences titlebar-font "$font 12"

# --- GTK theme, icons and cursor ----------------------------------------------------------------
gs org.cinnamon.desktop.interface gtk-theme "$base_theme"
gs org.cinnamon.desktop.interface icon-theme 'Mint-Y-Red'
gs org.cinnamon.desktop.interface cursor-theme 'Bibata-Modern-Classic'

# --- Default terminal ---------------------------------------------------------------------------
gs org.cinnamon.desktop.default-applications.terminal exec alacritty

# --- Workspaces: 4 fixed, Super+N switches, Super+Shift+N moves the focused window --------------
gs org.cinnamon.desktop.wm.preferences num-workspaces 4
gs org.cinnamon.muffin dynamic-workspaces false
for n in 1 2 3 4; do
    gs org.cinnamon.desktop.keybindings.wm "switch-to-workspace-$n" "['<Super>$n']"
    gs org.cinnamon.desktop.keybindings.wm "move-to-workspace-$n" "['<Super><Shift>$n']"
done

# --- Window keys --------------------------------------------------------------------------------
gs org.cinnamon.desktop.keybindings.wm close "['<Alt>F4', '<Super>q']"
gs org.cinnamon.desktop.keybindings show-desklets "[]"                  # frees Super+S for rofi
gs org.cinnamon.desktop.keybindings.media-keys terminal "[]"            # replaced by the custom one below

# --- Tiling: drag a window to a screen edge/corner to snap it to half/quarter (Super+arrows too) ---
gs org.cinnamon.muffin edge-tiling true

# --- Custom keybindings -------------------------------------------------------------------------
# Terminal: gtk-launch (not plain `alacritty`) so Muffin hands the new window focus
# Rofi:     Super+S launcher
# Alt+1..4: focus/launch the Nth app pinned in the taskbar (see bin/pinned-app)
custom() {  # id, name, command, binding
    local p="/org/cinnamon/desktop/keybindings/custom-keybindings/$1/"
    local s="org.cinnamon.desktop.keybindings.custom-keybinding:$p"
    gs "$s" name "$2"; gs "$s" command "$3"; gs "$s" binding "$4"
}
custom terminal 'Terminal'     'gtk-launch Alacritty'   "['<Control><Alt>t', '<Super>t']"
custom rofi     'Rofi launcher' 'rofi -show drun'       "['<Super>s']"
custom powermenu 'Power menu'   "$bin/power-menu"        "['<Super><Shift>l']"
for n in 1 2 3 4; do custom "pinned$n" "Pinned app $n" "$bin/pinned-app $n" "['<Alt>$n']"; done
gs org.cinnamon.desktop.keybindings custom-list "['terminal', 'rofi', 'pinned1', 'pinned2', 'pinned3', 'pinned4', 'powermenu']"

# --- Panels: thin top bar with everything, autohiding taskbar at the bottom ---------------------
gs org.cinnamon panels-enabled "['1:0:bottom', '2:0:top']"
gs org.cinnamon panels-height "['1:40', '2:36']"
gs org.cinnamon panels-autohide "['1:true', '2:false']"
gs org.cinnamon panel-zone-icon-sizes '[{"panelId": 1, "left": 0, "center": 0, "right": 18}, {"panelId": 2, "left": 0, "center": 0, "right": 18}]'
gs org.cinnamon panel-zone-symbolic-icon-sizes '[{"panelId":1,"left":18,"center":18,"right":18},{"panelId":2,"left":18,"center":18,"right":18}]'
gs org.cinnamon enabled-applets "['panel1:left:0:menu@cinnamon.org:0', 'panel1:left:1:separator@cinnamon.org:1', 'panel1:left:2:grouped-window-list@cinnamon.org:2', 'panel2:left:0:workspace-switcher@cinnamon.org:15', 'panel2:center:0:calendar@cinnamon.org:13', 'panel2:right:0:systray@cinnamon.org:3', 'panel2:right:1:xapp-status@cinnamon.org:4', 'panel2:right:2:notifications@cinnamon.org:5', 'panel2:right:3:removable-drives@cinnamon.org:7', 'panel2:right:4:keyboard@cinnamon.org:8', 'panel2:right:5:network@cinnamon.org:10', 'panel2:right:6:sound@cinnamon.org:11', 'panel2:right:7:power@cinnamon.org:12', 'panel2:right:8:panel-launchers@cinnamon.org:16']"
dconf write /org/cinnamon/next-applet-id 17

# --- Applet settings (JSON written by Cinnamon, only exists after the applet has run once) ------
sleep 3
python3 - <<'EOF'
import json, os, glob
spices = os.path.expanduser('~/.config/cinnamon/spices')

def edit(pattern, **values):
    files = glob.glob(f'{spices}/{pattern}')
    if not files:
        print(f'skipped (not created yet): {pattern}')
        return False
    for path in files:
        data = json.load(open(path))
        for key, value in values.items():
            if key in data and isinstance(data[key], dict):
                data[key]['value'] = value
        json.dump(data, open(path, 'w'), indent=4)
    return True

edit('calendar@cinnamon.org/*.json', **{'use-custom-format': True, 'custom-format': '%a %d %b   %H:%M'})
edit('power@cinnamon.org/*.json', labelinfo='percentage')
edit('workspace-switcher@cinnamon.org/*.json', **{'display-type': 'buttons'})
edit('panel-launchers@cinnamon.org/*.json', **{'launcherList': ['power-menu.desktop'], 'allow-dragging': False})   # the power button
edit('grouped-window-list@cinnamon.org/*.json', **{
    'super-num-hotkeys': False,   # Super+N is for workspaces, Alt+N is for the pinned apps
    'pinned-apps': ['com.brave.Origin.desktop', 'Alacritty.desktop', 'com.microsoft.VSCode.desktop', 'nemo.desktop'],
})
EOF

# --- Reload the applets that cache their settings -----------------------------------------------
for x in workspace-switcher calendar power grouped-window-list panel-launchers; do
    dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon \
        org.Cinnamon.ReloadXlet string:"$x@cinnamon.org" string:"APPLET" 2>/dev/null || true
done
echo "Cinnamon setup applied."
