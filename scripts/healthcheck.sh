#!/usr/bin/env bash
set -euo pipefail
pgrep -x Xvfb   >/dev/null || exit 1
pgrep -x x11vnc >/dev/null || exit 1
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT:-${NOVNC_PORT:-10000}}/vnc.html")
[ "$code" = "200" ] || [ "$code" = "401" ] || exit 1
