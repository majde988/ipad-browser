FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# تثبيت الأدوات، متصفح Chromium، محرر Geany، وحزم الخطوط العربية واللاتينية الكاملة
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    chromium \
    geany \
    geany-plugins \
    supervisor \
    procps \
    git \
    fonts-liberation \
    fonts-kacst \
    fonts-dejavu-core \
    locales \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# تحميل noVNC الكلاسيكية ES5
RUN rm -rf /usr/share/novnc && \
    git clone --branch v0.6.2 --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc

RUN mkdir -p /root/.config/chromium /root/.fluxbox /var/log/supervisor

# إعداد اختصار الكيبورد وقائمة سطح المكتب
RUN echo 'Control Mod1 e :Exec geany' > /root/.fluxbox/keys && \
    echo '[begin] (Menu)\n[exec] (Notepad++ / Geany) {geany}\n[exec] (Chromium Browser) {chromium --no-sandbox}\n[separator]\n[restart] (Restart Desktop)\n[end]' > /root/.fluxbox/menu

# حقن لوحة المفاتيح
RUN cat << 'EOF' > /usr/share/novnc/keyboard_addon.html
<style>
  #kbd-toggle { position: fixed; bottom: 10px; right: 10px; z-index: 99999; background: #007aff; color: #fff; border: none; padding: 8px 14px; border-radius: 20px; font-weight: bold; font-size: 14px; cursor: pointer; }
  #virtual-keyboard { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(20,20,20,0.95); z-index: 99998; padding: 6px 4px; box-sizing: border-box; border-top: 2px solid #007aff; display: flex; flex-direction: column; gap: 4px; }
  .kbd-row { display: flex; justify-content: center; gap: 3px; overflow-x: auto; }
  .k-btn { background: #333; color: #fff; border: 1px solid #555; border-radius: 4px; padding: 6px 8px; font-size: 13px; font-family: monospace; font-weight: bold; cursor: pointer; min-width: 32px; }
  .k-btn:active { background: #007aff; border-color: #fff; }
  .k-action { background: #005bb5; border-color: #007aff; }
  .k-green { background: #28a745; border-color: #218838; }
  .k-spec { background: #444; }
</style>
<button id="kbd-toggle" onclick="toggleKbd()">⌨️ الكلافي</button>
<div id="virtual-keyboard">
  <div class="kbd-row">
    <button class="k-btn k-green" onclick="sendCombo([0xffe3, 0xffe9, 0x0065])">📝 Notepad++</button>
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
    <button class="k-btn k-spec" onclick="pressK(0xffeb)">Win</button>
    <button class="k-btn k-spec" onclick="pressK(0xff08)">Bksp</button>
    <button class="k-btn k-spec" onclick="pressK(0xffff)">Del</button>
    <button class="k-btn k-action" onclick="pressK(0xff0d)">Enter ↵</button>
  </div>
  <div class="kbd-row">
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

# إعداد السيرفور
RUN echo '[supervisord]\nnodaemon=true\n\n\
[program:xvfb]\ncommand=Xvfb :0 -screen 0 1024x768x16\nautorestart=true\n\n\
[program:fluxbox]\ncommand=fluxbox\nenvironment=DISPLAY=":0"\nautorestart=true\n\n\
[program:x11vnc]\ncommand=x11vnc -display :0 -nopw -forever -shared -rfbport 5900 -noxdamage -nowf -wait 30 -defer 30\nautorestart=true\n\n\
[program:websockify]\ncommand=websockify --web /usr/share/novnc 10000 localhost:5900\nautorestart=true\n\n\
[program:chromium]\ncommand=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --disable-smooth-scrolling --disable-composited-antialiasing --renderer-process-limit=2 --window-size=1024,768 --start-maximized https://duckduckgo.com\nenvironment=DISPLAY=":0"\nautorestart=true\n' > /etc/supervisor/conf.d/supervisord.conf

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
