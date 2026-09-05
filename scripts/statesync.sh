#!/usr/bin/env bash
# مزامنة حالة الجلسة مع تخزين سحابي مجاني عبر rclone (يُضبط بالكامل بمتغيرات بيئة، بلا ملف config)
set -uo pipefail
if [ -z "${STATE_REMOTE:-}" ]; then echo "[statesync] STATE_REMOTE not set → disabled"; exit 0; fi
P="$HOME/.config/BraveSoftware/Brave-Browser/Default"
INC=(--include 'Sessions/**' --include 'Bookmarks' --include 'Preferences' --include 'Cookies')

case "${1:-loop}" in
  restore)
    mkdir -p "$HOME/Downloads" "$P"
    rclone copy "$STATE_REMOTE/downloads" "$HOME/Downloads" -q
    rclone copy "$STATE_REMOTE/profile"   "$P" "${INC[@]}" -q
    echo "[statesync] state restored"
    ;;
  loop)
    while sleep "${STATE_SYNC_SEC:-300}"; do
      rclone sync "$HOME/Downloads" "$STATE_REMOTE/downloads" -q
      rclone copy "$P" "$STATE_REMOTE/profile" "${INC[@]}" -q
      echo "[statesync] synced $(date +%T)"
    done
    ;;
esac
