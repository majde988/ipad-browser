FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# تثبيت الأدوات ومتصفح Chromium وخادم noVNC
# أضفنا حزم الخطوط (fonts-liberation و fonts-noto-color-emoji) لأن غيابها
# يخلي بزاف من المواقع تبان بلا نصوص أو بمربعات فارغة (tofu boxes) جوا الحاوية،
# لأن الصفحات كترندري من طرف Chromium اللي خدام داخل الكونتينر، ماشي فجهاز المستخدم
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    chromium \
    supervisor \
    procps \
    git \
    ca-certificates \
    curl \
    python3 \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# تحميل نسخة noVNC الكلاسيكية ES5 المتوافقة مع iOS 9
RUN rm -rf /usr/share/novnc && \
    git clone --branch v0.6.2 --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc

# إنشاء مجلدات التنزيلات وحفظ الجلسات وملفات اللوق
RUN mkdir -p /root/Downloads /root/.config/chromium /var/log/supervisor

# حقن لوحة المفاتيح الكاملة والشاملة داخل صفحة noVNC
RUN cat << 'EOF' > /usr/share/novnc/keyboard_addon.html
<style>
  #kbd-toggle { position: fixed; bottom: 10px; right: 10px; z-index: 99999; background: #007aff; color: #fff; border: none; padding: 8px 14px; border-radius: 20px; font-weight: bold; font-size: 14px; box-shadow: 0 4px 10px rgba(0,0,0,0.5); cursor: pointer; }
  #virtual-keyboard { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(20,20,20,0.95); z-index: 99998; padding: 6px 4px; box-sizing: border-box; border-top: 2px solid #007aff; display: flex; flex-direction: column; gap: 4px; }
  .kbd-row { display: flex; justify-content: center; gap: 3px; overflow-x: auto; }
  .k-btn { background: #333; color: #fff; border: 1px solid #555; border-radius: 4px; padding: 6px 8px; font-size: 13px; font-family: monospace; font-weight: bold; cursor: pointer; text-align: center; min-width: 32px; }
  .k-btn:active { background: #007aff; border-color: #fff; }
  .k-action { background: #005bb5; border-color: #007aff; }
  .k-spec { background: #444; }
</style>
<button id="kbd-toggle" onclick="toggleKbd()">⌨️ الكلافي</button>
<div id="virtual-keyboard">
  <div class="kbd-row">
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0074])">+ Tab</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0077])">✕ Tab</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0072])">🔄 Reload</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x006c])">🔍 URL</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0063])">📋 Copy</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0076])">📌 Paste</button>
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0061])">Select All</button>
  </div>
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
  <div class="kbd-row">
    <button class="k-btn" onclick="pressK(0xffc2)">F5</button>
    <button class="k-btn" onclick="pressK(0xffc8)">F11</button>
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

# ضبط محرك البحث الافتراضي DuckDuckGo بطريقة موثوقة عبر "Managed Policy"
# ملاحظة: العلامة --default-search-provider-name وحدها (بلا باقي العلامات المرافقة لها)
# ماعندهاش تأثير مضمون على Chromium، لهذا بدلناها بملف Policy رسمي وموثق
RUN mkdir -p /etc/chromium/policies/managed && cat << 'EOF' > /etc/chromium/policies/managed/policy.json
{
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "DuckDuckGo",
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
  "DefaultSearchProviderSuggestURL": "https://duckduckgo.com/ac/?q={searchTerms}&type=list"
}
EOF

# سكريبت تشغيل x11vnc: إذا حددتي متغير البيئة VNC_PASSWORD وقت التشغيل
# (docker run -e VNC_PASSWORD=xxxx ...) يخدم VNC محمي بكلمة سر.
# إذا ماحددتيهاش، يخدم بلا حماية زي قبل، وكيسجل تحذير فالـ log باش تكون واعي بالمخاطرة
RUN cat << 'EOF' > /usr/local/bin/start-vnc.sh
#!/bin/sh
if [ -n "$VNC_PASSWORD" ]; then
    exec x11vnc -display :0 -passwd "$VNC_PASSWORD" -forever -shared -rfbport 5900
else
    echo "[start-vnc] تحذير: VNC_PASSWORD ماشي محدد -> x11vnc خدام بلا كلمة سر (-nopw). لا تخليو البورت 10000/5900 مفتوحين مباشرة للانترنت بلا VPN/جدار ناري." >&2
    exec x11vnc -display :0 -nopw -forever -shared -rfbport 5900
fi
EOF
RUN chmod +x /usr/local/bin/start-vnc.sh

# إعداد السيرفور: أضفنا logfile لكل سيرفيس (كانو مجلد /var/log/supervisor موجود
# بلا ما يتستخدم)، priority باش يبداو بالترتيب الصحيح (Xvfb قبل الباقي)،
# و stopasgroup/killasgroup باش docker stop ينضف كل الـ sub-processes
# (خصوصا Chromium اللي كيولد عدة processes) بلا ما يخلي زومبي وراه
RUN cat << 'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=Xvfb :0 -screen 0 1024x768x16
priority=10
autorestart=true
stdout_logfile=/var/log/supervisor/xvfb.log
stderr_logfile=/var/log/supervisor/xvfb.log

[program:fluxbox]
command=fluxbox
environment=DISPLAY=":0"
priority=20
autorestart=true
stdout_logfile=/var/log/supervisor/fluxbox.log
stderr_logfile=/var/log/supervisor/fluxbox.log

[program:x11vnc]
command=/usr/local/bin/start-vnc.sh
priority=30
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc.log

[program:websockify]
command=websockify --web /usr/share/novnc --heartbeat 30 10000 localhost:5900
priority=40
autorestart=true
stdout_logfile=/var/log/supervisor/websockify.log
stderr_logfile=/var/log/supervisor/websockify.log

[program:file_server]
command=python3 -m http.server 10001 --directory /root/Downloads
priority=40
autorestart=true
stdout_logfile=/var/log/supervisor/file_server.log
stderr_logfile=/var/log/supervisor/file_server.log

[program:chromium]
command=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --force-device-scale-factor=1.25 --window-size=1024,768 --start-maximized --restore-last-session --no-first-run --password-store=basic --disable-session-crashed-bubble https://duckduckgo.com
environment=DISPLAY=":0",HOME="/root"
priority=50
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/var/log/supervisor/chromium.log
stderr_logfile=/var/log/supervisor/chromium.log
EOF

# بورت noVNC (يشمل صفحة الويب + WebSocket) وبورت خادم ملفات Downloads
EXPOSE 10000 10001

# نخليو بروفايل Chromium ومجلد Downloads قابلين للـ mount كـ volume
# باش الجلسة والتحميلات ما تضيعش لو تعاد إنشاء الحاوية.
# نصيحة: خدمي `docker run -v chrome-profile:/root/.config/chromium -v chrome-downloads:/root/Downloads ...`
# باش الحفظ يبقى ثابت عبر container جديد ماشي غير عبر restart لنفس الكونتينر
VOLUME ["/root/.config/chromium", "/root/Downloads"]

# فحص صحة بسيط: نتأكدو أن صفحة noVNC كتجاوب
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fs http://localhost:10000/ || exit 1

CMD ["/usr/bin/supervisord"]
