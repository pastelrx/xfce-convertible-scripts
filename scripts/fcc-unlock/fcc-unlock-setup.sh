#!/bin/bash
#
# fcc-unlock-setup.sh
#
# Detects WWAN modems and activates the matching vendor FCC-unlock script that
# ships with ModemManager, so the modem is automatically unlocked on every
# connection.
#
# Background: many laptop WWAN modems (Quectel, Sierra, Fibocom, Dell/HP rebrands)
# ship FCC-locked for US regulatory compliance and refuse to transmit until an
# unlock sequence is sent. ModemManager >= 1.18.4 includes vendor unlock scripts
# under /usr/share/ModemManager/fcc-unlock.available.d/ but ships them DISABLED.
# Enabling one is just a matter of symlinking it into the active directory
# /etc/ModemManager/fcc-unlock.d/ — but it has to be a symlink to the actual
# script file, not a copy or a directory, and it must be named after the modem's
# USB vendor:product ID (or bare vendor ID).
#
# This script automates the detection + symlinking so it works on any machine,
# not just one specific modem.
#
# Usage:
#   sudo ./fcc-unlock-setup.sh           detect and enable, then restart MM
#   sudo ./fcc-unlock-setup.sh --dry-run show what would happen, change nothing
#
# Requires: usbutils (lsusb), ModemManager. Run as root (writes to /etc).

set -u

AVAIL_DIR="/usr/share/ModemManager/fcc-unlock.available.d"
ACTIVE_DIR="/etc/ModemManager/fcc-unlock.d"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# --- sanity checks ------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must be run as root (it writes to $ACTIVE_DIR). Use sudo." >&2
    exit 1
fi

if [ ! -d "$AVAIL_DIR" ]; then
    echo "ERROR: $AVAIL_DIR not found." >&2
    echo "Your ModemManager may be too old (need >= 1.18.4) or built without" >&2
    echo "the bundled FCC-unlock scripts." >&2
    exit 1
fi

command -v lsusb >/dev/null 2>&1 || {
    echo "ERROR: lsusb not found. Install usbutils." >&2
    exit 1
}

# --- find candidate modem USB IDs ---------------------------------------------
# Parse lsusb's 6th field, which is the "vvvv:pppp" USB ID. lsusb lines look
# like:
#   Bus 003 Device 003: ID 2c7c:030a Quectel Wireless Solutions ...
#                          ^^^^^^^^^^ field 6
# (field 5 is the literal "ID", which is the off-by-one that bites naive
# read-based parsing.)
#
# For each ID we just check directly whether a script file exists in the
# available dir — first an exact vendor:product match, then a bare vendor
# match. No lookup table needed.

echo "Scanning USB devices for modems with available unlock scripts..."
echo

FOUND=0

# Feed lsusb output through a here-string to avoid running the loop body in a
# subshell (which would discard FOUND).
LSUSB_IDS=$(lsusb | awk '{print $6}')

while read -r id; do
    # skip blanks / malformed
    [[ "$id" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]] || continue

    vid=${id%%:*}
    pid=${id##*:}

    # decide which script name to use: prefer exact vendor:product, else vendor
    target=""
    if [ -e "$AVAIL_DIR/$vid:$pid" ]; then
        target="$vid:$pid"
    elif [ -e "$AVAIL_DIR/$vid" ]; then
        target="$vid"
    else
        # no unlock script for this device -> not a modem we handle
        continue
    fi

    echo "Modem found: $id"

    # resolve to the real underlying script (entries in available.d are often
    # symlinks pointing at the bare vendor file); link the active entry straight
    # to the real script so MM always has an executable target.
    real=$(readlink -f "$AVAIL_DIR/$target")
    link="$ACTIVE_DIR/$vid:$pid"

    echo "  script:  $target -> $real"
    echo "  linking: $link"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] no changes made"
        echo
        FOUND=1
        continue
    fi

    mkdir -p "$ACTIVE_DIR"

    # clean up anything wrong already sitting there (e.g. a stray directory)
    if [ -e "$link" ] || [ -L "$link" ]; then
        rm -rf "$link"
    fi

    ln -s "$real" "$link"
    echo "  done."
    echo
    FOUND=1
done <<< "$LSUSB_IDS"

if [ "$FOUND" -eq 0 ]; then
    echo "No modems with an available FCC-unlock script were found."
    echo "If you have a WWAN modem, check 'lsusb' and compare its vendor ID to:"
    echo "  ls $AVAIL_DIR"
    exit 0
fi

# --- restart ModemManager to apply --------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run complete. Re-run without --dry-run to apply."
    exit 0
fi

echo "Restarting ModemManager..."
systemctl restart ModemManager

echo
echo "Done. Check modem state with:"
echo "  mmcli -L"
echo "  mmcli -m 0"
echo
echo "The modem should no longer be FCC-locked. If state is still 'disabled',"
echo "enable it with: mmcli -m 0 --enable"
