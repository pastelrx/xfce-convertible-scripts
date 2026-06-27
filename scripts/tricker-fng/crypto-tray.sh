#!/bin/bash
#
# crypto-genmon.sh
#
# Crypto prices in the XFCE panel via xfce4-genmon-plugin.
#   - Panel: LABEL + price only (clean, easy to scan), coloured by 24h change.
#   - Tooltip (on hover): a wider watchlist WITH 24h percentages, for spotting
#     which coins are moving when something kicks off.
#
# Price size is chosen automatically by magnitude:
#   >= 1000  -> "$59.8k"      (BTC, ETH)
#   >= 1     -> "$140"        (SOL, LTC)
#   < 1      -> "$0.162"      (DOGE, XRP, ...)
#
# ---- CONFIG ----------------------------------------------------------------
# Coins are read from ~/.config/crypto-tray.conf if it exists (managed by the
# crypto-config GUI). The values below are just defaults used when no config
# file is present yet.
#
#   PANEL_COINS   — shown in the panel (compact, no percentages)
#   TOOLTIP_COINS — shown in the hover tooltip (with 24h %)
#
# Bare tickers separated by spaces; the script appends USDT and queries Binance.
#
PANEL_COINS="BTC ETH"
TOOLTIP_COINS="BTC ETH SOL XRP DOGE LTC"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/crypto-tray.conf"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"
# ----------------------------------------------------------------------------
#
# Setup:
#   sudo pacman -S xfce4-genmon-plugin curl
#   cp crypto-genmon.sh ~/.local/bin/ && chmod +x ~/.local/bin/crypto-genmon.sh
#   Add a "Generic Monitor" to the panel:
#     Command: /home/<you>/.local/bin/crypto-genmon.sh
#     Period (s): 60
#
# Source: Binance public API (no key). All coins fetched in one request.

GREEN="#98c379"
RED="#e06c75"

# --- build the URL-encoded symbols list from the union of both coin sets -----
# We fetch every coin that appears in either list, once.
declare -A WANT
for c in $PANEL_COINS $TOOLTIP_COINS; do WANT["$c"]=1; done

symbols=""
for c in "${!WANT[@]}"; do
    [ -n "$symbols" ] && symbols="$symbols,"
    symbols="$symbols%22${c}USDT%22"
done
API="https://api.binance.com/api/v3/ticker/24hr?symbols=%5B${symbols}%5D"

data=$(curl -s --max-time 8 "$API")
if [ -z "$data" ]; then
    echo "<txt>crypto —</txt>"
    echo "<tool>No connection</tool>"
    exit 0
fi

# --- helpers ----------------------------------------------------------------

# Isolate one coin's JSON object and echo "price pct".
get_coin() {
    local sym="$1USDT"
    local obj
    obj=$(echo "$data" | grep -o "{[^}]*\"symbol\":\"$sym\"[^}]*}")
    [ -z "$obj" ] && return 1
    local price pct
    price=$(echo "$obj" | grep -o '"lastPrice":"[0-9.]*"'           | sed 's/.*:"//; s/"//')
    pct=$(echo "$obj"   | grep -o '"priceChangePercent":"[-0-9.]*"' | sed 's/.*:"//; s/"//')
    [ -z "$price" ] || [ -z "$pct" ] && return 1
    echo "$price $pct"
}

# Format a price by magnitude (see header). Used for the COMPACT PANEL text.
fmt_price() {
    awk -v p="$1" 'BEGIN {
        if (p >= 1000)      printf "$%.1fk", p/1000;
        else if (p >= 1)    printf "$%.0f", p;
        else                printf "$%.3f", p;
    }'
}

# Format a price for the TOOLTIP, where there's room for full precision:
#   >= 1000  -> whole dollars with thousands separators   "$60,123"
#   1 .. 999 -> two decimals                              "$72.22"  "$1.11"
#   < 1      -> three decimals (small coins keep detail)  "$0.076"
# The thousands grouping is done manually so it works regardless of locale.
fmt_tooltip() {
    awk -v p="$1" 'BEGIN {
        if (p >= 1000) {
            # round to whole dollars, then insert commas every 3 digits
            n = sprintf("%.0f", p);
            len = length(n);
            out = "";
            for (i = 1; i <= len; i++) {
                out = out substr(n, i, 1);
                rem = len - i;            # digits still to the right
                if (rem > 0 && rem % 3 == 0) out = out ",";
            }
            printf "$%s", out;
        } else if (p >= 1) {
            printf "$%.2f", p;
        } else {
            printf "$%.3f", p;
        }
    }'
}

color_for() {  # echoes a colour for a percent value
    awk -v c="$1" -v g="$GREEN" -v r="$RED" 'BEGIN { print (c < 0) ? r : g }'
}

# --- panel text: label + price, coloured, no percentages --------------------
panel=""
for c in $PANEL_COINS; do
    if out=$(get_coin "$c"); then
        read -r p pct <<< "$out"
        col=$(color_for "$pct")
        chunk=$(printf '<span foreground="%s">%s %s</span>' "$col" "$c" "$(fmt_price "$p")")
        [ -n "$panel" ] && panel="$panel  "
        panel="$panel$chunk"
    fi
done
[ -z "$panel" ] && panel="crypto —"

# --- tooltip: watchlist with percentages ------------------------------------
tip=""
for c in $TOOLTIP_COINS; do
    if out=$(get_coin "$c"); then
        read -r p pct <<< "$out"
        pct_fmt=$(awk -v c="$pct" 'BEGIN { printf "%+.1f", c }')
        line=$(printf '%-5s %-10s  24h %s%%' "$c" "$(fmt_tooltip "$p")" "$pct_fmt")
        [ -n "$tip" ] && tip="$tip
"
        tip="$tip$line"
    fi
done
[ -z "$tip" ] && tip="No data"

echo "<txt>$panel</txt>"
echo "<tool>$tip</tool>"
