#!/bin/sh
# Links the plugin into SekaiPop's plugins folder and, when they are missing,
# installs the bundled Omdrop command, its receiver dependencies and a radio
# backend. Run it from the clone; `git pull` there later updates it (then run
# this again).
#
#   ./install.sh            install/link everything, and put its entry on the bar
#   ./install.sh --remove   take the plugin and its handler away (saved settings stay)
#   ./install.sh --help     show this help
#
# It asks for your password only when packages or the receiver service need it.
# An existing ~/.local/bin/omdrop is never replaced if it points at another copy.
set -eu

config="${SEKAIPOP_CONFIG_NAME:-sekaipop}"
plugins="${SEKAIPOP_PLUGINS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sekaipop/plugins}"
dest="$plugins/omdrop"
here=$(cd "$(dirname "$0")" && pwd)
vendor="$here/omdrop/vendor/omdrop"
vendor_omdrop="$vendor/bin/omdrop"
shell_dir="${SEKAIPOP_SHELL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/$config}"
bar_qml="$shell_dir/modules/sekai/bar/Bar.qml"
bin_link="${XDG_BIN_HOME:-$HOME/.local/bin}/omdrop"
unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/airdrop-receiver.service"
link_app="${XDG_DATA_HOME:-$HOME/.local/share}/applications/netmojo.omdrop-links.desktop"

usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

say() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() { warn "install.sh: $*"; exit 1; }

case "${1:-}" in
    "" ) ;;
    --remove) ;;
    -h|--help) usage; exit 0 ;;
    *) warn "install.sh: unknown option $1"; usage >&2; exit 2 ;;
esac

[ -f "$here/omdrop/plugin.json" ] || die "$here/omdrop/plugin.json is missing; run it from the clone."
[ -f "$vendor/manifest.json" ] || die "the bundled Omdrop copy is missing; run it from the clone."
[ -x "$vendor_omdrop" ] || die "$vendor_omdrop is not executable."

as_root() {
    if [ "${SEKAIPOP_OMDROP_NO_SUDO:-0}" = "1" ]; then
        warn "install.sh: skipping root step: $*"
        return 1
    fi
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        if [ -t 0 ]; then
            sudo "$@"
        elif sudo -n true >/dev/null 2>&1; then
            sudo "$@"
        else
            warn "install.sh: need sudo for: $* (run this in a terminal, or set SEKAIPOP_OMDROP_NO_SUDO=1 to skip)"
            return 1
        fi
    else
        warn "install.sh: need root for: $* (install sudo or run this as root)"
        return 1
    fi
}

install_pkgs() {
    command -v pacman >/dev/null 2>&1 || {
        warn "install.sh: pacman was not found; install these with your package manager: $*"
        return 1
    }
    as_root pacman -S --needed --noconfirm "$@"
}

aur_install() {
    pkg=$1
    if command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm "$pkg"
    elif command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm "$pkg"
    elif command -v makepkg >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
        cache="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop-omdrop/aur"
        mkdir -p "$cache"
        if [ -d "$cache/$pkg/.git" ]; then
            git -C "$cache/$pkg" pull --ff-only --quiet
        else
            git clone --depth=1 --quiet "https://aur.archlinux.org/$pkg.git" "$cache/$pkg"
        fi
        ( cd "$cache/$pkg" && makepkg -si --noconfirm )
    else
        warn "install.sh: no AUR helper and no makepkg; install $pkg from the AUR."
        return 1
    fi
}

receiver_libs_ready() {
    python=/usr/bin/python3
    [ -x "$python" ] || python=python3
    "$python" -c 'from libarchive import stream_reader; import ctypes; ctypes.CDLL("libkeyutils.so.1")' \
        >/dev/null 2>&1
}

install_receiver_deps() {
    if receiver_libs_ready; then
        say "Omdrop receiver libraries: ready"
        return 0
    fi
    say "Installing Omdrop's receiver libraries (python-libarchive-c, keyutils)…"
    if install_pkgs python-libarchive-c keyutils && receiver_libs_ready; then
        say "Omdrop receiver libraries: ready"
    else
        warn "install.sh: the receiver libraries are still missing; Omdrop will not receive files."
        return 1
    fi
}

radio_ready() {
    [ -x /usr/lib/omdrop/omdrop-discoverable ] \
        || [ -d /usr/lib/omdrop/radio ] \
        || command -v omdrop-discoverable >/dev/null 2>&1
}

enable_owlyd() {
    command -v systemctl >/dev/null 2>&1 || return 0
    if systemctl cat owlyd.service >/dev/null 2>&1; then
        if [ "$(systemctl is-enabled owlyd.service 2>/dev/null || true)" != "enabled" ] \
            || ! systemctl is-active --quiet owlyd.service 2>/dev/null; then
            say "Enabling Owly's radio service (owlyd)…"
            as_root systemctl enable --now owlyd.service \
                || warn "install.sh: could not enable owlyd; start it with: sudo systemctl enable --now owlyd"
        fi
    elif systemctl --user cat owlyd.service >/dev/null 2>&1; then
        if [ "$(systemctl --user is-enabled owlyd.service 2>/dev/null || true)" != "enabled" ] \
            || ! systemctl --user is-active --quiet owlyd.service 2>/dev/null; then
            say "Enabling Owly's radio service (owlyd)…"
            systemctl --user enable --now owlyd.service \
                || warn "install.sh: could not enable owlyd; start it with: systemctl --user enable --now owlyd"
        fi
    fi
}

install_radio_backend() {
    if radio_ready; then
        enable_owlyd
        say "Omdrop radio backend: ready"
        return 0
    fi
    [ "$(uname -s)" = "Linux" ] || {
        warn "install.sh: no Omdrop radio backend is installed; install one for this system."
        return 1
    }
    command -v pacman >/dev/null 2>&1 || {
        warn "install.sh: no radio backend found; install omdrop-owl or another Omdrop backend."
        return 1
    }

    machine=$(uname -m)
    if [ "$machine" = "aarch64" ] && grep -qi apple /proc/device-tree/compatible 2>/dev/null; then
        say "Installing Omdrop's Apple Silicon Wi-Fi driver…"
        if pacman -Si brcmfmac-awdl-dkms >/dev/null 2>&1; then
            install_pkgs brcmfmac-awdl-dkms || true
        else
            warn "install.sh: the Apple Silicon driver is not in the repositories."
            warn "Run this from a terminal to build it: $vendor_omdrop install-driver"
        fi
    elif grep -qs '^0x14e4$' /sys/bus/pci/devices/*/vendor 2>/dev/null \
        && grep -qs '^0x43a0$' /sys/bus/pci/devices/*/device 2>/dev/null; then
        say "Installing the Omdrop backend for the Broadcom BCM4360 (omdrop-bcm4360)…"
        aur_install omdrop-bcm4360 || true
    else
        say "Installing Owly's Omdrop backend (omdrop-owl-bin)…"
        aur_install omdrop-owl-bin || aur_install omdrop-owl || true
        enable_owlyd
    fi

    if radio_ready; then
        say "Omdrop radio backend: ready"
    else
        warn "install.sh: no radio backend is ready yet; run '$vendor_omdrop doctor' for the next step."
        return 1
    fi
}

patch_bar() {
    bar_patched=0
    if [ ! -f "$bar_qml" ]; then
        say "SekaiPop's Bar.qml was not found; plugin popups may not take the keyboard."
        return 0
    fi
    if grep -q 'win.pluginPopup !== ""' "$bar_qml"; then
        say "SekaiPop plugin-popup keyboard focus: ready"
        return 0
    fi
    if ! grep -q 'WlrLayershell.keyboardFocus: win.eqPopupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None' "$bar_qml"; then
        warn "install.sh: could not find SekaiPop's keyboard-focus line in $bar_qml."
        warn "Update SekaiPop or apply https://github.com/Blapples/SekaiPop/pull/120 by hand."
        return 0
    fi
    backup="$bar_qml.bak-sekaipop-omdrop-$(date +%Y%m%d-%H%M%S)"
    cp -p "$bar_qml" "$backup"
    tmp="$bar_qml.tmp.$$"
    sed 's#WlrLayershell.keyboardFocus: win.eqPopupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None#WlrLayershell.keyboardFocus: (win.eqPopupOpen || win.pluginPopup !== "") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None#' \
        "$bar_qml" > "$tmp"
    mv "$tmp" "$bar_qml"
    bar_patched=1
    say "Patched SekaiPop so plugin popups take the keyboard (backup: $backup)."
}

install_vendor_setup() {
    if [ "${SEKAIPOP_OMDROP_SKIP_SETUP:-0}" = "1" ]; then
        return 0
    fi
    say "Setting up Omdrop's receiver service and identity…"
    if "$vendor_omdrop" setup; then
        :
    else
        warn "install.sh: 'omdrop setup' did not finish; run '$vendor_omdrop setup' for the next step."
    fi

    if [ -e "$bin_link" ] || [ -L "$bin_link" ]; then
        current=$(readlink -f "$bin_link" 2>/dev/null || true)
        if [ "$current" != "$(readlink -f "$vendor_omdrop" 2>/dev/null || printf '%s' "$vendor_omdrop")" ]; then
            warn "install.sh: left $bin_link alone; it points at $current."
            say "The plugin itself uses the bundled command, so this only affects the terminal."
        fi
    elif mkdir -p "$(dirname "$bin_link")" && ln -s "$vendor_omdrop" "$bin_link"; then
        say "Put the omdrop command on your PATH at $bin_link."
    fi
}

reload_plugin() {
    command -v qs >/dev/null 2>&1 || {
        warn "install.sh: qs is not on PATH. Install SekaiPop, then run this again."
        return 0
    }
    if qs -c "$config" ipc call plugins reload >/dev/null 2>&1; then
        sleep 1
        if qs -c "$config" ipc call plugins list 2>/dev/null | grep -q '^omdrop[[:space:]]'; then
            if qs -c "$config" ipc call plugins bar omdrop on >/dev/null 2>&1; then
                say "Omdrop is on the bar."
            else
                say "Turn the entry on in Settings > Bar > Modules."
            fi
        else
            warn "omdrop did not load; check Settings > Desktop > Plugins for the reason."
        fi
    else
        say "SekaiPop is not running; it will load omdrop the next time it starts."
    fi
}

remove_install() {
    if [ -L "$dest" ]; then
        rm "$dest"
        say "removed the plugin link"
    elif [ -e "$dest" ]; then
        warn "install.sh: $dest exists and is not a link; left alone."
    else
        say "the plugin is not installed"
    fi

    if [ -L "$bin_link" ]; then
        current=$(readlink -f "$bin_link" 2>/dev/null || true)
        case "$current" in
            "$here"/*)
                rm "$bin_link"
                say "removed $bin_link"
                ;;
        esac
    fi

    if [ -r "$unit" ] && grep -qF "$here/" "$unit"; then
        rm "$unit"
        command -v systemctl >/dev/null 2>&1 \
            && systemctl --user daemon-reload >/dev/null 2>&1 || true
        say "removed the receiver service written from this copy"
    fi

    if [ -r "$link_app" ] && grep -qF "$here/" "$link_app"; then
        "$vendor_omdrop" links remove >/dev/null 2>&1 || true
        rm -f "$link_app"
        command -v update-desktop-database >/dev/null 2>&1 \
            && update-desktop-database "$(dirname "$link_app")" >/dev/null 2>&1 || true
        say "removed the received-link handler written from this copy"
    fi

    command -v qs >/dev/null 2>&1 \
        && qs -c "$config" ipc call plugins reload >/dev/null 2>&1 || true
    say "Kept Omdrop settings, identity, downloads, packages and radio backend."
    exit 0
}

[ "${1:-}" = "--remove" ] && remove_install

if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    die "$dest exists and is not a link; left alone."
fi

deps_ok=1
radio_ok=1
install_receiver_deps || deps_ok=0
install_radio_backend || radio_ok=0

mkdir -p "$plugins"
ln -sfn "$here/omdrop" "$dest"
say "linked omdrop into $plugins"

install_vendor_setup
patch_bar

if [ "$deps_ok" = "1" ] && [ "$radio_ok" = "1" ] \
    && "$vendor_omdrop" doctor --json >/dev/null 2>&1; then
    say "omdrop: ready"
else
    warn "omdrop: installed, but not ready yet; run '$vendor_omdrop doctor' for the next step."
fi

reload_plugin

if [ "${bar_patched:-0}" = "1" ]; then
    say "Restart SekaiPop (or your session) to apply the plugin-popup keyboard fix."
fi

say "The widget: add Omdrop from Edit Desktop (right-click the desktop)."
