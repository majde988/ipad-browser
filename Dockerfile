FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 1. تثبيت المستودع الرسمي لـ Brave Browser
RUN apt-get update && apt-get install -y curl gnupg && \
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# 2. تثبيت الحزم الأساسية: Brave Browser، محرر Geany، مدير الملفات، التيرمينال، أدوات النظام والخطوط
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    brave-browser \
    geany \
    geany-plugins \
    pcmanfm \
    lxterminal \
    dbus-x11 \
    supervisor \
    procps \
    feh \
    fonts-liberation \
    fonts-kacst \
    fonts-dejavu-core \
    locales \
    python3 \
    tar \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# 3. تحميل noVNC v0.6.2 المتوافقة مع iOS 9
RUN rm -rf /usr/share/novnc && mkdir -p /usr/share/novnc && \
    curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v0.6.2.tar.gz | tar -xz --strip-components=1 -C /usr/share/novnc

# 4. المجلدات والخلفية وربط التنزيلات بـ noVNC
RUN mkdir -p /root/Desktop /root/Downloads /tmp/brave-cache /root/.config/BraveSoftware /root/.fluxbox /var/log/supervisor /var/run && \
    ln -s /root/Downloads /usr/share/novnc/downloads && \
    curl -sL "https://wallpaperaccess.com/full/764827.jpg" -o /root/wallpaper.jpg || \
    curl -sL "https://i.imgur.com/S9Mj5u9.jpg" -o /root/wallpaper.jpg || true

# 5. اختصارات سطح المكتب لـ Brave والأدوات
RUN echo 'Control Mod1 e :Exec geany\n\
Control Mod1 t :Exec lxterminal\n\
Control Mod1 f :Exec pcmanfm /root/Desktop\n\
Control Mod1 b :Exec brave-browser --no-sandbox "https://www.google.com"\n\
Control Mod1 d :ShowDesktop\n\
Mod1 F4 :Close' > /root/.fluxbox/keys && \
    echo '[begin] (Menu)\n\
[exec] (Notepad++ / Geany) {geany}\n\
[exec] (File Manager) {pcmanfm /root/Desktop}\n\
[exec] (Terminal) {lxterminal}\n\
[exec] (Brave Shields Browser) {brave-browser --no-sandbox "https://www.google.com"}\n\
[separator]\n\
[restart] (Restart Desktop)\n\
[end]' > /root/.fluxbox/menu

# 6. حقن لوحة التحكم ومحاكي النقر البشري
RUN cat << 'EOF' > /usr/share/novnc/keyboard_addon.html
<style>
  #kbd-toggle { position: fixed; bottom: 8px; right: 8px; z-index: 99999; background: #007aff; color: #fff; border: none; padding: 7px 13px; border-radius: 20px; font-weight: bold; font-size: 13px; box-shadow: 0 4px 10px rgba(0,0,0,0.6); cursor: pointer; }
  #virtual-keyboard { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(18,18,18,0.97); z-index: 99998; padding: 5px 3px; box-sizing: border-box; border-top: 2px solid #007aff; display: flex; flex-direction: column; gap: 3px; }
  .kbd-row { display: flex; justify-content: center; gap: 3px; overflow-x: auto; padding-bottom: 1px; }
  .k-btn { background: #2c2c2c; color: #fff; border: 1px solid #444; border-radius: 4px; padding: 5px 7px; font-size: 12px; font-family: monospace; font-weight: bold; cursor: pointer; min-width: 28px; white-space: nowrap; }
  .k-btn:active { background: #007aff; border-color: #fff; }
  .k-bot { background: #6c3483; border-color: #8e44ad; color: #f5eef8; }
  .k-brave { background: #d35400; border-color: #e67e22; color: #fff; }
  .k-app { background: #1a5276; border-color: #2980b9; color: #5dade2; }
  .k-action { background: #005bb5; border-color: #007aff; }
  .k-green { background: #1e8449; border-color: #27ae60; color: #a9dfbf; }
  .k-red { background: #922b21; border-color: #c0392b; color: #f5b7b1; }
  .k-spec { background: #3d3d3d; }
</style>

<button id="kbd-toggle" onclick="toggleKbd()">🎛️ مركز التحكم</button>

<div id="virtual-keyboard">
  <div class="kbd-row">
    <button class="k-btn k-bot" id="humanBtn" onclick="toggleHumanMode()">🖱️ نقر بشري (Anti-Bot): OFF</button>
    <button class="k-btn k-green" onclick="window.open('/downloads/', '_blank')">📥 التنزيلات</button>
    <button class="k-btn k-action" onclick="pressK(0xff55)">📜 Scroll ⬆️</button>
    <button class="k-btn k-action" onclick="pressK(0xff56)">📜 Scroll ⬇️</button>
  </div>
  <div class="kbd-row">
    <button class="k-btn k-brave" onclick="sendCombo([0xffe3, 0xffe9, 0x0062])">🦁 Brave Shields</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0066])">📁 سطح المكتب</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0074])">💻 التيرمينال</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0065])">📝 Notepad++</button>
    <button class="k-btn k-spec" onclick="sendCombo([0xffe3, 0xffe9, 0x0064])">🪟 إخفاء الكل</button>
    <button class="k-btn k-red" onclick="sendCombo([0xffe9, 0xffc1])">❌ غلق نافذة</button>
  </div>
  <div class="kbd-row">
    <button class="k-btn k-green" onclick="sendCombo([0xffe3, 0x0073])">💾 Save</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0074])">+ Tab</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0077])">✕ Tab</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0072])">🔄 Reload</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x006c])">🔍 URL</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0063])">📋 Copy</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0076])">📌 Paste</button>
  </div>
  <div class="kbd-row">
    <button class="k-btn k-spec" onclick="pressK(0xff1b)">Esc</button>
    <button class="k-btn k-spec" onclick="pressK(0xff09)">Tab</button>
    <button class="k-btn k-spec" onclick="pressK(0xffe3)">Ctrl</button>
    <button class="k-btn k-spec" onclick="pressK(0xffe9)">Alt</button>
    <button class="k-btn k-spec" onclick="pressK(0xff08)">Bksp</button>
    <button class="k-btn k-spec" onclick="pressK(0xffff)">Del</button>
    <button class="k-btn k-action" onclick="pressK(0xff0d)">Enter ↵</button>
    <button class="k-btn k-action" onclick="pressK(0xff51)">⬅️</button>
    <button class="k-btn k-action" onclick="pressK(0xff52)">⬆️</button>
    <button class="k-btn k-action" onclick="pressK(0xff54)">⬇️</button>
    <button class="k-btn k-action" onclick="pressK(0xff53)">➡️</button>
  </div>
</div>

<script>
  var humanMode = false;
  var lastX = 512, lastY = 384;

  function toggleKbd() {
    var k = document.getElementById('virtual-keyboard');
    k.style.display = (k.style.display === 'none') ? 'flex' : 'none';
  }
  function toggleHumanMode() {
    humanMode = !humanMode;
    var btn = document.getElementById('humanBtn');
    btn.innerText = humanMode ? '🖱️ نقر بشري (Anti-Bot): ON' : '🖱️ نقر بشري (Anti-Bot): OFF';
    btn.style.background = humanMode ? '#28a745' : '#6c3483';
  }
  function pressK(keysym) {
    if (window.UI && window.UI.rfb) {
      window.UI.rfb.sendKey(keysym, 1);
      setTimeout(function(){ window.UI.rfb.sendKey(keysym, 0); }, 50);
    }
  }
  function sendCombo(keysyms) {
    if (window.UI && window.UI.rfb) {
      for (var i = 0; i < keysyms.length; i++) {
        window.UI.rfb.sendKey(keysyms[i], 1);
      }
      setTimeout(function(){
        for (var i = keysyms.length - 1; i >= 0; i--) {
          window.UI.rfb.sendKey(keysyms[i], 0);
        }
      }, 70);
    }
  }
  function humanMoveAndClick(targetX, targetY) {
    if (!window.UI || !window.UI.rfb) return;
    var rfb = window.UI.rfb;
    var startX = lastX, startY = lastY;
    var steps = 10, cur = 0;
    var midX = (startX + targetX) / 2 + (Math.random() * 60 - 30);
    var midY = (startY + targetY) / 2 + (Math.random() * 60 - 30);

    var timer = setInterval(function() {
      cur++;
      var t = cur / steps;
      var x = Math.round((1 - t) * (1 - t) * startX + 2 * (1 - t) * t * midX + t * t * targetX);
      var y = Math.round((1 - t) * (1 - t) * startY + 2 * (1 - t) * t * midY + t * t * targetY);
      rfb.sendPointerEvent(x, y, 0);

      if (cur >= steps) {
        clearInterval(timer);
        lastX = targetX;
        lastY = targetY;
        rfb.sendPointerEvent(targetX, targetY, 1);
        setTimeout(function() {
          rfb.sendPointerEvent(targetX, targetY, 0);
        }, 80 + Math.floor(Math.random() * 40));
      }
    }, 15);
  }
  document.addEventListener('click', function(e) {
    if (humanMode && window.UI && window.UI.rfb) {
      var canvas = document.getElementsByTagName('canvas')[0];
      if (canvas && e.target === canvas) {
        e.stopPropagation();
        var rect = canvas.getBoundingClientRect();
        var scaleX = canvas.width / rect.width;
        var scaleY = canvas.height / rect.height;
        var x = Math.round((e.clientX - rect.left) * scaleX);
        var y = Math.round((e.clientY - rect.top) * scaleY);
        humanMoveAndClick(x, y);
      }
    }
  }, true);
</script>
EOF

RUN sed -i '/<\/body>/e cat /usr/share/novnc/keyboard_addon.html' /usr/share/novnc/vnc.html && \
    sed -i '/<\/body>/e cat /usr/share/novnc/keyboard_addon.html' /usr/share/novnc/vnc_auto.html

# 7. تشغيل Supervisord: صلحنا أمر x11vnc بـ -nohttp الصافي
RUN cat << 'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
user=root
logfile=/dev/stdout
logfile_maxbytes=0
pidfile=/var/run/supervisord.pid

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[program:xvfb]
command=Xvfb :0 -screen 0 1024x768x16
priority=10
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:wallpaper]
command=sh -c "sleep 2 && feh --bg-scale /root/wallpaper.jpg"
priority=15
autorestart=false
startretries=1
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:fluxbox]
command=fluxbox
environment=DISPLAY=":0"
priority=20
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:x11vnc]
command=x11vnc -display :0 -nopw -forever -shared -localhost -rfbport 5900 -nohttp -noclipboard -nosel -wait 20 -defer 20
priority=30
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:websockify]
command=websockify --web /usr/share/novnc --heartbeat 15 10000 127.0.0.1:5900
priority=35
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:brave]
command=brave-browser --no-sandbox --disable-gpu --disable-dev-shm-usage --force-dark-mode --enable-features=WebContentsForceDark --disable-features=BraveRewards,BraveNews,BraveWallet,BraveSync --disk-cache-dir=/tmp/brave-cache --disk-cache-size=209715200 --js-flags="--max-old-space-size=150 --optimize-for-size" --renderer-process-limit=1 --window-size=1024,768 --start-maximized "https://www.google.com"
environment=DISPLAY=":0",HOME="/root"
priority=50
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

EXPOSE 10000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
