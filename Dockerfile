FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV MOZ_DISABLE_CONTENT_SANDBOX=1

# 1. تثبيت الحزم
RUN apt-get update && apt-get install -y \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    firefox-esr \
    geany \
    geany-plugins \
    pcmanfm \
    lxterminal \
    nginx-light \
    supervisor \
    procps \
    feh \
    fonts-liberation \
    fonts-kacst \
    fonts-dejavu-core \
    locales \
    python3 \
    curl \
    tar \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# 2. تحميل noVNC v0.6.2 بـ curl
RUN rm -rf /usr/share/novnc && mkdir -p /usr/share/novnc && \
    curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v0.6.2.tar.gz | tar -xz --strip-components=1 -C /usr/share/novnc

# 3. المجلدات والخلفية
RUN mkdir -p /root/Desktop /root/Downloads /tmp/firefox-cache /root/.mozilla/firefox/mainprofile /root/.fluxbox /var/log/supervisor /var/run && \
    curl -sL "https://wallpaperaccess.com/full/764827.jpg" -o /root/wallpaper.jpg || \
    curl -sL "https://i.imgur.com/S9Mj5u9.jpg" -o /root/wallpaper.jpg || true

# 4. إعدادات Firefox فائقة الخفة مع تعطيل الاقتراحات المسببة للضغط
RUN cat << 'EOF' > /root/.mozilla/firefox/mainprofile/user.js
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("browser.theme.content-theme", 2);
user_pref("browser.theme.toolbar-theme", 2);
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");

user_pref("security.sandbox.content.level", 0);
user_pref("gfx.webrender.software", true);
user_pref("layers.acceleration.disabled", true);

user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.autoFill", false);

user_pref("webgl.override-renderer", "ANGLE (Intel, Intel(R) UHD Graphics 630 Direct3D11 vs_5_0 ps_5_0)");
user_pref("webgl.override-vendor", "Google Inc. (Intel)");
user_pref("webgl.disabled", false);

user_pref("dom.webdriver.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("general.useragent.override", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0");
user_pref("intl.accept_languages", "ar,en-US,en");

user_pref("dom.ipc.processCount", 1);
user_pref("browser.cache.memory.enable", false);
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.parent_directory", "/tmp/firefox-cache");
user_pref("browser.sessionstore.max_tabs_undo", 1);
user_pref("browser.startup.homepage", "https://www.google.com");
EOF

# 5. سكريبت استقبال الملفات
RUN cat << 'EOF' > /root/upload_server.py
import http.server
import socketserver
import cgi
import os

class UploadHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={'REQUEST_METHOD': 'POST', 'CONTENT_TYPE': self.headers.get('Content-Type', '')}
            )
            if 'file' in form:
                file_item = form['file']
                filename = os.path.basename(file_item.filename)
                save_path = os.path.join('/root/Desktop', filename)
                with open(save_path, 'wb') as f:
                    f.write(file_item.file.read())
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write(b"OK")
            else:
                self.send_response(400)
                self.end_headers()
        except Exception:
            self.send_response(500)
            self.end_headers()

if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    server = socketserver.TCPServer(('127.0.0.1', 8001), UploadHandler)
    server.serve_forever()
EOF

# 6. ضبط Nginx
RUN cat << 'EOF' > /etc/nginx/nginx.conf
user root;
worker_processes 1;
pid /var/run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    client_max_body_size 500M;
    server {
        listen 10000;
        location / {
            root /usr/share/novnc;
            index vnc.html;
        }
        location /websockify {
            proxy_pass http://127.0.0.1:6080/websockify;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
            proxy_buffering off;
        }
        location /downloads/ {
            alias /root/Downloads/;
            autoindex on;
        }
        location /upload {
            proxy_pass http://127.0.0.1:8001;
        }
    }
}
EOF

# 7. ضبط اختصارات سطح المكتب
RUN echo 'Control Mod1 e :Exec geany\n\
Control Mod1 t :Exec lxterminal\n\
Control Mod1 f :Exec pcmanfm /root/Desktop\n\
Control Mod1 b :Exec firefox-esr -profile /root/.mozilla/firefox/mainprofile "https://www.google.com"\n\
Control Mod1 d :ShowDesktop\n\
Mod1 F4 :Close' > /root/.fluxbox/keys && \
    echo '[begin] (Menu)\n\
[exec] (Notepad++ / Geany) {geany}\n\
[exec] (File Manager) {pcmanfm /root/Desktop}\n\
[exec] (Terminal) {lxterminal}\n\
[exec] (Firefox Dark) {firefox-esr -profile /root/.mozilla/firefox/mainprofile "https://www.google.com"}\n\
[separator]\n\
[restart] (Restart Desktop)\n\
[end]' > /root/.fluxbox/menu

# 8. حقن لوحة التحكم ومحاكي النقر البشري
RUN cat << 'EOF' > /usr/share/novnc/keyboard_addon.html
<style>
  #kbd-toggle { position: fixed; bottom: 8px; right: 8px; z-index: 99999; background: #007aff; color: #fff; border: none; padding: 7px 13px; border-radius: 20px; font-weight: bold; font-size: 13px; box-shadow: 0 4px 10px rgba(0,0,0,0.6); cursor: pointer; }
  #virtual-keyboard { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(18,18,18,0.97); z-index: 99998; padding: 5px 3px; box-sizing: border-box; border-top: 2px solid #007aff; display: flex; flex-direction: column; gap: 3px; }
  .kbd-row { display: flex; justify-content: center; gap: 3px; overflow-x: auto; padding-bottom: 1px; }
  .k-btn { background: #2c2c2c; color: #fff; border: 1px solid #444; border-radius: 4px; padding: 5px 7px; font-size: 12px; font-family: monospace; font-weight: bold; cursor: pointer; min-width: 28px; white-space: nowrap; }
  .k-btn:active { background: #007aff; border-color: #fff; }
  .k-bot { background: #6c3483; border-color: #8e44ad; color: #f5eef8; }
  .k-app { background: #1a5276; border-color: #2980b9; color: #5dade2; }
  .k-action { background: #005bb5; border-color: #007aff; }
  .k-green { background: #1e8449; border-color: #27ae60; color: #a9dfbf; }
  .k-red { background: #922b21; border-color: #c0392b; color: #f5b7b1; }
  .k-spec { background: #3d3d3d; }
</style>

<input type="file" id="fileUploader" style="display:none;" onchange="handleFileUpload(this)">
<button id="kbd-toggle" onclick="toggleKbd()">🎛️ مركز التحكم</button>

<div id="virtual-keyboard">
  <div class="kbd-row">
    <button class="k-btn k-bot" id="humanBtn" onclick="toggleHumanMode()">🖱️ نقر بشري (Anti-Bot): OFF</button>
    <button class="k-btn k-green" onclick="document.getElementById('fileUploader').click()">📤 رفع ملف (AirDrop)</button>
    <button class="k-btn k-green" onclick="window.open('/downloads/', '_blank')">📥 التنزيلات</button>
    <button class="k-btn k-action" onclick="pressK(0xff55)">📜 Scroll ⬆️</button>
    <button class="k-btn k-action" onclick="pressK(0xff56)">📜 Scroll ⬇️</button>
  </div>
  <div class="kbd-row">
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0062])">🦊 Firefox Dark</button>
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

  function handleFileUpload(input) {
    if (input.files.length === 0) return;
    var file = input.files[0];
    var fd = new FormData();
    fd.append('file', file);
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '/upload', true);
    xhr.onload = function() {
      if (xhr.status === 200) {
        alert('✅ تم رفع الملف "' + file.name + '" مباشرة إلى سطح المكتب في السحابة!');
      } else {
        alert('❌ فشل رفع الملف.');
      }
    };
    xhr.send(fd);
  }
</script>
EOF

RUN sed -i '/<\/body>/e cat /usr/share/novnc/keyboard_addon.html' /usr/share/novnc/vnc.html && \
    sed -i '/<\/body>/e cat /usr/share/novnc/keyboard_addon.html' /usr/share/novnc/vnc_auto.html

# 9. تشغيل Supervisord: بث كل السجلات الحية لـ Render (stdout/stderr) + إصلاح كراش الحافظة في x11vnc
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
command=x11vnc -display :0 -nopw -forever -shared -rfbport 5900 -noclipboard -nosel -wait 20 -defer 20
priority=30
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:websockify]
command=websockify --heartbeat 15 6080 localhost:5900
priority=35
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:upload_server]
command=python3 /root/upload_server.py
priority=35
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=nginx -g "daemon off;"
priority=40
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:firefox]
command=firefox-esr -profile /root/.mozilla/firefox/mainprofile --width 1024 --height 768 "https://www.google.com"
environment=DISPLAY=":0",HOME="/root",MOZ_DISABLE_CONTENT_SANDBOX="1"
priority=50
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

EXPOSE 10000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
