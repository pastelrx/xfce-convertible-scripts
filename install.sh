#!/bin/bash
#
# install.sh — interactive installer for xfce-convertible-scripts
#
# Run from the cloned repo:
#   git clone https://github.com/pastelrx/xfce-convertible-scripts.git
#   cd xfce-convertible-scripts
#   ./install.sh
#
# Presents a numbered menu of the scripts in this repo. Pick what you want,
# it checks dependencies (offering to install missing ones via pacman), copies
# each script to the right place, and prints any manual follow-up steps.
#
# No external dependencies — pure bash + coreutils.

set -u

# Resolve the repo root (directory this script lives in), so it works no matter
# where it's called from.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

BIN_DIR="$HOME/.local/bin"
CFG_DIR="$HOME/.config"

# colours (fall back to nothing if not a tty)
if [ -t 1 ]; then
    B=$'\e[1m'; DIM=$'\e[2m'; GRN=$'\e[32m'; YEL=$'\e[33m'; RED=$'\e[31m'; CYN=$'\e[36m'; RST=$'\e[0m'
else
    B=""; DIM=""; GRN=""; YEL=""; RED=""; CYN=""; RST=""
fi

# --- MANIFEST -----------------------------------------------------------------
# One entry per installable item. Pipe-separated fields:
#
#   key | relative_path_under_scripts | dest | deps | description
#
# dest:
#   bin       -> copy to ~/.local/bin, chmod +x
#   config    -> copy to ~/.config (keeps the basename, minus ".example")
#   run-sudo  -> don't copy; it's a one-shot you run with sudo from the repo
#
# deps: space-separated pacman package names ("" for none). gromit-mpx lives in
# the AUR, so it's listed separately as an AUR note rather than a pacman dep.
#
# To add a new script later: drop it under scripts/ and add a line here.
MANIFEST=(
  "gromit-toggle|gromit-toggle/gromit-toggle.sh|bin|xorg-xinput|Smart launcher/toggle for Gromit-MPX screen annotation (needs gromit-mpx from AUR)"
  "gromit-config|gromit-toggle/gromit-mpx.cfg.example|config||Gromit-MPX config: cyan pen + eraser on the pen side button"
  "crypto-tray|tricker-fng/crypto-tray.sh|bin|xfce4-genmon-plugin curl|Crypto prices in the XFCE panel (configurable coins, Binance)"
  "crypto-config|tricker-fng/crypto-config.sh|bin|yad|GUI to pick which coins crypto-tray shows (run via rofi/hotkey)"
  "fng-tray|tricker-fng/fng-tray.sh|bin|xfce4-genmon-plugin curl|Fear & Greed index in the panel (alternative.me)"
  "fcc-unlock|fcc-unlock/fcc-unlock-setup.sh|run-sudo|modemmanager usbutils|Auto-activate a WWAN modem's FCC unlock via ModemManager"
)

# --- helpers ------------------------------------------------------------------

field() { echo "$1" | cut -d'|' -f"$2"; }

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

# collect missing pacman deps across a list of manifest entries
collect_missing_deps() {
    local entries=("$@")
    local missing=""
    for e in "${entries[@]}"; do
        local deps; deps=$(field "$e" 4)
        [ -z "$deps" ] && continue   # no deps for this item
        for d in $deps; do
            if ! pkg_installed "$d"; then
                case " $missing " in *" $d "*) ;; *) missing="$missing $d";; esac
            fi
        done
    done
    echo "$missing"
}

post_note() {
    # per-item manual follow-up shown after install
    case "$1" in
        gromit-toggle)
            echo "  • Bind a hotkey: Settings → Keyboard → Application Shortcuts"
            echo "    Command: $BIN_DIR/gromit-toggle.sh   (e.g. Super+Home)"
            echo "  • gromit-mpx itself is in the AUR: yay -S gromit-mpx"
            ;;
        gromit-config)
            echo "  • Restart gromit-mpx to load the config."
            ;;
        crypto-tray)
            echo "  • Add a Generic Monitor to the panel:"
            echo "    Command: $BIN_DIR/crypto-tray.sh   Period: 60"
            echo "  • Edit coins via the crypto-config GUI, or by hand in"
            echo "    ~/.config/crypto-tray.conf"
            ;;
        crypto-config)
            echo "  • Run it to pick coins via a GUI: crypto-config.sh"
            echo "    (launch from rofi, a keyboard shortcut, or a terminal)"
            echo "  • Needs ~/.local/bin on PATH to call it by name — add to"
            echo "    ~/.profile if rofi can't find it."
            ;;
        fng-tray)
            echo "  • Add a second Generic Monitor:"
            echo "    Command: $BIN_DIR/fng-tray.sh   Period: 3600"
            ;;
        fcc-unlock)
            echo "  • This one is a one-shot, not a copied script. Run it with:"
            echo "    sudo $SCRIPTS_DIR/fcc-unlock/fcc-unlock-setup.sh --dry-run"
            echo "    then without --dry-run to apply."
            ;;
    esac
}

install_item() {
    local entry="$1"
    local key path dest
    key=$(field "$entry" 1)
    path=$(field "$entry" 2)
    dest=$(field "$entry" 3)
    local src="$SCRIPTS_DIR/$path"

    if [ ! -f "$src" ]; then
        echo "  ${RED}!${RST} $key: source not found ($src), skipping"
        return 1
    fi

    case "$dest" in
        bin)
            mkdir -p "$BIN_DIR"
            cp "$src" "$BIN_DIR/"
            chmod +x "$BIN_DIR/$(basename "$src")"
            echo "  ${GRN}✓${RST} $key → $BIN_DIR/$(basename "$src")"
            ;;
        config)
            mkdir -p "$CFG_DIR"
            # strip a trailing ".example" so foo.cfg.example -> foo.cfg
            local base; base=$(basename "$src"); base=${base%.example}
            cp "$src" "$CFG_DIR/$base"
            echo "  ${GRN}✓${RST} $key → $CFG_DIR/$base"
            ;;
        run-sudo)
            echo "  ${CYN}↪${RST} $key is a one-shot — not copied (see notes below)"
            ;;
    esac
}

# --- menu ---------------------------------------------------------------------

echo
echo "${B}xfce-convertible-scripts installer${RST}"
echo "${DIM}Repo: $REPO_DIR${RST}"
echo
echo "Available components:"
echo

i=0
declare -a KEYS
for e in "${MANIFEST[@]}"; do
    i=$((i+1))
    KEYS[$i]="$e"
    key=$(field "$e" 1)
    desc=$(field "$e" 5)
    printf "  ${B}%2d${RST}) ${CYN}%-14s${RST} %s\n" "$i" "$key" "$desc"
done
echo
echo "  ${B} a${RST}) all of the above"
echo "  ${B} q${RST}) quit"
echo
printf "Select items (e.g. ${B}1 3 4${RST}, or ${B}a${RST}): "
read -r choice

# normalise selection into a list of manifest entries
declare -a SELECTED
case "$choice" in
    q|Q|"") echo "Nothing to do."; exit 0 ;;
    a|A|all)
        SELECTED=("${MANIFEST[@]}")
        ;;
    *)
        for n in $choice; do
            if [[ "$n" =~ ^[0-9]+$ ]] && [ -n "${KEYS[$n]:-}" ]; then
                SELECTED+=("${KEYS[$n]}")
            else
                echo "${YEL}Ignoring invalid choice: $n${RST}"
            fi
        done
        ;;
esac

[ "${#SELECTED[@]}" -eq 0 ] && { echo "Nothing selected."; exit 0; }

# --- dependency check ---------------------------------------------------------
echo
missing=$(collect_missing_deps "${SELECTED[@]}")
if [ -n "$missing" ]; then
    echo "${YEL}Missing packages:${RST}$missing"
    printf "Install them now with pacman? [Y/n] "
    read -r yn
    case "$yn" in
        n|N) echo "Skipping dependency install — scripts may not work until installed." ;;
        *)
            # shellcheck disable=SC2086
            sudo pacman -S --needed $missing || {
                echo "${RED}pacman failed. Continuing, but install the packages manually.${RST}"
            }
            ;;
    esac
else
    echo "${GRN}All dependencies already present.${RST}"
fi

# --- install ------------------------------------------------------------------
echo
echo "${B}Installing:${RST}"
for e in "${SELECTED[@]}"; do
    install_item "$e"
done

# --- follow-up notes ----------------------------------------------------------
echo
echo "${B}Next steps:${RST}"
for e in "${SELECTED[@]}"; do
    key=$(field "$e" 1)
    note=$(post_note "$key")
    if [ -n "$note" ]; then
        echo "${CYN}$key:${RST}"
        echo "$note"
    fi
done

# PATH reminder for ~/.local/bin
echo
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "${YEL}Note:${RST} $BIN_DIR is not on your PATH. Add it in ~/.profile or shell rc if you want to call the scripts by name." ;;
esac

echo
echo "${GRN}Done.${RST}"
