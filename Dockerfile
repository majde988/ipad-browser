# syntax=docker/dockerfile:1
FROM debian:bullseye-slim

ARG NOVNC_VERSION=0.6.2
ARG APP_USER=desk
ARG APP_UID=1000

LABEL org.opencontainers.image.title="CloudDesk" \
      org.opencontainers.image.description="Browser-in-Container: Xvfb + Fluxbox + Brave via noVNC 0.6.2 (iOS 9 compatible), Render Free ready" \
      org.opencontainers.image.version="2.1"

# ── متغيرات قابلة للتعديل وقت التشغيل ─────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    TZ=Africa/Algiers \
    APP_USER=${APP_USER} APP_HOME=/home/${APP_USER} \
    DISPLAY=:0 \
    SCREEN_WIDTH=1024 SCREEN_HEIGHT=768 SCREEN_DEPTH=16 \
    NOVNC_PORT=10000 VNC_PORT=5900 \
    VNC_PASSWORD="" WEB_USER="" WEB_PASSWORD="" ACCESS_TOKEN="" \
    ENABLE_CLIPBOARD=false \
    START_URL="https://www.google.com" \
    BRAVE_LANG=ar BRAVE_HEAP_MB=128 BRAVE_CACHE_MB=200 BRAVE_DARK=true \
    WALLPAPER_URL="" \
    MALLOC_ARENA_MAX=2 \
    MEM_LIMIT_MB=512 MEMGUARD_SOFT=70 MEMGUARD_HARD=82 MEMGUARD_CRIT=92 \
    MEMGUARD_INTERVAL=3 MEMGUARD_COOLDOWN=20 \
    STATE_REMOTE="" STATE_SYNC_SEC=300

# ── 1. الحزم + مستودع Brave الرسمي ─────────────────────────────────
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xvfb x11-xserver-utils fluxbox x11vnc websockify brave-browser \
        geany geany-plugins pcmanfm lxterminal dbus-x11 \
        supervisor tini gosu procps feh xdotool bash \
        locales tzdata python3 python3-websocket rclone tar \
        fonts-liberation fonts-kacst fonts-noto-core fonts-dejavu-core fonts-noto-color-emoji; \
    sed -i 's/^# *\(ar_DZ.UTF-8\|en_US.UTF-8\)/\1/' /etc/locale.gen; locale-gen; \
    fc-cache -f; \
    apt-get clean; rm -rf /var/lib/apt/lists/*

# ── 2. noVNC (إصدار مثبَّت متوافق مع iOS 9) ─────────────────────────
RUN set -eux; mkdir -p /usr/share/novnc; \
    curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
      | tar -xz --strip-components=1 -C /usr/share/novnc; \
    rm -rf /usr/share/novnc/tests /usr/share/novnc/docs /usr/share/novnc/.github

# ── 3. مستخدم غير جذري + المجلدات + الخلفية ─────────────────────────
RUN set -eux; \
    useradd -m -u ${APP_UID} -s /bin/bash ${APP_USER}; \
    mkdir -p ${APP_HOME}/Desktop ${APP_HOME}/Downloads ${APP_HOME}/.fluxbox \
             ${APP_HOME}/.config/BraveSoftware /var/log/supervisor; \
    ln -s ${APP_HOME}/Downloads /usr/share/novnc/downloads; \
    ln -s /run/clouddesk/api /usr/share/novnc/api; \
    ( curl -fsSL "https://raw.githubusercontent.com/Bavfalcon9/Wallpapers/master/Windows%2010%20Hero.jpg" -o ${APP_HOME}/wallpaper.jpg \
   || curl -fsSL "https://archive.org/download/windows-10-hero-wallpaper/img0.jpg" -o ${APP_HOME}/wallpaper.jpg \
   || echo "wallpaper skipped" )

# ── 4. ملفات الإعداد والسكربتات ─────────────────────────────────────
COPY config/fluxbox/          ${APP_HOME}/.fluxbox/
COPY config/supervisord.conf  /etc/supervisor/supervisord.conf
COPY web/control_panel.html   /usr/share/novnc/control_panel.html
COPY scripts/                 /usr/local/bin/

RUN set -eux; chmod +x /usr/local/bin/*.sh /usr/local/bin/*.py; \
    for f in vnc.html vnc_auto.html; do \
      sed -i '/<\/body>/e cat /usr/share/novnc/control_panel.html' /usr/share/novnc/$f; \
    done; \
    chown -R ${APP_USER}:${APP_USER} ${APP_HOME} /var/log/supervisor

EXPOSE ${NOVNC_PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
