#!/bin/sh
# Links the plugin into SekaiPop's plugins folder, reloads the shell's plugins and puts
# its bar entry on. Run it from the clone; `git pull` there later updates it (then run
# this again).
#
#   ./install.sh            link omdrop, and put its entry on the bar
#   ./install.sh --remove   take the link away (its saved settings stay)
#   ./install.sh --help     show this help
set -eu

config="${SEKAIPOP_CONFIG_NAME:-sekaipop}"
plugins="${SEKAIPOP_PLUGINS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sekaipop/plugins}"
dest="$plugins/omdrop"

usage() {
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
    "" ) ;;
    --remove) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
esac

here=$(cd "$(dirname "$0")" && pwd)
[ -f "$here/omdrop/plugin.json" ] || {
    echo "install.sh: $here/omdrop/plugin.json is missing; run it from the clone." >&2
    exit 1
}

if [ "${1:-}" = "--remove" ]; then
    if [ -L "$dest" ]; then
        rm "$dest"
        echo "removed omdrop"
    elif [ -e "$dest" ]; then
        echo "$dest exists and is not a link: left alone" >&2
        exit 1
    else
        echo "omdrop is not installed"
    fi
    command -v qs >/dev/null 2>&1 \
        && qs -c "$config" ipc call plugins reload >/dev/null 2>&1 || true
    exit 0
fi

if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "$dest exists and is not a link: left alone" >&2
    exit 1
fi

mkdir -p "$plugins"
ln -sfn "$here/omdrop" "$dest"
echo "linked omdrop into $plugins"

if command -v omdrop >/dev/null 2>&1; then
    if omdrop doctor --json >/dev/null 2>&1; then
        echo "omdrop: ready"
    else
        echo "omdrop: installed, but 'omdrop doctor' is not happy; run it for the next step." >&2
    fi
else
    echo "warning: omdrop is not on PATH. Install Omdrop first:" >&2
    echo "  https://github.com/netmojo-systems/omdrop-plugin" >&2
fi

if command -v qs >/dev/null 2>&1; then
    if qs -c "$config" ipc call plugins reload >/dev/null 2>&1; then
        # The scan takes a moment; then the entry goes on the bar (it starts off).
        sleep 1
        if qs -c "$config" ipc call plugins list 2>/dev/null | grep -q '^omdrop[[:space:]]'; then
            if qs -c "$config" ipc call plugins bar omdrop on >/dev/null 2>&1; then
                echo "Omdrop is on the bar."
            else
                echo "Turn the entry on in Settings > Bar > Modules."
            fi
        else
            echo "omdrop did not load; check Settings > Desktop > Plugins for the reason." >&2
        fi
    else
        echo "SekaiPop is not running; it will load omdrop the next time it starts."
    fi
else
    echo "warning: qs is not on PATH. Install SekaiPop, then run this again." >&2
fi

echo "The widget: add Omdrop from Edit Desktop (right-click the desktop)."
