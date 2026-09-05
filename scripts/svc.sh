#!/usr/bin/env bash
# استخدام: svc.sh {xvfb|fluxbox|x11vnc|websockify|brave}
set -euo pipefail

wait_for_x() {
  for _ in $(seq 1 100); do xset q >/dev/null 2>&1 && return 0; sleep 0.2; done
  echo "X server not ready" >&2; return 1
}

case "${1:-}" in
  xvfb)
    # -fbdir: الـ framebuffer يصبح ملفاً ممسوحاً (mmap) بدل ذاكرة مجهولة → صفحاته قابلة للإخلاء للقرص
    mkdir -p /tmp/xvfb-fb
    exec Xvfb "$DISPLAY" -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}" \
         -fbdir /tmp/xvfb-fb -nolisten tcp -dpi 96 +extension RANDR
    ;;

  fluxbox)
    wait_for_x
    ( sleep 2
      if [ -s "$HOME/wallpaper.jpg" ]; then feh --no-fehbg --bg-fill "$HOME/wallpaper.jpg"
      else xsetroot -solid '#0b3d91'; fi ) &
    exec fluxbox
    ;;

    x11vnc)
    wait_for_x
    args=(-display "$DISPLAY" -forever -shared -localhost -rfbport "$VNC_PORT"
          -xkb -noxrecord -nobell -wait 20 -defer 20 -noxdamage -q)
    if [ "${ENABLE_CLIPBOARD}" != "true" ]; then args+=(-noclipboard -nosel); fi
    if [ -s /run/clouddesk/vncpasswd ]; then args+=(-rfbauth /run/clouddesk/vncpasswd)
    else args+=(-nopw); fi
    exec x11vnc "${args[@]}"
    ;;

  websockify)
    LISTEN_PORT="${PORT:-$NOVNC_PORT}"     # Render يفرض المنفذ عبر $PORT
    args=(--web /usr/share/novnc --heartbeat 15)
    if [ -n "${WEB_USER}" ] && [ -n "${WEB_PASSWORD}" ]; then
      args+=(--auth-plugin BasicHTTPAuth --auth-source "${WEB_USER}:${WEB_PASSWORD}")
    fi
    if [ -n "${ACCESS_TOKEN}" ]; then
      # وضع "مفتاح في الرابط": قناة VNC تُفتح فقط لمن يحمل الرمز، بلا أي كتابة على الجهاز
      printf '%s: 127.0.0.1:%s\n' "$ACCESS_TOKEN" "$VNC_PORT" > /run/clouddesk/tokens
      chmod 600 /run/clouddesk/tokens
      echo "[svc] access token ENABLED → open: /vnc_auto.html?path=websockify%3Ftoken%3D${ACCESS_TOKEN}"
      exec websockify "${args[@]}" --token-plugin TokenFile --token-source /run/clouddesk/tokens \
           "0.0.0.0:${LISTEN_PORT}"
    fi
    echo "[svc] ⚠️  OPEN MODE: no VNC password, no token — anyone with the URL gets the desktop"
    exec websockify "${args[@]}" "0.0.0.0:${LISTEN_PORT}" "127.0.0.1:${VNC_PORT}"
    ;;

  brave)
    wait_for_x
    rm -f "$HOME/.config/BraveSoftware/Brave-Browser"/Singleton* 2>/dev/null || true
    feats=""; [ "${BRAVE_DARK}" = "true" ] && feats="WebContentsForceDark"
    args=(
      --no-sandbox --disable-gpu --in-process-gpu --disable-software-rasterizer
      --disable-dev-shm-usage
      --no-first-run --no-default-browser-check --password-store=basic
      --disable-crash-reporter --disable-breakpad --disable-background-networking
      --disable-component-update --disable-extensions --disable-sync
      --lang="${BRAVE_LANG}"
      --enable-low-end-device-mode
      --renderer-process-limit=1 --process-per-site --disable-site-isolation-trials
      --js-flags="--max-old-space-size=${BRAVE_HEAP_MB} --optimize-for-size --gc-global"
      --disable-features=BraveRewards,BraveNews,BraveWallet,BraveSync,BraveVPN,Translate,BackForwardCache
      --disk-cache-dir=/tmp/brave-cache --disk-cache-size=$(( BRAVE_CACHE_MB * 1024 * 1024 ))
      --media-cache-size=$(( BRAVE_CACHE_MB * 1024 * 1024 / 2 ))
      --aggressive-cache-discard
      --restore-last-session --hide-crash-restore-bubble
      --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1
      --window-position=0,0 --window-size="${SCREEN_WIDTH},${SCREEN_HEIGHT}" --start-maximized
    )
    [ -n "$feats" ] && args+=(--enable-features="$feats")
    [ "${BRAVE_DARK}" = "true" ] && args+=(--force-dark-mode)
    exec dbus-launch --exit-with-session brave-browser "${args[@]}" "${START_URL}"
    ;;

  *) echo "usage: $0 {xvfb|fluxbox|x11vnc|websockify|brave}" >&2; exit 1 ;;
esac
