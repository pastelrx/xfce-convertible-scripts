#!/bin/bash
#
# fng-tray.sh
#
# Crypto Fear & Greed index in the XFCE panel via xfce4-genmon-plugin.
# Shows "F&G <value>" coloured by zone, with the classification in the tooltip.
# Kept separate from the price ticker so you can put a panel separator between.
#
# Caching: the index only changes a few times a day, so hitting the API hourly
# is plenty. But genmon waits a full period before its FIRST run, so a long
# genmon period means a long blank gap after boot/login. Instead we set a SHORT
# genmon period and cache here: the script serves a cached value until it's
# older than CACHE_TTL, only then re-fetching. Net effect: it paints almost
# immediately after login (first genmon tick finds no fresh cache and fetches),
# then only really hits the network once an hour.
#
# Setup:
#   sudo pacman -S xfce4-genmon-plugin curl
#   cp fng-tray.sh ~/.local/bin/ && chmod +x ~/.local/bin/fng-tray.sh
#   Add a "Generic Monitor" to the panel:
#     Command: /home/<you>/.local/bin/fng-tray.sh
#     Period (s): 300      # short, so it paints soon after login; real API
#                          # calls are throttled to hourly by the cache below.
#
# Source: alternative.me Fear & Greed API (no key).
#
# Attribution: alternative.me asks that their Fear & Greed data be displayed
# with attribution right next to it. This script puts "Data from alternative.me"
# in the panel tooltip, next to the value. Keep it if you redistribute.

API="https://api.alternative.me/fng/?limit=1"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fng-tray"
CACHE_FILE="$CACHE_DIR/last.txt"
CACHE_TTL=3600        # seconds; re-fetch only when cache is older than this

mkdir -p "$CACHE_DIR"

# render <txt>/<tool> from a "value|classification" pair
render() {
    local value="$1" cls="$2"

    if   [ "$value" -le 24 ]; then color="#e06c75"   # red        extreme fear
    elif [ "$value" -le 44 ]; then color="#e5915b"   # orange     fear
    elif [ "$value" -le 54 ]; then color="#e5c07b"   # yellow     neutral
    elif [ "$value" -le 74 ]; then color="#98c379"   # lt green   greed
    else                           color="#7ec699"   # green      extreme greed
    fi

    # & must be escaped as &amp; in Pango markup.
    echo "<txt><span foreground=\"$color\">F&amp;G $value</span></txt>"
    echo "<tool>Fear &amp; Greed: $value — ${cls:-?}
Data from alternative.me</tool>"
}

# --- serve from cache if it's still fresh ------------------------------------
if [ -f "$CACHE_FILE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$age" -lt "$CACHE_TTL" ]; then
        IFS='|' read -r c_value c_cls < "$CACHE_FILE"
        if [ -n "$c_value" ]; then
            render "$c_value" "$c_cls"
            exit 0
        fi
    fi
fi

# --- cache stale or missing: fetch -------------------------------------------
data=$(curl -s --max-time 8 "$API")

if [ -z "$data" ]; then
    # network failed: fall back to stale cache if we have one, else placeholder
    if [ -f "$CACHE_FILE" ]; then
        IFS='|' read -r c_value c_cls < "$CACHE_FILE"
        [ -n "$c_value" ] && { render "$c_value" "$c_cls"; exit 0; }
    fi
    echo "<txt>F&amp;G —</txt>"
    echo "<tool>No connection</tool>"
    exit 0
fi

# Response (pretty-printed, spaces after colons):
#   {"data":[{"value": "54","value_classification": "Greed", ...}], ...}
value=$(echo "$data" | grep -o '"value":[[:space:]]*"[0-9]*"' | head -1 | sed 's/.*"\([0-9]*\)"$/\1/')
cls=$(echo "$data"   | grep -o '"value_classification":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')

if [ -z "$value" ]; then
    # parse failed: serve stale cache if available
    if [ -f "$CACHE_FILE" ]; then
        IFS='|' read -r c_value c_cls < "$CACHE_FILE"
        [ -n "$c_value" ] && { render "$c_value" "$c_cls"; exit 0; }
    fi
    echo "<txt>F&amp;G —</txt>"
    echo "<tool>Parse error</tool>"
    exit 0
fi

# success: update cache and render
echo "${value}|${cls}" > "$CACHE_FILE"
render "$value" "$cls"
