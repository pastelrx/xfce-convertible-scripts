#!/bin/bash
#
# crypto-config.sh
#
# Small GUI to choose which coins crypto-tray.sh shows, without editing the
# script. Writes ~/.config/crypto-tray.conf, which crypto-tray.sh reads.
#
# Launch it from a terminal, from a menu, or bind it to a click on the crypto
# panel monitor (genmon "command on click").
#
# Requires: yad (zenity can't combine checkboxes + text fields in one window).
#   sudo pacman -S yad
#
# How it works:
#   - A preset list of popular coins is shown as checkboxes (for the tooltip).
#   - A free-text field lets you add any other tickers not in the preset.
#   - A second field sets the (usually short) list of panel coins.
#   - On Save, it writes the conf file and refreshes the panel.

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/crypto-tray.conf"

# Preset coins offered as checkboxes. Edit this list to change what's offered.
PRESET=(BTC ETH SOL XRP DOGE LTC ADA DOT)

# --- load current values (if the conf exists) --------------------------------
PANEL_COINS="BTC ETH"
TOOLTIP_COINS="BTC ETH SOL XRP DOGE LTC"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

# Make a lookup of currently-enabled tooltip coins so we can pre-tick boxes.
declare -A ENABLED
for c in $TOOLTIP_COINS; do ENABLED["$c"]=1; done

# Custom coins = tooltip coins that aren't in the preset (so they survive a
# round-trip through the GUI via the free-text field).
custom=""
for c in $TOOLTIP_COINS; do
    in_preset=0
    for p in "${PRESET[@]}"; do [ "$c" = "$p" ] && in_preset=1 && break; done
    [ "$in_preset" -eq 0 ] && custom="$custom $c"
done
custom="${custom# }"

# --- check yad is available --------------------------------------------------
if ! command -v yad >/dev/null 2>&1; then
    # fall back to a plain message if yad isn't installed
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --text="This config GUI needs 'yad'.\nInstall it with:  sudo pacman -S yad"
    else
        echo "This config GUI needs 'yad'. Install: sudo pacman -S yad" >&2
    fi
    exit 1
fi

# --- build yad --form fields -------------------------------------------------
# One CHK field per preset coin, then two text fields. yad --form returns the
# field values separated by '|' in the order declared.
fields=()
for c in "${PRESET[@]}"; do
    state="FALSE"
    [ "${ENABLED[$c]:-}" = "1" ] && state="TRUE"
    fields+=(--field="$c:CHK" "$state")
done
fields+=(--field="Add custom (space-separated):" "$custom")
fields+=(--field="Panel coins:" "$PANEL_COINS")

out=$(yad --form \
    --title="Crypto Tray — coins" \
    --text="Tick coins to show in the tooltip.\nAdd others in the custom field. Panel coins is the short row in the panel itself." \
    --width=320 \
    --separator="|" \
    --button="Cancel:1" \
    --button="Save:0" \
    "${fields[@]}")

# user cancelled or closed the window
[ $? -ne 0 ] && exit 0

# --- parse yad output --------------------------------------------------------
# Split the '|'-separated values into an array, in declaration order:
#   [0 .. N-1] = preset checkbox states (TRUE/FALSE)
#   [N]        = custom text
#   [N+1]      = panel coins text
IFS='|' read -r -a vals <<< "$out"

n=${#PRESET[@]}
new_tooltip=""
for i in "${!PRESET[@]}"; do
    if [ "${vals[$i]}" = "TRUE" ]; then
        new_tooltip="$new_tooltip ${PRESET[$i]}"
    fi
done

custom_in="${vals[$n]}"
panel_in="${vals[$((n+1))]}"

# append custom coins (uppercased, de-spaced)
for c in $custom_in; do
    new_tooltip="$new_tooltip $(echo "$c" | tr '[:lower:]' '[:upper:]')"
done
new_tooltip="${new_tooltip# }"

# normalise panel coins (uppercase)
panel_norm=""
for c in $panel_in; do
    panel_norm="$panel_norm $(echo "$c" | tr '[:lower:]' '[:upper:]')"
done
panel_norm="${panel_norm# }"

# sensible fallbacks if somehow empty
[ -z "$new_tooltip" ] && new_tooltip="BTC"
[ -z "$panel_norm" ]  && panel_norm="BTC"

# --- write the conf ----------------------------------------------------------
mkdir -p "$(dirname "$CONF")"
cat > "$CONF" << EOF
# Managed by crypto-config. Edit here or re-run the GUI.
PANEL_COINS="$panel_norm"
TOOLTIP_COINS="$new_tooltip"
EOF

# --- refresh the panel so changes show immediately ---------------------------
# genmon doesn't expose a direct "refresh", but restarting the panel reloads
# all plugins. This is the reliable way to make the new coins appear at once.
if command -v xfce4-panel >/dev/null 2>&1; then
    xfce4-panel --restart 2>/dev/null &
fi

exit 0
