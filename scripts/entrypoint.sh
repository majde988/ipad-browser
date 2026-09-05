#!/usr/bin/env bash
# يعمل كـ root لمرة واحدة عند الإقلاع، ثم يسلّم التحكم لـ supervisord
set -euo pipefail
log() { printf '\033[1;34m[entrypoint]\033[0m %s\n' "$*"; }

# المنطقة الزمنية
if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
fi

# مجلدات وقت التشغيل + إصلاح ملكية الـ Volumes (تُنشأ كـ root افتراضياً)
mkdir -p "$APP_HOME/Downloads" "$APP_HOME/.config/BraveSoftware" /tmp/brave-cache \
         /run/clouddesk/api /run/clouddesk/cmd
chown -R "$APP_USER:$APP_USER" "$APP_HOME/Downloads" "$APP_HOME/.config/BraveSoftware" \
                              /tmp/brave-cache /run/clouddesk

# تنظيف بقايا انهيار سابق (وإلا يرفض Brave / Xvfb الإقلاع)
find "$APP_HOME/.config/BraveSoftware" -maxdepth 2 -name 'Singleton*' -delete 2>/dev/null || true
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true

# نمط الوصول
if [ -n "${VNC_PASSWORD:-}" ]; then
  gosu "$APP_USER" x11vnc -storepasswd "$VNC_PASSWORD" /run/clouddesk/vncpasswd >/dev/null 2>&1
  unset VNC_PASSWORD
  log "🔐 auth: VNC password"
elif [ -n "${ACCESS_TOKEN:-}" ]; then
  log "🔑 auth: URL token (zero-typing mode)"
else
  log "🔓 auth: NONE — open mode (anyone with the URL gets the desktop)"
fi

# خلفية مخصصة اختيارية
if [ -n "${WALLPAPER_URL:-}" ]; then
  if curl -fsSL "$WALLPAPER_URL" -o "$APP_HOME/wallpaper.jpg"; then
    chown "$APP_USER" "$APP_HOME/wallpaper.jpg"; log "🖼️  wallpaper downloaded"
  else
    log "wallpaper download failed, using default"
  fi
fi

# استعادة الحالة من التخزين السحابي (إن كان مضبوطاً)
gosu "$APP_USER" env HOME="$APP_HOME" /usr/local/bin/statesync.sh restore || log "state restore skipped"

log "🖥️  Screen ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH} | port ${PORT:-$NOVNC_PORT} | user ${APP_USER}"
exec "$@"
