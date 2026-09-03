FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# تثبيت Chromium، Geany، مدير الملفات، التيرمينال، خادم الصوت PulseAudio، ffmpeg، وبوابة Nginx
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
    nginx-light \
    pulseaudio \
    pulseaudio-utils \
    ffmpeg \
    supervisor \
    procps \
    git \
    fonts-liberation \
    fonts-kacst \
    fonts-dejavu-core \
    locales \
    python3 \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# تحميل noVNC الكلاسيكية المتوافقة مع iOS 9
RUN rm -rf /usr/share/novnc && \
    git clone --branch v0.6.2 --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc

# إنشاء مجلدات العمل، سطح المكتب، والتنزيلات
RUN mkdir -p /root/Desktop /root/Downloads /tmp/chromium-cache /root/.config/chromium /root/.fluxbox /var/log/supervisor /var/www/uploads

# سكريبت استقبال الملفات المرفوعة من الآيباد وحفظها في سطح المكتب مباشرة
RUN cat << 'EOF' > /root/upload_server.py
import http.server
import socketserver
import cgi
import os

class UploadHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        form = cgi.FieldStorage(
            fp=self.rfile,
            headers=self.headers,
            environ={'REQUEST_METHOD': 'POST', 'CONTENT_TYPE': self.headers['Content-Type']}
        )
        if 'file' in form:
            file_item = form['file']
            filename = os.path.basename(file_item.filename)
            save_path = os.path.join('/root/Desktop', filename)
            with open(save_path, 'wb') as f:
                f.write(file_item.file.read())
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(400)
            self.end_headers()

if __name__ == '__main__':
    server = socketserver.TCPServer(('127.0.0.1', 8001), UploadHandler)
    server.serve_forever()
EOF

# ضبط إعدادات Nginx لدمج VNC، بث الصوت المباشر، ورفع وتنزيل الملفات في منفذ واحد 10000
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
            proxy_read_timeout 86400;
        }
        location /audio {
            proxy_pass http://127.0.0.1:8000;
            proxy_buffering off;
            proxy_read_timeout 86400;
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

# ضبط اختصارات البرامج لسطح المكتب
RUN echo 'Control Mod1 e :Exec geany\n\
Control Mod1 t :Exec lxterminal\n\
Control Mod1 f :Exec pcmanfm /root/Desktop\n\
Control Mod1 b :Exec chromium --no-sandbox "https://www.google.com/search?q=&udm=50"\n\
Control Mod1 d :ShowDesktop\n\
Mod1 F4 :Close' > /root/.fluxbox/keys && \
    echo '[begin] (Menu)\n\
[exec] (Notepad++ / Geany) {geany}\n\
[exec] (File Manager) {pcmanfm /root/Desktop}\n\
[exec] (Terminal) {lxterminal}\n\
[exec] (Google AI Browser) {chromium --no-sandbox "https://www.google.com/search?q=&udm=50"}\n\
[separator]\n\
[restart] (Restart Desktop)\n\
[end]' > /root/.fluxbox/menu

# حقن شريط التحكم الاحترافي الشامل (الصوت، AirDrop، والماوس)
RUN cat << 'EOF' > /usr/share/novnc/keyboard_addon.html
<style>
  #kbd-toggle { position: fixed; bottom: 8px; right: 8px; z-index: 99999; background: #007aff; color: #fff; border: none; padding: 7px 13px; border-radius: 20px; font-weight: bold; font-size: 13px; box-shadow: 0 4px 10px rgba(0,0,0,0.6); cursor: pointer; }
  #virtual-keyboard { position: fixed; bottom: 0; left: 0; width: 100%; background: rgba(18,18,18,0.97); z-index: 99998; padding: 5px 3px; box-sizing: border-box; border-top: 2px solid #007aff; display: flex; flex-direction: column; gap: 3px; }
  .kbd-row { display: flex; justify-content: center; gap: 3px; overflow-x: auto; }
  .k-btn { background: #2c2c2c; color: #fff; border: 1px solid #444; border-radius: 4px; padding: 5px 7px; font-size: 12px; font-family: monospace; font-weight: bold; cursor: pointer; min-width: 28px; white-space: nowrap; }
  .k-btn:active { background: #007aff; border-color: #fff; }
  .k-gold { background: #b7950b; border-color: #f1c40f; color: #fef9e7; }
  .k-app { background: #1a5276; border-color: #2980b9; color: #5dade2; }
  .k-action { background: #005bb5; border-color: #007aff; }
  .k-green { background: #1e8449; border-color: #27ae60; color: #a9dfbf; }
  .k-red { background: #922b21; border-color: #c0392b; color: #f5b7b1; }
  .k-spec { background: #3d3d3d; }
</style>

<audio id="remoteAudio" preload="none"></audio>
<input type="file" id="fileUploader" style="display:none;" onchange="handleFileUpload(this)">

<button id="kbd-toggle" onclick="toggleKbd()">🎛️ مركز التحكم</button>

<div id="virtual-keyboard">
  <!-- سطر الوسائط، الصوت، وتبادل الملفات السحابي -->
  <div class="kbd-row">
    <button class="k-btn k-gold" id="audioBtn" onclick="toggleAudio()">🔊 تشغيل الصوت</button>
    <button class="k-btn k-green" onclick="document.getElementById('fileUploader').click()">📤 رفع ملف (AirDrop)</button>
    <button class="k-btn k-green" onclick="window.open('/downloads/', '_blank')">📥 التنزيلات</button>
    <button class="k-btn k-action" onclick="pressK(0xff55)">📜 Scroll ⬆️</button>
    <button class="k-btn k-action" onclick="pressK(0xff56)">📜 Scroll ⬇️</button>
    <button class="k-btn k-spec" onclick="sendCombo([0xffe3, 0x003d])">🔍 Zoom +</button>
    <button class="k-btn k-spec" onclick="sendCombo([0xffe3, 0x002d])">🔍 Zoom -</button>
  </div>
  <!-- سطر التطبيقات المباشرة -->
  <div class="kbd-row">
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0062])">🌐 Google AI</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0066])">📁 سطح المكتب</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0074])">💻 التيرمينال</button>
    <button class="k-btn k-app" onclick="sendCombo([0xffe3, 0xffe9, 0x0065])">📝 Notepad++</button>
    <button class="k-btn k-spec" onclick="sendCombo([0xffe3, 0xffe9, 0x0064])">🪟 إخفاء الكل</button>
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
    <button class="k-btn k-action" onclick="sendCombo([0xffe3, 0x0061])">Select All</button>
  </div>
  <!-- سطر أزرار الكيبورد والأسهم الكاملة -->
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
  // تشغيل / إيقاف الصوت المباشر من السيرفور
  function toggleAudio() {
    var a = document.getElementById('remoteAudio');
    var btn = document.getElementById('audioBtn');
    if (a.paused) {
      a.src = '/audio?' + new Date().getTime();
      a.play();
      btn.innerText = '🔊 الصوت شغال';
      btn.style.background = '#28a745';
    } else {
      a.pause();
      a.src = '';
      btn.innerText = '🔇 تشغيل الصوت';
      btn.style.background = '#b7950b';
    }
  }
  // رفع الملفات مباشرة إلى سطح المكتب في السحابة
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

# سكريبت تشغيل بث الصوت عبر ffmpeg
RUN cat << 'EOF' > /usr/local/bin/start-audio.sh
#!/bin/sh
pulseaudio -D --exit-idle-time=-1
exec ffmpeg -f pulse -i default.monitor -ac 2 -ar 44100 -b:a 64k -f mp3 -listen 1 http://127.0.0.1:8000
EOF
RUN chmod +x /usr/local/bin/start-audio.sh

# إعداد Supervisord لإدارة كافة الخدمات بالتنسيق التام
RUN cat << 'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:xvfb]
command=Xvfb :0 -screen 0 1024x768x16
priority=10
autorestart=true

[program:audio]
command=/usr/local/bin/start-audio.sh
priority=15
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
command=websockify 6080 localhost:5900
priority=35
autorestart=true

[program:upload_server]
command=python3 /root/upload_server.py
priority=35
autorestart=true

[program:nginx]
command=nginx -g "daemon off;"
priority=40
autorestart=true

[program:chromium]
command=chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --disk-cache-dir=/tmp/chromium-cache --disk-cache-size=314572800 --js-flags="--max-old-space-size=150 --optimize-for-size" --renderer-process-limit=1 --enable-features=HighEfficiencyModeAvailable,PageDiscarding --enable-aggressive-tab-discard --disable-smooth-scrolling --disable-composited-antialiasing --window-size=1024,768 --start-maximized "https://www.google.com/search?q=&udm=50"
environment=DISPLAY=":0"
priority=50
autorestart=true
EOF

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
