FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# تثبيت متصفح Chromium، محرر Geany، مستكشف الملفات pcmanfm، التيرمينال lxterminal، الخطوط وأدوات النظام
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    chromium \
    geany \
    geany-plugins \
    pcmanfm \
    lxterminal \
    supervisor \
    procps \
    git \
    fonts-liberation \
    fonts-kacst \
    fonts-dejavu-core \
    locales \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# تحميل نسخة noVNC الكلاسيكية ES5 المتوافقة مع iOS 9
RUN rm -rf /usr/share/novnc && \
    git clone --branch v0.6.2 --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc

RUN mkdir -p /root/Downloads /tmp/chromium-cache /root/.config/chromium /root/.fluxbox /var/log/supervisor

# إعداد اختصارات تشغيل البرامج عبر Fluxbox
RUN echo 'Control Mod1 e :Exec geany\n\
Control Mod1 t :Exec lxterminal\n\
Control Mod1 f :Exec pcmanfm /root\n\
Control Mod1 b :Exec chromium --no-sandbox\n\
Control Mod1 d :ShowDesktop\n\
Mod1 F4 :Close' > /root/.fluxbox/keys && \
    echo '[begin] (Menu)\n\
[exec] (Notepad++ / Geany) {geany}\n\
[exec] (File Manager) {pcmanfm /root}\n\
[exec] (Terminal) {lxterminal}\n\
[exec] (Chromium Browser) {chromium --no-sandbox}\n\
[separator]\n\
[restart] (Restart Desktop)\n\
[end]' > /root/.fluxbox/menu

# حقن لوحة التحكم وشريط المهام المتكامل داخل صفحة noVNC
RUN cat << 'EOF' > /usr/share/novnc/keyboard_addon.html
<style>
  #kbd-toggle { position: fixed; bottom: 8px; right: 8px; z-index: 99999; background: #007aff; color: #fff; border: none; padding: 7px 13px; border-radius: 20px; font-weight: bold; font-size: 13px; box-shadow: 0 4px 10px rgba(0,0,0,0.6); cursor: pointer; }
  #virtual-keyboard { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(18,18,18,0.96); z-index: 99998; padding: 5px 3px; box-sizing: border-box; border-top: 2px solid #007aff; display: flex; flex-direction: column; gap: 3px; }
  .kbd-row { display: flex; justify-content: center; gap: 3px; overflow-x: auto; padding-bottom: 1px; }
  .k-btn { background: #2c2c2c; color: #fff; border: 1px solid #444; border-radius: 4px; padding: 5px 7px; font-size: 12px; font-family: monospace; font-weight: bold; cursor: pointer; min-width: 28px; white-space: nowrap; }
  .k-btn:active { background: #007aff; border-color: #fff; }
  .k-app { background: #1a5276; border-color: #2980b9; color: #5dade2; }
  .k-action { background: #005bb5; border-color: #007aff; }
  .k-green { background: #1e8449; border-color: #27ae60; color: #a9dfbf; }
  .k-red { background: #922b21; border-color: #c0392b; color: #f5b7b1; }
  .k-spec { background: #3d3d3d; }
</style>
<button id="kbd-toggle" onclick="toggleKbd()">🚀 لوحة التحكم</button>
<div id="virtual-keyboard">
  <!-- سطر تشغيل التطبيقات وإدارة النوافذ -->
  <div class="kbd-row">
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0066])">📁 الملفات</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0074])">💻 التيرمينال</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0065])">📝 Notepad++</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0062])">🌐 المتصفح</button>
    <button class="k-btn k-spec" onclick="sendCombo([0xffe3, 0xffe9, 0x0064])">🪟 سطح المكتب</button>
    <button class="k-btn k-red" onclick="sendCombo([0xffe9, 0xffc1])">❌ غلق نافذة</button>
  </div>
  <!-- سطر اختصارات التحرير والتصفح -->
  <div class="kbd-row">
    <button class="k-btn k-green" onclick="sendCombo([0xffe3, 0x0073])">💾 Save</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0074])">+ Tab</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0077])">✕ Tab</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0072])">🔄 Reload</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x006c])">🔍 URL</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0063])">📋 Copy</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0076])">📌 Paste</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0078])">✂️ Cut</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0061])">Select All</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x007a])">Undo</button>
  </div>
  <!-- سطر أزرار الكيبورد الكاملة -->
  <div class="kbd-row">
    <button class="k-btn k-spec" onclick="pressK(0xff1b)">Esc</button>
    <button class="k-btn k-spec" onclick="pressK(0xff09)">Tab</button>
    <button class="k-btn k-spec" onclick="pressK(0xffe3)">Ctrl</button>
    <button class="k-btn k-spec" onclick="pressK(0xffe9)">Alt</button>
    <button class="k-btn k-spec" onclick="pressK(0xffe1)">Shift</button>
    <button class="k-btn k-spec" onclick="pressK(0xffeb)">Win</button>
    <button class="k-btn k-spec" onclick="pressK(0xff08)">Bksp</button>
    <button class="k-btn k-spec" onclick="pressK(0xffff)">Del</button>
    <button class="k-btn k-action" onclick="pressK(0xff0d)">Enter ↵</button>
  </div>
  <!-- سطر الأسهم والدوال والتنقل -->
  <div class="kbd-row">
    <button class="k-btn" onclick="pressK(0xffbe)">F1</button>
    <button class="k-btn" onclick="pressK(0xffc2)">F5</button>
    <button class="k-btn" onclick="pressK(0xffc8)">F11</button>
    <button class="k-btn" onclick="pressK(0xffc9)">F12</button>
    <button class="k-btn" onclick="pressK(0xff50)">Home</button>
    <button class="k-btn" onclick="pressK(0xff57)">End</button>
    <button class="k-btn" onclick="pressK(0xff55)">PgUp</button>
    <button class="k-btn" onclick="pressK(0xff56)">PgDn</button>
    <button class="k-btn k-action" onclick="pressK(0xff51)">⬅️</button>
    <button class="k-btn k-action" onclick="pressK(0xff52)">⬆️</button>
    <button class="k-btn k-action" onclick="pressK(0xff54)">⬇️</button>
    <button class="k-btn k-action" onclick="pressK(0xff53)">➡️</button>
  </div>
</div>
<script>
  function toggleKbd() {
    var k = document.getElementById('virtual-keyboard');
    k.style.display = (k.style.display === 'none') ? 'flex' : 'none';
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
</script>
EOF

RUN sed -i '/<\/body>/e cat /usr/share/novnc/keyboard_addon.html' /usr/share/novnc/vnc.html && \
    sed -i '/<\/body>/e cat /usr/share/novnc/keyboard_addon.html' /usr/share/novnc/vnc_auto.html

# إعداد السيرفور مع خطة تفريغ الرام في الـ SSD
RUN cat << 'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:xvfb]
command=Xvfb :0 -screen 0 1024x768x16
priority=10
autorestart=true

[program:fluxbox]
command=fluxbox
environment=DISPLAY=":0"
priority=20
autorestart=true

[program:x11vnc]
command=x11vnc -display :0 -nopw -forever -shared -rfbport 5900 -noxdamage -nowf -wait 30 -defer 30
priority=30
autorestart=true

[program:websockify]
command=websockify --web /usr/share/novnc 10000 localhost:5900
priority=40
autorestart=true

[program:chromium]
command=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --disk-cache-dir=/tmp/chromium-cache --disk-cache-size=314572800 --js-flags="--max-old-space-size=150 --optimize-for-size" --renderer-process-limit=1 --enable-features=HighEfficiencyModeAvailable,PageDiscarding --enable-aggressive-tab-discard --disable-smooth-scrolling --disable-composited-antialiasing --window-size=1024,768 --start-maximized https://duckduckgo.com
environment=DISPLAY=":0"
priority=50
autorestart=true
EOF

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
