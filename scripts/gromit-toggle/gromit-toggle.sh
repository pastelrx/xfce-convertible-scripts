#!/bin/bash
#
# gromit-toggle.sh
#
# Smart launcher / toggle for Gromit-MPX (on-screen annotation tool).
#
# - If Gromit-MPX is not running, start it in active (drawing) mode.
# - If it is already running, toggle drawing on/off.
#
# Bind this to a hotkey (e.g. Super+Home) instead of calling gromit-mpx
# directly, so repeated key presses don't spawn multiple instances.
#
# Usage:
#   ./gromit-toggle.sh
#
# Requires: gromit-mpx

if pgrep -x gromit-mpx >/dev/null; then
    # already running -> toggle drawing mode
    gromit-mpx --toggle
else
    # not running -> launch and activate immediately
    gromit-mpx --active
fi
