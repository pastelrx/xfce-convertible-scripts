#!/bin/bash
#
# fng-genmon.sh
#
# Crypto Fear & Greed index in the XFCE panel via xfce4-genmon-plugin.
# Shows "F&G <value>" coloured by zone, with the classification text in the
# tooltip. Kept separate from the price ticker so you can place a panel
# separator between them.
#
# Setup:
#   sudo pacman -S xfce4-genmon-plugin curl
#   cp fng-genmon.sh ~/.local/bin/ && chmod +x ~/.local/bin/fng-genmon.sh
#   Add a second "Generic Monitor" to the panel:
#     Command: /home/<you>/.local/bin/fng-genmon.sh
#     Period (s): 3600        # the index only updates a few times a day
#
# Source: alternative.me Fear & Greed API (no key).
#
# Attribution: alternative.me asks that their Fear & Greed data be displayed
# with attribution right next to it for commercial use. This script puts
# "Data from alternative.me" in the panel tooltip, next to the value.

API="https://api.alternative.me/fng/?limit=1"

data=$(curl -s --max-time 8 "$API")
if [ -z "$data" ]; then
    echo "<txt>F&amp;G —</txt>"
    echo "<tool>No connection</tool>"
    exit 0
fi

# Response looks like:
#   {"name":"Fear and Greed Index","data":[{"value":"54",
#    "value_classification":"Greed","timestamp":"...", ...}], ...}
# Note: the API pretty-prints with spaces after colons ("value": "54"), so the
# patterns allow optional whitespace.
value=$(echo "$data" | grep -o '"value":[[:space:]]*"[0-9]*"' | head -1 | sed 's/.*"\([0-9]*\)"$/\1/')
cls=$(echo "$data"   | grep -o '"value_classification":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')

if [ -z "$value" ]; then
    echo "<txt>F&amp;G —</txt>"
    echo "<tool>Parse error</tool>"
    exit 0
fi

# Colour by zone (0-100):
#   0-24  extreme fear   red
#   25-44 fear           orange
#   45-54 neutral        yellow
#   55-74 greed          light green
#   75-100 extreme greed green
if   [ "$value" -le 24 ]; then color="#e06c75"   # red
elif [ "$value" -le 44 ]; then color="#e5915b"   # orange
elif [ "$value" -le 54 ]; then color="#e5c07b"   # yellow
elif [ "$value" -le 74 ]; then color="#98c379"   # light green
else                           color="#7ec699"   # green
fi

# Panel: "F&G 54" coloured. (& must be escaped as &amp; in Pango markup.)
# The tooltip carries the attribution required by alternative.me for displaying
# their data ("Data from alternative.me", shown right next to the value).
echo "<txt><span foreground=\"$color\">F&amp;G $value</span></txt>"
echo "<tool>Fear &amp; Greed: $value — ${cls:-?}
Data from alternative.me</tool>"
